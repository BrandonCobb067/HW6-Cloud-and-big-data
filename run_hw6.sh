#!/usr/bin/env bash
# Run the first 500,000 reviews in local Hive and build the submission.
set -euo pipefail
unset DEBUG
cd "$(dirname "$0")"
OUT=outputs/assignment
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo "Usage: bash run_hw6.sh [path/to/reviews_Video_Games.json.gz]"
  exit 0
fi
if [[ $# -gt 1 ]]; then
  echo "Expected at most one input path. See --help." >&2
  exit 1
fi
INPUT="${1:-data/reviews_Video_Games.json.gz}"
if [[ ! -f "$INPUT" ]]; then
  echo "Dataset not found: $INPUT. See README.md for the download command." >&2
  exit 1
fi
INPUT="$(realpath "$INPUT")"
for dependency in python3 beeline schematool; do
  command -v "$dependency" >/dev/null || { echo "Missing command: $dependency" >&2; exit 1; }
done
mkdir -p .runtime/conf .runtime/.beeline "$OUT" data
# Keep Derby logs and Beeline history with generated runtime files.
export HADOOP_CLIENT_OPTS="${HADOOP_CLIENT_OPTS:-} -Dderby.stream.error.file=$PWD/.runtime/derby.log -Duser.home=$PWD/.runtime"
python3 - <<'PY'
from pathlib import Path
from xml.sax.saxutils import escape
root = Path('.runtime').resolve()
props = {
 'javax.jdo.option.ConnectionURL': f'jdbc:derby:;databaseName={root}/metastore_schema;create=true',
 'javax.jdo.option.ConnectionDriverName': 'org.apache.derby.iapi.jdbc.AutoloadedDriver',
 'hive.metastore.warehouse.dir': f'file://{root}/warehouse_schema',
 'hive.exec.scratchdir': f'{root}/scratch',
 'hive.exec.local.scratchdir': f'{root}/local-scratch',
 'hive.execution.engine': 'mr',
 'hive.metastore.schema.verification': 'false',
 'datanucleus.schema.autoCreateAll': 'true',
 'fs.defaultFS': 'file:///',
 'mapreduce.framework.name': 'local',
 'hadoop.tmp.dir': f'{root}/hadoop-tmp',
 'hive.server2.enable.doAs': 'false',
 'metastore.metadata.transformer.class': ' ',
 'hive.strict.managed.tables': 'false',
}
Path('.runtime/conf/hive-site.xml').write_text(
 '<configuration>' + ''.join(
 f'<property><name>{k}</name><value>{escape(v)}</value></property>'
 for k, v in props.items()) + '</configuration>\n')
# Retain the installed Hive's Java/Hadoop setup when available.
hive_home = Path(__import__('os').environ.get('HIVE_HOME', '/opt/hive'))
source = hive_home / 'conf/hive-env.sh'
if source.exists():
 Path('.runtime/conf/hive-env.sh').write_text(source.read_text())
PY
export HIVE_CONF_DIR="$PWD/.runtime/conf"
HIVE_URL='jdbc:hive2://'
export HADOOP_HEAPSIZE_MAX=3072
# Beeline runs batch SQL with redirected output. Native JLine terminal discovery
# can fail from a real terminal on Java 21 when its FFM provider requires preview.
export HADOOP_CLIENT_OPTS="${HADOOP_CLIENT_OPTS:-} -Xmx3g -Dorg.jline.terminal.provider=dumb"
if [[ ! -f .runtime/schema-initialized ]]; then
  schematool -dbType derby -initSchema </dev/null > .runtime/schema-init.log 2>&1
  touch .runtime/schema-initialized
fi

echo "Preparing the first 500,000 reviews..."
python3 prepare_data.py "$INPUT" data/games_prepared.json > "$OUT/PrepareOutput.txt"
cat "$OUT/PrepareOutput.txt"
DATA_PATH="$(realpath data/games_prepared.json)"
if [[ "$DATA_PATH" == *"'"* || "$DATA_PATH" == *\\* || "$DATA_PATH" == *$'\n'* ]]; then
  echo "Use a repository path without quotes, backslashes, or newlines." >&2
  exit 1
fi
for part in 1 2 3; do
  echo "Running Part $part in Apache Hive..."
  if ! beeline -u "$HIVE_URL" --force=false --showHeader=true --outputformat=tsv2 \
    -e "SET DATA_PATH=$DATA_PATH;
$(cat "Part${part}.hql")" \
    </dev/null > "$OUT/Part${part}Output.txt" 2> "$OUT/Part${part}Log.txt"; then
    echo "Part $part failed. See $OUT/Part${part}Log.txt" >&2
    tail -20 "$OUT/Part${part}Log.txt" >&2
    exit 1
  fi
  echo "Part $part complete."
done
python3 - "$INPUT" "$OUT" <<'PY'
import hashlib
import re
import shutil
import sys
import zipfile
from pathlib import Path

source, output = map(Path, sys.argv[1:])
submission = Path('submission')
with source.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
preamble = (
    'HW6 - Apache Hive: queries and actual results\n'
    f'Dataset: {source.name}\nSource SHA-256: {digest}\n'
    'Scope: first 500,000 records\nLoaded reviews: 500,000\n\n'
    'Text results replace screenshots. No result rows are omitted.\n'
    'See Dataset-Note.txt for the dataset difference.\n\n'
)
explanations = {
    '6': 'The table is bucketed by unix_review_time into three buckets.\n',
    '7': 'Each row gives the earliest and latest calendar review dates in one '
         'physical bucket. Hash bucketing distributes rows by unix_review_time '
         'rather than consecutive time intervals, so the bucket date ranges can overlap.\n',
    '8': 'The filter selects products with more than one helpful vote per review '
         'on average. This can identify products whose reviews readers find useful. '
         'It is not a helpfulness ratio and may favor products with more exposure.\n',
}
reports = {}
for part, problems in ((1, ('1', '2', '3')), (2, ('3', '4', '5')), (3, ('6', '7', '8'))):
    query = Path(f'Part{part}.hql').read_text()
    separator = (r"(?m)^(?=SELECT '=== Part 3 Problem (\d) ===' AS section;)"
                 if part == 3 else r'(?m)^-- Problem (\d)\n')
    queries = re.split(separator, query)
    queries_by_problem = dict(zip(queries[1::2], queries[2::2]))
    results = re.split(r'(?m)^=== Part \d Problem (\d) ===\n',
                       (output / f'Part{part}Output.txt').read_text())
    if tuple(results[1::2]) != problems:
        raise ValueError(f'Part {part}: incomplete Hive output')
    for problem, result in zip(results[1::2], results[2::2]):
        result = re.sub(r'\nsection\n?$', '\n', result)
        setup = queries[0] if part == 1 and problem == '1' else 'USE hw6;\n\n'
        explanation = '\nEXPLANATION\n\n' + explanations[problem] if part == 3 else ''
        reports[f'Part{part}-Problem{problem}.txt'] = (
            preamble + f'PART {part}, PROBLEM {problem}: QUERIES\n\n'
            + setup + queries_by_problem[problem] + explanation
            + f'\nPART {part}, PROBLEM {problem}: ACTUAL HIVE OUTPUT\n\n' + result)
(submission / 'assignment').mkdir(parents=True, exist_ok=True)
(submission / 'Dataset-Note.txt').write_text(
    'HW6 - Dataset note\n\n'
    'The assignment requests the first 500,000 reviews but links\n'
    'reviews_Video_Games_5.json.gz, a 5-core dataset with only 231,780 reviews.\n'
    'To obtain 500,000 records, this submission uses the first 500,000 reviews\n'
    'in source order from reviews_Video_Games.json.gz (the full category).\n'
    'Source: https://snap.stanford.edu/data/amazon/productGraph/categoryFiles/reviews_Video_Games.json.gz\n'
    'This changes the review population from the linked 5-core dataset.\n\n'
    'Part1.hql, Part2.hql, and Part3.hql contain all queries. The required\n'
    'explanations are in the text reports. The nine reports contain queries and\n'
    'complete Apache Hive output, replacing screenshots. No result rows are\n'
    'omitted; the combined results file would duplicate these reports.\n'
    'Both problems numbered 3 are included. All reports use 500,000 reviews.\n'
)
files = [submission / 'Dataset-Note.txt']
for part in (1, 2, 3):
    path = submission / f'Part{part}.hql'
    shutil.copy2(path.name, path)
    files.append(path)
for name, text in reports.items():
    path = submission / 'assignment' / name
    path.write_text(text)
    files.append(path)
with zipfile.ZipFile('HW6-Submission.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
    for path in files:
        bundle.write(path)
print('Submission ready: HW6-Submission.zip (13 files)')
PY
