import gzip
import json
import os
import sys
from pathlib import Path


def prepare(source, destination, limit=500000):
    source = Path(source)
    destination = Path(destination)
    temporary = destination.with_name(destination.name + ".part")
    if source.resolve() in [destination.resolve(), temporary.resolve()]:
        raise ValueError("Input and output paths must differ.")

    destination.parent.mkdir(parents=True, exist_ok=True)
    opener = gzip.open if source.suffix == ".gz" else open
    count = 0
    try:
        with opener(source, "rt", encoding="utf-8") as reader, temporary.open(
            "w", encoding="utf-8", newline="\n"
        ) as writer:
            for line in reader:
                row = json.loads(line)
                count += 1
                row["review_id"] = count
                writer.write(json.dumps(row) + "\n")
                if count == limit:
                    break
        if count == 0:
            raise ValueError("No records found.")
        os.replace(temporary, destination)
    except Exception:
        if temporary.exists():
            temporary.unlink()
        raise
    return count


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python3 prepare_data.py input.json.gz output.json")
    count = prepare(sys.argv[1], sys.argv[2])
    print("Records prepared:", count)
    if count < 500000:
        print("Input contains fewer than 500000 records.")
