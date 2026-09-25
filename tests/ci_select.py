"""Conservative CI selection. Unknown paths and every main/release run are full."""
import argparse
import json
import os
from pathlib import PurePosixPath
import subprocess


def select(paths, event="pull_request"):
    # Only prose with no build/schema consumer is exempt. Component READMEs,
    # contracts, fixtures and all shared infrastructure deliberately remain full.
    def prose(path):
        p = PurePosixPath(path)
        return path in {"README.md", "AGENTS.md"} or (
            p.parts[0:1] == ("docs",) and p.suffix == ".md" and ".." not in p.parts
        )

    full = event != "pull_request" or not paths or not all(map(prose, paths))
    return {"version": 1, "full": full, "docs": True,
            "reason": "full qualification" if full else "foundational prose only",
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
