"""Compile each package through its own manifest with bounded concurrency."""
import argparse
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
import os
from pathlib import Path
import resource
import signal
import threading
import time

from capture import directory, provenance, run, write_json

ROOT = Path(__file__).resolve().parents[2]


def discover(root):
    packages = sorted(path.parent for path in (root / "packages/zig").glob("*/build.zig"))
    assert packages, "No standalone packages found"
    for path in packages:
        assert (path / "build.zig.zon").is_file(), f"Package manifest missing: {path.name}"
    return packages


def execute(root, jobs):
    assert 1 <= jobs <= 4, "Package compilation concurrency must be in 1..4"
    packages = discover(root)
    destination = root / ".cache/checks/packages-build.json"
    artifacts = directory(destination)
    cancelled = threading.Event()
    started = time.monotonic()
    usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
    report = {"version": 1, **provenance(root), "profile": "packages-build", "jobs": jobs,
              "logical_cpus": os.cpu_count(), "started_unix": time.time(),
              "affinity": sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None,
              "expected_checks": [path.name for path in packages], "checks": [],
              "completed": False, "active": [], "run_directory": str(artifacts.relative_to(destination.parent))}
    finished = {}
    active = {}

    def checkpoint():
        report.update(active=sorted(path.name for path in active.values()) or None,
                      checks=[finished[path.name] for path in packages if path.name in finished],
                      seconds=time.monotonic() - started)
        for path in (artifacts / "report.json", destination):
            write_json(path, report)

    def compile_package(path):
        entry = {"id": path.name, "phase": "build-graph", "completed": False,
                 "expected_stages": ["compile"], "stages": []}
        stage = {"stage": "compile", "cwd": str(path.relative_to(root)), "completed": False}
        entry["stages"].append(stage)
        began = time.monotonic()
        try:
            result = run(["zig", "build", "check"], cwd=path,
                         log=artifacts / f"{path.name}.log", result=stage, cancelled=cancelled)
            entry["completed"] = result.returncode == 0
        except BaseException as error:
            stage["error"] = type(error).__name__
        finally:
            stage["seconds"] = time.monotonic() - began
            write_json(artifacts / f"{path.name}.json", entry)
        return entry

    previous = signal.getsignal(signal.SIGTERM)

    def interrupted(*_):
        cancelled.set()
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)
    pool = ThreadPoolExecutor(max_workers=jobs)
    pending = iter(packages)
    code = 0
    checkpoint()
    try:
        def fill():
            while not cancelled.is_set() and len(active) < jobs:
                path = next(pending, None)
                if path is None:
                    break
                print(f"Package check: {path.name}", flush=True)
                active[pool.submit(compile_package, path)] = path
                checkpoint()

        fill()
        while active:
            ready, _ = wait(active, return_when=FIRST_COMPLETED)
            for future in ready:
                path = active.pop(future)
                entry = finished[path.name] = future.result()
                if not entry["completed"] and not code:
                    status = entry["stages"][0].get("exit_code")
                    code = status if status and status > 0 else 128 - status if status else 1
                    cancelled.set()
                checkpoint()
            fill()
        report["completed"] = not code and len(finished) == len(packages)
    except BaseException:
        cancelled.set()
        raise
    finally:
        # Workers terminate their own compiler groups and finalize diagnostics
        # before the coordinator returns or publishes the last checkpoint.
        pool.shutdown(wait=True, cancel_futures=True)
        for future, path in list(active.items()):
            if not future.cancelled():
                finished[path.name] = future.result()
            active.pop(future)
        signal.signal(signal.SIGTERM, previous)
        usage = resource.getrusage(resource.RUSAGE_CHILDREN)
        report["child_resources"] = {
            "user_seconds": usage.ru_utime - usage_before.ru_utime,
            "system_seconds": usage.ru_stime - usage_before.ru_stime,
            "max_child_rss_platform_units": usage.ru_maxrss,
            "input_blocks": usage.ru_inblock - usage_before.ru_inblock,
            "output_blocks": usage.ru_oublock - usage_before.ru_oublock,
        }
        checkpoint()
    print(f"Package checks: {len(finished)}/{len(packages)}, jobs={jobs}; {artifacts}", flush=True)
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=2)
    args = parser.parse_args()
    try:
        raise SystemExit(execute(ROOT, args.jobs))
    except KeyboardInterrupt:
        raise SystemExit(130)


if __name__ == "__main__":
    main()
