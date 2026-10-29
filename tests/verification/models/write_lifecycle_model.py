"""Finite SQL write lifecycle/token safety and fail-closed negative controls."""
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
from verification.models.tlc_support import complete, run_traces

MODELS = Path(__file__).resolve().parent
ACTIONS = {"Init", "Freeze", "Accept", "Commit", "Retry", "Cancel", "Observe",
           "LaterInsert", "Crash", "Recover", "Fence", "Execution", "Inspection",
           "LoseReply", "Cleanup", "Submit1", "Submit2", "LoseReply1", "LoseReply2", "Rebind"}
GUARDS = {
    "CheckOriginal": "OriginalApplication", "CheckBasis": "FrozenSelection",
    "CheckAtomic": "AtomicVisibility", "CheckCounts": "TruthfulCounts",
    "CheckFence": "FencedPublication", "CheckPolicy": "AuthorizedPublication",
    "CheckDisclosure": "AuthorizedDisclosure", "CheckStable": "StableDecision",
    "CheckRetention": "RetainedHistory", "CheckDurability": "DurablePublication",
}
TOKEN_GUARDS = {"CheckScope": "AccountTokenUnique", "CheckFingerprint": "FingerprintConflict",
                "CheckBinding": "FrozenObject", "CheckRecovery": "RetainedIdentity",
                "CheckAccount": "AccountIsolation"}


def counterexample(code, output, expected):
    violation = re.search(r"Error: Invariant (\w+) is violated\.", output)
    states = [int(n) for n in re.findall(r"^State (\d+): ", output, re.M)]
    actions = re.findall(r'^/\\ last = "([^"]+)"$', output, re.M)
    if (code != 12 or not violation or violation[1] != expected or len(actions) < 2 or
            actions[0] != "Init" or states != list(range(1, len(actions) + 1)) or
            not set(actions) <= ACTIONS or "Finished in " not in output):
        raise AssertionError(f"missing complete {expected} counterexample: {output[-4000:]}")
    return actions


def configure(module, **values):
    config = (MODELS / f"{module}.cfg").read_text()
    for key, value in values.items():
        literal = json.dumps(value).upper() if isinstance(value, bool) else json.dumps(value)
        config, count = re.subn(rf'(?m)^    {key} = .+$', f'    {key} = {literal}', config)
        if count != 1:
            raise AssertionError(f"missing/duplicate configuration field {key}")
    return config


def run_tlc(module, config, directory, seconds):
    directory.mkdir()
    shutil.copyfile(MODELS / f"{module}.tla", directory / f"{module}.tla")
    (directory / "model.cfg").write_text(config)
    command = ["tlc", "-workers", "1", "-seed", "1", "-fp", "0",
               "-metadir", str(directory / "states"), "-config", "model.cfg", f"{module}.tla"]
    (directory / "command.json").write_text(json.dumps(command) + "\n")
    try:
        result = subprocess.run(command, cwd=directory, capture_output=True, text=True,
                                env=os.environ | {"JAVA_TOOL_OPTIONS": "-Xmx512m"}, timeout=seconds)
    except subprocess.TimeoutExpired as failure:
        (directory / "tlc.log").write_bytes((failure.stdout or b"") + (failure.stderr or b""))
        raise RuntimeError(f"{directory.name}: incomplete exploration after timeout") from failure
    output = result.stdout + result.stderr
    (directory / "tlc.log").write_text(output)
    return result.returncode, output


def runner_controls():
    finished = ("Model checking completed. No error has been found.\n"
                "10 states generated, 2 distinct states found, 0 states left on queue")
    assert complete(0, finished) == (10, 2)
    trace = ('Error: Invariant AtomicVisibility is violated.\n'
             'State 1: <Initial predicate>\n/\\ last = "Init"\n'
             'State 2: <Commit>\n/\\ last = "Commit"\nFinished in 1s')
    assert counterexample(12, trace, "AtomicVisibility") == ["Init", "Commit"]
    for code, output in ((1, trace), (12, trace.replace('"Commit"', '"Unknown"')),
                         (12, trace.replace("State 2:", "State 3:")),
                         (12, trace.replace("Finished in 1s", "")),
                         (12, trace.replace("AtomicVisibility", "WrongInvariant"))):
        try:
            counterexample(code, output, "AtomicVisibility")
        except AssertionError:
            continue
        raise AssertionError("malformed counterexample accepted")
    for code, output in ((1, finished), (0, finished.replace("0 states left", "1 states left")),
                         (0, finished.splitlines()[0])):
        try:
            complete(code, output)
        except AssertionError:
            continue
        raise AssertionError("incomplete exploration accepted")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", help="built TablePartition trace adapter")
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    if not shutil.which("tlc"):
        raise SystemExit("TLC missing: use nix develop --command just test::write-lifecycle-model")
    runner_controls()
    destination = ROOT / ".cache/verification/write-lifecycle-model" / (
        time.strftime("%Y%m%dT%H%M%S") + f"-{os.getpid()}")
    destination.mkdir(parents=True)
    sources = [MODELS / name for name in ("WriteLifecycle.tla", "WriteLifecycle.cfg",
               "WriteTokens.tla", "WriteTokens.cfg", "write_lifecycle_model.py", "tlc_support.py", "write_lifecycle_state.zig")]
    sources += [ROOT / "packages/zig/transit-storage/src" / name for name in
                ("TablePartition.zig", "LocalWal.zig", "TableDmlIntent.zig")]
    evidence = {"version": 1, "status": "inconclusive", "conditional_liveness": ["EligibleProgress", "LearnableOutcome"],
                "implementation_replay": False, "tool": str(Path(shutil.which("tlc")).resolve()),
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)),
                "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
                "checks": []}
    traces = {}
    try:
        profiles = [(kind, variant, path) for path in ("split", "combined")
                    for kind in ("insert", "update", "delete", "truncate")
                    for variant in (("normal", "noop", "empty", "invalid") if kind == "update"
                                    else ("normal", "empty") if kind != "insert" else ("normal", "invalid"))]
        for kind, variant, path in profiles:
            name = f"{path}-{kind}-{variant}"
            code, output = run_tlc("WriteLifecycle", configure("WriteLifecycle", Kind=kind, Variant=variant, Path=path), destination / name, args.seconds)
            generated, states = complete(code, output)
            evidence["checks"].append({"name": name, "status": "exhausted", "generated": generated, "distinct": states})
        fair = configure("WriteLifecycle").replace("SPECIFICATION Spec", "SPECIFICATION FairSpec")
        fair += "\nPROPERTIES EligibleProgress LearnableOutcome\n"
        code, output = run_tlc("WriteLifecycle", fair, destination / "fair-update", args.seconds)
        generated, states = complete(code, output)
        evidence["checks"].append({"name": "fair-update", "status": "exhausted", "generated": generated, "distinct": states})
        token_profiles = {"same": {}, "conflict": {"Fingerprint2": 2},
                          "tables": {"Table2": 2, "Fingerprint2": 2},
                          "accounts": {"Account2": 2}, "tokens": {"Token2": 2}}
        for name, fields in token_profiles.items():
            config = configure("WriteTokens", **({"Table2": 1, "Fingerprint2": 1} | fields))
            code, output = run_tlc("WriteTokens", config, destination / f"tokens-{name}", args.seconds)
            generated, states = complete(code, output)
            evidence["checks"].append({"name": f"tokens-{name}", "status": "exhausted", "generated": generated, "distinct": states})
        token_traces = {}
        for module, guards in (("WriteLifecycle", GUARDS), ("WriteTokens", TOKEN_GUARDS)):
            for guard, invariant in guards.items():
                name = f"{module}-{guard}"
                local = destination / name
                fields = {guard: False}
                if guard == "CheckAccount":
                    fields |= {"Account2": 2, "Table2": 1, "Fingerprint2": 1}
                code, output = run_tlc(module, configure(module, **fields), local, args.seconds)
                actions = counterexample(code, output, invariant)
                (local / "counterexample.json").write_text(json.dumps({"violation": invariant, "actions": actions,
                    "implementation_replay": True}, indent=2) + "\n")
                evidence["checks"].append({"name": name, "status": "detected", "invariant": invariant})
                if module == "WriteLifecycle":
                    traces[guard] = actions
                else:
                    mode = "TokenIsolation" if guard == "CheckAccount" else "TokenConflict"
                    token_traces[guard] = [mode, *actions]
        # These expected projections are independent, fixed fixture oracles.
        # The replay does not execute a second implementation of the TLA model.
        committed = {"rows": [2, 2, 0], "decision": "committed", "matched": 2, "changed": 2}
        expected = {key: committed for key in GUARDS}
        expected["CheckBasis"] = {"rows": [1, 1, 1], "decision": "rejected", "matched": 0, "changed": 0}
        for key in ("CheckFence", "CheckPolicy"):
            expected[key] = {"rows": [1, 1, 0], "decision": "admitted", "matched": 0, "changed": 0,
                             "last_error": "StaleWriterEpoch" if key == "CheckFence" else "PermissionDenied"}
        expected["CheckDisclosure"] = {"rows": [1, 1, 0], "decision": "not_observed", "matched": 0,
                                       "changed": 0, "last_error": "PermissionDenied"}
        expected_tokens = {
            "CheckScope": {"replies": [1, 3], "unique_tokens": 1, "last_error": "ClientTokenConflict"},
            "CheckFingerprint": {"replies": [1, 3], "unique_tokens": 1, "last_error": "ClientTokenConflict"},
            "CheckBinding": {"replies": [1, 0], "target1": 1, "unique_tokens": 1, "last_error": "none"},
            "CheckRecovery": {"replies": [1, 0], "retained": True, "unique_tokens": 1, "last_error": "none"},
            "CheckAccount": {"replies": [1, 2], "unique_tokens": 2, "last_error": "none"},
        }
        all_traces = list(traces.values()) + list(token_traces.values())
        replayed = run_traces(args.binary, all_traces, destination, args.seconds)
        replayed_lifecycle = replayed[:len(traces)]
        replayed_tokens = replayed[len(traces):]
        for (guard, events), actual in zip(traces.items(), replayed_lifecycle, strict=True):
            for field, value in expected[guard].items():
                if actual[field] != value:
                    raise AssertionError(f"{guard} replay {events}: {actual} != {expected[guard]}")
            if actual["retained_rows"] != 2:
                raise AssertionError("retained snapshot changed")
        for (guard, events), actual in zip(token_traces.items(), replayed_tokens, strict=True):
            for field, value in expected_tokens[guard].items():
                if actual[field] != value:
                    raise AssertionError(f"{guard} token replay {events}: {actual} != {expected_tokens[guard]}")
        (destination / "replay-results.json").write_text(json.dumps(replayed, indent=2) + "\n")
        evidence["implementation_replay"] = {"selected_lifecycle_counterexamples": len(traces),
                                              "tokens": len(token_traces), "truncate": False, "finite_edge_correspondence": False}
        evidence["binary_sha256"] = hashlib.sha256(Path(args.binary).read_bytes()).hexdigest()
        evidence["status"] = "passed"
        print(f"Write lifecycle TLC: {len(profiles) + len(token_profiles)} finite profiles exhausted; "
              f"{len(GUARDS) + len(TOKEN_GUARDS)} negative controls detected. TRUNCATE and combined acceptance are proposals.")
        print(f"Evidence: {destination.relative_to(ROOT)}")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
