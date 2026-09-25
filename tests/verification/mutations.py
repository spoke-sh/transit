"""Prove selected real guards are observed, using isolated committed source clones."""
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
        "root.zig",
        "if (c.generation != p.generation or p.owner != record.request.principal) return error.StaleGeneration;",
        "// Mutation: omit activation fencing.",
    ),
    "revision": (
        "root.zig",
        "if (c.expected_revision != p.revision) return error.StaleState;",
        "// Mutation: omit state revision comparison.",
    ),
    "permission": (
        "root.zig",
        "if (p.grant.permissions & permission(required) == 0) return error.Forbidden;",
        "_ = required; // Mutation: omit current grant validation.",
    ),
    "view_deadline": (
        "resources.zig",
        """now.before(view.meta.deadline_ms) catch |err| {
                    if (err == error.DeadlineExpired) return error.StateViewExpired;
                    return err;
                };""",
        "// Mutation: omit captured-view deadline validation.",
    ),
}


def execute(checkout):
    process = subprocess.Popen(["zig", "build", "test-properties", "--", "--seeds", "1", "--steps", "1"],
        cwd=checkout, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=180)
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        raise
    return process.returncode, output


def main():
    # Snapshot semantics are deliberate. Running dirty source under an old
    # revision would make the recorded experiment misleading.
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT):
        raise SystemExit("Mutation checks use committed HEAD; commit source changes first.")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    destination = ROOT / ".cache/verification/mutations"
    destination.mkdir(parents=True, exist_ok=True)
    evidence = {"version": 1, "revision": revision, "status": "inconclusive", "mutants": []}
    try:
        with tempfile.TemporaryDirectory(prefix="transit-mutants-", dir="/tmp") as directory:
            checkout = Path(directory) / "src"
            subprocess.run(["git", "clone", "--quiet", "--local", "--no-hardlinks", "--no-checkout", str(ROOT), str(checkout)], check=True)
            subprocess.run(["git", "checkout", "--quiet", "--detach", revision], cwd=checkout, check=True)
            code, output = execute(checkout)
            (destination / "baseline.log").write_text(output)
            if code or "Transition properties passed:" not in output:
                raise RuntimeError("unmodified mutation baseline failed; no mutant result is qualified")
            for name, (filename, guard, replacement) in MUTANTS.items():
                source = checkout / CORE / filename
                original = source.read_text()
                assert original.count(guard) == 1, f"review changed guard: {name}"
                source.write_text(original.replace(guard, replacement))
                started = time.monotonic()
                code, output = execute(checkout)
                (destination / f"{name}.log").write_text(output)
                detected = code != 0 and "Transition invariant failed; minimized replay at" in output
                evidence["mutants"].append({"name": name,
                    "status": "detected" if detected else "survived" if code == 0 else "inconclusive",
                    "seconds": round(time.monotonic() - started, 3)})
                if not detected:
                    raise RuntimeError(f"{name}: mutant survived or did not execute; inspect {destination}")
                failure = checkout / ".cache/verification/transitions/failure.json"
                (destination / f"{name}.json").write_bytes(failure.read_bytes())
                source.write_text(original)
        evidence["status"] = "passed"
        print("Targeted mutations: generation, revision, current-permission and view-deadline omissions detected by real-engine schedules.")
    finally:
        (destination / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
