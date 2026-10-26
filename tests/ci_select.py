"""Conservative CI selection. Unknown paths and every main/release run are full."""
import argparse
import json
import os
from pathlib import PurePosixPath
import subprocess


def select(paths, event="pull_request"):
    # Navigation/instructions and inert historical records run the documentation
    # gate. Executable contracts, fixtures, models and selection metadata stay
    # full. Both endpoints of a rename must qualify independently.
    def documentation(path):
        p = PurePosixPath(path)
        if p.is_absolute() or ".." in p.parts or not p.parts:
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
        return (p.parts[:3] == ("tests", "verification", "results") and
                p.suffix in {".md", ".json", ".log", ".gz", ".patch", ".txt"})

    full = event != "pull_request" or not paths or not all(map(documentation, paths))
    return {"version": 1, "full": full, "docs": True,
            "reason": "full qualification" if full else "documentation only",
            "paths": sorted(set(paths))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--event", default="pull_request")
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
    plan = select(paths, args.event)
    print(json.dumps(plan, indent=2))
    if destination := os.getenv("GITHUB_OUTPUT"):
        with open(destination, "a") as output:
            output.write(f"full={str(plan['full']).lower()}\n")


if __name__ == "__main__":
    main()
