"""Exhaust local Table transaction schedules and detect missing isolation obligations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from runner.paths import ROOT
from verification.models.tlc_support import complete
from verification.models.transaction_decision_model import counterexample, runner_controls

MODELS = Path(__file__).resolve().parent
PROFILES = {
    "skew": ("SkewPrograms", "{}"),
    "publication": ("PublicationPrograms", "{2}"),
    "savepoint": ("SavepointPrograms", "{}"),
    "private": ("PrivatePrograms", "{}"),
    "barrier": ("BarrierPrograms", "{}"),
}
MUTANTS = {
    "CheckReads": ("skew", "Serializable"),
    "CheckDependencies": ("savepoint", "RetainedDependencies"),
    "CheckVisibility": ("publication", "AtomicVisibility"),
    "CheckBarrier": ("barrier", "BarrierIntegrity"),
    "CheckDefinition": ("skew", "CurrentDefinition"),
    "CheckPrivate": ("private", "ReadYourWrites"),
    "CheckAcquisition": ("publication", "CommonCut"),
}
ACTIONS = {"Init", "Begin", "Pin", "Acquire", "Crash", "Resume", "read", "write", "save", "rollback", "Freeze",
           "Prepare", "Commit", "Abort", "Finalize", "ChangeDefinition"}


def configuration(template, profile, guard=None):
    programs, read_only = PROFILES[profile]
    result = template.replace("Programs <- SkewPrograms", f"Programs <- {programs}")
    result = result.replace("ReadOnly = {}", f"ReadOnly = {read_only}")
    if guard:
        assert f"{guard} = TRUE" in result, guard
        result = result.replace(f"{guard} = TRUE", f"{guard} = FALSE")
        if guard != "CheckDefinition":
            result = result.replace("AllowDefinition = TRUE", "AllowDefinition = FALSE")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    tlc = shutil.which("tlc")
    if tlc is None:
        raise SystemExit("TLC missing: use nix develop --command just test::table-transaction-model")
    runner_controls()
    destination = ROOT / ".cache/verification/table-transaction-model" / (
        time.strftime("%Y%m%dT%H%M%S") + f"-{os.getpid()}")
    destination.mkdir(parents=True)
    sources = [MODELS / "TableTransaction.tla", MODELS / "TableTransaction.cfg",
               MODELS / "transaction_decision_model.py", MODELS / "tlc_support.py", Path(__file__)]
    evidence = {"version": 1, "status": "inconclusive", "transactions": 2, "tables": 2,
                "safety_only": True, "implementation_replay": False, "tool": tlc,
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)),
                "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sources}, "checks": []}
    try:
        template = (MODELS / "TableTransaction.cfg").read_text()
        cases = [(name, name, None) for name in PROFILES]
        cases += [(guard, profile, guard) for guard, (profile, _) in MUTANTS.items()]
        for name, profile, guard in cases:
            local = destination / name
            local.mkdir()
            shutil.copyfile(MODELS / "TableTransaction.tla", local / "TableTransaction.tla")
            (local / "model.cfg").write_text(configuration(template, profile, guard))
            command = [tlc, "-workers", "1", "-seed", "1", "-fp", "0", "-deadlock",
                       "-metadir", str(local / "states"), "-config", "model.cfg", "TableTransaction.tla"]
            (local / "command.json").write_text(json.dumps(command) + "\n")
            started = time.monotonic()
            try:
                result = subprocess.run(command, cwd=local, capture_output=True, text=True,
                                        env=os.environ | {"JAVA_TOOL_OPTIONS": "-Xmx512m"}, timeout=args.seconds)
            except subprocess.TimeoutExpired as failure:
                (local / "tlc.log").write_bytes((failure.stdout or b"") + (failure.stderr or b""))
                raise RuntimeError(f"{name}: incomplete exploration after timeout") from failure
            output = result.stdout + result.stderr
            (local / "tlc.log").write_text(output)
            check = {"name": name, "profile": profile, "seconds": round(time.monotonic() - started, 3)}
            if guard is None:
                generated, states = complete(result.returncode, output)
                check.update(status="passed", generated_states=generated, distinct_states=states)
                print(f"Table transaction {profile}: {states} states exhausted.", flush=True)
            else:
                actions = counterexample(result.returncode, output, MUTANTS[guard][1], ACTIONS)
                (local / "counterexample.json").write_text(json.dumps({
                    "violation": MUTANTS[guard][1], "actions": actions,
                    "implementation_replay": False}, indent=2) + "\n")
                check["status"] = "detected"
                print(f"Table transaction {guard}: {MUTANTS[guard][1]} detected.", flush=True)
            evidence["checks"].append(check)
        evidence["status"] = "passed"
        print("Five finite Table schedules and seven negative controls passed; no implementation refinement claim.")
        print(f"Evidence: {destination.relative_to(ROOT)}")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
