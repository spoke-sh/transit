"""Record hosted setup/check/cleanup/cache costs without conflating missing proofs with success."""
from datetime import datetime
from pathlib import Path
import argparse
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def seconds(start, end):
    return (datetime.fromisoformat(end.replace('Z', '+00:00')) - datetime.fromisoformat(start.replace('Z', '+00:00'))).total_seconds()


def summarize(run, jobs, log, budgets):
    lanes = []
    for job in jobs:
        if job['name'] in ('Selection and documentation', 'foundation-and-protocol'):
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
        hits = {kind for line in lines for kind in ('nix', 'zig') if f'Cache hit for: {kind}-' in line}
        misses = any('Cache not found' in line for line in lines)
        cold = any('CI dependency cache mode: cold' in line for line in lines)
        row['cache'] = dict(restored_bytes=sum(sizes) if sizes else 0 if cold else None,
                            mode='cold' if cold and not hits and not sizes else 'warm' if hits == {'nix', 'zig'} and len(sizes) == 2 else 'miss-or-partial' if misses else 'unknown')
        lanes.append(row)
    complete = bool(lanes) and all(row['conclusion'] == 'success' and row['seconds'] is not None for row in lanes)
    ends = [j['completed_at'] for j in jobs if j.get('completed_at')]
    feedback = seconds(run['created_at'], max(ends)) if ends else None
    cost = sum(seconds(j['started_at'], j['completed_at']) for j in jobs if j.get('started_at') and j.get('completed_at'))
    cache_known = all(row['cache']['restored_bytes'] is not None for row in lanes)
    cache_bytes = sum(row['cache']['restored_bytes'] or 0 for row in lanes) if cache_known else None
    qualified = complete and run['conclusion'] == 'success' and cache_known
    return dict(version=1, run_id=run['id'], revision=run['head_sha'], url=run['html_url'],
                conclusion=run['conclusion'], status='measured' if qualified else 'inconclusive',
                feedback_seconds=feedback, aggregate_runner_seconds=cost,
                restored_cache_bytes=cache_bytes, lanes=lanes,
                budget_met=qualified and feedback < budgets['feedback_seconds'] and cost <= budgets['aggregate_runner_seconds']
                           and cache_bytes <= budgets['restored_cache_bytes'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True, type=int)
    parser.add_argument('--repo', default='rupurt/rey')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    def api(path):
        return json.loads(subprocess.check_output(['gh', 'api', f'repos/{args.repo}/{path}'], text=True))
    run = api(f'actions/runs/{args.run}')
    response = api(f'actions/runs/{args.run}/attempts/{run["run_attempt"]}/jobs?per_page=100')
    if response['total_count'] != len(response['jobs']):
        raise ValueError('Job pagination is incomplete')
    log = subprocess.check_output(['gh', 'run', 'view', str(args.run), '--repo', args.repo,
                                   '--attempt', str(run['run_attempt']), '--log'], text=True)
    budgets = json.loads((ROOT / 'tests/verification/ci-budgets.json').read_text())
    result = summarize(run, response['jobs'], log, budgets)
    destination = args.output or ROOT / f'.cache/ci/cost-{args.run}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if summary := os.getenv('GITHUB_STEP_SUMMARY'):
        with open(summary, 'a') as out:
            out.write(f"\nCI cost evidence: {result['status']}; budget met: {result['budget_met']}.\n")


if __name__ == '__main__':
    main()
