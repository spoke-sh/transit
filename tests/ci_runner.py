"""CI must propagate failures and keep local/hosted task selection aligned."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import signal
import time

import yaml
from ci import LANES, ROOT, SUITE
from ci_select import select
from ci_cost import summarize
from verification.external_profiles import DISCOVERY


def main():
    workflow = yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text())
    selected = [row["lane"] for row in workflow["jobs"]["checks"]["strategy"]["matrix"]["include"]]
    assert selected == SUITE["tiers"]["ordinary"]
    assert SUITE["tiers"]["bindings"] == ["bindings-1", "bindings-2"]
    assert set(SUITE["tiers"]["bindings"]) <= set(selected)
    assert workflow["jobs"]["checks"]["strategy"]["fail-fast"] is False
    steps = workflow["jobs"]["checks"]["steps"]
    reclaim = next(step for step in steps if step.get("name") == "Reclaim unused hosted SDKs")
    assert reclaim["if"] == "runner.environment == 'github-hosted'"
    # A primary cache hit can fill the disk during extraction, before the shell
    # starts. Reclaim on all hosted runs and before either restore or build.
    for name in ("Restore Nix store", "Prepare development shell"):
        assert steps.index(reclaim) < next(i for i, step in enumerate(steps) if step.get("name") == name)
    names = [step.get("name") for step in steps]
    assert names.index("Prepare development shell") < names.index("Save Nix store")
    assert names.index("Save Nix store") < names.index("Run ${{ matrix.lane }} checks")
    artifacts = next(step for step in steps if step.get("name") == "Preserve task timings and completion evidence")
    assert ".cache/m9/station-local-readiness.json" in artifacts["with"]["path"].splitlines()
    gate = workflow["jobs"]["foundation-and-protocol"]
    assert gate["if"] == "always()" and gate["needs"] == ["plan", "checks", "documentation"]
    assert workflow["jobs"]["documentation"]["if"] == "needs.plan.outputs.full == 'false'"
    assert "transit-docs::check" in LANES["experience"]
    matrix = workflow["jobs"]["checks"]["strategy"]["matrix"]["include"]
    for cache in {row["cache"] for row in matrix}:
        assert sum(row["cache_writer"] for row in matrix if row["cache"] == cache) == 1
    events = workflow.get("on", workflow.get(True))
    assert events["push"]["branches"] == ["main"]
    assert {"pull_request", "merge_group", "workflow_dispatch"} <= events.keys()
    faults = yaml.safe_load((ROOT / '.github/workflows/fault-verification.yml').read_text())
    fault_events = faults.get('on', faults.get(True))
    assert fault_events['schedule'] and 'discovery' in fault_events['workflow_dispatch']['inputs']['profile']['options']
    assert len(DISCOVERY) == 13 and len({command[1] for command in DISCOVERY}) == 13
    assert ['just', 'test::resource-simulation', '--seeds', '4'] in DISCOVERY
    assert ['just', 'test::vortex', '--seed', '19', '--rounds', '16'] in DISCOVERY
    fault_steps = faults['jobs']['qualify']['steps']
    reclaim = next(step for step in fault_steps if step.get('name') == 'Reclaim unused hosted SDKs')
    assert reclaim['if'] == "runner.environment == 'github-hosted'"
    assert fault_steps.index(reclaim) < next(i for i, step in enumerate(fault_steps) if step.get('name') == 'Restore Nix store')
    budgets = {"feedback_seconds": 600, "aggregate_runner_seconds": 3000, "restored_cache_bytes": 2000}
    sample = dict(id=1, head_sha='fixture', html_url='https://example.invalid', conclusion='success', created_at='2026-01-01T00:00:00Z')
    job = dict(name='core', conclusion='success', started_at='2026-01-01T00:00:01Z', completed_at='2026-01-01T00:00:10Z', steps=[])
    log = 'core\tCache hit for: nix-key\ncore\tCache Size: ~0 MB (100 B)\ncore\tCache hit for: zig-key\ncore\tCache Size: ~0 MB (200 B)\n'
    full_jobs = [dict(job, name=name) for name in selected]
    full_log = ''.join(log.replace('core\t', name + '\t') for name in selected)
    measured = summarize(sample, full_jobs, full_log, budgets)
    assert measured['budget_met'] and measured['restored_cache_bytes'] == 300 * len(selected)
    assert measured['feedback_seconds'] == 10 and measured['aggregate_runner_seconds'] == 9 * len(selected)
    assert not measured['missing_lanes'] and not measured['duplicate_lanes']
    assert not summarize(sample, full_jobs, '', budgets)['budget_met']
    assert not summarize(sample, [dict(job, conclusion='failure'), *full_jobs[1:]], full_log, budgets)['budget_met']
    assert not summarize(sample, [dict(job, completed_at=None), *full_jobs[1:]], full_log, budgets)['budget_met']
    assert not summarize(sample, full_jobs, full_log, dict(budgets, feedback_seconds=10))['budget_met']
    cold_log = ''.join(name + '\tCI dependency cache mode: cold\n' for name in selected)
    assert not summarize(sample, full_jobs, cold_log, budgets)['budget_met']
    cold_budget = dict(feedback_seconds=20, aggregate_runner_seconds=60, restored_cache_bytes=0)
    cold = summarize(sample, full_jobs, cold_log, dict(budgets, cold=cold_budget))
    assert cold['budget_met'] and cold['budget'] == cold_budget and cold['cache_profile'] == 'cold'
    assert measured['budget'] == budgets and measured['cache_profile'] == 'warm'
    fallback_log = full_log.replace('Cache hit for: zig-key', 'Cache hit for restore-key: zig-key')
    fallback = summarize(sample, full_jobs, fallback_log, budgets)
    assert fallback['restored_cache_bytes'] == 300 * len(selected) and fallback['cache_profile'] == 'miss-or-partial'
    assert fallback['status'] == 'measured' and not fallback['budget_met']
    # Match an actual full hosted selection: the alternative docs-only job is
    # skipped, but every required matrix lane must still execute successfully.
    docs_skipped = dict(job, name='Documentation site', conclusion='skipped')
    full_budgets = dict(budgets, restored_cache_bytes=2000)
    full = summarize(sample, [*full_jobs, docs_skipped], full_log, full_budgets)
    assert full['budget_met'] and len(full['lanes']) == len(selected)
    assert full['restored_cache_bytes'] == 300 * len(selected)
    assert not summarize(sample, [*full_jobs[:-1], docs_skipped], full_log, full_budgets)['budget_met']
    assert not summarize(sample, [*full_jobs[:-1], dict(full_jobs[-1], conclusion='skipped'), docs_skipped], full_log, full_budgets)['budget_met']
    # Missing ordinary lanes cannot meet the suite budget even when there is no
    # skipped documentation job to expose the incomplete selection.
    for name in selected:
        incomplete = summarize(sample, [row for row in full_jobs if row['name'] != name], full_log, budgets)
        assert incomplete['status'] == 'inconclusive' and not incomplete['budget_met']
        assert incomplete['missing_lanes'] == [name] and not incomplete['duplicate_lanes']
    single = summarize(sample, [job], log, budgets)
    assert single['status'] == 'inconclusive' and not single['budget_met']
    assert single['feedback_seconds'] == 10 and single['aggregate_runner_seconds'] == 9
    assert single['restored_cache_bytes'] == 300
    duplicate = summarize(sample, [*full_jobs, job], full_log, budgets)
    assert duplicate['status'] == 'inconclusive' and not duplicate['budget_met']
    assert duplicate['duplicate_lanes'] == ['core'] and not duplicate['missing_lanes']
    assert not select(["docs/reference/state.md", "docs/roadmap/M26.md", "README.md"])["full"]
    for paths in ([], ["docs/schema.json"], ["contracts/STATE_V1.md"],
                  ["build.zig"], ["unknown"], ["docs/../../build.zig"],
                  ["docs/history/STATE.md", "packages/zig/transit-core/README.md"]):
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
                for docs in ("success", "failure", "cancelled", "skipped", ""):
                    passed = subprocess.run(["bash", "-e", "-c", gate_script], env=os.environ | {
                        "PLAN": plan, "FULL": full, "RESULT": result, "DOCS": docs,
                    }).returncode == 0
                    assert passed == (plan == "success" and (full, result, docs) in {
                        ("true", "success", "skipped"), ("false", "skipped", "success"),
                    }), (plan, full, result, docs)
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
        assert metadata["expected_tasks"] == LANES["browser"]
        assert "transit-board::browser" in (path / "summary").read_text()
    # Both independent binding jobs and the full local selector must execute
    # exactly their declared tasks, retaining complete per-lane evidence.
    with tempfile.TemporaryDirectory(prefix="transit-ci-bindings-") as directory:
        path = Path(directory)
        runner = path / "tests/ci.py"
        runner.parent.mkdir()
        runner.write_bytes((ROOT / "tests/ci.py").read_bytes())
        (runner.parent / "verification").mkdir()
        (runner.parent / "verification/suite.json").write_bytes((ROOT / "tests/verification/suite.json").read_bytes())
        script = path / "just"
        script.write_text(f"#!{sys.executable}\nimport sys\nfrom pathlib import Path\n"
                          "with Path('executed').open('a') as log: log.write(sys.argv[1]+'\\n')\n")
        script.chmod(0o755)
        env = os.environ | {"PATH": str(path) + os.pathsep + os.environ["PATH"]}
        for selection in ("bindings", *SUITE["tiers"]["bindings"]):
            (path / "executed").unlink(missing_ok=True)
            subprocess.run([sys.executable, "-B", runner, selection], env=env,
                           capture_output=True, check=True)
            lanes = SUITE["tiers"].get(selection, [selection])
            expected = [task for lane in lanes for task in LANES[lane]]
            assert (path / "executed").read_text().splitlines() == expected
            evidence = json.loads((path / f".cache/ci/{selection}.json").read_text())
            metadata = json.loads((path / f".cache/ci/{selection}.meta.json").read_text())
            assert [row["task"] for row in evidence] == expected
            assert metadata["completed"] and metadata["expected_tasks"] == expected
            assert metadata["result_count"] == len(expected)
            assert all(row["exit_code"] == 0 for row in evidence)
    # Kill the real runner while its second task is active. Neither SIGTERM nor
    # SIGKILL executes its finally block; the earlier task must remain recorded.
    with tempfile.TemporaryDirectory(prefix="transit-ci-interrupted-") as directory:
        path = Path(directory)
        runner = path / "tests/ci.py"
        runner.parent.mkdir()
        runner.write_bytes((ROOT / "tests/ci.py").read_bytes())
        (runner.parent / "verification").mkdir()
        expected = ["first", "paused", "later"]
        (runner.parent / "verification/suite.json").write_text(json.dumps({
            "version": 1, "lanes": {"fixture": expected}, "tiers": {}}))
        script = path / "just"
        script.write_text(f"#!{sys.executable}\nimport os,sys,time\nfrom pathlib import Path\n"
                          "Path(sys.argv[1]+'.started').touch()\n"
                          "if sys.argv[1] == os.getenv('BLOCK_TASK'): time.sleep(30)\n")
        script.chmod(0o755)
        env = os.environ | {"PATH": str(path) + os.pathsep + os.environ["PATH"],
                            "GITHUB_STEP_SUMMARY": str(path / "summary")}
        for sig in (signal.SIGTERM, signal.SIGKILL):
            marker = path / "paused.started"
            marker.unlink(missing_ok=True)
            child = subprocess.Popen([sys.executable, "-B", runner, "fixture"],
                                     env=env | {"BLOCK_TASK": "paused"},
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     start_new_session=True)
            try:
                deadline = time.monotonic() + 10
                while not marker.exists():
                    assert child.poll() is None and time.monotonic() < deadline
                    time.sleep(.02)
                os.killpg(child.pid, sig)
                child.communicate(timeout=5)
                assert child.returncode == -sig
            finally:
                try: os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError: pass
                child.communicate(timeout=5)
            evidence = json.loads((path / ".cache/ci/fixture.json").read_text())
            metadata = json.loads((path / ".cache/ci/fixture.meta.json").read_text())
            assert len(evidence) == metadata["result_count"] == 1
            assert evidence[0]["task"] == "first" and evidence[0]["exit_code"] == 0
            assert metadata["completed"] is False and metadata["expected_tasks"] == expected
            assert metadata["active_task"] == {"lane": "fixture", "task": "paused"}
            assert metadata["checkpoint_unix"] > 0
            assert not (path / "later.started").exists()
        # A complete subsequent run replaces the incomplete checkpoint only
        # after every selected task succeeds.
        subprocess.run([sys.executable, "-B", runner, "fixture"], env=env,
                       capture_output=True, check=True)
        evidence = json.loads((path / ".cache/ci/fixture.json").read_text())
        metadata = json.loads((path / ".cache/ci/fixture.meta.json").read_text())
        assert metadata["completed"] and metadata["active_task"] is None
        assert [row["task"] for row in evidence] == expected
        assert all(row["exit_code"] == 0 for row in evidence)
    # Run the discovery entry point: a completed first stage followed by a
    # definite task failure must retain both outcomes and stop before stage 3.
    with tempfile.TemporaryDirectory(prefix='transit-discovery-runner-') as directory:
        path = Path(directory)
        runner = path / 'tests/verification/external_profiles.py'
        runner.parent.mkdir(parents=True)
        runner.write_bytes((ROOT / 'tests/verification/external_profiles.py').read_bytes())
        (path / '.gitignore').write_text('.cache/\n')
        script = path / 'just'
        script.write_text(f'#!{sys.executable}\nimport sys\nprint("controlled stage", sys.argv[1:])\nsys.exit(23 if sys.argv[1] == "test::properties" else 0)\n')
        script.chmod(0o755)
        subprocess.run(['git', 'init', '-q'], cwd=path, check=True)
        subprocess.run(['git', 'add', '.'], cwd=path, check=True)
        subprocess.run(['git', '-c', 'user.name=CI fixture', '-c', 'user.email=fixture@example.invalid',
                        'commit', '-qm', 'test(ci): seed discovery fixture'], cwd=path, check=True)
        result = subprocess.run([sys.executable, '-B', runner, '--profile', 'discovery'], cwd=path,
                                env=os.environ | {'PATH': str(path) + os.pathsep + os.environ['PATH']}, capture_output=True)
        assert result.returncode != 0, result
        reports = list((path / '.cache/verification/external').glob('*/report.json'))
        assert len(reports) == 1
        evidence = json.loads(reports[0].read_text())
        assert not evidence['completed'] and not evidence['dirty']
        assert [stage['command'] for stage in evidence['stages']] == DISCOVERY[:2]
        assert evidence['stages'][0]['completed'] and evidence['stages'][0]['exit'] == 0
        assert not evidence['stages'][1]['completed'] and evidence['stages'][1]['exit'] == 23
        assert all(stage['timeout_seconds'] == 3600 for stage in evidence['stages'])
    print("CI lanes: disjoint local/hosted inventory, aggregate gate and failure propagation passed.")


if __name__ == "__main__":
    main()
