"""Real growing authority crash proof with fixed resident page budget."""
from contextlib import ExitStack
from pathlib import Path
import argparse
import hashlib
import json
import platform
import subprocess
import time
from pages import metrics, sample_process
from storage import Fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--rows", type=int, default=64)
    parser.add_argument("--cold-s3", action="store_true")
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    binary = str(Path(args.binary).resolve(strict=True))
    evidence = {"version": 1, "status": "inconclusive", "profile": "v3 authority with real provider; no service/Station",
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root)),
                "binary_sha256": hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                "platform": platform.platform(), "storage_profile": "s3" if args.cold_s3 else "hot",
                "zig": subprocess.check_output(["zig", "version"], text=True).strip(), "phases": []}
    destination = root / ".cache/verification" / f"growing-{evidence['storage_profile']}-{args.rows}.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with ExitStack() as resources:
            cold = None
            if args.cold_s3:
                from cold_storage import ColdStore, IMAGE
                cold = resources.enter_context(ColdStore())
                evidence["cold_image"] = IMAGE
            fixture = resources.enter_context(Fixture(cold.config() if cold else None))
            for phase in ("write", "recover", "checkpoint", "trim_recover"):
                if phase != "write":
                    fixture.start()
                started = time.monotonic()
                child, provider, objects = metrics(), metrics(), metrics()
                process = subprocess.Popen([binary, fixture.url, phase, str(args.rows)],
                    env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                try:
                    while process.poll() is None:
                        if time.monotonic() - started > args.timeout:
                            raise TimeoutError(f"Growing authority {phase} exceeded {args.timeout}s")
                        sample_process(process.pid, child)
                        sample_process(fixture.server.pid, provider)
                        if cold:
                            sample_process(cold.pid, objects)
                        time.sleep(0.02)
                    stdout, stderr = process.communicate()
                    if process.returncode:
                        raise RuntimeError(f"Growing authority {phase}: {stderr[-12000:]}")
                    result = json.loads(stdout)
                    sample_process(fixture.server.pid, provider)
                    result.update(seconds=round(time.monotonic() - started, 3), sampled_peak=child,
                                  provider_sampled_peak=provider)
                    result["wal_file_bytes"] = sum(p.stat().st_size for p in (fixture.root / "wal").rglob("*") if p.is_file())
                    if cold:
                        result.update(cold_store_sampled_peak=objects, cold_file_bytes=cold.file_bytes(),
                                      cold_data_objects=cold.data_objects())
                        if not result["cold_data_objects"]:
                            raise AssertionError("No persisted Ursula cold chunks")
                    evidence["phases"].append(result)
                    print(f"Growing authority: {json.dumps(result)}", flush=True)
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
