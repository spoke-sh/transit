"""Private transactional handler comparison; failures retain every raw attempt."""
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import time

from performance.load.station_turn import payload_hash
from performance.storage.log_runtime import distribution, require
from runner.capture import identity, provenance, write_json
from runner.paths import ROOT
from storage.tables.direct_table_maintenance import process_usage

COUNTERS = set("alloc_attempts alloc_successes resize_attempts resize_successes growing_resize_attempts remap_attempts remap_successes frees requested_bytes acquired_bytes released_bytes forbidden_attempts".split())

def validate(records, definition):
    groups = {}
    for row in records:
        groups.setdefault(row["event"], []).append(row)
    require(set(groups) == {"input_attempt", "attempt", "confirmed", "sample", "complete"}, "Missing or failed work")
    for kind in ("input_attempt", "attempt", "confirmed", "sample"):
        require([row["index"] for row in groups[kind]] == list(range(23)), f"Incomplete or duplicated {kind}")
    require(len(groups["complete"]) == 1 and groups["complete"][0]["definition"] == definition
            and groups["complete"][0]["turns"] == 23, "Missing completion evidence")
    allocations = Counter()
    for index, row in enumerate(groups["sample"]):
        require(groups["input_attempt"][index]["operation"] == groups["attempt"][index]["operation"], "Changed input identity")
        require(row["sha256"] == payload_hash(index), "State differs from the independent oracle")
        require(row["stage"] == ("warmup" if index < 3 else "measured") and row["ns"] > 0, "Invalid sample")
        require(row["runner_peak_bytes"] <= 64 * 1024 * 1024, "Resident budget exceeded")
        require(set(row["backing"]) == COUNTERS and all(isinstance(n, int) and n >= 0 for n in row["backing"].values()), "Incomplete allocation counters")
        if index >= 3:
            allocations.update(row["backing"])
    require(len({json.dumps(row["operation"], sort_keys=True) for row in groups["confirmed"]}) == 23, "Reused commit")
    return dict(attempts=23, successful=23, failed=0, refused=0, unknown=0,
                turn_ns=distribution([row["ns"] for row in groups["sample"][3:]]),
                client_backing=dict(allocations), passed=True)


def measure(node, caller, root, profile, url, restart, process):
    destination = Path(os.environ["TRANSIT_STATION_TRANSACTION_BASELINE"]).resolve()
    destination.mkdir(parents=True, exist_ok=False)
    definition = json.loads((ROOT / "contracts/transit-v1.schema.json").read_text())["x-transit"]["definition"]
    report = dict(completed=False, source=provenance(ROOT), definition=definition,
                  source_diff_sha256=hashlib.sha256(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=ROOT)).hexdigest(),
                  binaries=[identity(Path(path)) for path in (node, caller)],
                  config=dict(warmup=3, repeat=20),
                  machine=dict(platform=platform.platform(), cpu_count=os.cpu_count(), load=os.getloadavg(), affinity=sorted(os.sched_getaffinity(0))),
                  method=dict(runtime="private transactional handler", state_bytes=128, outputs_per_turn=1,
                              additional_work="one Table insert, two private Table reads and one journal append per turn",
                              timer="pending discovery through original decision and cleanup confirmation",
                              excludes=["input admission", "independent verification", "effect dispatch"],
                              client_allocations="runner, signed catalog caller and HTTP transport",
                              server_allocations="unmeasured", wal_requests="unmeasured", object_requests="unmeasured",
                              physical_syncs="unmeasured", cpu_cycles="unmeasured"))
    def command(phase):
        return [caller, url, f"station-transaction-{phase}-measured", str(profile)]
    try:
        subprocess.run(command("setup"), check=True, timeout=180)
        original = Path(f"{profile}.station-measured").read_bytes()
        report["node_before"] = process_usage(process())
        started = time.monotonic()
        with (destination / "measure.jsonl").open("w") as output, (destination / "diagnostics.log").open("w") as errors:
            subprocess.run(command("measure"), stdout=output, stderr=errors, check=True, timeout=3600)
        report["seconds"] = time.monotonic() - started
        report["node_after"] = process_usage(process())
        records = [json.loads(line) for line in (destination / "measure.jsonl").read_text().splitlines()]
        report["verification"] = validate(records, definition)
        restart()
        subprocess.run(command("recover"), check=True, timeout=180)
        subprocess.run(command("verify"), check=True, timeout=600)
        restart()
        subprocess.run(command("verify"), check=True, timeout=600)
        require(Path(f"{profile}.station-measured").read_bytes() == original, "Changed original binding")
        report["recovery"] = dict(restarts=2, signal="SIGKILL", replacement_principal=1018, handler_calls=0, passed=True)
        report["completed"] = True
    finally:
        if "verification" not in report and (destination / "measure.jsonl").exists():
            records = []
            for line in (destination / "measure.jsonl").read_text().splitlines():
                try:
                    records.append(json.loads(line))
                except ValueError:
                    break
            attempts = {row["index"] for row in records if row.get("event") == "attempt"}
            confirmed = {row["index"] for row in records if row.get("event") == "confirmed"}
            samples = {row["index"] for row in records if row.get("event") == "sample"}
            report["verification"] = dict(passed=False, attempts=len(attempts), successful=len(samples & confirmed),
                                          unknown=len(attempts - confirmed), failed=len(confirmed - samples))
        write_json(destination / "report.json", report)
    print(f"Transactional Station comparison verified: {destination / 'report.json'}", flush=True)
