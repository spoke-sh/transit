"""Reject unowned test paths and stale migration exceptions."""
import argparse
import json
from pathlib import Path, PurePosixPath
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def validate(root):
    policy = json.loads((root / "tests/runner/layout.json").read_text())
    assert policy["version"] == 1, "Unsupported test layout policy"
    owners = policy["owners"]
    legacy = policy["migration_exceptions"]
    assert owners and len(owners) == len(set(owners)), "Duplicate or missing test owners"
    assert all(name and PurePosixPath(name).name == name and name not in (".", "..")
               for name in owners), "Owners must be immediate directories"
    assert len(legacy) == len(set(legacy)), "Duplicate migration exceptions"
    for name in legacy:
        path = PurePosixPath(name)
        assert path.parts[0] == "tests" and ".." not in path.parts and str(path) == name, name
        assert len(path.parts) == 2 or path.parts[1] not in owners, f"Already owned: {name}"
    listed = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "tests"],
        cwd=root,
    ).decode().split("\0")
    files = {name for name in listed if name and (root / name).is_file()}
    missing = set(legacy) - files
    assert not missing, f"Remove stale migration exceptions: {sorted(missing)}"
    root_files = {"tests/README.md", "tests/AGENTS.md"}
    assert root_files <= files, "Test root requires README.md and AGENTS.md"
    active = set()
    for name in sorted(files - root_files - set(legacy)):
        parts = PurePosixPath(name).parts
        assert len(parts) > 2 and parts[1] in owners, f"Unowned test path: {name}"
        active.add(parts[1])
    for owner in sorted(active):
        for guide in ("README.md", "AGENTS.md"):
            assert f"tests/{owner}/{guide}" in files, f"Missing owner navigation: tests/{owner}/{guide}"
    return len(files), len(legacy)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        count, exceptions = validate(args.root.resolve())
    except (AssertionError, KeyError, ValueError) as error:
        raise SystemExit(f"Test layout: {error}") from error
    print(f"Test layout: {count} files owned; {exceptions} explicit migration exceptions remain")


if __name__ == "__main__":
    main()
