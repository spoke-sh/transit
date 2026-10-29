"""Exhaust object publication ordering and detect each removed sync obligation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

from runner.paths import ROOT
from verification.models.tlc_support import complete

MODELS = Path(__file__).resolve().parent
CONTROLS = {
    "SyncPayload": "ContentBeforeVisibility",
    "SyncChecks": "ContentBeforeVisibility",
    "SyncContentNames": "ContentBeforeVisibility",
    "SyncDescriptor": "DescriptorBeforeVisibility",
    "SyncDescriptorName": "AcknowledgedDurable",
}
ACTIONS = {
    "Init", "Partial", "PayloadWrite", "PayloadSync", "PayloadLink",
    "ChecksWrite", "ChecksSync", "ChecksLink", "ContentNamesSync",
    "DescriptorWrite", "DescriptorSync", "DescriptorReplace", "DescriptorNameSync",
    "Ack", "PersistBytes", "PersistName", "Kill", "IoError", "PowerLoss", "Recover",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, default=120)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    tlc = shutil.which("tlc")
    if not tlc:
        parser.error("TLC missing: run just test::object-publication-model in nix develop")
    destination = ROOT / ".cache/verification/object-publication-model"
    destination.mkdir(parents=True, exist_ok=True)
    sources = [MODELS / "ObjectPublication.tla", MODELS / "ObjectPublication.cfg",
               Path(__file__), MODELS / "tlc_support.py",
               ROOT / "packages/zig/transit-storage/src/DiskObjects.zig"]
    evidence = {
        "version": 1, "status": "inconclusive", "safety_only": True,
        "implementation_replay": False, "bounds": "one key, one candidate, exact retries; three files",
        "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        "checks": [],
    }
    try:
        with tempfile.TemporaryDirectory(prefix="transit-object-tlc-") as temporary:
            directory = Path(temporary)
            source = directory / "ObjectPublication.tla"
            shutil.copyfile(MODELS / source.name, source)
            template = (MODELS / "ObjectPublication.cfg").read_text()
            for guard in (None, *CONTROLS):
                name = guard or "safe"
                config = template if guard is None else template.replace(f"{guard} = TRUE", f"{guard} = FALSE")
                if guard:
                    assert config != template, f"missing control: {guard}"
                path = directory / f"{name}.cfg"
                path.write_text(config)
                (destination / path.name).write_text(config)
                started = time.monotonic()
                command = [tlc, "-workers", "1", "-seed", "1", "-fp", "0",
                           "-metadir", str(directory / name), "-config", str(path), str(source)]
                try:
                    result = subprocess.run(command, cwd=directory,
                        env=os.environ | {"JAVA_TOOL_OPTIONS": "-Xmx512m"},
                        capture_output=True, text=True, timeout=args.seconds)
                except subprocess.TimeoutExpired as error:
                    (destination / f"{name}.log").write_bytes((error.stdout or b"") + (error.stderr or b""))
                    raise RuntimeError(f"{name}: timeout is inconclusive") from error
                output = result.stdout + result.stderr
                (destination / f"{name}.log").write_text(output)
                if guard is None:
                    generated, distinct = complete(result.returncode, output)
                    evidence.update(generated_states=generated, distinct_states=distinct)
                    evidence["tool_banner"] = output.splitlines()[:4]
                else:
                    violation = re.search(r"Error: Invariant (\w+) is violated\.", output)
                    assert result.returncode == 12 and violation and violation[1] == CONTROLS[guard], output[-4000:]
                    events = re.findall(r'^/\\ last = "([^"]+)"$', output, re.M)
                    states = re.findall(r"^State \d+: ", output, re.M)
                    assert len(events) == len(states) and len(events) > 1 and events[0] == "Init", "incomplete trace"
                    assert set(events) <= ACTIONS, f"unknown actions: {set(events) - ACTIONS}"
                    (destination / f"{name}.json").write_text(json.dumps({
                        "violation": violation[1], "actions": events, "implementation_replay": False,
                    }, indent=2) + "\n")
                evidence["checks"].append({"guard": name, "status": "passed" if guard is None else "detected",
                    "seconds": round(time.monotonic() - started, 3)})
        evidence["status"] = "passed"
        print(f"Object publication TLC: {evidence['distinct_states']} states exhausted; five sync controls detected. "
              "Independent disk tests, not implementation refinement or physical power loss.")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
