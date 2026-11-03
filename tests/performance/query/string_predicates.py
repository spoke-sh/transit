"""Explicit raw/prepared page experiment with independent Python outcomes."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import platform
import statistics
from runner import capture
from runner.paths import ROOT
from query.logical.string_execution import expected

COLLATIONS = ("utf8_binary", "ascii_ci", "ebcdic_cp037", "ebcdic_037_pad", "ebcdic_1047_nopad")
ENCODINGS = ("dictionary", "fsst")
ROWS, REPEATS, CONSTRUCTIONS, BUDGET = 4096, 30, 100, 2 * 1024 * 1024
SOURCES = (
    "tests/performance/query/string_predicates.py",
    "tests/performance/query/string_predicates.zig",
    "tests/query/logical/string_execution.py",
    "tests/runner/capture.py",
    "build/checks.zig",
    "packages/zig/transit-fuze/src/ColumnPredicate.zig",
    "packages/zig/transit-fuze/src/Collation.zig",
    "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    "packages/zig/transit-memory/src/AllocationProbe.zig",
)


def oracle(collation):
    rows = [dict(state="value", value=f"Repeated Common Prefix {i % 256:03} Mixed Case Payload") for i in range(ROWS)]
    case = dict(collation=collation, literal="Repeated Common Prefix 128 Mixed Case Payload", rows=rows)
    outcomes = [outcome for op in ("eq", "ne", "lt", "le", "gt", "ge") for outcome in expected(dict(case, op=op))]
    return dict(checksum=sum(i + 1 for i, outcome in enumerate(outcomes) if outcome == "yes") * REPEATS,
                outcomes_sha256=hashlib.sha256(bytes(ord("Y") if outcome == "yes" else ord("N") for outcome in outcomes)).hexdigest())


def checked(sample, mode, collation, encoding, wanted):
    required = dict(wanted, mode=mode, collation=collation, encoding=encoding,
                    rows=ROWS, repeats=REPEATS, constructions=CONSTRUCTIONS, budget_bytes=BUDGET,
                    visits=REPEATS * (256 if encoding == "dictionary" else ROWS),
                    warm_allocations=0, warm_resizes=0, warm_remaps=0, warm_allocated_bytes=0,
                    end_live_bytes=0, build_mode="safe")
    for field, value in required.items():
        if sample.get(field) != value:
            raise ValueError(f"{mode}/{collation}/{encoding}: {field}: {sample.get(field)!r} != {value!r}")
    for field in ("elapsed_ns", "cpu_ns", "cold_ns", "encoded_bytes", "peak_bytes"):
        if not isinstance(sample.get(field), int) or sample[field] <= 0:
            raise ValueError(f"invalid {field}")
    if not 0 <= sample["prepared_bytes"] <= sample["peak_bytes"] <= BUDGET:
        raise ValueError("invalid memory accounting")
    if (mode == "prepared") != (sample["prepared_bytes"] > 0):
        raise ValueError("wrong preparation profile")
    if not sample.get("compiler") or not sample.get("cpu"):
        raise ValueError("missing build identity")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--repetitions", type=int, default=5)
    args = parser.parse_args()
    if not 3 <= args.repetitions <= 20:
        parser.error("repetitions must be between 3 and 20")
    binary = args.binary.resolve()
    directory = capture.directory(ROOT / ".cache/verification/string-predicates/latest.json")
    cpu = min(os.sched_getaffinity(0))
    record = dict(capture.provenance(ROOT), binary=capture.identity(binary),
                  sources={path: capture.identity(ROOT / path) for path in SOURCES},
                  machine=platform.uname()._asdict(), cpu=cpu, load=os.getloadavg(),
                  cpuinfo=Path("/proc/cpuinfo").read_text().split("\n\n")[0],
                  parameters=dict(repetitions=args.repetitions, rows=ROWS, repeats=REPEATS,
                                  constructions=CONSTRUCTIONS, budget_bytes=BUDGET),
                  cache="one unmeasured page pass and arena consolidation per process; no device IO",
                  timing="codec evaluation only; excludes reset, checksums and cleanup",
                  status="running", completed=False,
                  samples=[], summary=[])
    def save():
        capture.write_json(directory / "experiment.json", record)
    save()
    profiles = itertools.product(COLLATIONS, ENCODINGS)
    try:
        for collation, encoding in profiles:
            wanted = oracle(collation)
            samples = []
            for repetition in range(args.repetitions):
                for mode in (("raw", "prepared") if repetition % 2 else ("prepared", "raw")):
                    command = ["timeout", "120", "taskset", "-c", str(cpu), str(binary), mode, collation, encoding]
                    execution = dict(repetition=repetition, mode=mode, collation=collation, encoding=encoding,
                                     command=command, completed=False, validated=False, load=os.getloadavg())
                    record["samples"].append(execution)
                    save()
                    result = capture.run(command,
                                         cwd=ROOT, log=directory / f"{len(record['samples'])}.log",
                                         result=execution, capture_stdout=True)
                    result.check_returncode()
                    sample = json.loads(result.stdout)
                    execution["measurement"] = sample
                    save()
                    checked(sample, mode, collation, encoding, wanted)
                    execution["validated"] = True
                    save()
                    samples.append(sample)
            medians = {mode: statistics.median(s["elapsed_ns"] for s in samples if s["mode"] == mode) for mode in ("raw", "prepared")}
            record["summary"].append(dict(collation=collation, encoding=encoding, warm_ns=medians,
                ratio=medians["prepared"] / medians["raw"],
                warm_range_ns={mode: [min(s["elapsed_ns"] for s in samples if s["mode"] == mode),
                                      max(s["elapsed_ns"] for s in samples if s["mode"] == mode)] for mode in ("raw", "prepared")},
                cpu_ns={mode: statistics.median(s["cpu_ns"] for s in samples if s["mode"] == mode) for mode in ("raw", "prepared")},
                preparation_ns=statistics.median(s["cold_ns"] / s["constructions"] for s in samples if s["mode"] == "prepared")))
            save()
        if record["binary"] != capture.identity(binary) or record["sources"] != {path: capture.identity(ROOT / path) for path in SOURCES}:
            raise ValueError("measurement inputs changed during execution")
        record.update(status="passed", completed=True)
        print(json.dumps(record["summary"], indent=2))
    except BaseException as error:
        record.update(status="failed", error=f"{type(error).__name__}: {error}")
        raise
    finally:
        save()
        print(f"Evidence: {directory}")


if __name__ == "__main__":
    main()
