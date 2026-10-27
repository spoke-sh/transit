"""Assess the frozen wider-pipeline budgets for the selected portable default."""
import argparse
import json
from pathlib import Path
import statistics
from performance.query.pipelines import CASES, expected


def assess(report, controls, budgets):
    if report['status'] != 'passed' or report['completed'] is not True or report['tracked_dirty']:
        raise ValueError('Pipeline qualification requires complete committed-source measurements')
    if controls['status'] != 'passed' or controls['completed'] is not True or controls['dirty']:
        raise ValueError('Control qualification requires complete committed-source measurements')
    limits = budgets['limits']
    evidence, violations, comparisons = [], [], []

    def gate(name, actual, maximum):
        item = dict(gate=name, actual=actual, maximum=maximum)
        evidence.append(item)
        if actual > maximum:
            violations.append(item)

    engines = ['scalar', 'batch', 'simd', 'parallel1', 'parallel2', 'parallel4']
    if len(report['samples']) != len(CASES) * 2 * len(engines) * 10:
        raise ValueError('Expected the complete paired type/size/dispatch matrix')
    for case in CASES:
        for rows, repetitions in [(8, 100), (4096, 20)]:
            groups = {}
            count, checksum = expected(case, rows)
            for engine in engines:
                samples = [s for s in report['samples'] if (s['case'], s['rows'], s['engine']) == (case, rows, engine)]
                if len(samples) != 10 or {s['repetition'] for s in samples} != set(range(10)):
                    raise ValueError('Missing or duplicate paired sample')
                for s in samples:
                    r = s['record']
                    if (s['exit_code'] != 0 or s['warmup'] != (s['repetition'] == 0)
                            or r['count'] != count * repetitions or r['checksum'] != checksum * repetitions
                            or r['end_live_bytes'] != 0 or r['build_mode'] != 'safe'
                            or r['repetitions'] != repetitions or r['elapsed_ns'] <= 0):
                        raise ValueError('Invalid independent result or measurement')
                    implementation = 'reference' if engine == 'scalar' else 'avx2' if engine == 'simd' else 'portable'
                    workers = int(engine[-1]) if engine.startswith('parallel') else 0
                    if r['implementation'] != implementation or r['workers'] != workers or workers > limits['parallel_workers_max']:
                        raise ValueError('Unexpected dispatch or worker configuration')
                groups[engine] = statistics.median(s['record']['elapsed_ns'] for s in samples if not s['warmup'])
            scalar, candidate = groups['scalar'], groups['batch']
            comparisons.append(dict(case=case, rows=rows, ratios={k: v / scalar for k, v in groups.items()}))
            if rows == 4096:
                ratio = limits['large_generic_pipeline_ratio'] if case in ('utf8', 'nested') else limits['large_hot_pipeline_ratio']
                maximum = scalar * ratio
            else:
                # The frozen tiny budget permits either the ratio or the
                # additive allowance, not their sum.
                maximum = max(scalar * limits['tiny_pipeline_ratio'], scalar + repetitions * limits['tiny_additive_ns_per_query'])
            gate(f'{case}/{rows}/portable-pipeline', candidate, maximum)
    if len(controls['summary']) != 8 or len({x['sql'] for x in controls['summary']}) != 8:
        raise ValueError('Expected eight distinct existing controls')
    for control in controls['summary']:
        if control['control']['signature'] != control['candidate']['signature']:
            raise ValueError('Changed native result/export signature')
        for engine in ('control', 'candidate'):
            values = control[engine]['raw_ns']
            if len(values) != 9 or any(v <= 0 for v in values):
                raise ValueError('Expected nine positive native control measurements')
        ratio = statistics.median(control['candidate']['raw_ns']) / statistics.median(control['control']['raw_ns'])
        gate(control['sql'], ratio, limits['existing_control_ratio'])
    return dict(status='failed' if violations else 'passed', violations=violations, evidence=evidence,
                comparisons=comparisons, scope='Selected portable single-worker defaults; optional dispatch comparisons retained. Physical/queue bounds require the separate executable proofs.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('pipelines', 'controls', 'budgets', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    # A rejected input must replace any old successful assessment at this path.
    result = dict(status='failed', error='Assessment did not complete')
    args.output.write_text(json.dumps(result) + '\n')
    try:
        result = assess(*(json.loads(getattr(args, name).read_text()) for name in ('pipelines', 'controls', 'budgets')))
    except (ValueError, KeyError, OSError) as error:
        result['error'] = str(error)
        raise
    finally:
        args.output.write_text(json.dumps(result, indent=2) + '\n')
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(result['status'], len(result['evidence']), 'checks,', len(result['violations']), 'violations')
    if result['violations']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
