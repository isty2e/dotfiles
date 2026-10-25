import json
import os
import sys
from pathlib import Path

arguments = sys.argv[1:]
output = Path(arguments[arguments.index("--output") + 1])
url = arguments[-1]
name = url.rsplit("/", 1)[-1]
with Path(os.environ["CURL_LOG"]).open("a") as log:
    log.write(json.dumps({"url": url, "output": str(output)}) + "\n")

if name == os.environ.get("FAIL_ASSET"):
    output.write_text("partial download")
    sys.exit(22)

if name == os.environ.get("EMPTY_ASSET"):
    output.touch()
else:
    output.write_bytes((Path(os.environ["ASSET_SOURCE"]) / name).read_bytes())
