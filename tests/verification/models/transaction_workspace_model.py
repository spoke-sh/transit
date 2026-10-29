"""Exhaust catalog transaction workspace admission, common-cut epoch fence, and two-phase private statements."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from runner.paths import ROOT
from verification.models.tlc_support import complete, run_traces
from verification.models.transaction_decision_model import counterexample, runner_controls

MODELS = Path(__file__).resolve().parent
MUTANTS = {
    "CheckCoordinator": "ExclusiveCoordinator",
    "CheckAccountQuota": "AccountQuotaBounded",
    "CheckCutEpoch": "SingleEpochCut",
    "CheckCutRequired": "CutPrecedesStatement",
    "CheckSequence": "OrderedTwoPhaseStatements",
    "CheckOpClaim": "DisjointOperationClaims",
    "CheckWorkspaceQuota": "WorkspaceBytesBounded",
    "CheckDisclosure": "AuthorizedWorkspaceDisclosure",
}
ACTIONS = {
    "Init", "Begin1", "Begin2", "PinSelected", "AdvanceEpoch", "AcquireCut",
    "AdmitStmt1", "AdmitStmt2", "ExecuteStmt", "Autocommit1",
    "InspectWorkspace", "TogglePolicy", "CrashRecover",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", help="built DirectCatalog transaction workspace trace adapter")
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be positive")
    tlc = shutil.which("tlc")
    if tlc is None:
        raise SystemExit("TLC missing: use nix develop --command just test::transaction-workspace-model")
    runner_controls()
    destination = ROOT / ".cache/verification/transaction-workspace-model" / (
        time.strftime("%Y%m%dT%H%M%S") + f"-{os.getpid()}")
    destination.mkdir(parents=True)
    sources = [
        MODELS / "TransactionWorkspace.tla", MODELS / "TransactionWorkspace.cfg",
        MODELS / "tlc_support.py", MODELS / "transaction_workspace_state.zig", Path(__file__),
        ROOT / "packages/zig/transit-catalog/src/DirectCatalog.zig",
        ROOT / "packages/zig/transit-catalog/src/DirectTransaction.zig",
        ROOT / "packages/zig/transit-catalog/src/DirectTransactionWorkspace.zig",
        ROOT / "packages/zig/transit-catalog/src/DirectClientToken.zig",
        ROOT / "packages/zig/transit-catalog/src/OperationBinding.zig",
    ]
    evidence = {
        "version": 1, "status": "inconclusive", "safety_only": True,
        "implementation_replay": False, "tool": tlc,
        "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)),
        "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        "checks": [],
    }
    traces = {}
    try:
        template = (MODELS / "TransactionWorkspace.cfg").read_text()
        for guard in (None, *MUTANTS):
            name = guard or "safe"
            local = destination / name
            local.mkdir()
            shutil.copyfile(MODELS / "TransactionWorkspace.tla", local / "TransactionWorkspace.tla")
            config = template if guard is None else template.replace(f"{guard} = TRUE", f"{guard} = FALSE")
            if guard is not None and config == template:
                raise AssertionError(f"missing mutation switch: {guard}")
            (local / "model.cfg").write_text(config)
            command = [tlc, "-workers", "1", "-seed", "1", "-fp", "0",
                       "-metadir", str(local / "states"), "-config", "model.cfg", "TransactionWorkspace.tla"]
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
                actions = counterexample(result.returncode, output, MUTANTS[guard], ACTIONS)
                traces[guard] = actions
                (local / "counterexample.json").write_text(json.dumps({
                    "violation": MUTANTS[guard], "actions": actions,
                    "implementation_replay": True}, indent=2) + "\n")
            evidence["checks"].append({
                "guard": name, "status": "passed" if guard is None else "detected",
                "seconds": round(time.monotonic() - started, 3),
            })
        expected = {
            "CheckCoordinator": {"coordination": 4, "active_tx": 1, "last_error": "InvalidClientToken"},
            "CheckAccountQuota": {"active_tx": 1, "last_error": "TransactionAccountCapacity"},
            "CheckCutEpoch": {"cut_acquired": False, "last_error": "TransactionAuthorityChanged"},
            "CheckCutRequired": {"cut_acquired": False, "last_seq": 0, "pending_seq": 0, "last_error": "TransactionCutNotAcquired"},
            "CheckSequence": {"cut_acquired": True, "last_seq": 0, "pending_seq": 0, "last_error": "TransactionStatementConflict"},
            "CheckOpClaim": {"last_error": "DataIdentityConflict"},
            "CheckWorkspaceQuota": {"cut_acquired": True, "last_seq": 2, "pending_seq": 2, "private_rows": 1, "public_rows": 0, "last_error": "TransactionWorkspaceLimit"},
            "CheckDisclosure": {"disclosed": "denied", "last_error": "CatalogDenied"},
        }
        replayed = run_traces(args.binary, list(traces.values()), destination, args.seconds)
        for (guard, events), actual in zip(traces.items(), replayed, strict=True):
            for field, value in expected[guard].items():
                if actual[field] != value:
                    raise AssertionError(f"{guard} replay {events}: {actual} != {expected[guard]}")
        (destination / "replay-results.json").write_text(json.dumps(replayed, indent=2) + "\n")
        evidence["implementation_replay"] = {"counterexamples": len(traces)}
        evidence["binary_sha256"] = hashlib.sha256(Path(args.binary).read_bytes()).hexdigest()
        evidence["status"] = "passed"
        print(f"Transaction workspace TLC: {evidence['distinct_states']} states exhausted; "
              f"eight negative controls detected and replayed against Zig.")
        print(f"Evidence: {destination.relative_to(ROOT)}")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
