"""Kill the trusted sealed-input host at durable boundaries, then read its original."""
import argparse
import hashlib
import json
from pathlib import Path
import signal
import subprocess
import sys
import time

from runner import capture
from runner.paths import ROOT

BOUNDARIES = ("reservation", "hold", "readiness", "seal", "decision",
              "release_pending", "release_accepted")


def kill_at(binary, state, boundary):
    marker = state / "boundary"
    marker.unlink(missing_ok=True)
    child = subprocess.Popen([str(binary), str(state), "run", boundary],
                             stdin=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 120
        while not marker.exists():
            if child.poll() is not None:
                raise RuntimeError(f"host exited before {boundary}: {child.returncode}")
            if time.monotonic() >= deadline:
                raise TimeoutError(f"host did not reach {boundary}")
            time.sleep(0.05)
        assert marker.read_text() == boundary
        assert child.poll() is None, "marker must identify a live blocked process"
        child.kill()
        assert child.wait(timeout=10) == -signal.SIGKILL
        print(json.dumps({"boundary": boundary, "pid": child.pid,
                          "signal": "SIGKILL", "joined": True}), flush=True)
    finally:
        if child.poll() is None:
            child.kill()
        child.wait()
        child.stdin.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--kill-at", choices=BOUNDARIES)
    parser.add_argument("--state", type=Path)
    args = parser.parse_args()
    binary = args.binary.resolve(strict=True)
    if args.kill_at:
        kill_at(binary, args.state, args.kill_at)
        return
    directory = capture.directory(ROOT / ".cache/verification/source-capture/process.json")
    state = directory / "state"
    state.mkdir()
    commands = [("prepare", [str(binary), str(state), "prepare", "finish"])]
    commands += [(boundary, [sys.executable, "-B", "tests/runner/launch.py",
                            "tests/catalog/source_capture_process.py", str(binary),
                            "--state", str(state), "--kill-at", boundary])
                 for boundary in BOUNDARIES]
    commands.append(("finish", [str(binary), str(state), "run", "finish"]))
    meta = {**capture.provenance(ROOT), "completed": False, "active_task": None,
            "expected_tasks": [name for name, _ in commands],
            "binary": capture.identity(binary), "result_count": 0}
    results = []
    print(f"Capture process artifacts: {directory}", flush=True)
    try:
        for name, command in commands:
            meta["active_task"] = name
            capture.write_json(directory / "meta.json", meta)
            result = {"task": name}
            results.append(result)
            capture.write_json(directory / "results.json", results)
            capture.run(command, cwd=ROOT, log=directory / f"{name}.log",
                        result=result).check_returncode()
            capture.write_json(directory / "results.json", results)
            meta["result_count"] = len(results)
        report = json.loads((state / "result.json").read_text())
        expected = hashlib.sha256()
        chunk = bytes((i * 73 + 19) & 255 for i in range(65536))
        for _ in range(64):
            expected.update(chunk)
        assert report["phase"] == "released"
        assert report["evidence"]["body"] == {
            "bytes": 4 * 1024 * 1024, "sha256": list(expected.digest())}
        assert report["outcome"]["append"]["first"] == 0
        assert report["outcome"]["append"]["next"] == 1
        assert report["upstream"]["dependents"] == 0
        assert report["upstream"]["caller"] == "held"
        assert 0 < report["data_peak_bytes"] <= 7 * 1024 * 1024
        assert 0 < report["adapter_peak_bytes"] <= 2 * 1024 * 1024
        meta.update(completed=True, active_task=None,
                    observation=capture.identity(state / "result.json"))
    finally:
        capture.write_json(directory / "results.json", results)
        capture.write_json(directory / "meta.json", meta)
    capture.verify(directory)
    print("Seven real process deaths recovered one 4 MiB original capture and offset.")


if __name__ == "__main__":
    main()
