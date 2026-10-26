"""Assess precommitted experimental thresholds; semantic completion is separate."""
import argparse
import json
from pathlib import Path
import statistics


def assess(vector, files, budgets):
    for report in (vector, files):
        if report['status'] != 'passed' or report['completed'] is not True:
            raise ValueError('Incomplete measurement cannot satisfy a performance gate')
        if report['tracked_dirty']:
            raise ValueError('Qualification requires committed source')
    limits = budgets['limits']
    violations = []
    evidence = []

    def gate(name, actual, maximum):
        item = dict(gate=name, actual=actual, maximum=maximum)
        evidence.append(item)
        if actual > maximum:
            violations.append(item)

    for rows in (8, 4096):
        for phase in ('kernel', 'pipeline'):
            groups = {}
            for engine in ('scalar', 'batch'):
                samples = [s for s in vector['samples'] if not s['warmup'] and s['rows']==rows and s['phase']==phase and s['engine']==engine]
                if len(samples) != 9 or {s['repetition'] for s in samples} != set(range(1, 10)):
                    raise ValueError('Expected nine unique paired samples')
                if any(s['exit_code'] != 0 for s in samples):
                    raise ValueError('Failed vector sample')
                groups[engine] = [s['record'] for s in samples]
            control = statistics.median(r['elapsed_ns'] for r in groups['scalar'])
            candidate = statistics.median(r['elapsed_ns'] for r in groups['batch'])
            if rows == 4096:
                gate(f'{phase}/{rows}/elapsed', candidate, control*limits[f'large_{phase}_median_ratio'])
            elif phase == 'pipeline':
                gate('pipeline/tiny/elapsed', candidate, control*limits['tiny_pipeline_median_ratio'] + groups['batch'][0]['repetitions']*limits['tiny_pipeline_additive_ns_per_query'])
            if phase == 'pipeline':
                gate(f'pipeline/{rows}/allocations', max(r['allocations']/r['rows']/r['repetitions'] for r in groups['batch']), limits['allocations_per_source_row_max'])
                gate(f'pipeline/{rows}/peak_bytes', max(r['peak_live_bytes'] for r in groups['batch']), limits['batch_resident_bytes_max'])
    expected = {(shape, query, rows, budget) for shape in ('narrow', 'sparse') for query in ('filter', 'count', 'count-values') for rows in budgets['sweep']['rows'] for budget in budgets['sweep']['bytes']}
    seen = set()
    for case in files['summary']:
        key = case['shape'], case['query'], case['rows'], case['bytes']
        if key not in expected or key in seen:
            raise ValueError('Unexpected or duplicate file case')
        seen.add(key)
        if len(case['scalar']) != 3 or len(case['batch']) != 3:
            raise ValueError('Incomplete file case')
        for metric, ratio in [('elapsed_ns', 'file_pipeline_median_ratio'), ('first_batch_ns', 'file_first_result_median_ratio')]:
            control = statistics.median(r[metric] for r in case['scalar'])
            actual = statistics.median(r[metric] for r in case['batch'])
            gate('/'.join(map(str, key))+'/'+metric, actual, control*limits[ratio]+limits['file_additive_ns'])
    if seen != expected:
        raise ValueError('Missing file cases')
    return dict(status='failed' if violations else 'passed', scope='experimental int64 slice; excludes native control and production-default qualification', violations=violations, evidence=evidence)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for argument in ('vector', 'files', 'budgets', 'output'):
        parser.add_argument('--'+argument, type=Path, required=True)
    args = parser.parse_args()
    result = assess(*(json.loads(getattr(args, name).read_text()) for name in ('vector', 'files', 'budgets')))
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(result['status'], len(result['violations']), 'violations')
    if result['violations']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
