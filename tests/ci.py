"""One task inventory for hosted CI lanes and the complete local suite."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import platform

ROOT = Path(__file__).resolve().parents[1]
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
    try:
        for lane in lanes:
            for task in LANES[lane]:
                print(f"::group::{lane}: just {task}" if os.getenv("GITHUB_ACTIONS")
                      else f"CI {lane}: just {task}", flush=True)
                started = time.monotonic()
                try:
                    process = subprocess.run(["just", task], cwd=ROOT)
                    code = process.returncode
                except BaseException:
                    code = 130
                    raise
                finally:
                    elapsed = round(time.monotonic() - started, 2)
                    results.append({"lane": lane, "task": task, "seconds": elapsed, "exit_code": code})
                    print(f"{task}: {elapsed:.2f}s, exit {code}", flush=True)
                    if os.getenv("GITHUB_ACTIONS"):
                        print("::endgroup::", flush=True)
                if code:
                    raise SystemExit(code)
        completed = True
    finally:
        destination.write_text(json.dumps(results, indent=2) + "\n")
        # A result list is not evidence that the requested inventory completed.
        # Persist identity and completeness separately for interrupted suites.
        revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                  capture_output=True, text=True)
        metadata = {"version": 1, "revision": revision.stdout.strip() or None,
                    "tier": args.lane, "completed": completed,
                    "expected_tasks": [task for lane in lanes for task in LANES[lane]],
                    "seconds": round(time.monotonic() - started_suite, 2),
                    "run_id": os.getenv("GITHUB_RUN_ID"),
                    "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT")}
        metadata['machine'] = {
            'platform': platform.platform(), 'logical_cpus': os.cpu_count(),
            'affinity': sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else None,
            'runner': os.getenv('RUNNER_NAME'), 'runner_arch': os.getenv('RUNNER_ARCH'),
        }
        destination.with_suffix(".meta.json").write_text(json.dumps(metadata, indent=2) + "\n")
        summary = os.getenv("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a") as output:
                output.write(f"\n### CI {args.lane}\n\n| Task | Seconds | Exit |\n| --- | ---: | ---: |\n")
                for result in results:
                    output.write(f"| `{result['task']}` | {result['seconds']} | {result['exit_code']} |\n")


if __name__ == "__main__":
    main()
