"""Reviewed dependency selection; shared/unknown inputs and non-PR runs stay full."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SUITE = json.loads((ROOT / "tests/runner/suite.json").read_text())


def valid_path(path):
    p = PurePosixPath(path)
    return bool(path and not p.is_absolute() and ".." not in p.parts and str(p) == path)


def matrix(tasks, suite=SUITE):
    rows = []
    caches = set()
    for lane in suite["tiers"]["ordinary"]:
        chosen = [task for task in suite["lanes"][lane] if task in tasks]
        if not chosen:
            continue
        worker = suite["workers"][lane]
        rows.append(dict(worker, lane=lane, shell=suite["environments"][lane]["shell"],
                         cache_writer=worker["cache"] != "formal" and worker["cache"] not in caches))
        caches.add(worker["cache"])
    return rows


def affected(paths, suite=SUITE):
    """Follow reviewed reverse dependencies. No match means full, never empty."""
    groups = suite["selection"]["groups"]
    ordinary = {task for lane in suite["tiers"]["ordinary"] for task in suite["lanes"][lane]}
    visited = set()

    def audit(name, ancestors=()):
        assert name in groups and name not in ancestors, f"Unknown/cyclic dependency: {name}"
        if name in visited:
            return
        group = groups[name]
        assert set(group["tasks"]) <= ordinary, f"Unowned selection task: {name}"
        assert all(valid_path(path) for path in group.get("paths", [])), name
        assert all(prefix.endswith("/") and valid_path(prefix[:-1]) for prefix in group.get("prefixes", [])), name
        for dependency in group["depends_on"]:
            audit(dependency, (*ancestors, name))
        visited.add(name)

    for name in groups:
        audit(name)
    reached = set()
    for path in paths:
        matches = {name for name, group in groups.items()
                   if path in group.get("paths", []) or any(path.startswith(p) for p in group.get("prefixes", []))}
        if not matches:
            return None
        reached.update(matches)
    while True:
        expanded = reached | {name for name, group in groups.items() if reached.intersection(group["depends_on"])}
        if expanded == reached:
            break
        reached = expanded
    tasks = {task for name in reached for task in groups[name]["tasks"]}
    assert tasks, "Reviewed inputs have no executable consumer"
    return {"groups": sorted(reached), "tasks": sorted(tasks),
            "resources": sorted({resource for name in reached for resource in groups[name]["resources"]})}


def select(paths, event="pull_request", *, suite=SUITE, mode=None):
    # Navigation/instructions and inert historical records run the documentation
    # gate. Executable contracts, fixtures, models and selection metadata stay
    # full. Both endpoints of a rename must qualify independently.
    def documentation(path):
        p = PurePosixPath(path)
        if not valid_path(path):
            return False
        if p.parts[0] == "contracts":
            return False
        if p.name in {"README.md", "AGENTS.md"}:
            return True
        if p.parts[0:2] == ("docs", "handbook"):
            return True
        if p.parts[0] == "docs" and p.suffix == ".md":
            return True
        if path == "docs/history/qualification/migration.json":
            return True
        # These are retained observations, never fixtures or input budgets.
        # Do not extend this to other results/ directories: some own live gates.
        return (p.parts[:2] == ("tests", "evidence") and
                p.suffix in {".md", ".json", ".log", ".gz", ".patch", ".txt"})

    all_tasks = [task for lane in suite["tiers"]["ordinary"] for task in suite["lanes"][lane]]
    paths = sorted(set(paths))
    code = [path for path in paths if not documentation(path)]
    reviewed = None
    full = event != "pull_request" or not paths or any(not valid_path(path) for path in paths)
    if not full and code:
        reviewed = affected(code, suite)
        full = reviewed is None
    proposed = all_tasks if full else reviewed["tasks"] if reviewed else []
    policy = mode or suite["selection"]["mode"]
    assert policy in {"shadow", "enabled"}, "Unknown selection mode"
    shadow = policy == "shadow" and bool(reviewed) and not full
    tasks = all_tasks if full or shadow else proposed
    full = full or shadow
    lanes = {lane: [task for task in suite["lanes"][lane] if task in tasks]
             for lane in suite["tiers"]["ordinary"] if any(task in tasks for task in suite["lanes"][lane])}
    return {"version": 1, "full": full, "docs": True,
            "checks": bool(tasks), "documentation": not full and (not code or len(code) < len(paths)),
            "reason": "shadow comparison" if shadow else "full qualification" if full else
                      "reviewed dependencies" if reviewed else "documentation only",
            "paths": paths, "groups": reviewed["groups"] if reviewed else [],
            "resources": reviewed["resources"] if reviewed else [],
            "additional_lanes": {"browser": suite["lanes"]["browser"]} if "installation-ui" in lanes else {},
            "proposed_tasks": proposed, "lanes": lanes, "matrix": {"include": matrix(tasks, suite)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--event", default="pull_request")
    parser.add_argument("--mode", choices=("shadow", "enabled"), help="preview a reviewed selection without changing CI policy")
    parser.add_argument("--output", type=Path, help="retain the executable selection and its source identity")
    args = parser.parse_args()
    paths = []
    if args.event == "pull_request" and args.base:
        # No rename detection: both endpoints must qualify independently.
        # Missing revisions fail the planning job, never silently select less.
        output = subprocess.check_output([
            "git", "diff", "--name-only", "--no-renames", "-z",
            f"{args.base}...{args.head}", "--",
        ])
        paths = output.decode().rstrip("\0").split("\0") if output else []
    plan = select(paths, args.event, mode=args.mode)
    plan["checkout_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    plan["comparison"] = {"base": args.base, "head": args.head, "event": args.event}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(plan, indent=2) + "\n")
    print(json.dumps(plan, indent=2))
    if destination := os.getenv("GITHUB_OUTPUT"):
        with open(destination, "a") as output:
            output.write(f"full={str(plan['full']).lower()}\n")
            output.write(f"checks={str(plan['checks']).lower()}\n")
            output.write(f"documentation={str(plan['documentation']).lower()}\n")
            output.write(f"matrix={json.dumps(plan['matrix'])}\n")
            output.write(f"selection={json.dumps(plan)}\n")


if __name__ == "__main__":
    main()
