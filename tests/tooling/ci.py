"""One task inventory for hosted CI lanes and the complete local suite."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import platform

ROOT = Path(__file__).resolve().parents[2]
SUITE = json.loads((ROOT / "tests/verification/suite.json").read_text())
if SUITE["version"] != 1:
    raise ValueError("Unsupported verification suite version")
LANES = SUITE["lanes"]



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lane", choices=("all", *SUITE["tiers"], *LANES))
    args = parser.parse_args()
    tier = "ordinary" if args.lane == "all" else args.lane
    lanes = SUITE["tiers"].get(tier, [tier])
    results = []
    destination = ROOT / ".cache/ci" / f"{args.lane}.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    started_suite = time.monotonic()
    completed = False
    active_task = None
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True)
    metadata = {"version": 1, "revision": revision.stdout.strip() or None,
                "tier": args.lane,
                "expected_tasks": [task for lane in lanes for task in LANES[lane]],
                "run_id": os.getenv("GITHUB_RUN_ID"),
                "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
                "machine": {
                    'platform': platform.platform(), 'logical_cpus': os.cpu_count(),
                    'affinity': sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else None,
                    'runner': os.getenv('RUNNER_NAME'), 'runner_arch': os.getenv('RUNNER_ARCH'),
                }}

    def checkpoint():
        # SIGTERM/job cancellation need not run Python's finally blocks. Retain
        # each finished task and identify an unfinished attempt before launching
        # it. Atomic file replacement never publishes a partially encoded JSON.
        metadata.update(completed=completed, active_task=active_task,
                        seconds=round(time.monotonic() - started_suite, 2),
                        checkpoint_unix=time.time(), result_count=len(results))
        for path, value in ((destination, results), (destination.with_suffix(".meta.json"), metadata)):
            temporary = path.with_suffix(path.suffix + ".tmp")
            temporary.write_text(json.dumps(value, indent=2) + "\n")
            temporary.replace(path)

    checkpoint()
    try:
        for lane in lanes:
            for task in LANES[lane]:
                print(f"::group::{lane}: just {task}" if os.getenv("GITHUB_ACTIONS")
                      else f"CI {lane}: just {task}", flush=True)
                started = time.monotonic()
                active_task = {"lane": lane, "task": task}
                checkpoint()
                try:
                    process = subprocess.run(["just", task], cwd=ROOT)
                    code = process.returncode
                except BaseException:
                    code = 130
                    raise
                finally:
                    elapsed = round(time.monotonic() - started, 2)
                    results.append({"lane": lane, "task": task, "seconds": elapsed, "exit_code": code})
                    active_task = None
                    checkpoint()
                    print(f"{task}: {elapsed:.2f}s, exit {code}", flush=True)
                    if os.getenv("GITHUB_ACTIONS"):
                        print("::endgroup::", flush=True)
                if code:
                    raise SystemExit(code)
        completed = True
    finally:
        checkpoint()
        summary = os.getenv("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a") as output:
                output.write(f"\n### CI {args.lane}\n\n| Task | Seconds | Exit |\n| --- | ---: | ---: |\n")
                for result in results:
                    output.write(f"| `{result['task']}` | {result['seconds']} | {result['exit_code']} |\n")


if __name__ == "__main__":
    main()
