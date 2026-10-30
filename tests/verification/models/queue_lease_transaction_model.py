#!/usr/bin/env python3
"""Run the finite QueueLeaseTransaction design model and negative controls."""

from __future__ import annotations

import json
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from runner.paths import ROOT

MODELS = Path(__file__).resolve().parent
ACTION_RE = re.compile(r"^State \d+: <([A-Za-z0-9_]+) ")

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


def fail(message: str) -> None:
    raise SystemExit(message)


def parse_args(argv: list[str]) -> Path:
    output_dir: Path | None = None
    index = 0
    while index < len(argv):
        if argv[index] == "--output-dir":
            if index + 1 >= len(argv):
                fail("--output-dir requires a path")
            output_dir = Path(argv[index + 1])
            index += 2
        else:
            fail(f"unknown argument: {argv[index]}")
    if output_dir is None:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        output_dir = ROOT / ".cache" / "verification" / "queue-lease-transaction-model" / f"{stamp}-{os.getpid()}"
    return output_dir.resolve()


def run_tlc(work: Path, cfg_text: str) -> tuple[int, str]:
    tlc = shutil.which("tlc") or shutil.which("tlc2")
    if tlc is None:
        fail("tlc (TLA+ model checker) is not in PATH; run via 'just test::queue-lease-transaction-model'")
    shutil.copy2(MODELS / "QueueLeaseTransaction.tla", work / "QueueLeaseTransaction.tla")
    (work / "QueueLeaseTransaction.cfg").write_text(cfg_text, encoding="utf-8")
    cmd = [tlc, "-workers", "1", "-seed", "1", "-fp", "0", "-cleanup", "-deadlock", "-config", "QueueLeaseTransaction.cfg", "QueueLeaseTransaction"]
    proc = subprocess.run(cmd, cwd=work, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=300)
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


def main(argv: list[str]) -> None:
    output_dir = parse_args(argv)
    output_dir.mkdir(parents=True, exist_ok=True)
    base_cfg = (MODELS / "QueueLeaseTransaction.cfg").read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="transit-queue-lease-tx-tlc-") as tmp:
        work = Path(tmp)
        code, out = run_tlc(work, base_cfg)
        (output_dir / "safe.out").write_text(out, encoding="utf-8")
        if code != 0 or "Model checking completed. No error has been found." not in out or "0 states left on queue." not in out:
            fail(f"QueueLeaseTransaction safe model failed:\n{out}")
        match = re.search(r"(\d+) states generated, (\d+) distinct states found", out)
        if not match:
            fail(f"missing state count in QueueLeaseTransaction output:\n{out}")
        generated, distinct = int(match.group(1)), int(match.group(2))

        control_records: list[dict[str, object]] = []
        for idx, (switch, invariant) in enumerate(CONTROLS):
            mutated = base_cfg.replace(f"{switch} = TRUE", f"{switch} = FALSE")
            if mutated == base_cfg:
                fail(f"missing {switch} in QueueLeaseTransaction.cfg")
            c_work = work / f"control-{idx}"
            c_work.mkdir()
            c_code, c_out = run_tlc(c_work, mutated)
            (output_dir / f"{switch}.out").write_text(c_out, encoding="utf-8")
            if c_code == 0 or f"Invariant {invariant} is violated." not in c_out:
                fail(f"negative control {switch} did not violate {invariant}:\n{c_out}")
            trace = extract_trace(c_out)
            control_records.append({"switch": switch, "invariant": invariant, "trace": trace})

    summary = {
        "model": "QueueLeaseTransaction",
        "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "model_sha256": hashlib.sha256((MODELS / "QueueLeaseTransaction.tla").read_bytes()).hexdigest(),
        "config_sha256": hashlib.sha256(base_cfg.encode()).hexdigest(),
        "driver_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip()),
        "tlc_version": out.splitlines()[0],
        "completed": True,
        "states_generated": generated,
        "distinct_states": distinct,
        "controls": control_records,
    }
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    rel = output_dir.relative_to(ROOT) if output_dir.is_relative_to(ROOT) else output_dir
    print(f"Queue lease transaction TLC: {distinct} states exhausted; {len(CONTROLS)} negative controls detected. No storage/runtime correspondence claimed.")
    print(f"Evidence: {rel}")


if __name__ == "__main__":
    main(sys.argv[1:])
