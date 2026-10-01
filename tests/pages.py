"""Qualify immutable pages through owned disk Ursula and cache-free restart."""
from pathlib import Path
from contextlib import ExitStack
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
    return {"samples": 0, "rss_kib": None, "threads": None, "fds": None,
            "stack_kib": None, "read_bytes": None, "write_bytes": None}


def sample_process(pid, peak):
    """Report unavailable samples as null, never as zero resource use."""
    try:
        status = Path(f"/proc/{pid}/status").read_text()
        fds = len(list(Path(f"/proc/{pid}/fd").iterdir()))
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return
    peak["samples"] += 1
    for field, label in (("VmHWM", "rss_kib"), ("Threads", "threads"), ("VmStk", "stack_kib")):
        match = re.search(rf"^{field}:\s+(\d+)", status, re.M)
        if match:
            peak[label] = max(peak[label] or 0, int(match[1]))
    peak["fds"] = max(peak["fds"] or 0, fds)
    try:
        counters = Path(f"/proc/{pid}/io").read_text()
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return
    for field in ('read_bytes', 'write_bytes'):
        match = re.search(rf'^{field}:\s+(\d+)', counters, re.M)
        if match:
            peak[field] = max(peak[field] or 0, int(match[1]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--mutation-batch", type=int, choices=(1, 8), default=8)
    parser.add_argument("--keys", type=int, default=64)
    parser.add_argument("--cache", type=int, default=2)
    parser.add_argument("--layout", choices=("closed", "packed"), default="packed")
    parser.add_argument("--cold-s3", action="store_true", help="qualify persistent cold storage using pinned native MinIO")
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    binary = str(Path(args.binary).resolve(strict=True))
    evidence = {"version": 1, "layout": args.layout, "status": "inconclusive", "profile": "immutable page primitive; not running authority",
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root)),
                "binary_sha256": hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                "platform": platform.platform(), "logical_cpus": os.cpu_count(),
                "zig": subprocess.check_output(["zig", "version"], text=True).strip(),
                "sample_interval_ms": 20, "phases": []}
    storage_profile = "s3" if args.cold_s3 else "hot"
    evidence["storage_profile"] = storage_profile
    destination = root / ".cache/verification" / f"pages-{args.layout}-{storage_profile}-{args.keys}-{args.cache}-batch{args.mutation_batch}.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with ExitStack() as resources:
            cold = None
            if args.cold_s3:
                from cold_storage import ColdStore
                cold = resources.enter_context(ColdStore())
                evidence["cold_provider"] = cold.identity
            fixture = resources.enter_context(Fixture(cold.config() if cold else None))
            for i, phase in enumerate(("write", "recover", "checkpoint", "trim_recover")):
                if i:
                    fixture.start()
                started = time.monotonic()
                peak, provider_peak, cold_peak = metrics(), metrics(), metrics()
                assert fixture.server is not None
                sample_process(fixture.server.pid, provider_peak)
                process = subprocess.Popen([binary, fixture.url, phase, str(args.keys), str(args.cache), args.layout, str(args.mutation_batch)],
                    env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                try:
                    while process.poll() is None:
                        if time.monotonic() - started > args.timeout:
                            raise TimeoutError(f"page proof {phase} exceeded {args.timeout}s")
                        sample_process(process.pid, peak)
                        sample_process(fixture.server.pid, provider_peak)
                        if cold:
                            sample_process(cold.pid, cold_peak)
                        time.sleep(0.02)
                    stdout, stderr = process.communicate()
                    if process.returncode:
                        raise RuntimeError(f"page proof {phase}: {stderr[-12000:]}")
                    result = json.loads(stdout)
                    sample_process(fixture.server.pid, provider_peak)
                    result.update(seconds=round(time.monotonic() - started, 3),
                                  sampled_peak=peak, provider_sampled_peak=provider_peak)
                    result["wal_file_bytes"] = sum(path.stat().st_size for path in (fixture.root / "wal").rglob("*") if path.is_file())
                    if cold:
                        sample_process(cold.pid, cold_peak)
                        result["cold_store_sampled_peak"] = cold_peak
                        result["cold_file_bytes"] = cold.file_bytes()
                        result["cold_data_objects"] = cold.data_objects()
                        if result["cold_data_objects"] == 0:
                            raise AssertionError("Cold profile produced no persisted Ursula chunk objects")
                    evidence["phases"].append(result)
                    print(f"Immutable pages: {json.dumps(result)}", flush=True)
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.communicate()
                if i == 0 and args.layout == 'packed':
                    from page_batch_faults import check
                    check(binary, fixture, args.keys, args.cache, args.mutation_batch)
                fixture.stop()  # SIGKILL: no graceful shutdown flush.
        evidence["status"] = "passed"
        print("Immutable page roots, old views and deleted-key absence survive disk WAL interruption and root-only checkpoint/trim.")
    finally:
        destination.write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
