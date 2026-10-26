"""Real growing authority crash proof with fixed resident page budget."""
from contextlib import ExitStack
from pathlib import Path
import argparse
import hashlib
import json
import platform
import os
import resource
import subprocess
import time
import tempfile
from pages import metrics, sample_process
from harness.ursula import Fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--rows", type=int, default=64)
    parser.add_argument("--cache", type=int, default=1)
    parser.add_argument("--views", type=int, default=1)
    parser.add_argument("--output", type=Path, help="retain a distinct artifact for each matrix sample")
    parser.add_argument("--cold-s3", action="store_true")
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    disk = root / '.cache/verification/storage'
    disk.mkdir(parents=True, exist_ok=True)
    tempfile.tempdir = str(disk)  # Nix's TMPDIR may be tmpfs; measure the checkout filesystem.
    binary = str(Path(args.binary).resolve(strict=True))
    evidence = {"version": 1, "status": "inconclusive", "profile": "v1 authority with real provider; no service/Station",
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root)),
                "binary_sha256": hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                "platform": platform.platform(), "storage_profile": "s3" if args.cold_s3 else "hot",
                "zig": subprocess.check_output(["zig", "version"], text=True).strip(), "phases": []}
    evidence.update(resident_pages=args.cache, retained_views=args.views, logical_cpus=os.cpu_count(),
                    affinity=sorted(os.sched_getaffinity(0)),
                    stack_limit_bytes=resource.getrlimit(resource.RLIMIT_STACK)[0],
                    cpu=next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
                              if line.startswith('model name')), None),
                    memory_kib=next(line for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemTotal:')),
                    ursula=subprocess.check_output(['ursula', '--version'], text=True).strip())
    destination = args.output or root / ".cache/verification" / f"growing-{evidence['storage_profile']}-{args.rows}-{args.cache}.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with ExitStack() as resources:
            cold = None
            if args.cold_s3:
                from cold_storage import ColdStore
                cold = resources.enter_context(ColdStore())
                evidence["cold_provider"] = cold.identity
            fixture = resources.enter_context(Fixture(cold.config() if cold else None))
            evidence['filesystem'] = subprocess.check_output(['stat', '-f', '-c', '%T', fixture.root], text=True).strip()
            for phase in ("write", "recover", "checkpoint", "trim_recover"):
                if phase != "write":
                    fixture.start()
                started = time.monotonic()
                child, provider, objects = metrics(), metrics(), metrics()
                # The sample arrays can exceed pipe capacity on larger runs.
                # File-backed output also retains stderr without blocking the child.
                stdout_file = resources.enter_context((fixture.root / f'{phase}.json').open('w+'))
                stderr_file = resources.enter_context((fixture.root / f'{phase}.log').open('w+'))
                command = [binary, fixture.url, phase, str(args.rows), str(args.cache)]
                if args.views != 1:
                    command.append(str(args.views))
                process = subprocess.Popen(command,
                    env=fixture.env, stdout=stdout_file, stderr=stderr_file, text=True)
                try:
                    while process.poll() is None:
                        if time.monotonic() - started > args.timeout:
                            raise TimeoutError(f"Growing authority {phase} exceeded {args.timeout}s")
                        sample_process(process.pid, child)
                        sample_process(fixture.server.pid, provider)
                        if cold:
                            sample_process(cold.pid, objects)
                        time.sleep(0.02)
                    process.wait()
                    stdout_file.seek(0)
                    stderr_file.seek(0)
                    stdout, stderr = stdout_file.read(), stderr_file.read()
                    if process.returncode:
                        raise RuntimeError(f"Growing authority {phase}: {stderr[-12000:]}")
                    result = json.loads(stdout)
                    sample_process(fixture.server.pid, provider)
                    result.update(seconds=round(time.monotonic() - started, 3), sampled_peak=child,
                                  provider_sampled_peak=provider)
                    result["wal_file_bytes"] = sum(p.stat().st_size for p in (fixture.root / "wal").rglob("*") if p.is_file())
                    result["wal_allocated_bytes"] = sum(p.stat().st_blocks * 512 for p in (fixture.root / "wal").rglob("*") if p.is_file())
                    for field in ('operation_ns', 'turn_ns'):
                        samples = sorted(result[field])
                        result[field.replace('_ns', '_latency_ms')] = {
                            f'p{percent}': samples[max(0, (len(samples) * percent + 99) // 100 - 1)] / 1e6
                            for percent in (50, 95, 99)
                        } if samples else None
                    result['turns_per_second'] = len(result['turn_ns']) * 1e9 / sum(result['turn_ns']) if result['turn_ns'] else None
                    if cold:
                        result.update(cold_store_sampled_peak=objects, cold_file_bytes=cold.file_bytes(),
                                      cold_data_objects=cold.data_objects())
                        if not result["cold_data_objects"]:
                            raise AssertionError("No persisted Ursula cold chunks")
                    evidence["phases"].append(result)
                    print(f"Growing authority: {json.dumps({k: v for k, v in result.items() if k not in ('operation_ns', 'turn_ns')})}", flush=True)
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.communicate()
                fixture.stop()
        evidence["status"] = "passed"
        print("Growing authority roots, mailbox progress, captured views, grants and exact receipts survive SIGKILL/restart.")
    finally:
        destination.write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
