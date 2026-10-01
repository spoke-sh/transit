"""Freeze measured budgets before optimization; check complete matching evidence."""
import argparse
import gzip
import itertools
import json
import math
from pathlib import Path
import statistics
import run

MATRICES = ('baseline', 'projection-baseline', 'batch1-baseline', 'filter-baseline', 'count-baseline', 'sum-baseline')
DRIVERS = ('main.zig', 'Allocator.zig', 'run.py', 'duckdb_driver.py', 'allocations.c')


def read(path):
    data = Path(path).read_bytes()
    return json.loads(gzip.decompress(data) if str(path).endswith('.gz') else data)


def require(condition, message):
    if not condition: raise ValueError(message)


def complete(report):
    require(report.get('definition') == run.DEFINITION and report.get('status') == 'passed' and report.get('completed') is True, 'Incomplete or foreign report')
    require(report.get('dirty') is False, 'Measurement requires a clean committed tree')


def identity(report):
    machine = report['machine']
    cpu = [line for line in machine['cpuinfo'].splitlines() if line.split(':')[0].strip() in ('vendor_id', 'cpu family', 'model', 'model name', 'stepping')]
    return dict(parameters=report['parameters'], fixtures=report['fixtures'], toolchain=report['toolchain'],
        selected_cpu=machine['selected_cpu'], platform=machine['platform'], cpu=cpu, filesystem=report['filesystem'],
        drivers={name: report['harness']['tests/fuze_benchmarks/' + name] for name in DRIVERS},
        comparator={k: report['comparator'][k] for k in ('duckdb', 'build', 'pyarrow', 'module_sha256')},
        allocation_probe_sha256=report['allocation_probe']['sha256'])


def groups(report):
    complete(report)
    parameters = report['parameters']
    require(parameters['repetitions'] >= 3, 'At least three raw repetitions required')
    expected = set(itertools.product(parameters['shapes'], parameters['modes'], parameters['caches'], parameters['engines'], range(parameters['repetitions'])))
    seen = set(); grouped = {}; resident = {}
    for sample in report['samples']:
        key = tuple(sample[k] for k in ('shape', 'mode', 'cache', 'engine', 'repetition'))
        require(key not in seen, 'Duplicate measurement')
        seen.add(key)
        require(sample['exit_code'] == 0 and not sample.get('timeout') and not sample.get('validation_error'), 'Invalid sample')
        run.checked(sample['records'], sample['config'], sample['engine'])
        require(sample['config']['expected_rows'] == parameters['rows'], 'Wrong workload size')
        require(all(p['resident'] == 0 for p in sample['input_pages']) if sample['cache'] == 'cold_input' else True, 'Unverified cold input')
        if sample['engine'] != 'transit': continue
        case = '/'.join(key[:3])
        resident.setdefault(case, []).append(sample['image_peak_rss_kib'])
        for phase in sample['records']:
            if 'phase' in phase: grouped.setdefault(case + '/' + phase['phase'], []).append(phase)
    require(seen == expected, 'Missing or unexpected matrix samples')
    return grouped, resident


def numeric_limits(report):
    grouped, resident = groups(report)
    phases = {}
    for key, records in grouped.items():
        median = lambda name: statistics.median(r[name] for r in records)
        phases[key] = dict(elapsed_ns=math.ceil(median('elapsed_ns') * 1.5 + 250000),
            cpu_ns=math.ceil(median('cpu_ns') * 1.3 + 250000),
            first_batch_ns=math.ceil(median('first_batch_ns') * 1.5 + 250000) if records[0]['first_batch_ns'] is not None else None,
            allocations=max(r['allocations'] for r in records), allocated_bytes=max(r['allocated_bytes'] for r in records),
            source_bytes_read=max(r['source_bytes_read'] for r in records), source_read_calls=max(r['source_read_calls'] for r in records),
            peak_live_bytes=max(r['peak_live_bytes'] for r in records) + 1024)
    return dict(identity=identity(report), phases=phases,
        image_peak_rss_kib={case: math.ceil(max(values)*1.25 + 2048) for case, values in resident.items()})


def check_matrix(report, budget):
    grouped, resident = groups(report)
    require(identity(report) == budget['identity'], 'Different workload, fixtures, machine, compiler or measurement drivers')
    require(set(grouped) == set(budget['phases']) and set(resident) == set(budget['image_peak_rss_kib']), 'Budget coverage mismatch')
    violations = []
    for key, records in grouped.items():
        for metric, limit in budget['phases'][key].items():
            if limit is None: continue
            values = [r[metric] for r in records]
            actual = statistics.median(values) if metric in ('elapsed_ns', 'cpu_ns', 'first_batch_ns') else max(values)
            if actual > limit: violations.append(dict(case=key, metric=metric, actual=actual, limit=limit))
    for case, values in resident.items():
        if max(values) > budget['image_peak_rss_kib'][case]: violations.append(dict(case=case, metric='image_peak_rss_kib', actual=max(values), limit=budget['image_peak_rss_kib'][case]))
    return violations


def six_ratios(report):
    complete(report)
    samples = report['samples']
    rows = {}
    for engine in ('control', 'candidate'):
        selected = [s for s in samples if s['engine'] == engine and not s['warmup']]
        require(len(selected) >= 9 and len({s['repetition'] for s in selected}) == len(selected), 'Nine distinct specialized-path repetitions required')
        require(all(s['exit_code'] == 0 and len(s['records']) == 8 for s in selected), 'Incomplete specialized-path samples')
        rows[engine] = selected
    results = {}
    for i in range(8):
        records = [s['records'][i] for engine in rows.values() for s in engine]
        signatures = [{k:v for k,v in r.items() if k != 'elapsed_ns'} for r in records]
        require(all(s == signatures[0] and s['build_mode'] == 'safe' for s in signatures), 'Different specialized-path results')
        results[records[0]['sql']] = statistics.median(s['records'][i]['elapsed_ns'] for s in rows['candidate']) / statistics.median(s['records'][i]['elapsed_ns'] for s in rows['control'])
    require(len(results) == 8, 'Missing specialized-path cases')
    return results


def check_large(report):
    complete(report)
    require(report['memory_max'] == 256*1024**2 and report['memory_swap_max'] == 0, 'Different RAM/cache budget')
    require({s['mode'] for s in report['samples']} == {'explicit', 'sampled', 'full', 'raw'} and len(report['samples']) == 4, 'Incomplete large-input modes')
    for sample in report['samples']:
        require(sample.get('verified') is True and sample['exit_code'] == 0, 'Failed cgroup sample')
        require(all(p['resident'] == 0 for p in sample['input_pages']), 'Large input was not evicted')
        run.checked(sample['records'], sample['config'], 'transit')
        group = sample['records'][-1]['cgroup']; peak = int(group['memory_peak'])
        require(int(group['memory_max']) == report['memory_max'] and group['memory_swap_max'] == '0', 'Unenforced cgroup limit')
        require(peak <= report['memory_max']*1.02 and report['fixture']['bytes'] > peak*2, 'Input does not exceed measured RAM/cache')
        events = dict(line.split() for line in group['memory_events'].splitlines())
        require(events['oom'] == events['oom_kill'] == '0', 'Cgroup OOM')


def artifact(directory, name):
    path = directory / (name + '.json.gz')
    return path if path.exists() else directory / (name + '.json')


def freeze(directory):
    matrices = {name: numeric_limits(read(artifact(directory, name))) for name in MATRICES}
    six = read(artifact(directory, 'six-baseline')); ratios = six_ratios(six)
    require(all(r <= 1.15 for r in ratios.values()), 'Original six-type path already exceeds the proposed 15% budget')
    check_large(read(artifact(directory, 'large-baseline')))
    return dict(definition='transit.fuze.regression-budgets.v1', matrices=matrices,
        source_reports={name: run.digest(artifact(directory, name)) for name in (*MATRICES, 'six-baseline', 'large-baseline')},
        six=dict(max_ratio=1.15, observed_ratios=ratios, control=six['binaries']['control']['sha256'], driver=six['driver_sha256'], lock=six['lock_sha256'], cpu=six['cpu']))


def evaluate(directory, budget):
    require(budget['definition'] == 'transit.fuze.regression-budgets.v1', 'Foreign budget definition')
    violations = []
    for name in MATRICES:
        violations.extend(dict(report=name, **v) for v in check_matrix(read(artifact(directory, name)), budget['matrices'][name]))
    six = read(artifact(directory, 'six-baseline')); ratios = six_ratios(six); limit = budget['six']
    require((six['binaries']['control']['sha256'], six['driver_sha256'], six['lock_sha256'], six['cpu']) == (limit['control'], limit['driver'], limit['lock'], limit['cpu']), 'Different six-type control')
    for sql, ratio in ratios.items():
        if ratio > limit['max_ratio']: violations.append(dict(report='six', case=sql, metric='candidate_control_ratio', actual=ratio, limit=limit['max_ratio']))
    check_large(read(artifact(directory, 'large-baseline')))
    return violations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('freeze', 'check'))
    parser.add_argument('directory', type=Path)
    parser.add_argument('budgets', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.action == 'freeze':
        require(not args.budgets.exists(), 'Never overwrite reviewed budgets; use a new explicit baseline')
        args.budgets.write_text(json.dumps(freeze(args.directory), indent=2) + '\n')
        return
    require(args.output is not None, 'Check requires an explicit output report')
    result = dict(completed=False, status='running', violations=[])
    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + '\n')
    save()
    try:
        result['violations'] = evaluate(args.directory, read(args.budgets))
        result.update(completed=True, status='failed' if result['violations'] else 'passed',
            budgets_sha256=run.digest(args.budgets), reports={name: run.digest(artifact(args.directory, name)) for name in (*MATRICES, 'six-baseline', 'large-baseline')})
        require(not result['violations'], 'Numeric regression budget exceeded')
    except BaseException as error:
        result.update(status='failed', error=str(error)); raise
    finally: save()


if __name__ == '__main__': main()
