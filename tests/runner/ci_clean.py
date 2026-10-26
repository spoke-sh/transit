#!/usr/bin/env python3
"""Run the ordinary CI suite on committed HEAD without workspace build artifacts."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def run(*args, cwd=ROOT, **kwargs):
    return subprocess.run(args, cwd=cwd, check=True, **kwargs)


def profile(suite, selection):
    if selection in suite["lanes"]:
        return suite["environments"][selection]
    # The complete sequential inventory still needs every language and frontend.
    # A single lane uses its hosted environment, with no unrelated preparation.
    return {"shell": "bindings", "prepare": [["just", "transit-board::install"]]}


def check_profile(scope):
    if scope == "all":
        prepare = [["just", "transit-board::install"]]
    elif scope in ("contracts", "core"):
        # The last contract validator type-checks generated recursive types with
        # the client package's pinned compiler. Do not rely on prior Board builds.
        prepare = [["vp", "install", "--frozen-lockfile", "--filter", "transit", "--filter", "@transit/client"]]
    else:
        prepare = []
    return {"shell": "default", "prepare": prepare}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--complete", action="store_true", help="include the installed Chromium proof")
    suite = json.loads((ROOT / "tests/runner/suite.json").read_text())
    selection.add_argument("--lane", choices=[*suite["lanes"], "bindings"],
                           help="qualify one lane or both bindings lanes in a clean checkout; not the full suite")
    selection.add_argument("--check", choices=("fast", "contracts", "core", "all"),
                           help="run one check module scope in a clean checkout; not the CI suite")
    parser.add_argument("--work-root", type=Path, default=Path('/var/tmp'),
                        help="persistent short-path checkout parent (default: /var/tmp)")
    args = parser.parse_args()
    selected = f"check::{args.check}" if args.check else args.lane or ("complete" if args.complete else "all")
    environment = check_profile(args.check) if args.check else profile(suite, selected)
    if run("git", "status", "--porcelain", capture_output=True, text=True).stdout:
        raise SystemExit("ci clean checks committed HEAD; commit or stash source changes first.")
    revision = run("git", "rev-parse", "HEAD", capture_output=True, text=True).stdout.strip()
    # A separate clone leaves the user's working tree, worktree registrations,
    # launchers and build outputs alone. Keep paths short for Unix sockets.
    # nix develop's TMPDIR disappears with the shell, even after a failure.
    # Use a stable, short path so retained evidence survives that shell exit.
    # /tmp is often a shared tmpfs; a clean build can exceed 10 GiB and starve
    # simultaneous disk-store proofs. Keep this separate from their temp space.
    directory = tempfile.mkdtemp(prefix="transit-ci-", dir=args.work_root)
    evidence = ROOT / ".cache/ci/clean" / f"{revision[:12]}-{Path(directory).name}"
    checkout = Path(directory) / "src"
    scratch = Path(directory) / "tmp"
    scratch.mkdir()
    preparation = Path(directory) / "preparation.json"
    metadata = {"version": 1, "revision": revision, "selection": selected,
                "shell": environment["shell"], "completed": False, "phases": []}

    def checkpoint():
        temporary = preparation.with_suffix(".tmp")
        temporary.write_text(json.dumps(metadata, indent=2) + "\n")
        temporary.replace(preparation)

    def phase(name, *command, **kwargs):
        entry = {"phase": name, "command": list(command), "exit_code": None,
                 "started_unix": time.time()}
        metadata["phases"].append(entry)
        checkpoint()
        started = time.monotonic()
        try:
            result = run(*command, **kwargs)
            entry["exit_code"] = result.returncode
        except subprocess.CalledProcessError as error:
            entry["exit_code"] = error.returncode
            raise
        finally:
            entry["seconds"] = round(time.monotonic() - started, 3)
            checkpoint()

    try:
        phase("clone", "git", "clone", "--quiet", "--local", "--no-hardlinks", "--no-checkout", str(ROOT), str(checkout))
        phase("checkout", "git", "checkout", "--quiet", "--detach", revision, cwd=checkout)
        print(f"Clean CI: {revision} in {checkout}", flush=True)
        # The shell supplies tools, but checkout-local environment selection
        # must not leak from the calling shell into the isolated proof.
        env = {key: value for key, value in os.environ.items()
               if not key.startswith("TRANSIT_") and key not in ("KUBECONFIG", "LOG_LEVEL", "LOG_FORMAT")}
        shell = ["nix", "develop", f".#{environment['shell']}", "--command"]
        phase("shell", *shell, "true", cwd=checkout, env=env)
        for command in environment["prepare"]:
            phase("dependencies", *shell, "env", f"TMPDIR={scratch}",
                  *command, cwd=checkout, env=env)
        # Select TMPDIR after entering Nix, which supplies its own temporary
        # directory. The all-language ring keeps several clean consumers alive;
        # putting those builds in a shared tmpfs can exhaust unrelated fixtures.
        # This is the same inventory runner used by every ci::* recipe, entered
        # once with the pinned lane tools and this checkout's owned scratch.
        command = ["just", selected] if args.check else ["python3", "-B", "tests/runner/ci.py", selected]
        phase("checks", *shell, "env", f"TMPDIR={scratch}", *command, cwd=checkout, env=env)
        metadata["completed"] = True
        checkpoint()
    except (subprocess.CalledProcessError, KeyboardInterrupt):
        print(f"Clean CI did not complete; checkout and failure evidence retained at {directory}", flush=True)
        raise
    else:
        if (checkout / ".cache/ci").exists():
            shutil.copytree(checkout / ".cache/ci", evidence)
        evidence.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(preparation, evidence / "preparation.json")
        if (checkout / ".cache/verification").exists():
            shutil.copytree(checkout / ".cache/verification", evidence / "verification")
        if (checkout / ".cache/checks").exists():
            shutil.copytree(checkout / ".cache/checks", evidence / "checks")
        print(f"Clean CI timing and completion evidence: {evidence}", flush=True)
        shutil.rmtree(directory)
    label = f"Clean check {args.check}" if args.check else f"Clean CI lane {args.lane}" if args.lane else "Clean CI"
    print(f"{label} passed without inherited workspace build outputs.", flush=True)


if __name__ == "__main__":
    main()
