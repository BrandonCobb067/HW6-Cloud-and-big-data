#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo "Usage: bash run_hw6.sh /full/path/reviews_Video_Games_5.json.gz" >&2
  exit 1
fi
INPUT="$(realpath "$1")"
cd "$(dirname "$0")"
command -v python3 >/dev/null
command -v beeline >/dev/null
mkdir -p data outputs
python3 prepare_data.py "$INPUT" data/games_prepared.json > outputs/PrepareOutput.txt
DATA_PATH="$(realpath data/games_prepared.json)"
if [[ "$DATA_PATH" == *"'"* || "$DATA_PATH" == *\\* || "$DATA_PATH" == *$'\n'* ]]; then
  echo "Use a repository path without quotes, backslashes, or newlines." >&2
  exit 1
fi
HIVE_URL="${HIVE_URL:-jdbc:hive2://localhost:10000/default}"
beeline -u "$HIVE_URL" --force=false --showHeader=true --outputformat=table \
  --hiveconf "DATA_PATH=$DATA_PATH" -f Part1.hql \
  > outputs/Part1Output.txt 2> outputs/Part1Errors.txt
beeline -u "$HIVE_URL" --force=false --showHeader=true --outputformat=table \
  -f Part2.hql > outputs/Part2Output.txt 2> outputs/Part2Errors.txt
echo "Results saved in outputs/."
