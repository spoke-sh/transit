#!/usr/bin/env python3
"""Run the ordinary CI suite on committed HEAD without workspace build artifacts."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, cwd=ROOT, **kwargs):
    return subprocess.run(args, cwd=cwd, check=True, **kwargs)


def main():
    if run("git", "status", "--porcelain", capture_output=True, text=True).stdout:
        raise SystemExit("ci-clean checks committed HEAD; commit or stash source changes first.")
    revision = run("git", "rev-parse", "HEAD", capture_output=True, text=True).stdout.strip()
    # A separate clone leaves the user's working tree, worktree registrations,
    # launchers and build outputs alone. Keep paths short for Unix sockets.
    directory = tempfile.mkdtemp(prefix="transit-ci-")
    try:
        checkout = Path(directory) / "src"
        run("git", "clone", "--quiet", "--local", "--no-hardlinks", "--no-checkout", str(ROOT), str(checkout))
        run("git", "checkout", "--quiet", "--detach", revision, cwd=checkout)
        print(f"Clean CI: {revision} in {checkout}", flush=True)
        # The shell supplies tools, but checkout-local environment selection
        # must not leak from the calling shell into the isolated proof.
        env = {key: value for key, value in os.environ.items()
               if not key.startswith("REY_") and key not in ("KUBECONFIG", "LOG_LEVEL", "LOG_FORMAT")}
        for task in ("transit-board::install", "ci"):
            run("nix", "develop", "--command", "just", task, cwd=checkout, env=env)
    except (subprocess.CalledProcessError, KeyboardInterrupt):
        print(f"Clean CI did not complete; checkout and failure evidence retained at {directory}", flush=True)
        raise
    else:
        shutil.rmtree(directory)
    print("Clean CI passed without inherited workspace build outputs.", flush=True)


if __name__ == "__main__":
    main()
