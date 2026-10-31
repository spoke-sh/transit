"""Describe and qualify immutable native prefixes built by the owning Zig graph.

Zig owns dependency tracking, compilation caching and artifact publication. This
tool asks that graph for current outputs, or consumes an explicitly supplied,
verified portable publication of those outputs. It never caches test results.
"""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
import tarfile
import time

from harness.phases import Recorder
from runner.capture import provenance, run, write_json
from runner.paths import ROOT

EXPECTED = {
    "clients": {"lib/libtransit_client.so", "lib/libtransit_station.so",
                "bin/transit-client-host", "bin/transit-station-host", "bin/transit-admin",
                "bin/transit-station-http-worker", "bin/transit-station-grpc-worker"},
    "authority": {"bin/transit-node"},
    "c-sdk": {"lib/libtransit_sdk_client.so", "lib/libtransit_sdk_station.so",
              "lib/libtransit_sdk_examples_c.a", "bin/transit-c-counter", "bin/transit-cpp-counter"},
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


def source_identity(root, family=None):
    # Conservatively include every non-ignored native/build input, including
    # newly added source. Documentation and unrelated run output are not inputs.
    owners = ["build.zig", "build.zig.zon", "build", "packages/zig", "apps", "third_party",
              "nix", "flake.nix", "flake.lock", "VERSION", "contracts", "tasks/embed_web.py",
              "packages/ts", "package.json", "pnpm-lock.yaml", "pnpm-workspace.yaml",
              "vp.config.ts", "tests/harness/native_artifacts.py"]
    if family == "c-sdk":
        owners += ["bindings", "sdks/c", "sdks/cpp", "examples/station-sdk/c", "examples/station-sdk/cpp"]
    listed = subprocess.check_output([
        "git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--",
        *owners,
    ], cwd=root).decode().split("\0")
    included = {}
    for name in sorted(set(listed) - {""}):
        path = root / name
        if path.suffix == ".md":
            continue
        included[name] = digest(path) if path.is_file() else None
    assert included, "No native source inputs"
    # Version metadata embeds Git provenance, including the dirty marker.
    origin = provenance(root)
    identity = dict(files=included, revision=origin['revision'], dirty=origin['dirty'])
    return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()


def validate(record, *, source, optimize, family, definition):
    assert record["source_sha256"] == source, "Native source changed"
    assert record["build"]["optimize"] == PROFILES[optimize], "Wrong native optimization profile"
    assert record["build"]["set"] == family, "Wrong native artifact family"
    assert record["definition"] == definition, "Wrong native contract definition"
    observed = describe(Path(record["prefix"]))
    assert all(record[key] == value for key, value in observed.items()), "Native artifacts changed or are incomplete"
    return Path(record["prefix"])


def portable_target():
    machine = platform.machine()
    assert platform.system() == "Linux" and machine in {"x86_64", "aarch64"}, "Unsupported native bundle host"
    return f"{machine}-linux-gnu"


def publication(bundle, family, optimize, source, compiler, definition):
    prefix = bundle.resolve(strict=True) / f"{family}-{optimize}"
    record = json.loads((prefix / "record.json").read_text())
    record["prefix"] = str(prefix)
    # Zig expands the requested triple with the pinned compiler's default OS
    # range and glibc floor (e.g. linux.5.10...7.2-gnu.2.31).
    arch, system, abi = record["build"]["target"].split("-")
    assert f"{arch}-{system.split('.')[0]}-{abi.split('.')[0]}" == portable_target(), "Wrong native bundle target"
    assert record["build"]["cpu"] == "baseline", "Native bundle must use a portable CPU"
    assert record["build"]["compiler"] == subprocess.check_output([compiler, "version"], text=True).strip(), "Wrong native bundle compiler"
    validate(record, source=source, optimize=optimize, family=family, definition=definition)
    return record


def export(family, optimize, output, root=ROOT):
    # Transport immutable graph outputs, not the multi-GB compiler cache or any
    # installed consumer/service state. Tar retains executable mode bits.
    prefix, record_path = prepare(family, optimize, root, portable=True, imported=False)
    record = json.loads(record_path.read_text())
    name = f"{family}-{optimize}"
    assert not output.exists(), "Native publication already exists"
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".partial")
    with Recorder(root).phase("artifact-export", family) as row:
        with tarfile.open(temporary, "w:gz", compresslevel=1) as archive:
            for path in sorted(record["files"]):
                archive.add(prefix / path, arcname=f"{name}/{path}", recursive=False)
            archive.add(record_path, arcname=f"{name}/record.json", recursive=False)
        temporary.replace(output)
        row["bytes"] = output.stat().st_size
    return record


def unpack(archive, destination):
    with tarfile.open(archive) as source:
        members = source.getmembers()
        assert members and len({m.name for m in members}) == len(members), "Duplicate or empty native publication"
        roots = {PurePosixPath(m.name).parts[0] for m in members}
        assert len(roots) == 1 and roots <= {f"{f}-{p}" for f in EXPECTED for p in PROFILES}, "Unknown native publication"
        for member in members:
            path = PurePosixPath(member.name)
            assert member.isfile() and not path.is_absolute() and ".." not in path.parts, "Unsafe native publication entry"
        name = next(iter(roots))
        assert not (destination / name).exists(), "Native publication already installed"
        source.extractall(destination, filter="data")


def prepare(family, optimize, root=ROOT, *, portable=False, imported=True):
    attempt = Recorder(root)
    started = time.monotonic()
    with attempt.phase("input-identity", family):
        source = source_identity(root, family)
    inputs_done = time.monotonic()
    compiler = shutil.which("zig")
    assert compiler, "Enter the pinned Nix development environment"
    bundle = os.getenv("CI_NATIVE_BUNDLE_DIR") if imported else None
    definition = json.loads((root / "packages/zig/transit-client/abi-v1.json").read_text())["definition"]
    if bundle and family != "c-sdk":
        with attempt.phase("artifact-import", family):
            record = publication(Path(bundle), family, optimize, source, compiler, definition)
            assert source_identity(root, family) == source, "Native inputs changed during import"
        record.update(**provenance(root), phase_directory=str(attempt.directory),
                      preparation="import", phases={"import_seconds": time.monotonic() - started})
        return retain(record, family, optimize, root)
    build_root = root / "bindings" if family == "c-sdk" else root
    target = ["prefix"] if family == "c-sdk" else [f"fixture-{family}", "-Dsdk-examples=false"]
    command = [compiler, "build", *target, f"-Doptimize={optimize}"]
    if portable or bundle:
        command += [f"-Dtarget={portable_target()}", "-Dcpu=baseline"]
    with attempt.phase("build-graph", family) as row:
        result = run(command, cwd=build_root, log=attempt.directory / "build.log", result=row, capture_stdout=True)
        result.check_returncode()
    built = time.monotonic()
    with attempt.phase("output-verification", family):
        record = json.loads(result.stdout)
        assert source_identity(root, family) == source, "Native inputs changed during compilation; no record published"
        record.update(source_sha256=source, **provenance(root), command=command,
                      phase_directory=str(attempt.directory), build_directory=str(build_root))
        definition = json.loads((root / "packages/zig/transit-client/abi-v1.json").read_text())["definition"]
        prefix = validate(record, source=source, optimize=optimize, family=family, definition=definition)
    record["phases"] = {"input_identity_seconds": inputs_done - started,
                        "build_graph_seconds": built - inputs_done,
                        "output_verification_seconds": time.monotonic() - built}
    record["preparation"] = "build-graph"
    return retain(record, family, optimize, root)


def retain(record, family, optimize, root):
    # This is an invocation record, not a second compilation-cache authority.
    # No record exists until the complete build and input/output checks pass.
    destination = root / ".cache/native-artifacts"
    destination.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix=f"{family}-{optimize}-", dir=destination))
    write_json(directory / "record.json", record)
    return Path(record["prefix"]), directory / "record.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    inspect = commands.add_parser("inspect")
    inspect.add_argument("prefix", type=Path)
    build = commands.add_parser("prepare")
    build.add_argument("family", choices=EXPECTED)
    build.add_argument("--optimize", choices=("Debug", "ReleaseSafe"), required=True)
    publish = commands.add_parser("export")
    publish.add_argument("family", choices=EXPECTED)
    publish.add_argument("--optimize", choices=PROFILES, required=True)
    publish.add_argument("--output", type=Path, required=True)
    install = commands.add_parser("unpack")
    install.add_argument("archive", type=Path)
    install.add_argument("destination", type=Path)
    args = parser.parse_args()
    if args.action == "inspect":
        print(json.dumps(describe(args.prefix)))
    elif args.action == "export":
        export(args.family, args.optimize, args.output)
    elif args.action == "unpack":
        unpack(args.archive, args.destination)
    else:
        prefix, record = prepare(args.family, args.optimize)
        print(f"Native artifact record: {record}", file=sys.stderr)
        print(prefix)


if __name__ == "__main__":
    main()
