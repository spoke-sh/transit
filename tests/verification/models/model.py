"""Bounded TLC safety check, negative controls and concrete counterexample replay."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

from verification.simulation.transitions.transitions import ROOT, run

MODELS = Path(__file__).resolve().parent


def concrete(events):
    # Model requests 1 and 2 correspond to two admitted inputs. Journal offsets
    # differ by bootstrap, so actions name scheduler slots rather than raw IDs.
    actions = [{"kind": "send"}, {"kind": "send"}]
    for event in events:
        if event == "Init":
            continue
        if event in {"Own", "Revoke", "Grant"}:
            actions.append({"kind": event.lower()})
        elif event == "Close":
            actions.append({"kind": "terminate"})
        elif re.fullmatch(r"Prepare(Stale)?[01]", event):
            actions.append({"kind": "prepare", "slot": int(event[-1]),
                            "stale_generation": "Stale" in event})
        elif re.fullmatch(r"(Commit|Lost|Retry)[01]", event):
            actions.append({"kind": "retry" if event.startswith("Retry") else "commit",
                            "slot": int(event[-1]),
                            "fault": "after_append" if event.startswith("Lost") else "none"})
        else:
            raise ValueError(f"unmapped abstract action: {event}")
    actions.append({"kind": "restart"})
    return {"version": 1, "actions": actions}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--tail", type=int, choices=(3, 4, 5), default=3)
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    tlc = shutil.which("tlc")
    if tlc is None:
        raise SystemExit("TLC missing: use just test::model with the pinned Nix package")
    destination = ROOT / ".cache/verification/model"
    destination.mkdir(parents=True, exist_ok=True)
    evidence = {"version": 1, "status": "inconclusive", "max_tail": args.tail,
                "safety_only": True, "checks": []}
    try:
        with tempfile.TemporaryDirectory(prefix="transit-tlc-") as directory:
            directory = Path(directory)
            source = directory / "Authority.tla"
            shutil.copyfile(MODELS / "Authority.tla", source)
            template = (MODELS / "Authority.cfg").read_text().replace("MaxTail = 3", f"MaxTail = {args.tail}")
            for guard in (None, "CheckTail", "CheckGeneration", "CheckPermission", "CheckClosure"):
                name = guard or "safe"
                config = directory / f"{name}.cfg"
                config.write_text(template if guard is None else template.replace(f"{guard} = TRUE", f"{guard} = FALSE"))
                started = time.monotonic()
                result = subprocess.run([tlc, "-workers", "1", "-seed", "1", "-fp", "0",
                    "-metadir", str(directory / name), "-config", str(config), str(source)],
                    cwd=directory, env=os.environ | {"JAVA_TOOL_OPTIONS": "-Xmx512m"},
                    capture_output=True, text=True, timeout=args.seconds)
                output = result.stdout + result.stderr
                (destination / f"{name}.log").write_text(output)
                violation = re.search(r"Error: Invariant (\w+) is violated\.", output)
                if guard is None:
                    assert result.returncode == 0 and "Model checking completed. No error has been found." in output, output[-4000:]
                    counts = re.search(r"([\d,]+) states generated, ([\d,]+) distinct states found, 0 states left on queue", output)
                    assert counts, "incomplete model exploration"
                    evidence["distinct_states"] = int(counts[2].replace(",", ""))
                else:
                    # A parser failure, timeout or unexpected tool error cannot
                    # masquerade as a killed mutant. TLC 1.7.4 uses exit 12 for
                    # an invariant violation and lacks JSON trace export.
                    assert result.returncode == 12 and violation, output[-4000:]
                    events = re.findall(r'^/\\ last = "([^"]+)"$', output, re.M)
                    assert len(events) >= 3 and events[0] == "Init", "missing counterexample"
                    trace = concrete(events)
                    (destination / f"{name}.json").write_text(json.dumps(trace, indent=2) + "\n")
                    failures = run(str(Path(args.binary).resolve()), [trace], directory)
                    assert failures == [None], f"implementation did not reject modeled bad schedule: {failures}"
                evidence["checks"].append({"guard": name, "status": "passed" if guard is None else "detected-and-replayed",
                    "violated": violation[1] if violation else None,
                    "seconds": round(time.monotonic() - started, 3)})
        evidence["status"] = "passed"
        print(f"TLC finite safety model: {evidence['distinct_states']} states; four removed guards detected and replayed against Zig.")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
