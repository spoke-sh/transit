"""Prove selected real guards are observed, using isolated committed source clones."""
import argparse
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import tempfile
import time

from runner.paths import ROOT
CORE = Path("packages/zig/transit-core/src")
MUTANTS = {
    "generation": (
        "growing_state.zig",
        "if (process.owner != principal or process.generation != command.generation) return error.StaleGeneration;",
        "// Mutation: omit activation fencing.",
    ),
    "revision": (
        "growing_state.zig",
        "if (process.revision != command.expected_revision) return error.StaleState;\n    if (command.authorization)",
        "// Mutation: omit state revision comparison.\n    if (command.authorization)",
    ),
    "permission": (
        "growing.zig",
        "if (!permitted) return error.Forbidden;",
        "_ = permitted; // Mutation: omit current grant validation.",
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
    "domain": ("test-domain-simulation", ["--seeds", "1"], "domain-simulation-mutations", {
        "document_conflicts": ("transit-document/src/Document.zig", "if (!observed.contains(dot))", "if (!observed.contains(dot) and false)"),
        "checkpoint_floor": ("transit-station-document/src/Checkpoint.zig", "h.floor = progress.floor;", "h.floor = 0; // Mutation: forget accepted read floor."),
        "exchange_hold": ("transit-exchange/src/Exchange.zig", "if (c.caller == .held or c.dependents != 0) return error.ExchangeHasDependents;", "// Mutation: allow retirement with replay holds."),
        "refresh_generation": ("transit-serving/src/Refresh.zig", "if (generation != selection.generation) {", "if (false) { // Mutation: accept stale selected generation."),
        "provider_ready": ("transit-core/src/growing_runtime.zig", "if (binding.desired != .running or binding.phase != .ready or binding.incarnation == null) return error.ProviderNotReady;", "// Mutation: activate before provider readiness."),
        "catalog_policy": ("transit-catalog/src/DirectCatalog.zig", ".create => .create_table,", ".create => .schema, // Mutation: omit current CREATE privilege."),
        "catalog_receipt": ("transit-catalog/src/DirectCatalog.zig", "if (view) |*value| if (try value.table.observeEvidence(binding, current)) |accepted| return .{ .committed = accepted };", "if (view) |*value| { if (try value.table.observeEvidence(binding, current)) |accepted| { var changed = accepted; changed.outcome.position.next_lsn = self.store.root.next_lsn; return .{ .committed = changed }; } } // Mutation: replace original Table receipt position."),
        "catalog_inspection": ("transit-catalog/src/DirectCatalog.zig", "try check(try self.guard(arena.allocator(), policy, namespace, view.properties.target(target.object), .inspect));", "// Mutation: disclose resolved Table metadata without inspection rights."),
        "catalog_cursor": ("transit-catalog/src/DirectCatalogInspection.zig", "if (previous) |cursor| if (!std.meta.eql(try cursor.position.native(), position)) return error.CatalogObservationChanged;", "_ = previous; // Mutation: combine metadata pages across publication."),
    }, "Domain simulation:", "component invariant failed", "domain-simulation.json"),
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
    group.add_argument('--domain', action='store_true', help='qualify component contract assertions')
    group.add_argument('--scheduler', action='store_true', help='qualify shared Session/courier checks')
    group.add_argument('--resource', action='store_true', help='qualify resource/input atomicity checkers')
    group.add_argument('--simulation', action='store_true', help='qualify delivery order and provenance checkers')
    args = parser.parse_args()
    mode = "domain" if args.domain else "scheduler" if args.scheduler else "resource" if args.resource else "simulation" if args.simulation else "properties"
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
                source = checkout / (Path("packages/zig") if mode == "domain" else Path("packages/zig/transit-client/src") if mode == "scheduler" else CORE) / filename
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
                if mode == "domain":
                    shutil.copytree(checkout / ".cache/verification/domain-simulation", destination / name, dirs_exist_ok=True)
                source.write_text(original)
        evidence["status"] = "passed"
        print(f"{mode} mutations: {', '.join(mutants)} detected by real-engine schedules.")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
