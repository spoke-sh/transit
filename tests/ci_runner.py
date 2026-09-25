"""CI must propagate failures and keep local/hosted task selection aligned."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import yaml
from ci import LANES, ROOT


def main():
    workflow = yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text())
    selected = [row["lane"] for row in workflow["jobs"]["checks"]["strategy"]["matrix"]["include"]]
    assert selected == ["core", "experience"]
    assert workflow["jobs"]["checks"]["strategy"]["fail-fast"] is False
    gate = workflow["jobs"]["foundation-and-protocol"]
    assert gate["if"] == "always()" and gate["needs"] == "checks"
    tasks = [task for lane in selected for task in LANES[lane]]
    assert len(tasks) == len(set(tasks)), "a proof is duplicated across lanes"
    # Run the actual entry point with a deterministic failing task executable.
    # Later tasks must not run and the original status/evidence must survive.
    with tempfile.TemporaryDirectory(prefix="transit-ci-runner-") as directory:
        path = Path(directory)
        script = path / "just"
        script.write_text(f"#!{sys.executable}\nimport sys\nprint('deliberate task failure')\nsys.exit(23)\n")
        script.chmod(0o755)
        runner = path / "tests/ci.py"
        runner.parent.mkdir()
        runner.write_bytes((ROOT / "tests/ci.py").read_bytes())
        env = os.environ | {"PATH": str(path) + os.pathsep + os.environ["PATH"],
                            "GITHUB_STEP_SUMMARY": str(path / "summary")}
        result = subprocess.run([sys.executable, "-B", runner, "browser"], env=env, capture_output=True)
        assert result.returncode == 23, result
        evidence = json.loads((path / ".cache/ci/browser.json").read_text())
        assert len(evidence) == 1 and evidence[0]["exit_code"] == 23
        assert "transit-board::browser" in (path / "summary").read_text()
    print("CI lanes: disjoint local/hosted inventory, aggregate gate and failure propagation passed.")


if __name__ == "__main__":
    main()
