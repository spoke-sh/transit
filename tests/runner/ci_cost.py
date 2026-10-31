"""Record hosted setup/check/cleanup/cache costs without conflating missing proofs with success."""
from datetime import datetime
from pathlib import Path
import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import io
import statistics
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SUITE = json.loads((ROOT / 'tests/runner/suite.json').read_text())


def inventory_identity(suite=SUITE):
    # Include the browser continuation required by the installation-ui job. A budget
    # for fewer tasks, or a different lane allocation, cannot qualify this suite.
    lanes = {name: suite['lanes'][name] for name in [*suite['tiers']['ordinary'], 'browser']}
    encoded = json.dumps(lanes, sort_keys=True, separators=(',', ':')).encode()
    return dict(sha256=hashlib.sha256(encoded).hexdigest(),
                ordinary_tasks=sum(len(suite['lanes'][name]) for name in suite['tiers']['ordinary']),
                ordinary_lanes=len(suite['tiers']['ordinary']), browser_tasks=len(lanes['browser']))


def source_inventory(revision, api):
    # Read data from the measured revision; never execute that revision's code.
    # The workflow_run reporter deliberately runs trusted default-branch code.
    document = api(f'contents/tests/runner/suite.json?ref={revision}')
    assert document['encoding'] == 'base64', 'Unavailable source inventory bytes'
    suite = json.loads(base64.b64decode(''.join(document['content'].split()), validate=True))
    assert suite['version'] == 1, 'Unsupported source inventory'
    ordinary = suite['tiers']['ordinary']
    assert isinstance(ordinary, list) and ordinary and all(isinstance(name, str) for name in ordinary)
    assert len(set(ordinary)) == len(ordinary)
    tasks = []
    for name in dict.fromkeys([*ordinary, 'browser']):
        owned = suite['lanes'][name]
        assert isinstance(owned, list) and owned and all(isinstance(task, str) for task in owned)
        tasks.extend(owned)
    assert len(set(tasks)) == len(tasks), 'Duplicated source task ownership'
    return suite


def seconds(start, end):
    return (datetime.fromisoformat(end.replace('Z', '+00:00')) - datetime.fromisoformat(start.replace('Z', '+00:00'))).total_seconds()


def summarize(run, jobs, log, budgets, suite=SUITE):
    lanes = []
    ordinary_lanes = suite['tiers']['ordinary'] if suite is not None else []
    # Reusable workflows append their job name to the calling lane. Preserve
    # the original name when reading logs; inventory ownership uses the lane.
    jobs = [dict(job, log_name=job['name'], name=job['name'].removesuffix(' / execute')) for job in jobs]
    names = [job['name'] for job in jobs]
    missing_lanes = sorted(name for name in ordinary_lanes if name not in names)
    duplicate_lanes = sorted(name for name in ordinary_lanes if names.count(name) > 1)
    full_inventory = bool(ordinary_lanes) and not missing_lanes and not duplicate_lanes
    for job in jobs:
        if job['name'] in ('Selection and documentation', 'foundation-and-protocol'):
            continue
        # The full matrix owns documentation through installation-ui. Its separate
        # docs-only job is intentionally skipped by the selection gate.
        if full_inventory and job['name'] == 'Documentation site' and job['conclusion'] == 'skipped':
            continue
        # Missing/incomplete jobs remain explicit, with no invented duration.
        row = dict(name=job['name'], conclusion=job['conclusion'], seconds=None, phases={},
                   queue_seconds=seconds(run['created_at'], job['started_at']) if job.get('started_at') else None,
                   runner_labels=sorted(job.get('labels', [])))
        if job.get('started_at') and job.get('completed_at'):
            row['seconds'] = seconds(job['started_at'], job['completed_at'])
        for step in job['steps']:
            if step['conclusion'] == 'skipped' or not step.get('completed_at'):
                continue
            name = step['name']
            phase = ('cache_restore' if name.startswith('Restore ') else
                     'cache_save' if name.startswith('Save ') else
                     'checks_including_builds' if name.endswith(' checks') or name.startswith(('Qualify ', 'Weekly ')) else
                     'cleanup' if name.startswith(('Post ', 'Complete ', 'Preserve ')) else 'setup')
            row['phases'][phase] = row['phases'].get(phase, 0) + seconds(step['started_at'], step['completed_at'])
        lines = [line for line in log.splitlines() if line.startswith(job['log_name'] + '\t')]
        # Extract only byte counts and cache kinds, never raw logs or keys.
        sizes = [int(n) for line in lines for n in re.findall(r'Cache Size:.*\((\d+) B\)', line)]
        requested = {key for line in lines for key in re.findall(r'(?:\t|Z )[ \t]*(?:primary-key|key): ((?:nix|zig)-\S+)$', line)}
        restored = {key for line in lines for key in re.findall(r'Cache (?:hit for(?: restore-key)?:|restored from key:) ((?:nix|zig)-\S+)', line)}
        hits = {key.split('-', 1)[0] for key in restored}
        misses = any('Cache not found' in line or 'Could not find a cache' in line for line in lines)
        # actions/cache uses the same restored-key message for exact and prefix
        # hits. Compare its action input with the observed key, not just its kind.
        fallback = any('Cache hit for restore-key:' in line for line in lines) or bool(requested and restored - requested)
        cold = any('CI dependency cache mode: cold' in line for line in lines)
        # Match an emitted line, not Actions' rendered `echo "$NIX_CACHE"`
        # command. gh prefixes real output with a timestamp; controls omit it.
        policies = {policy for line in lines for policy in re.findall(r'(?:\t|Z )CI Nix cache policy: (\S+)$', line)}
        nix_policy = next(iter(policies)) if len(policies) == 1 else 'github' if not policies else 'unknown'
        expected_hits = {'zig'} if nix_policy == 'substitutes' else {'nix', 'zig'}
        exact_keys = (len(requested) == len(expected_hits)
                      and {key.split('-', 1)[0] for key in requested} == expected_hits
                      and restored == requested)
        row['cache'] = dict(restored_bytes=sum(sizes) if sizes else 0 if cold else None,
                            nix_policy=nix_policy,
                            mode='cold' if cold and not hits and not sizes else 'miss-or-partial' if misses or fallback else 'warm' if nix_policy in {'github', 'substitutes'} and exact_keys and len(sizes) == len(expected_hits) else 'unknown')
        lanes.append(row)
    complete = bool(lanes) and all(row['conclusion'] == 'success' and row['seconds'] is not None for row in lanes)
    ends = [j['completed_at'] for j in jobs if j.get('completed_at')]
    feedback = seconds(run['created_at'], max(ends)) if ends else None
    cost = sum(seconds(j['started_at'], j['completed_at']) for j in jobs if j.get('started_at') and j.get('completed_at'))
    cache_known = all(row['cache']['restored_bytes'] is not None for row in lanes)
    cache_bytes = sum(row['cache']['restored_bytes'] or 0 for row in lanes) if cache_known else None
    modes = {row['cache']['mode'] for row in lanes}
    profile = next(iter(modes)) if len(modes) == 1 else 'mixed'
    inventory = inventory_identity(suite) if suite is not None else None
    budget_matches = inventory is not None and budgets.get('inventory') == inventory
    limits = (budgets.get('cold') if profile == 'cold' else budgets if profile == 'warm' else None) if budget_matches else None
    recorded_limits = {key: limits[key] for key in ('feedback_seconds', 'aggregate_runner_seconds', 'restored_cache_bytes')} if limits else None
    qualified = full_inventory and complete and run['conclusion'] == 'success' and cache_known
    completed_lanes = [job for job in jobs if job['name'] in ordinary_lanes
                       and job['conclusion'] == 'success' and job.get('completed_at')]
    first = min(completed_lanes, key=lambda job: job['completed_at']) if completed_lanes else None
    return dict(version=1, run_id=run['id'], revision=run['head_sha'], url=run['html_url'],
                run_attempt=run.get('run_attempt', 1), cache_profile=profile, budget=recorded_limits,
                inventory=inventory, budget_inventory_matches=budget_matches,
                first_completed_lane=dict(name=first['name'], seconds=seconds(run['created_at'], first['completed_at'])) if first else None,
                conclusion=run['conclusion'], status='measured' if qualified else 'inconclusive',
                missing_lanes=missing_lanes, duplicate_lanes=duplicate_lanes,
                feedback_seconds=feedback, aggregate_runner_seconds=cost,
                restored_cache_bytes=cache_bytes, lanes=lanes,
                budget_met=qualified and limits is not None and feedback < limits['feedback_seconds'] and cost <= limits['aggregate_runner_seconds']
                           and cache_bytes <= limits['restored_cache_bytes'])


def archive_report(data):
    # Reports are untrusted data. Never extract or execute PR artifact contents.
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        members = archive.infolist()
        assert len(members) == 1 and members[0].filename.endswith('.json'), 'Unexpected feedback archive'
        assert members[0].file_size <= 2_000_000, 'Oversized feedback report'
        result = json.loads(archive.read(members[0]))
        assert result['version'] == 1
        return result


def evaluate(result, budgets, history):
    target = budgets.get('targets', {})
    matched = result['inventory'] == target.get('inventory')
    result['targets'] = target if matched else None
    result['target_met'] = (matched and result['status'] == 'measured'
                            and result['feedback_seconds'] <= target['feedback_seconds']
                            and result['aggregate_runner_seconds'] <= target['aggregate_runner_seconds'])
    policy = budgets.get('regressions', {})
    labels = sorted({tuple(lane['runner_labels']) for lane in result['lanes']})
    comparable = [row for row in history if row.get('status') == 'measured'
                  and row['inventory'] == result['inventory']
                  and row['cache_profile'] == result['cache_profile']
                  and sorted({tuple(lane.get('runner_labels', [])) for lane in row['lanes']}) == labels]
    result['sdk_feedback_targets'] = [dict(lane=lane['name'],
        seconds=(lane['queue_seconds'] + lane['seconds']) if lane.get('queue_seconds') is not None and lane['seconds'] is not None else None,
        target_seconds=target.get('affected_sdk_seconds'),
        completed=lane['conclusion'] == 'success') for lane in result['lanes'] if lane['name'].startswith('sdks-')]
    result['comparison_runs'] = [row['run_id'] for row in comparable]
    result['regressions'] = []
    eligible = (result['status'] == 'measured' and result['cache_profile'] in {'warm', 'cold'}
                and len(comparable) >= policy.get('minimum_samples', 3))
    if eligible:
        for metric in ('feedback_seconds', 'aggregate_runner_seconds'):
            baseline = statistics.median(row[metric] for row in comparable)
            excess = result[metric] - baseline
            if excess > max(policy.get('absolute_seconds', 30), baseline * policy.get('relative', .15)):
                result['regressions'].append(dict(metric=metric, baseline=baseline, observed=result[metric]))
    previous = comparable[0] if comparable else {}
    # A single slow hosted runner is a candidate. Enforce only consecutive
    # comparable regressions after a complete baseline exists.
    result['regression_confirmed'] = bool({r['metric'] for r in result['regressions']}
                                          & {r['metric'] for r in previous.get('regressions', [])})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True, type=int)
    parser.add_argument('--repo', default='spoke-sh/transit')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--enforce-regressions', action='store_true')
    args = parser.parse_args()
    def api(path):
        return json.loads(subprocess.check_output(['gh', 'api', f'repos/{args.repo}/{path}'], text=True))
    run = api(f'actions/runs/{args.run}')
    source_error = None
    try:
        suite = source_inventory(run['head_sha'], api)
    except (subprocess.CalledProcessError, ValueError, AssertionError, KeyError, TypeError) as error:
        suite = None
        source_error = type(error).__name__
    response = api(f'actions/runs/{args.run}/attempts/{run["run_attempt"]}/jobs?per_page=100')
    if response['total_count'] != len(response['jobs']):
        raise ValueError('Job pagination is incomplete')
    # A runner can die before uploading its log (for example during cache
    # extraction). Preserve measurable jobs and the missing-log distinction.
    logs, missing_logs = [], []
    for job in response['jobs']:
        if job['conclusion'] == 'skipped' or job['name'] in ('Selection and documentation', 'foundation-and-protocol'):
            continue
        fetched = subprocess.run(['gh', 'run', 'view', str(args.run), '--repo', args.repo,
                                  '--attempt', str(run['run_attempt']), '--job', str(job['id']), '--log'],
                                 text=True, capture_output=True)
        if fetched.returncode:
            missing_logs.append(dict(job_id=job['id'], name=job['name'], exit_code=fetched.returncode))
        else:
            logs.append(fetched.stdout)
    log = '\n'.join(logs)
    budgets = json.loads((ROOT / 'tests/runner/ci-budgets.json').read_text())
    result = summarize(run, response['jobs'], log, budgets, suite=suite)
    result['reporter_revision'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    result['unavailable_source_inventory'] = source_error
    result['unavailable_job_logs'] = missing_logs
    if missing_logs:
        result.update(status='inconclusive', budget_met=False)
    result['feedback_reports'], result['unavailable_feedback'] = [], []
    artifacts = api(f'actions/runs/{args.run}/artifacts?per_page=100')
    assert artifacts['total_count'] == len(artifacts['artifacts']), 'Artifact pagination is incomplete'
    for artifact in artifacts['artifacts']:
        if not artifact['name'].startswith('feedback-') or not artifact['name'].endswith(f'-{run["run_attempt"]}'):
            continue
        try:
            assert artifact['size_in_bytes'] <= 2_000_000, 'Oversized feedback artifact'
            data = subprocess.check_output(['gh', 'api', f'repos/{args.repo}/actions/artifacts/{artifact["id"]}/zip'])
            report = archive_report(data)
            assert str(report['run_id']) == str(args.run) and str(report['run_attempt']) == str(run['run_attempt'])
            assert report['inventory'] == result['inventory'], 'Feedback inventory mismatch'
            result['feedback_reports'].append(report)
        except (subprocess.CalledProcessError, ValueError, AssertionError, KeyError, zipfile.BadZipFile) as error:
            result['unavailable_feedback'].append(dict(artifact=artifact['name'], error=type(error).__name__))
    # Reuse prior reports, never rerun old source or download its native files.
    history = []
    recent = api('actions/workflows/ci.yml/runs?branch=main&status=success&per_page=10')
    for previous in recent['workflow_runs']:
        if previous['id'] >= args.run:
            continue
        try:
            candidates = api(f'actions/artifacts?name=ci-cost-{previous["id"]}&per_page=100')['artifacts']
            candidate = next(a for a in candidates if a['name'] == f'ci-cost-{previous["id"]}' and not a['expired'])
            assert candidate['size_in_bytes'] <= 2_000_000, 'Oversized cost artifact'
            history.append(archive_report(subprocess.check_output([
                'gh', 'api', f'repos/{args.repo}/actions/artifacts/{candidate["id"]}/zip'])))
        except (subprocess.CalledProcessError, ValueError, AssertionError, KeyError, StopIteration, zipfile.BadZipFile):
            continue
    evaluate(result, budgets, history)
    destination = args.output or ROOT / f'.cache/ci/cost-{args.run}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if summary := os.getenv('GITHUB_STEP_SUMMARY'):
        with open(summary, 'a') as out:
            out.write(f"\nCI cost evidence: {result['status']}; calibrated budget met: {result['budget_met']}; "
                      f"current target met: {result['target_met']}.\n\n")
            out.write('| Lane | Queue/dependency wait | Job seconds |\n| --- | ---: | ---: |\n')
            for lane in result['lanes']:
                out.write(f"| {lane['name']} | {lane['queue_seconds']} | {lane['seconds']} |\n")
            out.write(f"\nComparable baseline runs: `{result['comparison_runs']}`. "
                      f"Confirmed regression: `{result['regression_confirmed']}`.\n")
    if args.enforce_regressions and result['regression_confirmed']:
        raise SystemExit('CI feedback regressed on consecutive comparable successful runs')


if __name__ == '__main__':
    main()
