#!/usr/bin/env python3
"""Run the finite QueueLeaseTransaction TLA+ model, negative controls, and Zig trace replay."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from runner.paths import ROOT
from verification.models.tlc_support import complete, run_traces

MODELS = Path(__file__).resolve().parent

CONTROLS = (
    ("CheckTackPartition", "TackStatesMutuallyExclusive"),
    ("CheckKeyFifo", "KeyFifoMutualExclusion"),
    ("CheckLeaseEpochFence", "StaleEpochRejected"),
    ("CheckAtomicTurn", "AtomicThreePrimitiveTurn"),
    ("CheckSegmentReclaim", "SegmentReclaimedOnlyWhenTerminal"),
    ("CheckLeaseTimeFence", "ExpiredLeaseRejected"),
    ("CheckPolicyFence", "RevokedCommitRejected"),
    ("CheckRetainedPayload", "SegmentReclaimedOnlyWhenUnpinned"),
    ("CheckDlqDurability", "DlqRetainsPayload"),
)

ACTIONS = {
    "Init",
    "ClaimOffset1",
    "ClaimOffset2",
    "ClaimOffset3",
    "AckOffset2",
    "AckOffset3",
    "Tick",
    "ExpireLease1",
    "ReclaimOffset1",
    "PublishDlq",
    "ArchiveDlq",
    "PrepareTurn",
    "Revoke",
    "CommitThreePrimitiveTurn",
    "AbortTurn",
    "RecoverDecision",
    "Restart",
    "LoadAccepted",
    "StaleWorkerAck",
    "CorruptTackBitmap",
    "ReleaseHistory",
    "ReclaimSegment",
}

SAFE_SCHEDULES = {
    "three_primitive_commit_and_segment_gc": (
        [
            "Init",
            "ClaimOffset1",
            "ClaimOffset3",
            "AckOffset3",
            "PrepareTurn",
            "Restart",
            "LoadAccepted",
            "CommitThreePrimitiveTurn",
            "RecoverDecision",
            "ClaimOffset2",
            "AckOffset2",
            "ReleaseHistory",
            "ReclaimSegment",
        ],
        {
            "last_error": "none",
            "decision": "committed",
            "table_rows": 1,
            "outbox_next": 1,
            "dlq_next": 0,
            "offset0_state": "acked",
            "offset1_state": "acked",
            "offset2_state": "acked",
            "resident": True,
            "history_held": False,
            "segment_reclaimed": True,
            "uncommitted_isolated": True,
        },
    ),
    "abort_turn_preserves_queue_lease_and_isolates_outputs": (
        [
            "Init",
            "ClaimOffset1",
            "PrepareTurn",
            "AbortTurn",
            "RecoverDecision",
        ],
        {
            "last_error": "none",
            "decision": "aborted",
            "table_rows": 0,
            "outbox_next": 0,
            "dlq_next": 0,
            "offset0_state": "acquired",
            "offset1_state": "available",
            "offset2_state": "available",
            "epoch": 1,
            "uncommitted_isolated": True,
        },
    ),
    "paired_dlq_transfer_and_restart": (
        [
            "Init",
            "ClaimOffset1",
            "Tick",
            "ExpireLease1",
            "ReclaimOffset1",
            "Tick",
            "PublishDlq",
            "ArchiveDlq",
            "Restart",
        ],
        {
            "last_error": "none",
            "dlq_next": 1,
            "offset0_state": "archived",
            "offset1_state": "available",
            "offset2_state": "available",
            "epoch": 2,
            "resident": False,
        },
    ),
    "deadline_expiry_before_lease_deadline": (
        [
            "Init",
            "ClaimOffset1",
            "PrepareTurnDeadline",
            "TickDeadline",
            "CommitThreePrimitiveTurn",
        ],
        {
            "last_error": "TransactionDeadlineElapsed",
            "decision": "none",
            "table_rows": 0,
            "outbox_next": 0,
            "offset0_state": "acquired",
            "epoch": 1,
            "uncommitted_isolated": True,
        },
    ),
    "deadline_expiry_abort_cleanup": (
        [
            "Init",
            "ClaimOffset1",
            "PrepareTurnDeadline",
            "TickDeadline",
            "CommitThreePrimitiveTurn",
            "AbortTurn",
        ],
        {
            "last_error": "none",
            "decision": "aborted",
            "table_rows": 0,
            "outbox_next": 0,
            "offset0_state": "acquired",
            "epoch": 1,
            "uncommitted_isolated": True,
        },
    ),
}


def fail(message: str) -> None:
    raise SystemExit(message)


def counterexample(code: int, output: str, expected: str, allowed_actions: set[str] = ACTIONS) -> list[str]:
    violation = re.search(r"Error: Invariant (\w+) is violated\.", output)
    states = [int(n) for n in re.findall(r"^State (\d+): ", output, re.M)]
    actions = re.findall(r'\blast\s*\|->\s*"([^"]+)"', output)
    if (
        code != 12
        or not violation
        or violation[1] != expected
        or len(actions) < 2
        or actions[0] != "Init"
        or states != list(range(1, len(actions) + 1))
        or not set(actions) <= allowed_actions
        or "Finished in " not in output
    ):
        raise AssertionError(f"missing complete {expected} counterexample: {output[-4000:]}")
    return actions


def runner_controls() -> None:
    finished = (
        "Model checking completed. No error has been found.\n"
        "10 states generated, 2 distinct states found, 0 states left on queue"
    )
    assert complete(0, finished) == (10, 2)
    for code, text in (
        (1, finished),
        (0, finished.replace("0 states left", "1 states left")),
        (0, "Model checking completed. No error has been found."),
    ):
        try:
            complete(code, text)
        except AssertionError:
            continue
        raise AssertionError("incomplete exploration accepted")
    trace = (
        "Error: Invariant StaleEpochRejected is violated.\n"
        'State 1: <Initial predicate>\ns = [last |-> "Init"]\n'
        'State 2: <StaleWorkerAck line 95>\ns = [last |-> "StaleWorkerAck"]\n'
        "Finished in 1s"
    )
    assert counterexample(12, trace, "StaleEpochRejected") == ["Init", "StaleWorkerAck"]
    for code, text in (
        (1, trace),
        (12, trace.replace('"StaleWorkerAck"', '"UnknownAction"')),
        (12, trace.replace("State 2:", "State 3:")),
        (12, trace.replace("Finished in 1s", "")),
    ):
        try:
            counterexample(code, text, "StaleEpochRejected")
        except AssertionError:
            continue
        raise AssertionError("malformed counterexample accepted")


def parse_args(argv: list[str]) -> tuple[Path, Path, int]:
    if not argv:
        fail("usage: queue_lease_transaction_model.py <queue-lease-transaction-state-trace> [--output-dir DIR] [--seconds N]")
    replay = Path(argv[0]).resolve()
    args = argv[1:]
    output_dir: Path | None = None
    seconds = 120
    index = 0
    while index < len(args):
        if args[index] == "--output-dir":
            if index + 1 >= len(args):
                fail("--output-dir requires a path")
            output_dir = Path(args[index + 1])
            index += 2
        elif args[index] == "--seconds":
            if index + 1 >= len(args):
                fail("--seconds requires a positive integer")
            seconds = int(args[index + 1])
            if seconds <= 0:
                fail("--seconds must be positive")
            index += 2
        else:
            fail(f"unknown argument: {args[index]}")
    if output_dir is None:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        output_dir = ROOT / ".cache" / "verification" / "queue-lease-transaction-model" / f"{stamp}-{os.getpid()}"
    return replay, output_dir.resolve(), seconds


def run_tlc(work: Path, cfg_text: str, seconds: int) -> tuple[int, str]:
    tlc = shutil.which("tlc") or shutil.which("tlc2")
    if tlc is None:
        fail("tlc (TLA+ model checker) is not in PATH; run via 'just test::queue-lease-transaction-model'")
    shutil.copy2(MODELS / "QueueLeaseTransaction.tla", work / "QueueLeaseTransaction.tla")
    (work / "QueueLeaseTransaction.cfg").write_text(cfg_text, encoding="utf-8")
    cmd = [
        tlc,
        "-workers",
        "1",
        "-seed",
        "1",
        "-fp",
        "0",
        "-cleanup",
        "-deadlock",
        "-config",
        "QueueLeaseTransaction.cfg",
        "QueueLeaseTransaction",
    ]
    proc = subprocess.run(
        cmd,
        cwd=work,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=os.environ | {"JAVA_TOOL_OPTIONS": "-Xmx512m"},
        check=False,
        timeout=seconds,
    )
    return proc.returncode, proc.stdout


def assert_control_replay(switch: str, result: dict[str, object]) -> None:
    expected_map: dict[str, dict[str, object]] = {
        "CheckTackPartition": {
            "last_error": "QueueSidecarOverlap",
            "offset0_state": "acquired",
        },
        "CheckKeyFifo": {
            "last_error": "FIFOKeyBlocked",
            "offset0_state": "available",
            "offset1_state": "available",
        },
        "CheckLeaseEpochFence": {
            "last_error": "QueueLeaseFenced",
            "offset0_state": "acquired",
            "epoch": 2,
        },
        "CheckAtomicTurn": {
            "last_error": "none",
            "decision": "committed",
            "table_rows": 1,
            "outbox_next": 1,
            "offset0_state": "acked",
            "uncommitted_isolated": True,
        },
        "CheckSegmentReclaim": {
            "last_error": "none",
            "offset0_state": "available",
            "offset1_state": "available",
            "segment_reclaimed": False,
        },
        "CheckLeaseTimeFence": {
            "last_error": "QueueLeaseExpired",
            "decision": "none",
            "table_rows": 0,
            "outbox_next": 0,
            "offset0_state": "acquired",
        },
        "CheckPolicyFence": {
            "last_error": "CatalogDenied",
            "decision": "none",
            "table_rows": 0,
            "outbox_next": 0,
            "offset0_state": "acquired",
        },
        "CheckRetainedPayload": {
            "last_error": "QueueTerminalSegmentPinned",
            "offset0_state": "acked",
            "offset1_state": "acked",
            "history_held": True,
            "segment_reclaimed": False,
        },
        "CheckDlqDurability": {
            "last_error": "ClientOperationMissing",
            "offset0_state": "blocked",
            "dlq_next": 0,
        },
    }
    expected = expected_map.get(switch)
    if expected is None:
        fail(f"unhandled control switch: {switch}")
    for key, value in expected.items():
        if result.get(key) != value:
            fail(f"control {switch} Zig replay mismatch on {key}: expected {value!r}, got {result}")


def main(argv: list[str]) -> None:
    runner_controls()
    replay_binary, output_dir, seconds = parse_args(argv)
    output_dir.mkdir(parents=True, exist_ok=True)
    base_cfg = (MODELS / "QueueLeaseTransaction.cfg").read_text(encoding="utf-8")
    sources = [
        MODELS / "QueueLeaseTransaction.tla",
        MODELS / "QueueLeaseTransaction.cfg",
        MODELS / "tlc_support.py",
        MODELS / "queue_lease_transaction_state.zig",
        Path(__file__),
        ROOT / "packages/zig/transit-storage/src/Tack.zig",
        ROOT / "packages/zig/transit-storage/src/QueuePartition.zig",
        ROOT / "packages/zig/transit-storage/src/LogTransaction.zig",
        ROOT / "packages/zig/transit-catalog/src/DirectCatalog.zig",
        ROOT / "packages/zig/transit-catalog/src/DirectStorageGraph.zig",
    ]

    with tempfile.TemporaryDirectory(prefix="transit-queue-lease-tx-tlc-") as tmp:
        work = Path(tmp)
        code, out = run_tlc(work, base_cfg, seconds)
        (output_dir / "safe.out").write_text(out, encoding="utf-8")
        generated, distinct = complete(code, out)

        control_traces: list[list[str]] = []
        control_records: list[dict[str, object]] = []
        for idx, (switch, invariant) in enumerate(CONTROLS):
            mutated = base_cfg.replace(f"{switch} = TRUE", f"{switch} = FALSE")
            if mutated == base_cfg:
                fail(f"missing {switch} in QueueLeaseTransaction.cfg")
            c_work = work / f"control-{idx}"
            c_work.mkdir()
            c_code, c_out = run_tlc(c_work, mutated, seconds)
            (output_dir / f"{switch}.out").write_text(c_out, encoding="utf-8")
            trace = counterexample(c_code, c_out, invariant)
            control_traces.append(trace)
            control_records.append({"switch": switch, "invariant": invariant, "trace": trace})

        replayed_controls = run_traces(str(replay_binary), control_traces, work, seconds)
        for record, result in zip(control_records, replayed_controls, strict=True):
            assert_control_replay(str(record["switch"]), result)
            record["zig_replay"] = result

        safe_names = list(SAFE_SCHEDULES.keys())
        safe_traces = [SAFE_SCHEDULES[name][0] for name in safe_names]
        replayed_safe = run_traces(str(replay_binary), safe_traces, work, seconds)
        safe_records: list[dict[str, object]] = []
        for name, trace, actual in zip(safe_names, safe_traces, replayed_safe, strict=True):
            expected = SAFE_SCHEDULES[name][1]
            for key, value in expected.items():
                if actual.get(key) != value:
                    fail(f"safe schedule {name} Zig replay mismatch on {key}: expected {value!r}, got {actual}")
            safe_records.append({"name": name, "trace": trace, "zig_replay": actual})

    summary = {
        "model": "QueueLeaseTransaction",
        "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip()),
        "sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        "binary_sha256": hashlib.sha256(replay_binary.read_bytes()).hexdigest(),
        "tlc_version": out.splitlines()[0],
        "completed": True,
        "states_generated": generated,
        "distinct_states": distinct,
        "implementation_replay": {
            "controls": len(control_records),
            "safe_schedules": len(safe_records),
        },
        "controls": control_records,
        "safe_schedules": safe_records,
    }
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    rel = output_dir.relative_to(ROOT) if output_dir.is_relative_to(ROOT) else output_dir
    print(
        f"Queue lease transaction TLC: {distinct} states exhausted; "
        f"{len(CONTROLS)} negative controls and {len(safe_records)} concrete schedules replayed against Zig."
    )
    print(f"Evidence: {rel}")


if __name__ == "__main__":
    main(sys.argv[1:])
