"""Describe and qualify immutable native prefixes built by the owning Zig graph.

Zig owns dependency tracking, compilation caching and artifact publication. This
tool always asks that graph for current outputs; it never caches test results or
decides that a previous build can be skipped from a Git revision alone.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
import time

from runner.capture import provenance, write_json
from runner.paths import ROOT

EXPECTED = {
    "clients": {"lib/libtransit_client.so", "lib/libtransit_station.so",
                "bin/transit-client-host", "bin/transit-station-host", "bin/transit-admin",
                "bin/transit-station-http-worker", "bin/transit-station-grpc-worker"},
    "authority": {"bin/transit-node"},
}
CONTRACTS = {"contracts/client.json", "contracts/station.json"}
PROFILES = {"Debug": "debug", "ReleaseSafe": "safe"}


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def describe(prefix):
    prefix = prefix.resolve(strict=True)
    metadata = json.loads((prefix / "build.json").read_text())
    assert metadata["version"] == 1 and metadata["set"] in EXPECTED, "Unknown native artifact set"
    names = metadata["artifacts"]
    assert len(names) == len(set(names)) and set(names) == EXPECTED[metadata["set"]], "Incomplete native artifact set"
    for name in names:
        assert not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts
    definitions = [json.loads((prefix / name).read_text())["definition"] for name in sorted(CONTRACTS)]
    assert len(set(definitions)) == 1 and len(definitions[0]) == 64, "Mixed native definitions"
    return {"prefix": str(prefix), "build": metadata, "definition": definitions[0],
            "files": {name: {"sha256": digest(prefix / name), "bytes": (prefix / name).stat().st_size}
                      for name in sorted({*names, *CONTRACTS, "build.json"})}}


def source_identity(root):
    # Conservatively include every non-ignored native/build input, including
    # newly added source. Documentation and unrelated run output are not inputs.
    listed = subprocess.check_output([
        "git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--",
        "build.zig", "build.zig.zon", "build", "packages/zig", "apps", "third_party",
        "nix", "flake.nix", "flake.lock", "tests/harness/native_artifacts.py",
    ], cwd=root).decode().split("\0")
    included = {}
    for name in sorted(set(listed) - {""}):
        path = root / name
        if path.suffix == ".md":
            continue
        included[name] = digest(path) if path.is_file() else None
    assert included, "No native source inputs"
    return hashlib.sha256(json.dumps(included, sort_keys=True).encode()).hexdigest()


def validate(record, *, source, optimize, family, definition):
    assert record["source_sha256"] == source, "Native source changed"
    assert record["build"]["optimize"] == PROFILES[optimize], "Wrong native optimization profile"
    assert record["build"]["set"] == family, "Wrong native artifact family"
    assert record["definition"] == definition, "Wrong native contract definition"
    observed = describe(Path(record["prefix"]))
    assert all(record[key] == value for key, value in observed.items()), "Native artifacts changed or are incomplete"
    return Path(record["prefix"])


def prepare(family, optimize, root=ROOT):
    started = time.monotonic()
    source = source_identity(root)
    inputs_done = time.monotonic()
    compiler = shutil.which("zig")
    assert compiler, "Enter the pinned Nix development environment"
    command = [compiler, "build", f"fixture-{family}", f"-Doptimize={optimize}", "-Dsdk-examples=false"]
    result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, check=True, text=True)
    built = time.monotonic()
    record = json.loads(result.stdout)
    assert source_identity(root) == source, "Native inputs changed during compilation; no record published"
    record.update(source_sha256=source, **provenance(root), command=command)
    definition = json.loads((root / "packages/zig/transit-client/abi-v1.json").read_text())["definition"]
    prefix = validate(record, source=source, optimize=optimize, family=family, definition=definition)
    record["phases"] = {"input_identity_seconds": inputs_done - started,
                        "build_graph_seconds": built - inputs_done,
                        "output_verification_seconds": time.monotonic() - built}
    # This is an invocation record, not a second compilation-cache authority.
    # No record exists until the complete build and input/output checks pass.
    destination = root / ".cache/native-artifacts"
    destination.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix=f"{family}-{optimize}-", dir=destination))
    write_json(directory / "record.json", record)
    return prefix, directory / "record.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    inspect = commands.add_parser("inspect")
    inspect.add_argument("prefix", type=Path)
    build = commands.add_parser("prepare")
    build.add_argument("family", choices=EXPECTED)
    build.add_argument("--optimize", choices=("Debug", "ReleaseSafe"), required=True)
    args = parser.parse_args()
    if args.action == "inspect":
        print(json.dumps(describe(args.prefix)))
    else:
        prefix, record = prepare(args.family, args.optimize)
        print(f"Native artifact record: {record}", file=sys.stderr)
        print(prefix)


if __name__ == "__main__":
    main()
