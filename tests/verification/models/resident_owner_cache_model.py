#!/usr/bin/env python3
"""Run the ResidentOwnerCache TLA+ model, negative controls, and Zig trace replay."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MODELS = Path(__file__).resolve().parent
ACTION_RE = re.compile(r"^State \d+: <([A-Za-z0-9_]+) ")

CONTROLS = (
    ("CheckRecoverSincePrefix", "ResidentOwnerMatchesColdReplay"),
    ("CheckUncertainAppendEviction", "NoPoisonedResidentAfterUncertainAppend"),
    ("CheckTxOwnerIsolation", "TransactionDoesNotMutateResidentSlot"),
    ("CheckEvictBeforeRelease", "NoDanglingWarmCachePin"),
    ("CheckConflictAbsenceProof", "RetryPinOnlyOnVerifiedAbsence"),
)


def fail(message: str) -> None:
    raise SystemExit(message)


def parse_args(argv: list[str]) -> tuple[Path, Path]:
    if not argv:
        fail("usage: resident_owner_cache_model.py <resident-owner-cache-state-trace> [--output-dir DIR]")
    replay = Path(argv[0]).resolve()
    args = argv[1:]
    output_dir: Path | None = None
    index = 0
    while index < len(args):
        if args[index] == "--output-dir":
            if index + 1 >= len(args):
                fail("--output-dir requires a path")
            output_dir = Path(args[index + 1])
            index += 2
        else:
            fail(f"unknown argument: {args[index]}")
    if output_dir is None:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        output_dir = ROOT / ".cache" / "verification" / "resident-owner-cache-model" / f"{stamp}-{os.getpid()}"
    return replay, output_dir.resolve()


def run_tlc(work: Path, cfg_text: str) -> tuple[int, str]:
    tlc = shutil.which("tlc") or shutil.which("tlc2")
    if tlc is None:
        fail("tlc (TLA+ model checker) is not in PATH; run via 'just test::resident-owner-cache-model'")
    shutil.copy2(MODELS / "ResidentOwnerCache.tla", work / "ResidentOwnerCache.tla")
    (work / "ResidentOwnerCache.cfg").write_text(cfg_text, encoding="utf-8")
    cmd = [tlc, "-workers", "1", "-seed", "1", "-fp", "0", "-cleanup", "-deadlock", "-config", "ResidentOwnerCache.cfg", "ResidentOwnerCache"]
    proc = subprocess.run(cmd, cwd=work, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    return proc.returncode, proc.stdout


def extract_trace(output: str) -> list[str]:
    actions = ["Init"]
    for line in output.splitlines():
        match = ACTION_RE.match(line.strip())
        if match and match.group(1) != "Initial":
            actions.append(match.group(1))
    if len(actions) < 2:
        fail(f"TLC failure did not include a replayable action trace:\n{output}")
    return actions


def replay_traces(binary: Path, traces: list[list[str]], work: Path) -> list[dict[str, object]]:
    trace_file = work / "traces.json"
    trace_file.write_text(json.dumps(traces), encoding="utf-8")
    proc = subprocess.run([str(binary), str(trace_file)], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if proc.returncode != 0:
        fail(f"Zig resident owner cache replay failed ({proc.returncode}):\n{proc.stderr}\n{proc.stdout}")
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    if len(lines) != len(traces):
        fail(f"expected {len(traces)} replay results, got {len(lines)}")
    return [json.loads(line) for line in lines]


def assert_control_replay(switch: str, result: dict[str, object]) -> None:
    if switch == "CheckRecoverSincePrefix":
        if result["last_error"] != "InvalidDirectCatalogHistory":
            fail(f"expected Zig recoverSince with corrupted chain hint to fail closed with InvalidDirectCatalogHistory, got {result}")
    elif switch == "CheckUncertainAppendEviction":
        if result["last_error"] != "TableRecoveryRequired":
            fail(f"expected Zig poisoned owner after uncertain append to fail closed with TableRecoveryRequired, got {result}")
    elif switch == "CheckTxOwnerIsolation":
        if not result["resident_slot_unchanged"] or result["tx_private_rows"] != 1 or result["public_rows"] != 0:
            fail(f"expected Zig transaction execution to isolate resident CachedTable slot and keep public_rows=0, got {result}")
    elif switch == "CheckEvictBeforeRelease":
        if result["cache_advertised"] or not result["pin_released"]:
            fail(f"expected Zig cache eviction to stop advertising before release and complete release on recovery, got {result}")
    elif switch == "CheckConflictAbsenceProof":
        if result["last_error"] not in ("DataIdentityConflict", "Conflict") or not result["pin_accepted"]:
            fail(f"expected Zig ambiguous pin Conflict to preserve accepted original pin in pinState, got {result}")
    else:
        fail(f"unhandled control switch: {switch}")


def main(argv: list[str]) -> None:
    replay_binary, output_dir = parse_args(argv)
    output_dir.mkdir(parents=True, exist_ok=True)
    base_cfg = (MODELS / "ResidentOwnerCache.cfg").read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="transit-resident-owner-cache-tlc-") as tmp:
        work = Path(tmp)
        code, out = run_tlc(work, base_cfg)
        (output_dir / "safe.out").write_text(out, encoding="utf-8")
        if code != 0 or "Model checking completed. No error has been found." not in out or "0 states left on queue." not in out:
            fail(f"ResidentOwnerCache safe model failed:\n{out}")
        match = re.search(r"(\d+) states generated, (\d+) distinct states found", out)
        if not match:
            fail(f"missing state count in ResidentOwnerCache output:\n{out}")
        generated, distinct = int(match.group(1)), int(match.group(2))

        control_traces: list[list[str]] = []
        control_records: list[dict[str, object]] = []
        for idx, (switch, invariant) in enumerate(CONTROLS):
            mutated = base_cfg.replace(f"{switch} = TRUE", f"{switch} = FALSE")
            if mutated == base_cfg:
                fail(f"missing {switch} in ResidentOwnerCache.cfg")
            c_work = work / f"control-{idx}"
            c_work.mkdir()
            c_code, c_out = run_tlc(c_work, mutated)
            (output_dir / f"{switch}.out").write_text(c_out, encoding="utf-8")
            if c_code == 0 or f"Invariant {invariant} is violated." not in c_out:
                fail(f"negative control {switch} did not violate {invariant}:\n{c_out}")
            trace = extract_trace(c_out)
            control_traces.append(trace)
            control_records.append({"switch": switch, "invariant": invariant, "trace": trace})

        replayed = replay_traces(replay_binary, control_traces, work)
        for record, result in zip(control_records, replayed):
            assert_control_replay(str(record["switch"]), result)
            record["zig_replay"] = result

    summary = {
        "model": "ResidentOwnerCache",
        "states_generated": generated,
        "distinct_states": distinct,
        "controls": control_records,
    }
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    rel = output_dir.relative_to(ROOT) if output_dir.is_relative_to(ROOT) else output_dir
    print(f"Resident owner cache TLC: {distinct} states exhausted; five negative controls detected and replayed against Zig.")
    print(f"Evidence: {rel}")


if __name__ == "__main__":
    main(sys.argv[1:])
