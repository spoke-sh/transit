"""Paired result-codec costs with exact workload and allocation gates."""
import argparse
import json
import math
import os
from pathlib import Path
import platform
import shutil
import statistics
import threading

from runner import capture
from runner.paths import ROOT

BUDGETS = Path(__file__).with_name('budgets.json')


def assess(samples, budgets):
    assert budgets['version'] == 1
    assert set(samples) == {'baseline', 'candidate'}
    assert all(len(runs) == budgets['paired_samples'] for runs in samples.values()), 'Incomplete paired samples'
    times, shapes = {}, {}
    for role, runs in samples.items():
        times[role] = {}
        shapes[role] = {}
        for reports in runs:
            assert [r['profile'] for r in reports] == ['database_wire_encoding', 'native_result_encoding']
            for report in reports:
                assert (report['rows_per_sample'], report['columns'], report['warmups'], report['repetitions'], report['optimize']) == (10000, 7, 1, 5, 'safe')
                native = report['profile'] == 'native_result_encoding'
                assert [s.get('batch_rows') if native else s.get('path') for s in report['samples']] == (
                    [1, 32] if native else ['postgres_text', 'postgres_binary', 'mysql_text', 'mysql_binary'])
                for sample in report['samples']:
                    key = str(sample['batch_rows']) if native else sample['path']
                    assert sample['framed_bytes'] > 0
                    if native:
                        assert sample['batches'] == (10000 + sample['batch_rows'] - 1) // sample['batch_rows']
                        assert 0 < sample['maximum_frame_bytes'] <= 4194304
                    shape = {field: sample[field] for field in (('batches', 'framed_bytes', 'maximum_frame_bytes') if native else ('framed_bytes',))}
                    assert shape == shapes[role].setdefault(key, shape), 'Workload changed between samples'
                    for phase in (('encode_ms', 'decode_ms') if native else ('milliseconds',)):
                        values = sample[phase]
                        assert len(values) == 5 and all(math.isfinite(value) and value > 0 for value in values), 'Invalid timing'
                        times[role].setdefault(key + '/' + phase, []).append(statistics.median(values))
                    if native and role == 'candidate':
                        for phase in ('encode', 'decode'):
                            counts = sample[phase + '_backing']
                            assert len(counts) == 5
                            assert all(0 <= c[field] <= budgets['native_backing_attempts_max'] for c in counts for field in ('alloc_attempts', 'growing_resize_attempts', 'remap_attempts')), 'Backing allocation attempt'
                        for phase in ('encoder', 'decoder'):
                            peaks = sample[phase + '_peak_bytes']
                            assert len(peaks) == 5 and all(0 < peak <= budgets['native_owner_reserved_bytes_max'] for peak in peaks), 'Resident bound'
    assert shapes['baseline'] == shapes['candidate'], 'Different framed workload'
    comparison = []
    for name, values in times['candidate'].items():
        baseline = statistics.median(times['baseline'][name])
        candidate = statistics.median(values)
        ratio = candidate / baseline
        comparison.append(dict(case=name, baseline_ms=baseline, candidate_ms=candidate, ratio=ratio,
                               passed=ratio <= budgets['median_time_ratio_max']))
    return dict(status='passed' if all(row['passed'] for row in comparison) else 'failed', comparisons=comparison)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', required=True, type=Path)
    parser.add_argument('--baseline-revision', required=True)
    parser.add_argument('--candidate', required=True, type=Path)
    parser.add_argument('--cpu', required=True, type=int)
    args = parser.parse_args()
    if args.cpu not in os.sched_getaffinity(0):
        parser.error('--cpu must name an available CPU')
    budgets = json.loads(BUDGETS.read_text())
    destination = capture.directory(ROOT / '.cache/allocations/result-codecs.json')
    evidence = capture.provenance(ROOT) | dict(status='inconclusive', samples={'baseline': [], 'candidate': []},
        runs=[], binaries={}, budgets=budgets, driver=capture.identity(Path(__file__)), budget_file=capture.identity(BUDGETS),
        baseline_revision=args.baseline_revision, machine=platform.platform(), cpu=args.cpu, initial_load=os.getloadavg(),
        scope='Isolated codec work and native backing counters; excludes service, I/O, TLS and OS allocation claims.')
    path = destination / 'evidence.json'
    capture.write_json(path, evidence)
    try:
        for role in ('baseline', 'candidate'):
            binary = destination / role
            shutil.copy2(getattr(args, role), binary)
            evidence['binaries'][role] = capture.identity(binary)
        # Each executable performs its own finite warmup. Alternating process
        # order reduces drift; both frozen programs inherit the same CPU affinity.
        for pair in range(budgets['paired_samples']):
            for role in (('baseline', 'candidate') if pair % 2 == 0 else ('candidate', 'baseline')):
                result = dict(role=role, pair=pair, completed=False)
                evidence['runs'].append(result)
                capture.write_json(path, evidence)
                previous = os.sched_getaffinity(0)
                cancelled = threading.Event()
                timer = threading.Timer(300, cancelled.set)
                timer.start()
                try:
                    os.sched_setaffinity(0, {args.cpu})
                    process = capture.run([str(destination / role)], cwd=ROOT, log=destination / f'{pair}-{role}.log',
                                          result=result, capture_stdout=True, cancelled=cancelled)
                finally:
                    os.sched_setaffinity(0, previous)
                    timer.cancel()
                    timer.join()
                assert process.returncode == 0, result
                evidence['samples'][role].append([json.loads(line) for line in process.stdout.splitlines()])
                capture.write_json(path, evidence)
        evidence.update(assess(evidence['samples'], budgets))
    except BaseException as failure:
        evidence['failure'] = str(failure)
        raise
    finally:
        evidence['final_load'] = os.getloadavg()
        capture.write_json(path, evidence)
        print(f'Codec comparison: {destination}', flush=True)
    print(json.dumps({key: evidence[key] for key in ('status', 'comparisons')}, indent=2))
    if evidence['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
