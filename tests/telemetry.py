"""Bounded, cancelable telemetry writer against real blocked/closed OS pipes."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def run(binary):
    command = [str(binary)]
    if hasattr(os, "sched_getaffinity"):
        command = ["taskset", "-c", str(min(os.sched_getaffinity(0))), *command]
    measured = {}
    for mode in ("off", "drained", "stalled", "closed"):
        env = os.environ | {"LOG_FORMAT": "json", "LOG_LEVEL": "off" if mode == "off" else "info"}
        start = time.monotonic()
        with subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as child:
            if mode == "stalled" and sys.platform == "linux":
                import fcntl
                fcntl.fcntl(child.stderr.fileno(), fcntl.F_SETPIPE_SZ, 4096)
            if mode == "closed":
                child.stderr.close()
            if mode in ("stalled", "closed"):
                # Do not drain stderr through communicate: that would hide blocking.
                child.wait(timeout=4)
                stdout = child.stdout.read()
                stderr = child.stderr.read() if mode == "stalled" else b""
            else:
                stdout, stderr = child.communicate(timeout=4)
            assert child.returncode == 0, (mode, child.returncode, stderr[-2000:])
        value = json.loads(stdout)
        assert value["snapshot"]["active"] == 0
        assert value["snapshot"]["outcomes"][0] == 10000
        assert sum(value["snapshot"]["buckets"]) == 10000
        if mode == "closed":
            assert value["sink_errors"] > 0
        if mode == "stalled" and sys.platform == "linux":
            assert value["writer_was_busy"], value
        if mode != "off":
            assert value["dropped"] + value["suppressed"] > 0
        if mode in ("drained", "stalled"):
            assert stderr, mode
        for line in stderr.splitlines():
            record = json.loads(line)
            assert record["schema_version"] == 1 and len(line) < 2048
            assert len(record["service_instance_id"]) == 32
        measured[mode] = {"wall_seconds": round(time.monotonic() - start, 3), "emit_ms": round(value["emitted_ns"] / 1e6, 3)}
    print("Telemetry: 10,000 completions, bounded queues, metrics despite log loss, and one-CPU pipe cancellation passed:", measured)


if __name__ == "__main__":
    run(Path(sys.argv[1]).resolve())
