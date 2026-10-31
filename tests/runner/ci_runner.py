"""CI must propagate failures and keep local/hosted task selection aligned."""
import json
import base64
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import signal
import time

import yaml
from ci import LANES, ROOT, SUITE
from capture import verify
from ci_select import matrix, select
from ci_clean import profile
from ci_cost import inventory_identity, source_inventory, summarize
from external_profiles import DISCOVERY
from packages import discover
from task_coverage import read_recipes


def clean_runner():
    # Exercise clone isolation, lane preparation and retained failures with a
    # fake Nix executable. This checks orchestration, not the selected proofs.
    with tempfile.TemporaryDirectory(prefix="transit-clean-runner-") as directory:
        root = Path(directory)
        source = root / "source"
        (source / "tests/runner").mkdir(parents=True)
        (source / "tests/runner/ci_clean.py").write_bytes((ROOT / "tests/runner/ci_clean.py").read_bytes())
        (source / "tests/runner/capture.py").write_bytes((ROOT / "tests/runner/capture.py").read_bytes())
        (source / "tests/runner/suite.json").write_bytes((ROOT / "tests/runner/suite.json").read_bytes())
        (source / ".gitignore").write_text(".cache/\n")
        for command in (["init", "-q"], ["add", "."],
                        ["-c", "user.name=CI fixture", "-c", "user.email=fixture@example.invalid",
                         "commit", "-qm", "test(ci): seed clean fixture"]):
            subprocess.run(["git", *command], cwd=source, check=True)
        executable = root / "nix"
        executable.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
assert not any(key.startswith("TRANSIT_") for key in os.environ)
assert os.environ["ZIG_LOCAL_PKG_DIR"] == str(Path.cwd() / ".cache/ci-zig/p")
with open(os.environ["CI_CLEAN_RECORD"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
if "tests/runner/ci.py" in sys.argv or any(arg.startswith("check::") for arg in sys.argv):
    path = Path(".cache/checks" if any(arg.startswith("check::") for arg in sys.argv) else ".cache/ci")
    path.mkdir(parents=True)
    (path / "runs/fixture").mkdir(parents=True)
    (path / "runs/fixture/task.log").write_text("automatic output")
    (path / "result.json").write_text('{"fixture": true}\\n')
    Path(".cache/verification").mkdir()
    Path(".cache/verification/proof.json").write_text('{"fixture": true}\\n')
    Path(".cache/native-artifacts/fixture").mkdir(parents=True)
    Path(".cache/native-artifacts/fixture/record.json").write_text('{"fixture": true}\\n')
    sys.exit(int(os.environ.get("CI_CLEAN_EXIT", "0")))
''')
        executable.chmod(0o755)
        record = root / "commands.jsonl"
        env = os.environ | {"PATH": str(root) + os.pathsep + os.environ["PATH"],
                            "CI_CLEAN_RECORD": str(record), "TRANSIT_FIXTURE_LEAK": "denied"}
        for lane, exit_code in (("formal", 0), ("installation-ui", 0),
                                *((lane, 0) for lane in SUITE["tiers"]["sdks"]), ("sdks", 0), ("formal", 23),
                                ("check::fast", 0), ("check::contracts", 0), ("check::contracts", 24)):
            record.unlink(missing_ok=True)
            work = root / f"{lane}-{exit_code}"
            work.mkdir()
            check_scope = lane.removeprefix("check::") if lane.startswith("check::") else None
            selection = ["--check", check_scope] if check_scope else ["--lane", lane]
            result = subprocess.run([sys.executable, "-B", source / "tests/runner/ci_clean.py",
                                     *selection, "--work-root", work], cwd=source,
                                    env=env | {"CI_CLEAN_EXIT": str(exit_code)}, capture_output=True)
            assert (result.returncode == 0) == (exit_code == 0), result.stderr.decode()
            commands = [json.loads(line) for line in record.read_text().splitlines()]
            expected = ({"shell": "default", "prepare": [] if check_scope == "fast" else
                        [["just", "ci::dependencies"],
                         ["vp", "install", "--frozen-lockfile", "--filter", "transit", "--filter", "@transit/client"]]}
                        if check_scope else profile(SUITE, lane))
            assert len(commands) == 2 + len(expected["prepare"]), commands
            assert all(command[:6] == ["develop", ".#" + expected["shell"],
                                       "--option", "eval-cache", "false", "--command"]
                       for command in commands), commands
            assert [command[8:] for command in commands[1:-1]] == expected["prepare"]
            expected_command = ["just", lane] if check_scope else ["python3", "-B", "tests/runner/ci.py", lane]
            assert commands[-1][8:] == expected_command
            if exit_code:
                reports = list(work.glob("transit-ci-*/preparation.json"))
                result_directory = "checks" if check_scope else "ci"
                assert len(reports) == 1 and (reports[0].parent / f"src/.cache/{result_directory}/result.json").is_file()
            else:
                assert not list(work.iterdir()), "successful clone was not removed"
                reports = list((source / ".cache/ci/clean").glob("*/preparation.json"))
                reports = [p for p in reports if json.loads(p.read_text())["selection"] == lane]
                assert len(reports) == 1
                assert (reports[0].parent / "verification/proof.json").is_file()
                assert (reports[0].parent / "native-artifacts/fixture/record.json").is_file()
                result_directory = "checks" if check_scope else "."
                assert (reports[0].parent / result_directory / "runs/fixture/task.log").read_text() == "automatic output"
                if check_scope:
                    assert (reports[0].parent / "checks/result.json").is_file()
            metadata = json.loads(reports[0].read_text())
            assert metadata["completed"] == (exit_code == 0)
            assert metadata["phases"][-1]["exit_code"] == exit_code
            assert metadata["shell"] == expected["shell"]
            assert all(row["seconds"] >= 0 for row in metadata["phases"])
            assert all((reports[0].parent / "preparation" / row["log"]).is_file()
                       for row in metadata["phases"])


def release_workflow():
    workflow = yaml.safe_load((ROOT / '.github/workflows/release.yml').read_text())
    assert workflow['concurrency']['cancel-in-progress'] == "${{ github.event_name == 'pull_request' }}"
    # PyYAML's YAML 1.1 loader parses the workflow's `on` key as True.
    triggers = workflow[True]['pull_request']['paths']
    assert {'tests/interfaces/installation/board_workbench.py',
            'tests/interfaces/cli/console_terminal.py', 'tests/interfaces/cli/console_edit.py',
            'apps/transit-board-web/browser/workbench.spec.ts', 'tasks/bindings.just'} <= set(triggers)
    jobs = workflow['jobs']

    def ancestors(name):
        needs = jobs[name].get('needs', [])
        if isinstance(needs, str):
            needs = [needs]
        return set(needs).union(*(ancestors(parent) for parent in needs))

    # Packaging failures must not hide independent installed-consumer evidence.
    for job in ('sdk-build', 'sdk-consumers', 'sdk-zig', 'installed', 'board'):
        assert 'build' in ancestors(job) and 'images' not in ancestors(job)
        assert any(step.get('with', {}).get('name') == 'runtime-${{ matrix.artifact }}'
                   for step in jobs[job]['steps'])
    assert 'sdk-build' not in ancestors('installed')
    # Independence during diagnosis must never weaken the publication gate.
    required = {'qualification', 'build', 'images', 'installed', 'board', 'sdk-build',
                'sdk-consumers', 'sdk-zig', 'sdk-loaders', 'handbook', 'assemble', 'homebrew'}
    assert required <= ancestors('publish')
    assert 'images' in ancestors('assemble')
    assert {'publish', 'published'} <= ancestors('promote-nightly')
    for job in required | {'publish', 'published', 'promote-nightly'}:
        assert 'always()' not in jobs[job].get('if', '')
        assert not jobs[job].get('continue-on-error', False)
        assert not any(step.get('continue-on-error', False) for step in jobs[job].get('steps', []))
    assert "needs.prepare.outputs.publish == 'true'" in jobs['publish']['if']
    prepare = next(step for step in jobs['prepare']['steps'] if step.get('id') == 'identity')
    assert "github.event_name == 'pull_request' && 'nightly'" in prepare['env']['CHANNEL']
    assert "github.ref == 'refs/heads/main'" in prepare['env']['PUBLISH']
    assert "github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')" in prepare['env']['PUBLISH']
    for job in ('build', 'images', 'sdk-build', 'sdk-zig', 'board'):
        platforms = jobs[job]['strategy']['matrix']['include']
        assert {(row['architecture'], row['runner']) for row in platforms} == {
            ('x86_64', 'ubuntu-24.04'), ('aarch64', 'ubuntu-24.04-arm')}
        assert jobs[job]['strategy']['fail-fast'] is False
    evidence = next(step for step in jobs['images']['steps']
                    if step.get('name') == 'Preserve image conversion diagnostics')
    assert evidence['if'] == 'failure()'
    assert evidence['with']['path'] == '.cache/release-images/'


def main():
    # Fixture runners must not inherit the hosted job's source-bound selection.
    os.environ.pop("TRANSIT_CI_SELECTION_PATH", None)
    clean_runner()
    release_workflow()
    workflow = yaml.safe_load((ROOT / ".github/workflows/ci.yml").read_text())
    strategy = workflow["jobs"]["checks"]["strategy"]
    assert strategy["matrix"] == "${{ fromJSON(needs.plan.outputs.runtime_matrix) }}"
    assert strategy["max-parallel"] == SUITE["selection"]["max_parallel"]
    workers = matrix({task for lane in SUITE["tiers"]["ordinary"] for task in LANES[lane]})
    selected = [row["lane"] for row in workers]
    assert selected == SUITE["tiers"]["ordinary"]
    assert SUITE["tiers"]["sdks"] == ["sdks-conformance", "sdks-scripting", "sdks-systems", "sdks-managed"]
    assert set(SUITE["tiers"]["sdks"]) <= set(selected)
    assert workflow["jobs"]["checks"]["strategy"]["fail-fast"] is False
    lane_workflow = yaml.safe_load((ROOT / '.github/workflows/ci-lane.yml').read_text())
    execution = lane_workflow['jobs']['execute']
    steps = execution['steps']
    assert workflow['jobs']['sdks']['needs'] == ['plan', 'native']
    assert workflow['jobs']['checks']['needs'] == 'plan'
    assert workflow['jobs']['sdks']['with']['native_bundle'] is True
    assert workflow['jobs']['native']['strategy']['matrix'] == {'family': ['clients', 'authority'], 'optimize': ['Debug', 'ReleaseSafe']}
    assert next(step for step in steps if step.get('name') == 'Download immutable native publications')['if'] == 'inputs.native_bundle'
    assert next(step for step in steps if step.get('name') == 'Run ${{ inputs.lane }} checks')['if'] == "inputs.native_family == ''"
    assert execution["env"]["ZIG_LOCAL_PKG_DIR"] == "${{ github.workspace }}/.cache/ci-zig/p"
    package_cache = next(step for step in steps if step.get("id") == "zig-cache")
    assert package_cache["with"]["key"].startswith("zig-v3-")
    reclaim = next(step for step in steps if step.get("name") == "Reclaim unused hosted SDKs")
    assert reclaim["if"] == "runner.environment == 'github-hosted' && inputs.cache != 'formal'"
    # A primary cache hit can fill the disk during extraction, before the shell
    # starts. Large hosted lanes reclaim before either restore or build. Formal
    # uses binary substitutes and does not restore an unrelated SDK closure.
    for name in ("Restore Nix store", "Prepare development shell"):
        assert steps.index(reclaim) < next(i for i, step in enumerate(steps) if step.get("name") == name)
    names = [step.get("name") for step in steps]
    dependencies = next(step for step in steps if step.get("name") == "Fetch pinned Zig dependencies")
    assert dependencies["if"] == "inputs.lane != 'formal'"
    assert dependencies["run"].endswith("--command just ci::dependencies")
    assert names.index("Restore Zig standard libraries and fetched packages") < names.index("Fetch pinned Zig dependencies")
    assert names.index("Fetch pinned Zig dependencies") < names.index("Run ${{ inputs.lane }} checks")
    for lane, environment in SUITE["environments"].items():
        if lane != "formal":
            assert environment["prepare"][0] == ["just", "ci::dependencies"]
    assert names.index("Prepare development shell") < names.index("Save Nix store")
    assert names.index("Save Nix store") < names.index("Run ${{ inputs.lane }} checks")
    for name in ('Restore Nix store', 'Save Nix store'):
        assert "inputs.cache != 'formal'" in next(step['if'] for step in steps if step.get('name') == name)
    assert "github.event_name == 'workflow_dispatch' && github.run_id" in workflow['concurrency']['group']
    assert workflow['concurrency']['cancel-in-progress'] is True
    artifacts = next(step for step in steps if step.get("name") == "Preserve task timings and completion evidence")
    assert ".cache/m9/station-local-readiness.json" in artifacts["with"]["path"].splitlines()
    assert ".cache/checks/*.json" in artifacts["with"]["path"].splitlines()
    assert {".cache/ci/runs/", ".cache/checks/runs/"} <= set(artifacts["with"]["path"].splitlines())
    assert ".cache/native-artifacts/" in artifacts["with"]["path"].splitlines()
    gate = workflow["jobs"]["foundation-and-protocol"]
    assert gate["if"] == "always()" and gate["needs"] == ["plan", "checks", "native", "sdks", "documentation"]
    assert workflow["jobs"]["documentation"]["if"] == "needs.plan.outputs.documentation == 'true'"
    assert workflow["jobs"]["checks"]["if"] == "needs.plan.outputs.runtime_checks == 'true'"
    assert "transit-docs::check" in LANES["installation-ui"]
    # Renaming a lane must not omit its frontend preparation or the separately
    # invoked browser continuation from hosted qualification.
    assert next(step["if"] for step in steps if step.get("name") == "Install locked Board frontend dependencies") == (
        "inputs.lane == 'installation-ui' || inputs.lane == 'launchers' || inputs.lane == 'browser'")
    for name in ("Install browser and host dependencies",):
        assert next(step["if"] for step in steps if step.get("name") == name) == "inputs.lane == 'browser'"
    assert select([], "push")["lanes"]["browser"] == LANES["browser"]
    assert not select([], "push")["additional_lanes"]
    for row in workers:
        assert row["shell"] == SUITE["environments"][row["lane"]]["shell"]
    assert profile(SUITE, "formal") == {"shell": "ci-formal", "prepare": []}
    assert LANES["formal"] == ["test::sql-rewrites", "test::model-delivery", "test::queue-lease-transaction-model",
                               "test::wal-model", "test::resident-owner-cache-model", "test::transaction-decision-model",
                               "test::storage-lifecycle-model", "test::transaction-workspace-model", "test::model",
                               "test::console-model", "test::statement-result-model", "test::table-transaction-model",
                               "test::write-lifecycle-model", "test::object-publication-model"]
    assert ".cache/verification/write-lifecycle-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/wal-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/object-publication-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/transaction-decision-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/table-transaction-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/transaction-workspace-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/storage-lifecycle-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/resident-owner-cache-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/queue-lease-transaction-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/console-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/verification/statement-result-model/" in artifacts["with"]["path"].splitlines()
    assert ".cache/allocations/runs/" in artifacts["with"]["path"].splitlines()
    for cache in {row["cache"] for row in workers}:
        assert sum(row["cache_writer"] for row in workers if row["cache"] == cache) == (0 if cache == 'formal' else 1)
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
    budgets = {"feedback_seconds": 600, "aggregate_runner_seconds": 3000, "restored_cache_bytes": 300 * len(selected) + 1,
               "inventory": inventory_identity()}
    sample = dict(id=1, head_sha='fixture', html_url='https://example.invalid', conclusion='success', created_at='2026-01-01T00:00:00Z')
    job = dict(name='core', conclusion='success', started_at='2026-01-01T00:00:01Z', completed_at='2026-01-01T00:00:10Z', steps=[])
    log = ('core\t  primary-key: nix-key\ncore\tCache hit for: nix-key\ncore\tCache Size: ~0 MB (100 B)\n'
           'core\t  key: zig-key\ncore\tCache hit for: zig-key\ncore\tCache Size: ~0 MB (200 B)\n')
    full_jobs = [dict(job, name=name) for name in selected]
    full_log = ''.join(log.replace('core\t', name + '\t') for name in selected)
    measured = summarize(sample, full_jobs, full_log, budgets)
    nested = summarize(sample, [dict(row, name=row['name'] + ' / execute') for row in full_jobs], full_log.replace('\t', ' / execute\t'), budgets)
    assert nested['budget_met'] and nested['inventory'] == measured['inventory']
    assert measured['budget_met'] and measured['restored_cache_bytes'] == 300 * len(selected)
    assert measured['feedback_seconds'] == 10 and measured['aggregate_runner_seconds'] == 9 * len(selected)
    assert not measured['missing_lanes'] and not measured['duplicate_lanes']
    assert measured['first_completed_lane'] == dict(name=selected[0], seconds=10)
    assert measured['budget_inventory_matches']
    expected_tasks = sum(len(LANES[name]) for name in selected)
    assert measured['inventory']['ordinary_tasks'] == expected_tasks
    for old_inventory in (None, dict(inventory_identity(), ordinary_tasks=33),
                          dict(inventory_identity(), sha256='foreign')):
        stale = summarize(sample, full_jobs, full_log, dict(budgets, inventory=old_inventory))
        assert stale['status'] == 'measured' and not stale['budget_met']
        assert stale['budget'] is None and not stale['budget_inventory_matches']
    expanded = json.loads(json.dumps(SUITE))
    expanded['lanes']['storage-query'].append('test::additional-storage-scope')
    assert inventory_identity(expanded)['ordinary_tasks'] == expected_tasks + 1
    expanded_measurement = summarize(sample, full_jobs, full_log, budgets, suite=expanded)
    assert expanded_measurement['status'] == 'measured'
    assert not expanded_measurement['budget_inventory_matches']
    assert expanded_measurement['budget'] is None and not expanded_measurement['budget_met']
    changed = json.loads(json.dumps(SUITE))
    changed['lanes']['browser'][0] = 'test::different-browser-scope'
    assert inventory_identity(changed)['sha256'] != inventory_identity()['sha256']
    assert not summarize(sample, full_jobs, full_log, dict(budgets, inventory=inventory_identity(changed)))['budget_met']
    def source_api(path):
        assert path == 'contents/tests/runner/suite.json?ref=measured-source'
        return dict(encoding='base64', content=base64.b64encode(json.dumps(changed).encode()).decode())
    historical = source_inventory('measured-source', source_api)
    other_source = summarize(sample, full_jobs, full_log, budgets, suite=historical)
    assert other_source['status'] == 'measured' and not other_source['budget_met']
    assert other_source['inventory'] == inventory_identity(changed)
    unavailable = summarize(sample, full_jobs, full_log, budgets, suite=None)
    assert unavailable['status'] == 'inconclusive' and unavailable['inventory'] is None
    assert not unavailable['budget_met'] and unavailable['budget'] is None
    for invalid in (dict(SUITE, version=999), dict(SUITE, tiers={'ordinary': ['core', 'core']})):
        try:
            source_inventory('measured-source', lambda path: dict(encoding='base64', content=base64.b64encode(json.dumps(invalid).encode()).decode()))
        except AssertionError:
            pass
        else:
            raise AssertionError('Foreign or duplicated source inventory qualified')
    assert not summarize(sample, full_jobs, '', budgets)['budget_met']
    assert not summarize(sample, [dict(job, conclusion='failure'), *full_jobs[1:]], full_log, budgets)['budget_met']
    assert not summarize(sample, [dict(job, completed_at=None), *full_jobs[1:]], full_log, budgets)['budget_met']
    assert not summarize(sample, full_jobs, full_log, dict(budgets, feedback_seconds=10))['budget_met']
    cold_log = ''.join(name + '\tCI dependency cache mode: cold\n' for name in selected)
    assert not summarize(sample, full_jobs, cold_log, budgets)['budget_met']
    cold_budget = dict(feedback_seconds=20, aggregate_runner_seconds=10 * len(selected), restored_cache_bytes=0)
    cold = summarize(sample, full_jobs, cold_log, dict(budgets, cold=cold_budget))
    assert cold['budget_met'] and cold['budget'] == cold_budget and cold['cache_profile'] == 'cold'
    assert measured['budget'] == {key: value for key, value in budgets.items() if key != 'inventory'} and measured['cache_profile'] == 'warm'
    fallback_log = full_log.replace('Cache hit for: zig-key', 'Cache hit for restore-key: zig-key')
    fallback = summarize(sample, full_jobs, fallback_log, budgets)
    assert fallback['restored_cache_bytes'] == 300 * len(selected) and fallback['cache_profile'] == 'miss-or-partial'
    assert fallback['status'] == 'measured' and not fallback['budget_met']
    # The pinned action emits the same restored-key message on a prefix hit;
    # no explicit "restore-key" marker is needed to establish a mismatch.
    silent_fallback = full_log.replace('Cache hit for: zig-key', 'Cache restored from key: zig-other')
    assert summarize(sample, full_jobs, silent_fallback, budgets)['cache_profile'] == 'miss-or-partial'
    no_keys = full_log.replace('primary-key: nix-key', 'No requested Nix key').replace('key: zig-key', 'No requested Zig key')
    assert summarize(sample, full_jobs, no_keys, budgets)['cache_profile'] == 'unknown'
    assert not summarize(sample, full_jobs, no_keys, budgets)['budget_met']
    # Formal deliberately uses Nix binary substitutes; only its configured Zig
    # cache can be warm. An undeclared missing Nix restore remains incomplete.
    formal_log = 'formal\tCI Nix cache policy: substitutes\nformal\t  key: zig-key\nformal\tCache hit for: zig-key\nformal\tCache Size: ~0 MB (200 B)\n'
    substitutes_log = full_log.replace(log.replace('core\t', 'formal\t'), formal_log)
    substitutes = summarize(sample, full_jobs, substitutes_log, budgets)
    assert substitutes['cache_profile'] == 'warm' and substitutes['budget_met']
    assert substitutes['restored_cache_bytes'] == 300 * len(selected) - 100
    assert next(row for row in substitutes['lanes'] if row['name'] == 'formal')['cache']['nix_policy'] == 'substitutes'
    echoed = ('formal\tRecord dependency cache mode\t2026-10-27T05:28:48.4628028Z '
              '\x1b[36;1mecho "CI Nix cache policy: $NIX_CACHE"\x1b[0m\n')
    hosted_policy = substitutes_log.replace('formal\tCI Nix cache policy: substitutes',
        'formal\tRecord dependency cache mode\t2026-10-27T05:28:48.4771360Z CI Nix cache policy: substitutes')
    assert summarize(sample, full_jobs, echoed + hosted_policy, budgets)['cache_profile'] == 'warm'
    assert not summarize(sample, full_jobs, hosted_policy.replace('policy: substitutes', 'policy: unknown'), budgets)['budget_met']
    conflicting = hosted_policy + 'formal\tCI Nix cache policy: github\n'
    assert not summarize(sample, full_jobs, conflicting, budgets)['budget_met']
    undeclared = summarize(sample, full_jobs, substitutes_log.replace('CI Nix cache policy: substitutes', 'No policy'), budgets)
    assert undeclared['cache_profile'] == 'mixed' and not undeclared['budget_met']
    nix_miss_log = substitutes_log.replace('formal\tCI Nix cache policy: substitutes', 'formal\tCould not find a cache.')
    assert next(row for row in summarize(sample, full_jobs, nix_miss_log, budgets)['lanes'] if row['name'] == 'formal')['cache']['mode'] == 'miss-or-partial'
    # Match an actual full hosted selection: the alternative docs-only job is
    # skipped, but every required matrix lane must still execute successfully.
    docs_skipped = dict(job, name='Documentation site', conclusion='skipped')
    full_budgets = dict(budgets)
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
    assert not select(["docs/handbook/reference/state.md", "docs/roadmap/11-releases.md", "README.md"])["full"]
    assert not select(["docs/handbook/catalog.ts", "docs/handbook/src/css/custom.css",
                       "docs/handbook/package.json"])["full"]
    assert not select(["tests/README.md", "tests/verification/models/AGENTS.md",
                       "packages/zig/transit-core/README.md",
                       "docs/history/qualification/migration.json",
                       "tests/evidence/verification/record/report.json",
                       "tests/evidence/verification/record/failed.log.gz"])["full"]
    for paths in ([], ["docs/schema.json"], ["contracts/STATE_V1.md"],
                  ["build.zig"], ["unknown"], ["docs/../../build.zig"], ["/README.md"],
                  ["docs/handbook/../../build.zig"], ["docs/handbook-old/site.ts"],
                  ["docs/handbook/catalog.ts", "pnpm-lock.yaml"],
                  ["contracts/sql/README.md"], ["tests/fixtures/record.json"],
                  ["tests/evidence/verification/record/test.py"],
                  ["tests/evidence/verification/../suite.json"],
                  ["tests/performance/query/budgets/record/budgets.json"],
                  ["tests/verification/invariants.json"], ["tests/runner/suite.json"],
                  ["tests/README.md", "packages/zig/transit-core/src/lib.zig"]):
        assert select(paths)["full"], paths
    assert select(["tests/verification/models/Wal.tla"])["lanes"] == {"formal": ["test::wal-model"]}
    assert select(["tests/verification/models/ObjectPublication.tla"])["lanes"] == {"formal": ["test::object-publication-model"]}
    assert select(["tests/verification/models/TransactionDecision.tla"])["lanes"] == {"formal": ["test::transaction-decision-model", "test::table-transaction-model"]}
    assert select(["tests/verification/models/TableTransaction.tla"])["lanes"] == {"formal": ["test::table-transaction-model"]}
    assert select(["tests/verification/models/TransactionWorkspace.tla"])["lanes"] == {"formal": ["test::transaction-workspace-model"]}
    assert select(["tests/verification/models/StorageLifecycle.tla"])["lanes"] == {"formal": ["test::storage-lifecycle-model"]}
    assert select(["tests/verification/models/ResidentOwnerCache.tla"])["lanes"] == {"formal": ["test::resident-owner-cache-model"]}
    assert select(["tests/verification/models/QueueLeaseTransaction.tla"])["lanes"] == {"formal": ["test::queue-lease-transaction-model"]}
    assert select(["tests/verification/models/WriteLifecycle.tla"])["lanes"] == {"formal": ["test::write-lifecycle-model"]}
    assert select(["tests/verification/models/StatementResult.tla"])["lanes"] == {"formal": ["test::statement-result-model"]}
    assert select(["contracts/sql/FuzeCell.lean"])["lanes"] == {"formal": ["test::sql-rewrites"]}
    assert select(["tests/verification/models/tlc_support.py"])["lanes"] == {"formal": ["test::queue-lease-transaction-model", "test::resident-owner-cache-model", "test::transaction-decision-model", "test::storage-lifecycle-model", "test::transaction-workspace-model", "test::console-model", "test::statement-result-model", "test::table-transaction-model", "test::write-lifecycle-model", "test::object-publication-model"]}
    assert select(["sdks/go/client/types.go"])["lanes"] == {"sdks-systems": ["bindings::go-sdk-test"]}
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
        command = [sys.executable, "-B", str(ROOT / "tests/runner/ci_select.py"), "--base"]
        result = subprocess.run([*command, base], cwd=path, capture_output=True, check=True)
        plan = json.loads(result.stdout)
        assert plan["full"] and plan["paths"] == ["docs/example.md", "source.zig"]
        assert subprocess.run([*command, "missing-revision"], cwd=path, capture_output=True).returncode != 0
    # Exercise the actual shell gate: skipped, cancelled and missing evidence
    # cannot pass merely because a dependent job did not execute.
    gate_script = gate["steps"][0]["run"]
    for checks, documentation in (("true", "false"), ("false", "true"), ("true", "true"),
                                  ("false", "false"), ("", "true"), ("true", "")):
        for plan in ("success", "failure", "cancelled", "skipped", ""):
            for result in ("success", "failure", "cancelled", "skipped", ""):
                for docs in ("success", "failure", "cancelled", "skipped", ""):
                    passed = subprocess.run(["bash", "-e", "-c", gate_script], env=os.environ | {
                        "PLAN": plan, "CHECKS": checks, "DOCUMENTATION": documentation,
                        "RESULT": result, "DOCS": docs,
                        "SDKS": "false", "NATIVE_RESULT": "skipped", "SDK_RESULT": "skipped",
                    }).returncode == 0
                    assert passed == (plan == "success" and (checks, documentation) != ("false", "false")
                                      and (checks, result) in {("true", "success"), ("false", "skipped")}
                                      and (documentation, docs) in {("true", "success"), ("false", "skipped")}), (
                                          plan, checks, documentation, result, docs)
    tasks = [task for lane in selected for task in LANES[lane]]
    assert len(tasks) == len(set(tasks)), "a proof is duplicated across lanes"
    assert {"test::packages-build", "test::compute"} <= set(LANES["core"])
    assert "test::packages" not in LANES["core"]
    recipes = (ROOT / "tasks/test.just").read_text()
    compile_recipe = read_recipes(ROOT)["test::packages-build"]
    assert compile_recipe["body"] == [['python3 -B tests/runner/packages.py --jobs "$1"']]
    full_recipe = recipes.split("\npackages:\n", 1)[1].split("\n\n", 1)[0]
    discovered = discover(ROOT)
    assert len(discovered) == len(full_recipe.strip().splitlines())
    for package in discovered:
        build = package / "build.zig"
        assert 'b.step("check",' in build.read_text(), build
        assert f"cd packages/zig/{package.name} && zig build test" in full_recipe, build
    # Compile-only checks cannot replace Fuze's upstream runtime owner.
    assert 'zig build test-compute' in recipes
    assert 'b.step("test-compute",' in (ROOT / "packages/zig/transit-fuze/build.zig").read_text()
    # Run the actual entry point with a deterministic failing task executable.
    # Later tasks must not run and the original status/evidence must survive.
    for native, sdk in (("success", "success"), ("failure", "skipped"),
                        ("skipped", "success"), ("success", "cancelled"), ("success", "")):
        passed = subprocess.run(["bash", "-e", "-c", gate_script], env=os.environ | {
            "PLAN": "success", "CHECKS": "false", "RESULT": "skipped",
            "SDKS": "true", "NATIVE_RESULT": native, "SDK_RESULT": sdk,
            "DOCUMENTATION": "false", "DOCS": "skipped",
        }).returncode == 0
        assert passed == (native == sdk == "success")
    with tempfile.TemporaryDirectory(prefix="transit-ci-runner-") as directory:
        path = Path(directory)
        script = path / "just"
        script.write_text(f"#!{sys.executable}\nimport sys\nprint('deliberate task failure')\nsys.exit(23)\n")
        script.chmod(0o755)
        runner = path / "tests/runner/ci.py"
        runner.parent.mkdir(parents=True)
        runner.write_bytes((ROOT / "tests/runner/ci.py").read_bytes())
        (runner.parent / "capture.py").write_bytes((ROOT / "tests/runner/capture.py").read_bytes())
        (path / "tests/runner/suite.json").write_bytes((ROOT / "tests/runner/suite.json").read_bytes())
        env = os.environ | {"PATH": str(path) + os.pathsep + os.environ["PATH"],
                            "GITHUB_STEP_SUMMARY": str(path / "summary")}
        result = subprocess.run([sys.executable, "-B", runner, "browser"], env=env, capture_output=True)
        assert result.returncode == 23, result
        evidence = json.loads((path / ".cache/ci/browser.json").read_text())
        assert len(evidence) == 1 and evidence[0]["exit_code"] == 23
        metadata = json.loads((path / ".cache/ci/browser.meta.json").read_text())
        assert metadata["completed"] is False
        assert metadata["expected_tasks"] == LANES["browser"]
        logs = path / ".cache/ci" / metadata["run_directory"]
        assert (logs / evidence[0]["log"]).read_text() == "deliberate task failure\n"
        assert json.loads((logs / "results.json").read_text()) == evidence
        assert "transit-board::browser" in (path / "summary").read_text()
    # Independent SDK jobs and the full local selector must execute
    # exactly their declared tasks, retaining complete per-lane evidence.
    with tempfile.TemporaryDirectory(prefix="transit-ci-sdks-") as directory:
        path = Path(directory)
        runner = path / "tests/runner/ci.py"
        runner.parent.mkdir(parents=True)
        runner.write_bytes((ROOT / "tests/runner/ci.py").read_bytes())
        (runner.parent / "capture.py").write_bytes((ROOT / "tests/runner/capture.py").read_bytes())
        (path / "tests/runner/suite.json").write_bytes((ROOT / "tests/runner/suite.json").read_bytes())
        script = path / "just"
        script.write_text(f"#!{sys.executable}\nimport sys\nfrom pathlib import Path\n"
                          "with Path('executed').open('a') as log: log.write(sys.argv[1]+'\\n')\n")
        script.chmod(0o755)
        env = os.environ | {"PATH": str(path) + os.pathsep + os.environ["PATH"]}
        for selection in ("formal", "sdks", *SUITE["tiers"]["sdks"]):
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
            initial, current = metadata['resources_initial'], metadata['resources_current']
            assert current['child_user_seconds'] >= initial['child_user_seconds']
            assert current['child_system_seconds'] >= initial['child_system_seconds']
            assert current['max_child_rss_platform_units'] >= initial['max_child_rss_platform_units'] > 0
            assert all(row["exit_code"] == 0 for row in evidence)
            verify(path / ".cache/ci" / metadata["run_directory"])
    # Kill the real runner while its second task is active. Neither SIGTERM nor
    # SIGKILL executes its finally block; the earlier task must remain recorded.
    with tempfile.TemporaryDirectory(prefix="transit-ci-interrupted-") as directory:
        path = Path(directory)
        runner = path / "tests/runner/ci.py"
        runner.parent.mkdir(parents=True)
        runner.write_bytes((ROOT / "tests/runner/ci.py").read_bytes())
        (runner.parent / "capture.py").write_bytes((ROOT / "tests/runner/capture.py").read_bytes())
        expected = ["first", "paused", "later"]
        (path / "tests/runner/suite.json").write_text(json.dumps({
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
            assert metadata["active_task"] == {"lane": "fixture", "task": "paused", "log": "002.log"}
            assert metadata["checkpoint_unix"] > 0
            retained = path / ".cache/ci" / metadata["run_directory"]
            assert (retained / "002.log").is_file()
            assert json.loads((retained / "meta.json").read_text()) == metadata
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
        verify(path / ".cache/ci" / metadata["run_directory"])
        assert len(list((path / ".cache/ci/runs").iterdir())) == 3
        assert not json.loads((retained / "meta.json").read_text())["completed"]
    # Run the discovery entry point: a completed first stage followed by a
    # definite task failure must retain both outcomes and stop before stage 3.
    with tempfile.TemporaryDirectory(prefix='transit-discovery-runner-') as directory:
        path = Path(directory)
        runner = path / 'tests/runner/external_profiles.py'
        runner.parent.mkdir(parents=True)
        runner.write_bytes((ROOT / 'tests/runner/external_profiles.py').read_bytes())
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
