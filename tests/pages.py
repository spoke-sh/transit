"""Qualify immutable pages through owned disk Ursula and cache-free restart."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import time
from storage import Fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--keys", type=int, default=64)
    parser.add_argument("--cache", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    binary = str(Path(args.binary).resolve(strict=True))
    evidence = {"version": 1, "status": "inconclusive", "profile": "immutable page primitive; not running authority",
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root)),
                "binary_sha256": hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                "platform": platform.platform(), "logical_cpus": os.cpu_count(),
                "zig": subprocess.check_output(["zig", "version"], text=True).strip(),
                "sample_interval_ms": 20, "phases": []}
    destination = root / ".cache/verification" / f"pages-{args.keys}-{args.cache}.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with Fixture() as fixture:
            for i, phase in enumerate(("write", "recover", "checkpoint", "trim_recover")):
                if i:
                    fixture.start()
                started = time.monotonic()
                peak = {"rss_kib": 0, "threads": 0, "fds": 0}
                process = subprocess.Popen([binary, fixture.url, phase, str(args.keys), str(args.cache)],
                    env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                try:
                    while process.poll() is None:
                        if time.monotonic() - started > args.timeout:
                            raise TimeoutError(f"page proof {phase} exceeded {args.timeout}s")
                        status = Path(f"/proc/{process.pid}/status")
                        try:
                            text = status.read_text()
                            for field, label in (("VmHWM", "rss_kib"), ("Threads", "threads")):
                                match = re.search(rf"^{field}:\s+(\d+)", text, re.M)
                                if match:
                                    peak[label] = max(peak[label], int(match[1]))
                            peak["fds"] = max(peak["fds"], len(list(Path(f"/proc/{process.pid}/fd").iterdir())))
                        except FileNotFoundError:
                            pass
                        time.sleep(0.02)
                    stdout, stderr = process.communicate()
                    if process.returncode:
                        raise RuntimeError(f"page proof {phase}: {stderr[-12000:]}")
                    result = json.loads(stdout)
                    result.update(seconds=round(time.monotonic() - started, 3), sampled_peak=peak)
                    result["wal_file_bytes"] = sum(path.stat().st_size for path in (fixture.root / "wal").rglob("*") if path.is_file())
                    evidence["phases"].append(result)
                    print(f"Immutable pages: {json.dumps(result)}", flush=True)
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.communicate()
                fixture.stop()  # SIGKILL: no graceful shutdown flush.
        evidence["status"] = "passed"
        print("Immutable page roots, old views and deleted-key absence survive disk WAL interruption and root-only checkpoint/trim.")
    finally:
        destination.write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
