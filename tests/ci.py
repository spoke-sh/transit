"""One task inventory for hosted CI lanes and the complete local suite."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
LANES = {
    "core": (
        "check-core", "test::dev-environment", "test::kubectl-transit",
        "test::deployments", "test::telemetry", "test::packages",
        "test::arrow", "test::client-abi", "test::station", "test::storage",
        "test::service", "test::runtime-upgrade", "test::callers",
        "test::inspection", "test::state",
    ),
    "experience": (
        "transit-board::check", "bindings::node-check", "test::observability",
        "transit-board::test", "launchers::local::test", "launchers::local::test-station",
    ),
    "browser": ("transit-board::browser",),
    "bindings": ("bindings::check", "bindings::test"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lane", choices=("all", *LANES))
    args = parser.parse_args()
    lanes = ("core", "experience", "bindings") if args.lane == "all" else (args.lane,)
    results = []
    destination = ROOT / ".cache/ci" / f"{args.lane}.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
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
    finally:
        destination.write_text(json.dumps(results, indent=2) + "\n")
        summary = os.getenv("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a") as output:
                output.write(f"\n### CI {args.lane}\n\n| Task | Seconds | Exit |\n| --- | ---: | ---: |\n")
                for result in results:
                    output.write(f"| `{result['task']}` | {result['seconds']} | {result['exit_code']} |\n")


if __name__ == "__main__":
    main()
