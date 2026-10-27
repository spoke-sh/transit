#!/usr/bin/env python3
"""Adversarial child used only by host-runtime boundary proofs."""
import json
from pathlib import Path
import sys
import time

config = Path(sys.argv[1])
mode = config.read_text()
for line in sys.stdin:
    request = json.loads(line)
    if "hello" in request:
        response = {"host_version": 1, "station_version": 1, "transit_version": 1}
    elif mode == "stall":
        config.with_suffix(".entered").write_text("entered")
        time.sleep(5)
        break
    elif mode == "malformed":
        print('{"status":1.5,"value":null}', flush=True)
        break
    elif mode == "oversize":
        print("x" * (528 * 1024 + 1), flush=True)
        break
    elif mode == "exit":
        break
    else:
        response = request
    print(json.dumps({"status": 0, "value": response}), flush=True)
