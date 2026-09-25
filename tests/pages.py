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


def metrics():
    return {"samples": 0, "rss_kib": None, "threads": None, "fds": None}


def sample_process(pid, peak):
    """Report unavailable samples as null, never as zero resource use."""
    try:
        status = Path(f"/proc/{pid}/status").read_text()
        fds = len(list(Path(f"/proc/{pid}/fd").iterdir()))
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return
    peak["samples"] += 1
    for field, label in (("VmHWM", "rss_kib"), ("Threads", "threads")):
        match = re.search(rf"^{field}:\s+(\d+)", status, re.M)
        if match:
            peak[label] = max(peak[label] or 0, int(match[1]))
    peak["fds"] = max(peak["fds"] or 0, fds)


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
                peak, provider_peak = metrics(), metrics()
                assert fixture.server is not None
                sample_process(fixture.server.pid, provider_peak)
                process = subprocess.Popen([binary, fixture.url, phase, str(args.keys), str(args.cache)],
                    env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                try:
                    while process.poll() is None:
                        if time.monotonic() - started > args.timeout:
                            raise TimeoutError(f"page proof {phase} exceeded {args.timeout}s")
                        sample_process(process.pid, peak)
                        sample_process(fixture.server.pid, provider_peak)
                        time.sleep(0.02)
                    stdout, stderr = process.communicate()
                    if process.returncode:
                        raise RuntimeError(f"page proof {phase}: {stderr[-12000:]}")
                    result = json.loads(stdout)
                    sample_process(fixture.server.pid, provider_peak)
                    result.update(seconds=round(time.monotonic() - started, 3),
                                  sampled_peak=peak, provider_sampled_peak=provider_peak)
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
