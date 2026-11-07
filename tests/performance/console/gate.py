#!/usr/bin/env python3
"""Early-detection console latency and resource regression gate."""
import argparse
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import sys

from performance.console.console_latency import digest
from performance.mutations.mutation_latency import distribution
from runner.paths import ROOT

DEFINITION = 'transit.console.latency-budgets.v1'
BUDGETS = Path(__file__).with_name('budgets.json')
DEFAULT_WORKLOAD = {
    'startup_restarts': 2,
    'startup_default': True,
    'repeat': 1,
    'cycles': 5,
    'warm_reads': 2,
    'worker_interval_ms': 10,
    'cpus': 4,
}
STATEMENT_CASES = (
    'select_cold',
    'select_empty',
    'select_empty_warm',
    'insert',
    'select_after_write',
    'select_one_warm',
    'select_json_after_insert',
    'update',
    'select_after_update',
    'update_noop',
    'update_empty',
    'select_json_after_update',
    'delete',
    'select_after_delete',
    'delete_empty',
    'select_json_after_delete',
    'document_select_cold',
    'document_select_empty',
    'document_select_empty_warm',
    'document_insert',
    'document_select_after_write',
    'document_select_warm',
    'document_update',
    'document_select_after_update',
    'document_select_json',
    'document_delete',
    'document_select_after_delete',
    'kv_get_empty',
    'kv_put_if_absent',
    'kv_get_after_put',
    'kv_put_if_present',
    'kv_get_after_update',
    'kv_get_json',
    'kv_delete',
    'kv_delete_empty',
    'kv_get_after_delete',
    'stream_consume_empty',
    'stream_produce',
    'stream_consume_after_produce',
    'stream_consume_warm',
    'stream_consume_json',
    'queue_claim_empty',
    'queue_enqueue',
    'queue_claim',
    'queue_extend_lease',
    'queue_ack',
    'queue_enqueue_nack',
    'queue_claim_nack',
    'queue_nack',
    'queue_claim_after_ack',
)
STATEMENT_CLASSES = {
    'warm_read': (
        'select_empty',
        'select_empty_warm',
        'select_one_warm',
        'select_json_after_insert',
        'select_json_after_update',
        'select_json_after_delete',
    ),
    'refresh_read': (
        'select_cold',
        'select_after_write',
        'select_after_update',
        'select_after_delete',
    ),
    'dml_write': (
        'insert',
        'update',
        'update_noop',
        'update_empty',
        'delete',
        'delete_empty',
    ),
    'document_warm_read': (
        'document_select_empty',
        'document_select_empty_warm',
        'document_select_warm',
        'document_select_json',
    ),
    'document_refresh_read': (
        'document_select_cold',
        'document_select_after_write',
        'document_select_after_update',
        'document_select_after_delete',
    ),
    'document_write': (
        'document_insert',
        'document_update',
        'document_delete',
    ),
    'kv_read': (
        'kv_get_empty',
        'kv_get_after_put',
        'kv_get_after_update',
        'kv_get_json',
        'kv_get_after_delete',
    ),
    'kv_write': (
        'kv_put_if_absent',
        'kv_put_if_present',
        'kv_delete',
        'kv_delete_empty',
    ),
    'stream_read': (
        'stream_consume_empty',
        'stream_consume_after_produce',
        'stream_consume_warm',
        'stream_consume_json',
    ),
    'stream_write': (
        'stream_produce',
    ),
    'queue_read': (
        'queue_claim_empty',
        'queue_claim',
        'queue_claim_nack',
        'queue_claim_after_ack',
    ),
    'queue_write': (
        'queue_enqueue',
        'queue_extend_lease',
        'queue_ack',
        'queue_enqueue_nack',
        'queue_nack',
    ),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_jsonl(path):
    lines = [line for line in Path(path).read_text().splitlines() if line.strip()]
    require(lines, f'Empty JSONL transcript: {path}')
    return [json.loads(line) for line in lines]


def limit_ms(baseline_ms, budgets):
    ratio = 1.0 + budgets['max_regression_pct'] / 100.0
    noise = (budgets['fast_read_noise_floor_ms']
             if baseline_ms < budgets['fast_read_threshold_ms'] else 0.0)
    return round(baseline_ms * ratio + noise, 3)


def expected_statement_samples(workload):
    cycles = workload['cycles']
    warm_reads = workload['warm_reads']
    expected = {case: cycles for case in STATEMENT_CASES}
    expected['select_cold'] = 1
    expected['select_empty'] = cycles - 1
    expected['select_empty_warm'] = cycles * warm_reads
    expected['select_one_warm'] = cycles * warm_reads
    expected['document_select_cold'] = 1
    expected['document_select_empty'] = cycles - 1
    expected['document_select_empty_warm'] = cycles * warm_reads
    expected['document_select_warm'] = cycles * warm_reads
    expected['stream_consume_warm'] = cycles * warm_reads
    return expected


def extract_metrics(startup_records, statement_records, workload=None):
    workload = DEFAULT_WORKLOAD if workload is None else workload
    require(startup_records and isinstance(startup_records[0], dict), 'Missing startup provenance header')
    startup_header = startup_records[0]
    require(startup_header.get('startup_restarts') == workload['startup_restarts'], 'Startup restart count mismatch')
    require(startup_header.get('startup_default') is workload['startup_default'], 'Startup default profile mismatch')
    require(not startup_header.get('startup_debug') and not startup_header.get('instrumented'),
            'Diagnostic startup run cannot qualify latency budgets')

    startups = [row for row in startup_records[1:] if row.get('phase') == 'startup']
    require(len(startups) == workload['startup_restarts'] + 1, 'Incomplete startup samples')
    for index, sample in enumerate(startups):
        require(sample.get('index') == index, f'Out-of-order startup sample at {index}')
        require(sample.get('profile') == ('fresh' if index == 0 else 'restart'), 'Unexpected startup profile')
        require(sample.get('ui') is True and sample.get('outcome') == 'ok', 'Failed or headless startup sample')
        require(sample.get('verified_rows') == (0 if index == 0 else 1), 'Unexpected verified startup row count')
        losses = sample.get('losses', {})
        require(losses == {'dropped': 0, 'suppressed': 0, 'sink_errors': 0}, 'Startup telemetry loss detected')
        for field in ('ready_ns', 'first_verified_result_ns', 'verification_ns'):
            value = sample.get(field)
            require(isinstance(value, int) and value > 0, f'Invalid startup {field}')

    fresh = startups[0]
    restarts = startups[1:]
    restart_ready = statistics.median(row['ready_ns'] / 1e6 for row in restarts)
    restart_verified = statistics.median(row['first_verified_result_ns'] / 1e6 for row in restarts)

    require(statement_records and isinstance(statement_records[0], dict), 'Missing statement provenance header')
    statement_header = statement_records[0]
    require(statement_header.get('repeat') == workload['repeat'], 'Statement repeat count mismatch')
    require(statement_header.get('cycles') == workload['cycles'], 'Statement cycle count mismatch')
    require(statement_header.get('warm_reads') == workload['warm_reads'], 'Statement warm-read count mismatch')
    require(statement_header.get('resource_snapshots') is True, 'Statement resource snapshots required')
    require(not statement_header.get('instrumented') and not statement_header.get('local_trace')
            and not statement_header.get('historical_result_profile'),
            'Instrumented or historical statement run cannot qualify latency budgets')
    require(statement_header.get('overrides', {}).get('worker_interval_ms') == workload['worker_interval_ms'],
            'Statement worker_interval_ms override mismatch')

    require(not any(row.get('phase') == 'statement_failure' for row in statement_records[1:]),
            'Statement failure record present')
    phases = [row.get('phase') for row in statement_records[1:]]
    require('idle' in phases and 'idle_after_statements' in phases, 'Missing idle observation phases')
    summaries = [row for row in statement_records[1:] if row.get('phase') == 'statement_summary']
    require(len(summaries) == 1, 'Missing or duplicate statement_summary phase')
    distributions = summaries[0].get('distributions', {})
    expected_counts = expected_statement_samples(workload)
    require(set(distributions) == set(STATEMENT_CASES), 'Statement case coverage mismatch')

    statement_metrics = {}
    for case in STATEMENT_CASES:
        dist = distributions[case]
        require(dist.get('samples') == expected_counts[case],
                f'Unexpected sample count for {case}: {dist.get("samples")} != {expected_counts[case]}')
        metric = dist['min_ms'] if case in ('select_cold', 'document_select_cold') else dist['p50_ms']
        require(isinstance(metric, (int, float)) and math.isfinite(metric) and metric > 0,
                f'Invalid latency metric for {case}')
        statement_metrics[case] = round(float(metric), 3)

    statements = [row for row in statement_records[1:] if row.get('phase') == 'statement']
    resources = [row for row in statement_records[1:] if row.get('phase') == 'client_resources']
    total_expected = sum(expected_counts.values())
    require(len(statements) == total_expected and len(resources) == total_expected,
            'Incomplete statement or client_resources records')

    class_metrics = {}
    for class_name, cases in STATEMENT_CLASSES.items():
        values = [row['timer_ms'] * 1_000_000 for row in statements if row.get('case') in cases]
        require(values and all(isinstance(v, int) and v > 0 for v in values),
                f'Invalid statement timings for class {class_name}')
        class_metrics[class_name] = round(float(distribution(values)['p50_ms']), 3)

    process_counts = {row.get('process_count') for row in resources}
    require(len(process_counts) == 1 and next(iter(process_counts)) == 7,
            f'Expected constant 7 owned processes across statement resources, got {sorted(process_counts)}')
    by_cycle = {}
    for row in resources:
        pss = row.get('pss_bytes')
        threads = row.get('threads')
        require(isinstance(pss, int) and pss > 0 and isinstance(threads, int) and threads > 0,
                'Invalid resource snapshot counters')
        by_cycle.setdefault(row.get('cycle'), []).append(pss)
    require(set(by_cycle) == set(range(workload['cycles'])), 'Missing cycle resource snapshots')
    cycle1_pss = by_cycle[1][-1]
    last_pss = by_cycle[workload['cycles'] - 1][-1]
    growth_ratio = round(last_pss / cycle1_pss, 4)

    return {
        'startup': {
            'fresh_ready_ms': round(fresh['ready_ns'] / 1e6, 3),
            'fresh_first_verified_result_ms': round(fresh['first_verified_result_ns'] / 1e6, 3),
            'restart_ready_p50_ms': round(float(restart_ready), 3),
            'restart_first_verified_result_p50_ms': round(float(restart_verified), 3),
        },
        'statement_classes': class_metrics,
        'statements': statement_metrics,
        'resources': {
            'process_count': 7,
            'threads_max': max(row['threads'] for row in resources),
            'pss_bytes_max': max(row['pss_bytes'] for row in resources),
            'cycle_pss_growth_ratio': growth_ratio,
        },
    }


def freeze_budgets(runs, *, max_regression_pct=20.0, fast_read_threshold_ms=50.0,
                   fast_read_noise_floor_ms=15.0, cycle_pss_growth_ratio_max=1.15,
                   workload=None):
    require(runs, 'At least one complete calibration run is required to freeze budgets')
    workload = dict(DEFAULT_WORKLOAD if workload is None else workload)
    extracted = [extract_metrics(startup, statements, workload) for startup, statements in runs]
    revisions = {startup[0].get('source_revision') for startup, _ in runs} | {
        statements[0].get('source_revision') for _, statements in runs
    }
    require(len(revisions) == 1 and next(iter(revisions)), 'Calibration runs must share one source_revision')
    # Periodic 1-second supervisor/maintenance ticks can overlap any individual
    # 5-sample refresh_read or dml_write case depending on cycle phase. Pool the
    # per-case envelope within refresh_read and dml_write while keeping exact
    # per-case warm_read baselines and pooled class medians.
    class_envelope = {
        class_name: max(item['statements'][case] for item in extracted for case in cases)
        for class_name, cases in STATEMENT_CLASSES.items()
    }
    statement_baselines = {}
    for class_name, cases in STATEMENT_CLASSES.items():
        for case in cases:
            observed_max = max(item['statements'][case] for item in extracted)
            statement_baselines[case] = (
                observed_max if class_name in ('warm_read', 'document_warm_read') else max(observed_max, class_envelope[class_name])
            )
    return {
        'version': 1,
        'definition': DEFINITION,
        'calibrated_revision': next(iter(revisions)),
        'calibration_runs': len(extracted),
        'max_regression_pct': max_regression_pct,
        'fast_read_threshold_ms': fast_read_threshold_ms,
        'fast_read_noise_floor_ms': fast_read_noise_floor_ms,
        'workload': workload,
        'startup': {
            key: max(item['startup'][key] for item in extracted)
            for key in ('fresh_ready_ms', 'fresh_first_verified_result_ms',
                        'restart_ready_p50_ms', 'restart_first_verified_result_p50_ms')
        },
        'statement_classes': {
            class_name: max(item['statement_classes'][class_name] for item in extracted)
            for class_name in STATEMENT_CLASSES
        },
        'statements': {case: statement_baselines[case] for case in STATEMENT_CASES},
        'resources': {
            'process_count': 7,
            'threads_max': max(item['resources']['threads_max'] for item in extracted),
            'pss_bytes_max': max(item['resources']['pss_bytes_max'] for item in extracted),
            'cycle_pss_growth_ratio': max(item['resources']['cycle_pss_growth_ratio'] for item in extracted),
            'cycle_pss_growth_ratio_max': cycle_pss_growth_ratio_max,
        },
    }


def assess(startup_records, statement_records, budgets):
    require(budgets.get('version') == 1 and budgets.get('definition') == DEFINITION,
            'Unsupported or foreign console latency budget definition')
    metrics = extract_metrics(startup_records, statement_records, budgets['workload'])
    comparisons = []
    violations = []

    for key, baseline in budgets['startup'].items():
        observed = metrics['startup'][key]
        limit = limit_ms(baseline, budgets)
        passed = observed <= limit
        row = dict(category='startup', metric=key, baseline_ms=baseline,
                   observed_ms=observed, limit_ms=limit, passed=passed)
        comparisons.append(row)
        if not passed:
            violations.append(row)

    for class_name in STATEMENT_CLASSES:
        baseline = budgets['statement_classes'][class_name]
        observed = metrics['statement_classes'][class_name]
        limit = limit_ms(baseline, budgets)
        passed = observed <= limit
        row = dict(category='statement_classes', metric=class_name, baseline_ms=baseline,
                   observed_ms=observed, limit_ms=limit, passed=passed)
        comparisons.append(row)
        if not passed:
            violations.append(row)

    for case in STATEMENT_CASES:
        baseline = budgets['statements'][case]
        observed = metrics['statements'][case]
        limit = limit_ms(baseline, budgets)
        passed = observed <= limit
        row = dict(category='statements', metric=case, baseline_ms=baseline,
                   observed_ms=observed, limit_ms=limit, passed=passed)
        comparisons.append(row)
        if not passed:
            violations.append(row)

    ratio = 1.0 + budgets['max_regression_pct'] / 100.0
    resource_checks = (
        ('process_count', metrics['resources']['process_count'],
         budgets['resources']['process_count'], budgets['resources']['process_count']),
        ('threads_max', metrics['resources']['threads_max'],
         budgets['resources']['threads_max'], math.floor(budgets['resources']['threads_max'] * ratio)),
        ('pss_bytes_max', metrics['resources']['pss_bytes_max'],
         budgets['resources']['pss_bytes_max'], math.floor(budgets['resources']['pss_bytes_max'] * ratio)),
        ('cycle_pss_growth_ratio', metrics['resources']['cycle_pss_growth_ratio'],
         budgets['resources']['cycle_pss_growth_ratio'], budgets['resources']['cycle_pss_growth_ratio_max']),
    )
    for name, observed, baseline, limit in resource_checks:
        passed = (observed == limit) if name == 'process_count' else (observed <= limit)
        row = dict(category='resources', metric=name, baseline=baseline,
                   observed=observed, limit=limit, passed=passed)
        comparisons.append(row)
        if not passed:
            violations.append(row)

    return {
        'definition': DEFINITION,
        'status': 'passed' if not violations else 'failed',
        'metrics': metrics,
        'comparisons': comparisons,
        'violations': violations,
    }


def run_workload(cli, node, host, output_dir, workload):
    output_dir.mkdir(parents=True, exist_ok=True)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    driver = ROOT / 'tests/performance/console/console_latency.py'
    env = os.environ.copy()
    existing_pythonpath = env.get('PYTHONPATH')
    tests_dir = str(ROOT / 'tests')
    env['PYTHONPATH'] = tests_dir if not existing_pythonpath else f'{tests_dir}{os.pathsep}{existing_pythonpath}'

    available_cpus = sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else []
    selected_cpus = set(available_cpus[:workload['cpus']]) if available_cpus else None

    def invoke(output_path, extra_args):
        command = [
            sys.executable, '-B', str(driver),
            str(cli), str(node), str(host),
            '--binary-revision', revision,
            *extra_args,
        ]
        previous = os.sched_getaffinity(0) if selected_cpus else None
        try:
            if selected_cpus:
                os.sched_setaffinity(0, selected_cpus)
            with output_path.open('w') as handle:
                subprocess.run(command, cwd=ROOT, env=env, stdout=handle, check=True)
        finally:
            if previous is not None:
                os.sched_setaffinity(0, previous)

    startup_path = output_dir / 'startup.jsonl'
    statements_path = output_dir / 'statements.jsonl'
    invoke(startup_path, [
        '--startup-restarts', str(workload['startup_restarts']),
        *(['--startup-default'] if workload['startup_default'] else []),
    ])
    invoke(statements_path, [
        '--statements',
        '--repeat', str(workload['repeat']),
        '--cycles', str(workload['cycles']),
        '--warm-reads', str(workload['warm_reads']),
        '--resources',
        '--worker-interval-ms', str(workload['worker_interval_ms']),
    ])
    return startup_path, statements_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', type=Path, help='built ReleaseSafe transit binary')
    parser.add_argument('--node', type=Path, help='built ReleaseSafe transit-node binary')
    parser.add_argument('--host', type=Path, help='built ReleaseSafe transit-query-host binary')
    parser.add_argument('--budgets', type=Path, default=BUDGETS, help='checked-in budgets JSON file')
    parser.add_argument('--output', type=Path, default=ROOT / '.cache/transit-latency/gate',
                        help='directory for raw JSONL transcripts and gate report')
    parser.add_argument('--from-dir', type=Path, action='append', default=[],
                        help='existing directory containing startup.jsonl and statements.jsonl')
    parser.add_argument('--freeze', action='store_true',
                        help='recalibrate and write budgets.json from measured transcripts')
    parser.add_argument('--check-only', action='store_true',
                        help='evaluate existing transcripts in --from-dir without launching binaries')
    args = parser.parse_args()

    if args.check_only and len(args.from_dir) != 1:
        parser.error('--check-only requires exactly one --from-dir')
    if not args.from_dir and not (args.cli and args.node and args.host):
        parser.error('provide --cli, --node and --host or --from-dir')

    budgets = json.loads(args.budgets.read_text()) if args.budgets.exists() else None
    workload = budgets['workload'] if budgets and 'workload' in budgets else DEFAULT_WORKLOAD

    if args.freeze:
        directories = list(args.from_dir)
        if not directories:
            run_workload(args.cli.resolve(), args.node.resolve(), args.host.resolve(), args.output, workload)
            directories = [args.output]
        runs = [(read_jsonl(directory / 'startup.jsonl'), read_jsonl(directory / 'statements.jsonl'))
                for directory in directories]
        frozen = freeze_budgets(runs, workload=workload)
        args.budgets.write_text(json.dumps(frozen, indent=2) + '\n')
        print(json.dumps({'action': 'frozen', 'budgets': str(args.budgets),
                          'calibrated_revision': frozen['calibrated_revision'],
                          'calibration_runs': frozen['calibration_runs']}, indent=2))
        return

    require(budgets is not None, f'Missing budget file: {args.budgets}')
    report_path = args.output / 'report.json'
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'definition': DEFINITION, 'completed': False, 'status': 'running', 'violations': []}
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    try:
        if args.check_only or args.from_dir:
            directory = args.from_dir[0]
        else:
            run_workload(args.cli.resolve(), args.node.resolve(), args.host.resolve(), args.output, workload)
            directory = args.output
        startup_path = directory / 'startup.jsonl'
        statements_path = directory / 'statements.jsonl'
        evaluation = assess(read_jsonl(startup_path), read_jsonl(statements_path), budgets)
        report.update(
            completed=True,
            budgets_sha256=digest(args.budgets),
            startup_sha256=digest(startup_path),
            statements_sha256=digest(statements_path),
            **evaluation,
        )
    except BaseException as error:
        report.update(status='failed', error=str(error))
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + '\n')

    print(json.dumps({key: report[key] for key in ('status', 'metrics', 'violations')}, indent=2))
    if report['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
