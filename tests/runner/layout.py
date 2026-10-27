"""Reject unowned test paths and stale migration exceptions."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def validate_migration(root, path, owners, complete=False):
    mapping = json.loads((root / path).read_text())
    baseline = json.loads((root / mapping["baseline"]).read_text())
    original = {entry["path"]: entry for entry in baseline["files"]}
    assert mapping["version"] == 1 and mapping["baseline_revision"] == baseline["revision"], "Foreign migration basis"
    entries = mapping["files"]
    sources = [entry["source"] for entry in entries]
    destinations = [entry["destination"] for entry in entries if entry.get("disposition", "file") == "file"]
    assert len(sources) == len(set(sources)) and set(sources) == original.keys(), "Missing or duplicate source dispositions"
    assert len(destinations) == len(set(destinations)), "Duplicate migration destinations"
    for entry in entries:
        source, destination = entry["source"], entry["destination"]
        disposition = entry.get("disposition", "file")
        assert disposition in {"file", "archive"}, entry
        if disposition == "archive":
            archive = entry["archive"]
            assert destination is None and entry["owner"] == "evidence", entry
            assert archive["revision"] == baseline["revision"] and archive["path"] == source, "Foreign archive basis"
            assert archive["sha256"] == original[source]["sha256"], "Changed archive identity"
            if complete:
                assert not (root / source).exists(), f"Archived generated output remains: {source}"
            continue
        parts = PurePosixPath(destination).parts
        assert parts and parts[0] == "tests" and ".." not in parts, destination
        owner = parts[1] if len(parts) > 2 else "index"
        assert owner == entry["owner"] and (owner in owners or owner == "index"), destination
        assert owner != "index" or destination in {"tests/README.md", "tests/AGENTS.md"}, destination
        assert entry["role"] in {"navigation", "retained-observation", "active-budget", "formal-model",
                                 "input", "catalog", "helper", "executable", "compiled-tests", "oracle", "consumer"}, entry
        current = root / destination if (root / destination).is_file() else root / source
        assert current.is_file(), f"Missing migrated file: {source} -> {destination}"
        if complete:
            assert (root / destination).is_file(), f"Unmigrated file: {source}"
            assert source == destination or not (root / source).exists(), f"Old migration path remains: {source}"
        if entry["role"] == "retained-observation":
            assert hashlib.sha256(current.read_bytes()).hexdigest() == original[source]["sha256"], f"Changed retained evidence: {source}"


def verify_archives(root, path):
    mapping = json.loads((root / path).read_text())
    original = {entry["path"]: entry for entry in json.loads((root / mapping["baseline"]).read_text())["files"]}
    entries = [entry for entry in mapping["files"] if entry.get("disposition") == "archive"]
    process = subprocess.Popen(["git", "cat-file", "--batch"], cwd=root,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        for entry in entries:
            archive = entry["archive"]
            process.stdin.write(f'{archive["revision"]}:{archive["path"]}\n'.encode())
            process.stdin.flush()
            header = process.stdout.readline().split()
            assert len(header) == 3 and header[1] == b"blob", f"Unavailable archive object: {entry['source']}"
            remaining = int(header[2])
            assert remaining == original[entry["source"]]["bytes"], f"Changed archive size: {entry['source']}"
            digest = hashlib.sha256()
            while remaining:
                block = process.stdout.read(min(remaining, 65536))
                assert block, "Incomplete archive object"
                digest.update(block)
                remaining -= len(block)
            assert process.stdout.read(1) == b"\n", "Invalid archive framing"
            assert digest.hexdigest() == archive["sha256"], f"Changed archive bytes: {entry['source']}"
        process.stdin.close()
        assert process.wait(timeout=10) == 0, "Archive reader failed"
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=10)
        process.stdin.close()
        process.stdout.close()
    return len(entries)


def validate(root, complete=False):
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
    if complete:
        assert not legacy, "Migration exceptions remain"
    if path := policy.get("migration_map"):
        validate_migration(root, path, owners, complete)
    return len(files), len(legacy)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--complete", action="store_true", help="require every planned destination and no migration exceptions")
    parser.add_argument("--archive-integrity", action="store_true", help="verify archived bytes in the original Git revision")
    args = parser.parse_args()
    try:
        count, exceptions = validate(args.root.resolve(), args.complete)
        if args.archive_integrity:
            policy = json.loads((args.root / "tests/runner/layout.json").read_text())
            print(f"Archived observations verified: {verify_archives(args.root, policy['migration_map'])}")
    except (AssertionError, KeyError, ValueError) as error:
        raise SystemExit(f"Test layout: {error}") from error
    print(f"Test layout: {count} files owned; {exceptions} explicit migration exceptions remain")


if __name__ == "__main__":
    main()
