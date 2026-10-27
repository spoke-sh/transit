"""Record hosted setup/check/cleanup/cache costs without conflating missing proofs with success."""
from datetime import datetime
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SUITE = json.loads((ROOT / 'tests/runner/suite.json').read_text())
ORDINARY_LANES = SUITE['tiers']['ordinary']


def inventory_identity(suite=SUITE):
    # Include the browser continuation required by the experience job. A budget
    # for fewer tasks, or a different lane allocation, cannot qualify this suite.
    lanes = {name: suite['lanes'][name] for name in [*suite['tiers']['ordinary'], 'browser']}
    encoded = json.dumps(lanes, sort_keys=True, separators=(',', ':')).encode()
    return dict(sha256=hashlib.sha256(encoded).hexdigest(),
                ordinary_tasks=sum(len(suite['lanes'][name]) for name in suite['tiers']['ordinary']),
                ordinary_lanes=len(suite['tiers']['ordinary']), browser_tasks=len(lanes['browser']))


def seconds(start, end):
    return (datetime.fromisoformat(end.replace('Z', '+00:00')) - datetime.fromisoformat(start.replace('Z', '+00:00'))).total_seconds()


def summarize(run, jobs, log, budgets):
    lanes = []
    names = [job['name'] for job in jobs]
    missing_lanes = sorted(name for name in ORDINARY_LANES if name not in names)
    duplicate_lanes = sorted(name for name in ORDINARY_LANES if names.count(name) > 1)
    full_inventory = not missing_lanes and not duplicate_lanes
    for job in jobs:
        if job['name'] in ('Selection and documentation', 'foundation-and-protocol'):
            continue
        # The full matrix owns documentation through experience. Its separate
        # docs-only job is intentionally skipped by the selection gate.
        if full_inventory and job['name'] == 'Documentation site' and job['conclusion'] == 'skipped':
            continue
        # Missing/incomplete jobs remain explicit, with no invented duration.
        row = dict(name=job['name'], conclusion=job['conclusion'], seconds=None, phases={})
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
        lines = [line for line in log.splitlines() if line.startswith(job['name'] + '\t')]
        # Extract only byte counts and cache kinds, never raw logs or keys.
        sizes = [int(n) for line in lines for n in re.findall(r'Cache Size:.*\((\d+) B\)', line)]
        hits = {kind for line in lines for kind in re.findall(r'Cache (?:hit for(?: restore-key)?:|restored from key:) (nix|zig)-', line)}
        misses = any('Cache not found' in line for line in lines)
        fallback = any('Cache hit for restore-key:' in line for line in lines)
        cold = any('CI dependency cache mode: cold' in line for line in lines)
        row['cache'] = dict(restored_bytes=sum(sizes) if sizes else 0 if cold else None,
                            mode='cold' if cold and not hits and not sizes else 'miss-or-partial' if misses or fallback else 'warm' if hits == {'nix', 'zig'} and len(sizes) == 2 else 'unknown')
        lanes.append(row)
    complete = bool(lanes) and all(row['conclusion'] == 'success' and row['seconds'] is not None for row in lanes)
    ends = [j['completed_at'] for j in jobs if j.get('completed_at')]
    feedback = seconds(run['created_at'], max(ends)) if ends else None
    cost = sum(seconds(j['started_at'], j['completed_at']) for j in jobs if j.get('started_at') and j.get('completed_at'))
    cache_known = all(row['cache']['restored_bytes'] is not None for row in lanes)
    cache_bytes = sum(row['cache']['restored_bytes'] or 0 for row in lanes) if cache_known else None
    modes = {row['cache']['mode'] for row in lanes}
    profile = next(iter(modes)) if len(modes) == 1 else 'mixed'
    inventory = inventory_identity()
    budget_matches = budgets.get('inventory') == inventory
    limits = (budgets.get('cold') if profile == 'cold' else budgets if profile == 'warm' else None) if budget_matches else None
    recorded_limits = {key: limits[key] for key in ('feedback_seconds', 'aggregate_runner_seconds', 'restored_cache_bytes')} if limits else None
    qualified = full_inventory and complete and run['conclusion'] == 'success' and cache_known
    completed_lanes = [job for job in jobs if job['name'] in ORDINARY_LANES
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True, type=int)
    parser.add_argument('--repo', default='spoke-sh/transit')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    def api(path):
        return json.loads(subprocess.check_output(['gh', 'api', f'repos/{args.repo}/{path}'], text=True))
    run = api(f'actions/runs/{args.run}')
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
    result = summarize(run, response['jobs'], log, budgets)
    result['unavailable_job_logs'] = missing_logs
    if missing_logs:
        result.update(status='inconclusive', budget_met=False)
    destination = args.output or ROOT / f'.cache/ci/cost-{args.run}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if summary := os.getenv('GITHUB_STEP_SUMMARY'):
        with open(summary, 'a') as out:
            out.write(f"\nCI cost evidence: {result['status']}; budget met: {result['budget_met']}.\n")


if __name__ == '__main__':
    main()
