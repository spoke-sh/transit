"""Prove selected real guards are observed, using isolated committed source clones."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
CORE = Path("packages/zig/transit-core/src")
MUTANTS = {
    "generation": (
        "growing_state.zig",
        "if (process.owner != principal or process.generation != command.generation) return error.StaleGeneration;",
        "// Mutation: omit activation fencing.",
    ),
    "revision": (
        "growing_state.zig",
        "if (process.revision != command.expected_revision) return error.StaleState;\n    _ = try nextInput(engine, process, command.input);",
        "// Mutation: omit state revision comparison.\n    _ = try nextInput(engine, process, command.input);",
    ),
    "permission": (
        "growing.zig",
        "if (principal_value.grant.permissions & p.permission(needed) == 0) return error.Forbidden;",
        "_ = needed; // Mutation: omit current grant validation.",
    ),
    "view_deadline": (
        "growing_state.zig",
        """engine.before(sample, meta.deadline_ms) catch |err| {
        if (err == error.DeadlineExpired) return error.StateViewExpired;
        return err;
    };""",
        "// Mutation: omit captured-view deadline validation.",
    ),
}
SIMULATION_MUTANTS = {
    "route_order": (
        "growing_work.zig",
        "if (first.value != id) return error.RouteBlocked;",
        "_ = first; // Mutation: permit a later output to bypass its route predecessor.",
    ),
    "delivery_origin": (
        "growing_work.zig",
        ".process = .{ .pid = out.source, .turn = out.turn, .output = out.id }",
        ".process = .{ .pid = out.source, .turn = out.turn, .output = out.id + 1 }",
    ),
}

RESOURCE_MUTANTS = {
    "resource_write": ("growing_state.zig", "try candidate.mutate(mutations[0..mutation_count]);",
                       "try candidate.mutate(mutations[0..0]); // Mutation: omit resource writes."),
    "input_progress": ("growing_state.zig", "process.consumed += 1;",
                       "process.consumed += 0; // Mutation: publish state/output without input progress."),
}
SCHEDULER_MUTANTS = {
    "courier_pending": ("delivery.zig", "        return err;", "        pending.* = null; return err; // Mutation: discard uncertain identity."),
    "session_activation": ("Session.zig", "if (process.owner != self.principal or process.generation != self.generation) return error.StaleActivation;", "// Mutation: omit Session activation validation."),
}
MODES = {
    "scheduler": ("test-scheduler-simulation", ["--seeds", "1", "--steps", "1"], "scheduler-simulation-mutations", SCHEDULER_MUTANTS,
                  "Scheduler simulation:", "Scheduler simulation failed (invariant)", "scheduler-simulation/minimized.json"),
    "properties": ("test-properties", ["--seeds", "1", "--steps", "1"], "mutations", MUTANTS,
                   "Transition properties passed:", "Transition invariant failed; minimized replay at", "transitions/failure.json"),
    "simulation": ("test-simulation", ["--seeds", "1", "--steps", "1"], "simulation-mutations", SIMULATION_MUTANTS,
                   "Delivery simulation:", "Simulation failed (correspondence)", "simulation/minimized.json"),
    "resource": ("test-resource-simulation", ["--smoke"], "resource-simulation-mutations", RESOURCE_MUTANTS,
                 "Resource simulation:", "Resource simulation failed (correspondence)", "resource-simulation/minimized.json"),
}

def execute(checkout, mode):
    target, arguments, *_ = MODES[mode]
    process = subprocess.Popen(["zig", "build", target, "--", *arguments],
        cwd=checkout, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=180)
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        raise
    return process.returncode, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--scheduler', action='store_true', help='qualify shared Session/courier checks')
    group.add_argument('--resource', action='store_true', help='qualify resource/input atomicity checkers')
    group.add_argument('--simulation', action='store_true', help='qualify delivery order and provenance checkers')
    args = parser.parse_args()
    mode = "scheduler" if args.scheduler else "resource" if args.resource else "simulation" if args.simulation else "properties"
    _, _, artifact, mutants, passed, marker, minimized = MODES[mode]
    # Snapshot semantics are deliberate. Running dirty source under an old
    # revision would make the recorded experiment misleading.
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT):
        raise SystemExit("Mutation checks use committed HEAD; commit source changes first.")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    destination = ROOT / ".cache/verification" / artifact
    destination.mkdir(parents=True, exist_ok=True)
    evidence = {"version": 1, "revision": revision, "status": "inconclusive", "mutants": []}
    try:
        with tempfile.TemporaryDirectory(prefix="transit-mutants-") as directory:
            checkout = Path(directory) / "src"
            subprocess.run(["git", "clone", "--quiet", "--local", "--no-hardlinks", "--no-checkout", str(ROOT), str(checkout)], check=True)
            subprocess.run(["git", "checkout", "--quiet", "--detach", revision], cwd=checkout, check=True)
            code, output = execute(checkout, mode)
            (destination / "baseline.log").write_text(output)
            if code or passed not in output:
                raise RuntimeError("unmodified mutation baseline failed; no mutant result is qualified")
            for name, (filename, guard, replacement) in mutants.items():
                source = checkout / (Path("packages/zig/transit-client/src") if mode == "scheduler" else CORE) / filename
                original = source.read_text()
                assert original.count(guard) == 1, f"review changed guard: {name}"
                source.write_text(original.replace(guard, replacement))
                started = time.monotonic()
                code, output = execute(checkout, mode)
                (destination / f"{name}.log").write_text(output)
                detected = code != 0 and marker in output
                evidence["mutants"].append({"name": name,
                    "status": "detected" if detected else "survived" if code == 0 else "inconclusive",
                    "seconds": round(time.monotonic() - started, 3)})
                if not detected:
                    raise RuntimeError(f"{name}: mutant survived or did not execute; inspect {destination}")
                failure = checkout / ".cache/verification" / minimized
                (destination / f"{name}.json").write_bytes(failure.read_bytes())
                source.write_text(original)
        evidence["status"] = "passed"
        print(f"{mode} mutations: {', '.join(mutants)} detected by real-engine schedules.")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
