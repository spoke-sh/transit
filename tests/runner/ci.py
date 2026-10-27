"""One task inventory for hosted CI lanes and the complete local suite."""
import argparse
import json
import os
from pathlib import Path
import time
import platform
import resource
import shutil
import subprocess

from capture import directory, provenance, run, write_json

ROOT = Path(__file__).resolve().parents[2]
SUITE = json.loads((ROOT / "tests/runner/suite.json").read_text())
if SUITE["version"] != 1:
    raise ValueError("Unsupported verification suite version")
LANES = SUITE["lanes"]


def resource_observation():
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    result = {
        "child_user_seconds": usage.ru_utime, "child_system_seconds": usage.ru_stime,
        "max_child_rss_platform_units": usage.ru_maxrss,
        "child_input_blocks": usage.ru_inblock, "child_output_blocks": usage.ru_oublock,
    }
    try:
        result["workspace_free_bytes"] = shutil.disk_usage(ROOT).free
    except OSError:
        result["workspace_free_bytes"] = None
    try:
        memory = dict(line.split(':', 1) for line in Path('/proc/meminfo').read_text().splitlines())
        result["host_available_memory_bytes"] = int(memory['MemAvailable'].split()[0]) * 1024
    except (OSError, KeyError, ValueError):
        result["host_available_memory_bytes"] = None
    try:
        result["host_io_pressure_total_seconds"] = {
            fields[0]: int(dict(item.split('=', 1) for item in fields[1:])['total']) / 1_000_000
            for fields in map(str.split, Path('/proc/pressure/io').read_text().splitlines())
        }
    except (OSError, KeyError, ValueError):
        result["host_io_pressure_total_seconds"] = None
    return result


def selected_tasks(lane, selection):
    from ci_select import select

    plan = json.loads(Path(selection).read_text())
    assert plan["version"] == 1, "Unknown CI selection format"
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    assert plan["checkout_sha"] == revision, "Selection belongs to a different source revision"
    expected = select(plan["paths"], plan["comparison"]["event"], suite=SUITE)
    assert all(plan[key] == value for key, value in expected.items()), "CI selection differs from the current dependency policy"
    lanes = plan["lanes"] | plan["additional_lanes"]
    assert lane in lanes and lanes[lane], "Lane has no selected checks"
    return lanes[lane], plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lane", choices=("all", *SUITE["tiers"], *LANES))
    # This is runner input, not Transit application configuration. Consume it
    # before starting tools/services, whose TRANSIT_ namespace rejects unknown
    # settings. Keep the parsed plan in metadata instead of the child environment.
    parser.add_argument("--selection", default=os.environ.pop("TRANSIT_CI_SELECTION_PATH", None))
    args = parser.parse_args()
    tier = "ordinary" if args.lane == "all" else args.lane
    lanes = SUITE["tiers"].get(tier, [tier])
    tasks = {lane: LANES[lane] for lane in lanes}
    selection = None
    if args.selection:
        assert args.lane in LANES, "Scoped selection requires one named lane"
        tasks[args.lane], selection = selected_tasks(args.lane, args.selection)
    results = []
    destination = ROOT / ".cache/ci" / f"{args.lane}.json"
    artifacts = directory(destination)
    started_suite = time.monotonic()
    completed = False
    active_task = None
    metadata = {"version": 1, **provenance(ROOT),
                "run_directory": str(artifacts.relative_to(destination.parent)),
                "started_unix": time.time(),
                "tier": args.lane,
                "expected_tasks": [task for lane in lanes for task in tasks[lane]],
                "selection": selection,
                "run_id": os.getenv("GITHUB_RUN_ID"),
                "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
                "resources_initial": resource_observation(),
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
                        checkpoint_unix=time.time(), result_count=len(results),
                        resources_current=resource_observation())
        for path, value in ((destination, results), (destination.with_suffix(".meta.json"), metadata),
                            (artifacts / "results.json", results), (artifacts / "meta.json", metadata)):
            write_json(path, value)

    checkpoint()
    try:
        for lane in lanes:
            for task in tasks[lane]:
                print(f"::group::{lane}: just {task}" if os.getenv("GITHUB_ACTIONS")
                      else f"CI {lane}: just {task}", flush=True)
                started = time.monotonic()
                log = artifacts / f"{len(results) + 1:03d}.log"
                active_task = {"lane": lane, "task": task, "log": log.name}
                result = {"lane": lane, "task": task, "log": log.name,
                          "command": ["just", task], "exit_code": None, "completed": False}
                checkpoint()
                try:
                    process = run(["just", task], cwd=ROOT, log=log, result=result)
                    code = process.returncode
                except BaseException:
                    code = 130
                    raise
                finally:
                    elapsed = round(time.monotonic() - started, 2)
                    result.update(seconds=elapsed)
                    results.append(result)
                    active_task = None
                    checkpoint()
                    print(f"{task}: {elapsed:.2f}s, exit {code}", flush=True)
                    if os.getenv("GITHUB_ACTIONS"):
                        print("::endgroup::", flush=True)
                if code:
                    raise SystemExit(code if code > 0 else 128 - code)
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
