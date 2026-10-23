"""Measure Transit components; full TPC workloads stay explicitly blocked."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import sqlite3
import statistics
import struct
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name('manifest.json')
DEFINITION = 'transit.declarative-benchmarks.v1'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def load_manifest():
    data = json.loads(MANIFEST.read_text())
    require(data['definition'] == DEFINITION, 'incompatible benchmark definition')
    expected = {
        'TPC-C': {'New-Order', 'Payment', 'Order-Status', 'Delivery', 'Stock-Level'},
        'TPC-E': {'Broker-Volume', 'Customer-Position', 'Market-Feed', 'Market-Watch', 'Security-Detail', 'Trade-Lookup', 'Trade-Order', 'Trade-Result', 'Trade-Status', 'Trade-Update', 'Data-Maintenance', 'Trade-Cleanup'},
        'TPC-H': {f'Q{i:02}' for i in range(1, 23)} | {'RF1', 'RF2'},
        'TPC-DS': {f'Q{i:02}' for i in range(1, 100)} | {'LF_CR', 'LF_CS', 'LF_I', 'LF_SR', 'LF_SS', 'LF_WR', 'LF_WS', 'DF_CS', 'DF_SS', 'DF_WS', 'DF_I'},
    }
    require(len(data['suites']) == 4, 'four suites required')
    require({suite['id'] for suite in data['suites']} == set(expected), 'suite inventory differs')
    for suite in data['suites']:
        require(set(suite['operations']) == expected[suite['id']], f"incomplete coverage: {suite['id']}")
        require(len(suite['operations']) == len(set(suite['operations'])), 'duplicate workload')
        require(suite['common_blockers'], 'full workload requires explicit blockers')
        for feature in suite['common_blockers'] + suite['additional_suite_requirements']:
            require(feature in data['features'], f'unknown feature {feature}')
    for feature in data['features'].values():
        require((ROOT / feature['owner']).is_file(), 'missing feature owner')
    for name in ('components', 'probes'):
        ids = [case['id'] for case in data[name]]
        require(len(ids) == len(set(ids)), f'duplicate {name}')
    require(len(data['components']) == 33 and len(data['probes']) == 9, 'component/probe inventory changed; review coverage')
    for case in data['components']:
        if case['kind'] == 'select':
            types = case.get('output_types')
            require(isinstance(types, list) and 1 <= len(types) <= 8
                    and all(t in ('int64', 'uint64') for t in types), 'missing or invalid independent output types')
    for suite in expected:
        require({case['kind'] for case in data['components'] if case['suite'] == suite} == {'select', 'declaration', 'mutation'}, f'missing component layer: {suite}')
    return data


def coverage(data):
    return [dict(id=suite['id'], specification=suite['specification'], source=suite['url'],
                 full_workload_status='blocked', completed=0, total=len(suite['operations']),
                 operations=[dict(id=name, status='blocked', blockers=suite['common_blockers']) for name in suite['operations']],
                 additional_suite_requirements=suite['additional_suite_requirements']) for suite in data['suites']]


def fixture_rows(rows, seed):
    for n in range(rows):
        yield n, None if n % 13 == 0 else (n * 17 + seed) % 101


def fixture_hash(rows, seed):
    h = hashlib.sha256()
    for key, value in fixture_rows(rows, seed):
        h.update(struct.pack('<qBq', key, value is not None, value or 0))
    return h.hexdigest()


def invoke(binary, config, directory, timeout):
    path = directory / 'request.json'
    path.write_text(json.dumps(config) + '\n')
    result = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    require(result.returncode == 0, f'probe exited {result.returncode}: {result.stderr[-4096:]}')
    return [json.loads(line) for line in result.stdout.splitlines()]


def checked_records(records, data):
    require(records and records[0].get('kind') == 'metadata', 'missing build metadata')
    require(records[0]['optimization'] == 'safe', 'benchmark requires ReleaseSafe')
    actual = {}
    for record in records[1:]:
        key = (record['id'], record['phase'])
        require(key not in actual, f'duplicate result {key}')
        actual[key] = record
    expected = set()
    for case in data['components']:
        expected.add((case['id'], 'compile'))
        phases = {'select': ['execute'], 'declaration': ['verify_declaration'], 'mutation': ['verify_mutation', 'build_candidate']}[case['kind']]
        expected.update((case['id'], phase) for phase in phases)
    expected.update((probe['id'], 'capability_probe') for probe in data['probes'])
    require(set(actual) == expected, 'missing, extra or mislabeled component results')
    for record in actual.values():
        if record['phase'] in ('compile', 'execute', 'build_candidate'):
            require(type(record.get('elapsed_ns')) is int and record['elapsed_ns'] > 0
                    and type(record.get('iterations')) is int and record['iterations'] > 0, 'missing or invalid timing')
    return actual


def expected_candidate(case):
    # Compare complete logical contents with a separate SQL implementation,
    # never with a reproduction of Transit's private row/index encoding.
    source = case['source']
    require(source.isidentifier(), 'invalid fixture source')
    with sqlite3.connect(':memory:') as oracle:
        oracle.execute(f'CREATE TABLE {source} (id INTEGER PRIMARY KEY, quantity INTEGER)')
        initial = [(1, 50), (2, None)]
        oracle.executemany(f'INSERT INTO {source} VALUES (?, ?)', initial)
        matched = oracle.execute(case['sql']).rowcount
        rows = oracle.execute(f'SELECT id, quantity FROM {source} ORDER BY id').fetchall()
    before, after = dict(initial), dict(rows)
    changed = sum(key not in before or key not in after or before[key] != after[key]
                  for key in before.keys() | after.keys())
    require(len(rows) <= 5, 'mutation fixture result exceeded')
    return dict(matched=matched, changed=changed, rows=[list(row) for row in rows] + [None] * (5 - len(rows)))


def expected_schema():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    columns = [dict(id=str(index), name=name, type={'int64': {}}, nullable=index != 1,
                    default=None, max_characters=None, encoding='plain', collation='none') for index, name in enumerate(('id', 'quantity'), 1)]
    return dict(definition=definition, object='1', revision='1', next_column='3', columns=columns, primary_key=['1'])


def verify(records, data, config, directory):
    import pyarrow.ipc as ipc
    actual = checked_records(records, data)
    query_outputs = []
    for record in actual.values():
        if record['phase'] in ('compile', 'execute', 'build_candidate'):
            expected_iterations = config['iterations'] if record['phase'] == 'execute' else config['compile_iterations']
            require(record['iterations'] == expected_iterations, 'wrong iteration count')
    with sqlite3.connect(directory / 'oracle.sqlite') as oracle:
        oracle.execute('CREATE TABLE fixture (id INTEGER PRIMARY KEY, quantity INTEGER)')
        oracle.executemany('INSERT INTO fixture VALUES (?, ?)', fixture_rows(config['rows'], config['seed']))
        for source in sorted({case['source'] for case in data['components']}):
            require(source.isidentifier(), 'invalid fixture source')
            oracle.execute(f'CREATE VIEW {source} AS SELECT id, quantity FROM fixture ORDER BY id')
        for index, case in enumerate(data['components']):
            if case['kind'] == 'select':
                result = actual[case['id'], 'execute']
                cursor = oracle.execute(case['sql'])
                expected = cursor.fetchall()  # Each component emits at most eight rows.
                require(len(expected) <= 8, 'unbounded oracle result')
                names = [col[0].lower().split('(')[0] if '(' in col[0] else col[0] for col in cursor.description]
                require(len(names) == len(case['output_types']), 'independent output type width mismatch')
                combined = []
                segment_hashes = []
                require(result['finished'] in ('source_end', 'limit') and result['segments'] > 0, 'incomplete query')
                for segment in range(result['segments']):
                    segment_path = directory / f'{index}-{segment}.arrow'
                    segment_hashes.append(digest(segment_path))
                    table = ipc.open_stream(segment_path).read_all()
                    require(table.column_names == names, f"schema mismatch: {case['id']}")
                    for row in table.to_pylist():
                        cells = []
                        for name, expected_type in zip(names, case['output_types'], strict=True):
                            cell = row[name]
                            require(cell['alternatives'] == [], 'unexpected conflict alternatives')
                            kind = 2 if expected_type == 'uint64' else 1
                            require((cell['state'], cell['kind']) == ((1, 7) if cell['value'] is None else (3, kind)), 'wrong cell type/state')
                            cells.append(cell['value'])
                        combined.append(tuple(cells))
                require(combined == expected and result['rows'] == len(expected), f"incorrect Arrow result: {case['id']}: {combined} != {expected}")
                query_outputs.append(dict(id=case['id'], columns=names, rows=combined, segment_sha256=segment_hashes))
            elif case['kind'] == 'mutation':
                result = actual[case['id'], 'verify_mutation']
                require(result['candidate'] == expected_candidate(case), f"incorrect typed candidate: {case['id']}")
            else:
                require(actual[case['id'], 'verify_declaration']['schema'] == expected_schema(), 'incorrect typed schema')
    for probe in data['probes']:
        require(actual[probe['id'], 'capability_probe']['err'] == probe['expected_error'], f"capability changed: {probe['id']}")
    return actual, query_outputs


def summarize(samples, baseline):
    result = []
    for key, first in baseline.items():
        if 'elapsed_ns' not in first:
            continue
        values = [sample[key]['elapsed_ns'] / sample[key]['iterations'] for sample in samples]
        result.append(dict(id=key[0], phase=key[1], median_ns=statistics.median(values), min_ns=min(values), max_ns=max(values)))
    return result


def write_report(path, report):
    # Replace atomically so an interrupted write cannot look like a complete run.
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(report, indent=2) + '\n')
    temp.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--samples', type=int, default=5)
    parser.add_argument('--rows', type=int, default=8192)
    parser.add_argument('--page-rows', type=int, default=8)
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--iterations', type=int, default=10)
    parser.add_argument('--compile-iterations', type=int, default=2000)
    parser.add_argument('--timeout', type=int, default=120)
    parser.add_argument('--output', type=Path, default=Path('.cache/verification/benchmarks/report.json'))
    parser.add_argument('--require-full', action='store_true', help='return exit 2 if any full workload is blocked')
    args = parser.parse_args()
    for name, lower, upper in [('samples', 1, 100), ('rows', 0, 1000000), ('page_rows', 1, 8), ('seed', 0, 2**32 - 1), ('iterations', 1, 1000), ('compile_iterations', 1, 1000000), ('timeout', 1, 3600)]:
        if not lower <= getattr(args, name) <= upper:
            parser.error(f'{name} must be between {lower} and {upper}')
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    report = dict(definition=DEFINITION, status='running', summary=[], samples=[],
                  timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat())
    write_report(output, report)
    started = time.monotonic()
    try:
        data = load_manifest()
        binary = args.binary.resolve(strict=True)
        import pyarrow
        report.update(revision=git('rev-parse', 'HEAD'), dirty=bool(git('status', '--porcelain')),
                      manifest_sha256=digest(MANIFEST), binary_sha256=digest(binary),
                      harness_sha256=digest(Path(__file__)), lock_sha256=digest(ROOT / 'flake.lock'),
                      driver_sha256=digest(ROOT / 'tests/declarative_bench.zig'),
                      platform=platform.platform(), machine=platform.machine(), cpu_count=os.cpu_count(),
                      cpu_model=next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')), 'unknown') if Path('/proc/cpuinfo').exists() else platform.processor(),
                      affinity=sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else None,
                      load_average=list(os.getloadavg()) if hasattr(os, 'getloadavg') else None,
                      python=platform.python_version(), pyarrow=pyarrow.__version__, sqlite=sqlite3.sqlite_version,
                      features=data['features'], suites=coverage(data), components=data['components'],
                      probes=data['probes'], scope='synthetic paged Fuze and private Station proposals; no storage, authorization, network, commit, catalog publication or SDK/CLI latency',
                      fixture=dict(generator='id=0..rows-1; quantity=NULL when id%13=0 else (id*17+seed)%101', rows=args.rows, seed=args.seed, page_rows=args.page_rows, sha256=fixture_hash(args.rows, args.seed), scale_factor=None),
                      repetitions=dict(samples=args.samples, iterations=args.iterations, compile_iterations=args.compile_iterations))
        config = dict(rows=args.rows, page_rows=args.page_rows, seed=args.seed, iterations=args.iterations,
                      compile_iterations=args.compile_iterations,
                      cases=[{k: v for k, v in case.items() if k not in ('suite', 'output_types')} for case in data['components']], probes=[{k: v for k, v in probe.items() if k != 'expected_error'} for probe in data['probes']])
        with tempfile.TemporaryDirectory(prefix='components-', dir=output.parent) as temp:
            directory = Path(temp)
            # Verification plus a full unrecorded warm-up precede the samples.
            records = invoke(binary, dict(config, verify_dir=str(directory)), directory, args.timeout)
            baseline, query_outputs = verify(records, data, config, directory)
            report['build'] = records[0]
            report['verification'] = dict(status='passed', records=records[1:], query_outputs=query_outputs, oracle='SQLite query results and typed mutation rows/counts; PyArrow IPC; exact neutral Table schemas')
            warmup = invoke(binary, config, directory, args.timeout)
            require(warmup[0] == records[0], 'build metadata changed')
            require({k: {f: v for f, v in r.items() if f != 'elapsed_ns'} for k, r in checked_records(warmup, data).items()} == {k: {f: v for f, v in r.items() if f != 'elapsed_ns'} for k, r in baseline.items()}, 'warm-up differs')
            samples = []
            for _ in range(args.samples):
                records = invoke(binary, config, directory, args.timeout)
                require(records[0] == report['build'], 'sample build changed')
                actual = checked_records(records, data)
                for key, record in actual.items():
                    require({k: v for k, v in record.items() if k != 'elapsed_ns'} == {k: v for k, v in baseline[key].items() if k != 'elapsed_ns'}, f'sample workload differs: {key}')
                samples.append(actual)
                report['samples'].append(records[1:])
            report['summary'] = summarize(samples, baseline)
        report['status'] = 'components_passed_full_workloads_blocked'
    except (Exception, KeyboardInterrupt) as error:
        report.update(status='failed', error=f'{type(error).__name__}: {error}', summary=[])
        write_report(output, report)
        print(f'benchmark failed; report: {output}: {error}', file=sys.stderr)
        return 1
    report['elapsed_seconds'] = time.monotonic() - started
    write_report(output, report)
    print(json.dumps(dict(output=str(output), status=report['status'], components=len(data['components']), blocked_workloads=sum(s['total'] for s in report['suites']), summary=report['summary']), indent=2))
    return 2 if args.require_full else 0


if __name__ == '__main__':
    sys.exit(main())
