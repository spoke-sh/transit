#!/usr/bin/env python3
"""The project selects its reference even before creation, never a personal cluster."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run():
    with tempfile.TemporaryDirectory(prefix="transit-env-") as temp:
        root = Path(temp)
        subprocess.run(["git", "init", "-q", root], check=True)
        nested = root / "nested"
        nested.mkdir()
        personal = root / "personal-config"
        personal.write_text("untouched personal config")
        env = dict(os.environ, KUBECONFIG=str(personal))
        env.pop("REY_KUBECONFIG", None)

        def selected():
            return subprocess.check_output(
                ["bash", "-c", 'source "$1"; printf "%s" "$KUBECONFIG"',
                 "test", ROOT / "nix/dev-environment.sh"],
                cwd=nested, env=env, text=True)

        expected = root / ".cache/reference/kubeconfig"
        assert selected() == str(expected)
        expected.parent.mkdir(parents=True)
        expected.write_text("fixture")
        assert selected() == str(expected)
        expected.unlink()
        assert selected() == str(expected)
        env["REY_KUBECONFIG"] = str(root / "explicit-config")
        assert selected() == env["REY_KUBECONFIG"]
        assert personal.read_text() == "untouched personal config"
    print("Project kubeconfig selection, subdirectory use, override and personal-config isolation passed.")


if __name__ == "__main__":
    run()
