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
from ci_cost import summarize


def main():
    workflow = yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text())
    selected = [row["lane"] for row in workflow["jobs"]["checks"]["strategy"]["matrix"]["include"]]
    assert selected == ["core", "growth", "experience", "launchers", "bindings"]
    assert workflow["jobs"]["checks"]["strategy"]["fail-fast"] is False
    reclaim = next(step for step in workflow['jobs']['checks']['steps'] if step.get('name') == 'Reclaim unused hosted SDKs')
    assert reclaim['if'] == "runner.environment == 'github-hosted' && steps.nix-cache.outputs.hit-primary-key != 'true'"
    gate = workflow["jobs"]["foundation-and-protocol"]
    assert gate["if"] == "always()" and gate["needs"] == ["plan", "checks"]
    matrix = workflow["jobs"]["checks"]["strategy"]["matrix"]["include"]
    for cache in {row["cache"] for row in matrix}:
        assert sum(row["cache_writer"] for row in matrix if row["cache"] == cache) == 1
    events = workflow.get("on", workflow.get(True))
    assert events["push"]["branches"] == ["main"]
    assert {"pull_request", "merge_group", "workflow_dispatch"} <= events.keys()
    budgets = {"feedback_seconds": 600, "aggregate_runner_seconds": 3000, "restored_cache_bytes": 1000}
    sample = dict(id=1, head_sha='fixture', html_url='https://example.invalid', conclusion='success', created_at='2026-01-01T00:00:00Z')
    job = dict(name='core', conclusion='success', started_at='2026-01-01T00:00:01Z', completed_at='2026-01-01T00:00:10Z', steps=[])
    log = 'core\tCache hit for: nix-key\ncore\tCache Size: ~0 MB (100 B)\ncore\tCache hit for: zig-key\ncore\tCache Size: ~0 MB (200 B)\n'
    measured = summarize(sample, [job], log, budgets)
    assert measured['budget_met'] and measured['restored_cache_bytes'] == 300
    assert measured['feedback_seconds'] == 10 and measured['aggregate_runner_seconds'] == 9
    assert not summarize(sample, [job], '', budgets)['budget_met']
    assert not summarize(sample, [dict(job, conclusion='failure')], log, budgets)['budget_met']
    assert not summarize(sample, [dict(job, completed_at=None)], log, budgets)['budget_met']
    assert not summarize(sample, [job], log, dict(budgets, feedback_seconds=10))['budget_met']
    cold_log = 'core\tCI dependency cache mode: cold\n'
    assert not summarize(sample, [job], cold_log, budgets)['budget_met']
    cold_budget = dict(feedback_seconds=20, aggregate_runner_seconds=20, restored_cache_bytes=0)
    cold = summarize(sample, [job], cold_log, dict(budgets, cold=cold_budget))
    assert cold['budget_met'] and cold['budget'] == cold_budget and cold['cache_profile'] == 'cold'
    assert measured['budget'] == budgets and measured['cache_profile'] == 'warm'
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
    assert {"test::packages-build", "test::compute"} <= set(LANES["core"])
    assert "test::packages" not in LANES["core"]
    recipes = (ROOT / "tasks/test.just").read_text()
    compile_recipe = recipes.split("\npackages-build:\n", 1)[1].split("\n\n", 1)[0]
    full_recipe = recipes.split("\npackages:\n", 1)[1].split("\n\n", 1)[0]
    assert compile_recipe.replace("zig build check", "zig build test") == full_recipe
    for build in (ROOT / "packages/zig").glob("*/build.zig"):
        assert 'b.step("check",' in build.read_text(), build
        assert f"packages/zig/{build.parent.name}" in compile_recipe, build
    # Compile-only checks cannot replace Fuze's upstream runtime owner.
    assert 'zig build test-compute' in recipes
    assert 'b.step("test-compute",' in (ROOT / "packages/zig/transit-fuze/build.zig").read_text()
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
