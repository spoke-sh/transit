"""CI must propagate failures and keep local/hosted task selection aligned."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import yaml
from ci import LANES, ROOT
from ci_select import select


def main():
    workflow = yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text())
    selected = [row["lane"] for row in workflow["jobs"]["checks"]["strategy"]["matrix"]["include"]]
    assert selected == ["core", "experience", "bindings"]
    assert workflow["jobs"]["checks"]["strategy"]["fail-fast"] is False
    gate = workflow["jobs"]["foundation-and-protocol"]
    assert gate["if"] == "always()" and gate["needs"] == ["plan", "checks"]
    events = workflow.get("on", workflow.get(True))
    assert events["push"]["branches"] == ["main"]
    assert {"pull_request", "merge_group", "workflow_dispatch"} <= events.keys()
    assert not select(["docs/STATE.md", "README.md"])["full"]
    for paths in ([], ["docs/schema.json"], ["contracts/STATE_V1.md"],
                  ["build.zig"], ["unknown"], ["docs/../../build.zig"],
                  ["docs/STATE.md", "packages/zig/transit-core/README.md"]):
        assert select(paths)["full"], paths
    for event in ("push", "merge_group", "workflow_dispatch", "unknown"):
        assert select(["README.md"], event)["full"]
    # A moved source file must not become a docs-only diff. Check Git path
    # discovery itself, including deletions and a missing comparison revision.
    with tempfile.TemporaryDirectory(prefix="transit-ci-diff-") as directory:
        path = Path(directory)
        def git(*args):
            return subprocess.check_output(["git", *args], cwd=path, stderr=subprocess.DEVNULL)
        git("init", "-q")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "user.name", "CI fixture")
        (path / "source.zig").write_text("test {}\n")
        git("add", ".")
        git("commit", "-qm", "test(ci): seed selection fixture")
        base = git("rev-parse", "HEAD").decode().strip()
        (path / "docs").mkdir()
        git("mv", "source.zig", "docs/example.md")
        git("commit", "-qm", "test(ci): move source into documentation")
        command = [sys.executable, "-B", str(ROOT / "tests/ci_select.py"), "--base"]
        result = subprocess.run([*command, base], cwd=path, capture_output=True, check=True)
        plan = json.loads(result.stdout)
        assert plan["full"] and plan["paths"] == ["docs/example.md", "source.zig"]
        assert subprocess.run([*command, "missing-revision"], cwd=path, capture_output=True).returncode != 0
    # Exercise the actual shell gate: skipped, cancelled and missing evidence
    # cannot pass merely because a dependent job did not execute.
    gate_script = gate["steps"][0]["run"]
    for plan in ("success", "failure", "cancelled", "skipped", ""):
        for full in ("true", "false", ""):
            for result in ("success", "failure", "cancelled", "skipped", ""):
                passed = subprocess.run(["bash", "-e", "-c", gate_script], env=os.environ | {
                    "PLAN": plan, "FULL": full, "RESULT": result,
                }).returncode == 0
                assert passed == (plan == "success" and (full, result) in {
                    ("true", "success"), ("false", "skipped"),
                }), (plan, full, result)
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
        (runner.parent / "verification").mkdir()
        (runner.parent / "verification/suite.json").write_bytes((ROOT / "tests/verification/suite.json").read_bytes())
        env = os.environ | {"PATH": str(path) + os.pathsep + os.environ["PATH"],
                            "GITHUB_STEP_SUMMARY": str(path / "summary")}
        result = subprocess.run([sys.executable, "-B", runner, "browser"], env=env, capture_output=True)
        assert result.returncode == 23, result
        evidence = json.loads((path / ".cache/ci/browser.json").read_text())
        assert len(evidence) == 1 and evidence[0]["exit_code"] == 23
        metadata = json.loads((path / ".cache/ci/browser.meta.json").read_text())
        assert metadata["completed"] is False
        assert metadata["expected_tasks"] == ["transit-board::browser"]
        assert "transit-board::browser" in (path / "summary").read_text()
    print("CI lanes: disjoint local/hosted inventory, aggregate gate and failure propagation passed.")


if __name__ == "__main__":
    main()
