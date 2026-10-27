"""Exhaust the finite local WAL model and detect six independent ordering mutants."""
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
MODELS = Path(__file__).resolve().parent
MUTANTS = {
    "CheckSync": "PublishedHistory",
    "CheckFence": "AppendFenced",
    "CheckTrimOrder": "DeletionAuthorized",
    "ResumeTrim": "TrimComplete",
    "SyncRecovered": "PublishedHistory",
    "SyncRecoveredNames": "PublishedHistory",
}
ACTIONS = {
    "Init", "BeginAppend", "Create", "Partial", "Write", "FileSync", "NameSync",
    "BeginFence", "BeginTrim", "MetaWrite", "MetaSync", "Rename", "MetaDirSync",
    "Delete", "DeleteSync", "Ack", "TrimAck", "PersistData", "PersistName",
    "PersistMeta", "Kill", "PowerLoss", "IoError", "Recover", "Repair", "RecoverSync",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lsns", type=int, choices=(1, 2, 3), default=2)
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    tlc = shutil.which("tlc")
    if tlc is None:
        raise SystemExit("TLC missing: use nix develop --command just test::wal-model")
    destination = ROOT / ".cache/verification/wal-model"
    destination.mkdir(parents=True, exist_ok=True)
    sources = [MODELS / "Wal.tla", MODELS / "Wal.cfg", Path(__file__),
               ROOT / "packages/zig/transit-storage/src/DiskWal.zig"]
    evidence = {"version": 1, "status": "inconclusive", "max_lsn": args.lsns,
                "max_epoch": 2, "safety_only": True, "implementation_replay": False,
                "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sources}, "checks": []}
    try:
        with tempfile.TemporaryDirectory(prefix="transit-wal-tlc-") as temporary:
            directory = Path(temporary)
            source = directory / "Wal.tla"
            shutil.copyfile(MODELS / "Wal.tla", source)
            template = (MODELS / "Wal.cfg").read_text().replace("MaxLsn = 2", f"MaxLsn = {args.lsns}")
            for guard in (None, *MUTANTS):
                name = guard or "safe"
                config = template if guard is None else template.replace(f"{guard} = TRUE", f"{guard} = FALSE")
                if guard is not None:
                    assert config != template, f"missing mutation switch: {guard}"
                config_path = directory / f"{name}.cfg"
                config_path.write_text(config)
                (destination / f"{name}.cfg").write_text(config)
                started = time.monotonic()
                command = [tlc, "-workers", "1", "-seed", "1", "-fp", "0",
                           "-metadir", str(directory / name), "-config", str(config_path), str(source)]
                try:
                    result = subprocess.run(command, cwd=directory,
                        env=os.environ | {"JAVA_TOOL_OPTIONS": "-Xmx512m"},
                        capture_output=True, text=True, timeout=args.seconds)
                except subprocess.TimeoutExpired as error:
                    output = (error.stdout or b"") + (error.stderr or b"")
                    (destination / f"{name}.log").write_bytes(output)
                    raise RuntimeError(f"{name}: timed out; model exploration is inconclusive") from error
                output = result.stdout + result.stderr
                (destination / f"{name}.log").write_text(output)
                violation = re.search(r"Error: Invariant (\w+) is violated\.", output)
                if guard is None:
                    assert result.returncode == 0 and "Model checking completed. No error has been found." in output, output[-4000:]
                    counts = re.search(r"([\d,]+) states generated, ([\d,]+) distinct states found, 0 states left on queue", output)
                    assert counts, "missing exhaustive queue completion"
                    evidence["distinct_states"] = int(counts[2].replace(",", ""))
                else:
                    assert result.returncode == 12 and violation and violation[1] == MUTANTS[guard], output[-4000:]
                    events = re.findall(r'^/\\ last = "([^"]+)"$', output, re.M)
                    states = re.findall(r"^State \d+: ", output, re.M)
                    assert len(events) == len(states) and len(events) > 1 and events[0] == "Init", "missing counterexample states"
                    assert set(events) <= ACTIONS, f"unmapped model actions: {set(events) - ACTIONS}"
                    (destination / f"{name}.json").write_text(json.dumps(
                        {"version": 1, "violation": violation[1], "actions": events,
                         "implementation_replay": False}, indent=2) + "\n")
                evidence["checks"].append({"guard": name, "status": "passed" if guard is None else "detected",
                    "violation": violation[1] if violation else None,
                    "seconds": round(time.monotonic() - started, 3)})
        evidence["status"] = "passed"
        print(f"WAL TLC: {evidence['distinct_states']} states exhausted; six ordering mutants detected. No code refinement or power-loss experiment claimed.")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
