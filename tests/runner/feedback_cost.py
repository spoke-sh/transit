"""Summarize this job's task/phase evidence without double-counting nested time."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re

from capture import provenance, write_json
from ci_cost import inventory_identity

ROOT = Path(__file__).resolve().parents[2]
# Prefer the specific operation inside a schedule or installation. Uninstrumented
# time remains explicit; native build-graph time includes cache lookup and linking.
PRIORITY = {'schedule': 0, 'input-identity': 20, 'output-verification': 20,
            'setup': 30, 'readiness': 30, 'teardown': 40, 'consumer-install': 50,
            'packaging': 60, 'build-graph': 70, 'artifact-import': 70, 'consumer-build': 80}


def partition(rows):
    events = []
    for index, row in enumerate(rows):
        if 'seconds' not in row:
            continue
        start, duration = row['started_unix'], row['seconds']
        assert duration >= 0
        if duration == 0:
            continue
        events.extend(((start, 1, index), (start + duration, -1, index)))
    totals, active, previous = Counter(), set(), None
    for instant, change, index in sorted(events):
        if active and previous is not None:
            chosen = max(active, key=lambda i: (PRIORITY.get(rows[i]['kind'], 10),
                                                -rows[i]['seconds'], i))
            totals[rows[chosen]['kind']] += instant - previous
        if change == 1:
            active.add(index)
        else:
            active.discard(index)
        previous = instant
    return {kind: round(seconds, 3) for kind, seconds in sorted(totals.items())}


def collect(root, lane):
    origin = provenance(root)
    metadata_path = root / f'.cache/ci/{lane}.meta.json'
    metadata = json.loads(metadata_path.read_text()) if metadata_path.exists() else {}
    tasks_path = root / f'.cache/ci/{lane}.json'
    tasks = json.loads(tasks_path.read_text()) if tasks_path.exists() else []
    phases, incomplete = [], []
    for path in sorted((root / '.cache/checks/phases').glob('*/*.json')):
        if path.name == 'source.json':
            continue
        source = json.loads((path.parent / 'source.json').read_text())
        row = json.loads(path.read_text())
        if source['revision'] != origin['revision'] or row['started_unix'] < metadata.get('started_unix', 0):
            continue
        if not all(re.fullmatch(r'[a-z0-9][a-z0-9_.-]*', row[key]) for key in ('kind', 'owner')):
            raise ValueError('Invalid phase label')
        phases.append(row)
        if not row['completed']:
            incomplete.append(dict(kind=row['kind'], owner=row['owner'], outcome=row['outcome']))
    durations = partition(phases)
    native = []
    for path in (root / '.cache/native-artifacts').glob('*/record.json'):
        record = json.loads(path.read_text())
        if record['revision'] == origin['revision']:
            native.append(record)
    task_rows = [{key: row.get(key) for key in ('task', 'seconds', 'exit_code', 'completed', 'started_unix', 'finished_unix')}
                 for row in tasks]
    finished = [row for row in task_rows if row['finished_unix'] is not None]
    first = min(finished, key=lambda row: row['finished_unix']) if finished else None
    failures = [row for row in finished if row['exit_code'] != 0]
    first_failure = min(failures, key=lambda row: row['finished_unix']) if failures else None
    native_job = lane.startswith('native-')
    completed = bool(native and not incomplete and any(row['kind'] == 'artifact-export' and row['completed'] for row in phases)) if native_job else metadata.get('completed', False)
    return dict(version=1, lane=lane, **origin, run_id=os.getenv('GITHUB_RUN_ID'),
                run_attempt=os.getenv('GITHUB_RUN_ATTEMPT'), inventory=inventory_identity(),
                completed=completed, phase_evidence_complete=bool(phases) and not incomplete,
                task_seconds=metadata.get('seconds'), tasks=task_rows,
                first_completed_task=first, first_failed_task=first_failure,
                phase_seconds=durations, instrumented_seconds=round(sum(durations.values()), 3),
                unattributed_task_seconds=round(max(0, metadata['seconds'] - sum(durations.values())), 3) if 'seconds' in metadata else None,
                incomplete_phases=incomplete, native_preparations=dict(Counter(r['preparation'] for r in native)),
                native_artifact_bytes=sum(sum(f['bytes'] for f in r['files'].values()) for r in native))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane', required=True)
    args = parser.parse_args()
    assert re.fullmatch(r'[a-zA-Z0-9-]+', args.lane)
    result = collect(ROOT, args.lane)
    destination = ROOT / f'.cache/ci/feedback-{args.lane}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    write_json(destination, result)
    if summary := os.getenv('GITHUB_STEP_SUMMARY'):
        with open(summary, 'a') as output:
            output.write('\n### Build and SDK feedback\n\n| Phase (exclusive wall seconds) | Seconds |\n| --- | ---: |\n')
            for kind, seconds in result['phase_seconds'].items():
                output.write(f'| {kind} | {seconds:.3f} |\n')
            output.write(f"\nNative preparations: `{json.dumps(result['native_preparations'])}`. "
                         f"Task completion: `{result['completed']}`; phase evidence complete: `{result['phase_evidence_complete']}`.\n")


if __name__ == '__main__':
    main()
