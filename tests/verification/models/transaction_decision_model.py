"""Exhaust one original transaction decision and detect six missing obligations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

from runner.paths import ROOT
from verification.models.tlc_support import complete

MODELS = Path(__file__).resolve().parent
MUTANTS = {
    "CheckFrozen": "FrozenDecision",
    "CheckComplete": "CompletePreparation",
    "CheckFence": "FencedPublication",
    "CheckPolicy": "CurrentPublication",
    "CheckStable": "OriginalDecision",
    "CheckDisclosure": "CurrentDisclosure",
}
ACTIONS = {"Init", "Freeze", "Prepare", "Commit", "Abort", "Observe",
           "LoseReply", "Recover", "Fence", "Policy", "Availability", "Conflict"}


def counterexample(code, output, expected):
    violation = re.search(r"Error: Invariant (\w+) is violated\.", output)
    states = [int(n) for n in re.findall(r"^State (\d+): ", output, re.M)]
    actions = re.findall(r'^/\\ last = "([^"]+)"$', output, re.M)
    if (code != 12 or not violation or violation[1] != expected or
            len(actions) < 2 or actions[0] != "Init" or
            states != list(range(1, len(actions) + 1)) or
            not set(actions) <= ACTIONS or "Finished in " not in output):
        raise AssertionError(f"missing complete {expected} counterexample: {output[-4000:]}")
    return actions


def runner_controls():
    finished = ("Model checking completed. No error has been found.\n"
                "10 states generated, 2 distinct states found, 0 states left on queue")
    assert complete(0, finished) == (10, 2)
    for code, text in ((1, finished), (0, finished.replace("0 states left", "1 states left")),
                       (0, "Model checking completed. No error has been found.")):
        try:
            complete(code, text)
        except AssertionError:
            continue
        raise AssertionError("incomplete exploration accepted")
    trace = ('Error: Invariant FrozenDecision is violated.\n'
             'State 1: <Initial predicate>\n/\\ last = "Init"\n'
             'State 2: <Decide>\n/\\ last = "Abort"\nFinished in 1s')
    assert counterexample(12, trace, "FrozenDecision") == ["Init", "Abort"]
    for code, text in ((1, trace), (12, trace.replace('"Abort"', '"Unknown"')),
                       (12, trace.replace("State 2:", "State 3:")),
                       (12, trace.replace("Finished in 1s", ""))):
        try:
            counterexample(code, text, "FrozenDecision")
        except AssertionError:
            continue
        raise AssertionError("malformed counterexample accepted")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    tlc = shutil.which("tlc")
    if tlc is None:
        raise SystemExit("TLC missing: use nix develop --command just test::transaction-decision-model")
    runner_controls()
    destination = ROOT / ".cache/verification/transaction-decision-model" / (
        time.strftime("%Y%m%dT%H%M%S") + f"-{os.getpid()}")
    destination.mkdir(parents=True)
    sources = [MODELS / "TransactionDecision.tla", MODELS / "TransactionDecision.cfg",
               MODELS / "tlc_support.py", Path(__file__),
               ROOT / "packages/zig/transit-storage/src/TransactionDecisionLog.zig",
               ROOT / "packages/zig/transit-storage/src/TransactionDirectory.zig"]
    evidence = {"version": 1, "status": "inconclusive", "participants": 2,
                "epochs": 2, "attempts": 1, "safety_only": True,
                "implementation_replay": False, "tool": tlc,
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)),
                "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sources}, "checks": []}
    try:
        template = (MODELS / "TransactionDecision.cfg").read_text()
        for guard in (None, *MUTANTS):
            name = guard or "safe"
            local = destination / name
            local.mkdir()
            shutil.copyfile(MODELS / "TransactionDecision.tla", local / "TransactionDecision.tla")
            config = template if guard is None else template.replace(f"{guard} = TRUE", f"{guard} = FALSE")
            if guard is not None and config == template:
                raise AssertionError(f"missing mutation switch: {guard}")
            (local / "model.cfg").write_text(config)
            command = [tlc, "-workers", "1", "-seed", "1", "-fp", "0",
                       "-metadir", str(local / "states"), "-config", "model.cfg", "TransactionDecision.tla"]
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
            if guard is None:
                generated, states = complete(result.returncode, output)
                evidence["generated_states"] = generated
                evidence["distinct_states"] = states
            else:
                actions = counterexample(result.returncode, output, MUTANTS[guard])
                (local / "counterexample.json").write_text(json.dumps({
                    "violation": MUTANTS[guard], "actions": actions,
                    "implementation_replay": False}, indent=2) + "\n")
            evidence["checks"].append({"guard": name, "status": "passed" if guard is None else "detected",
                                       "seconds": round(time.monotonic() - started, 3)})
        evidence["status"] = "passed"
        print(f"Transaction decision TLC: {evidence['distinct_states']} states exhausted; six negative controls detected. "
              "Table visibility, isolation and implementation refinement are outside this model.")
        print(f"Evidence: {destination.relative_to(ROOT)}")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
