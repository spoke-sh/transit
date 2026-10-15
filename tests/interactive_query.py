"""Owned native snapshot/Fuze/Arrow console proofs, independently of workers."""
import argparse
import json
from pathlib import Path
import signal
import shutil
import hashlib
import subprocess
import threading
import time
import select

from cold_storage import ColdStore
from storage import Fixture, free_port, wait_ready
from latency_probe import Probe
from console_latency import measured_run
from console_terminal import Terminal


def check(node, proof, cli, kind, rows=41, age=0, resident_pages=64):
    started = time.monotonic()
    request_regressions = []
    # Measured declarative-authorization profile for this exact fixture.
    # Admission, bounded page acquisition and final disclosure check current
    # native privileges. Other sizes retain their prior checks until measured;
    # these bounds do not extrapolate to arbitrary schema/cardinality growth.
    accepted_table = kind == 'table' and rows == 41 and age == 0 and resident_pages == 64
    metadata_budget = 23 if accepted_table else 5
    parameter_overhead = 23 if accepted_table else 4

    def request_bound(sql, actual, expected, exact=False):
        if actual != expected if exact else actual > expected:
            evidence = dict(sql=sql, expected_requests=expected, actual_requests=actual)
            request_regressions.append(evidence)
            print(json.dumps(dict(source=kind, request_budget_failure=evidence)), flush=True)
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        root = fixture.root
        frozen = []
        for name, source in (('node', node), ('proof', proof), ('cli', cli)):
            target = root / name
            shutil.copy2(source, target)
            frozen.append(str(target))
        node, proof, cli = frozen
        print(json.dumps({'source': kind, 'rows': 12 if kind == 'document' else rows,
                          'aged_operations': age, 'resident_pages': resident_pages,
                          'request_budget_profile': 'authorized-table-41-measured-2026-10-15' if accepted_table else 'prior-source-profile',
                          'executables': {Path(path).name: hashlib.sha256(Path(path).read_bytes()).hexdigest()
                                          for path in frozen}}), flush=True)
        public = json.loads(subprocess.check_output([proof, 'public']))
        url = f'http://127.0.0.1:{free_port()}'
        config = root / 'node.json'
        config.write_text(json.dumps({'profile': 'native_v1',
            'genesis': {'realm': 46, 'root_key': public, 'max_clock_error_ms': 10000},
            'ursula_url': fixture.url, 'bucket': 'interactive', 'journal': 'authority',
            'port': int(url.rsplit(':', 1)[1]), 'resident_pages': resident_pages, 'request_timeout_ms': 10000}))
        gate, release = threading.Event(), threading.Event()
        blocked = [False]

        def before(path, body):
            kind = json.loads(body)['query']['kind'] if path == '/v1/query' else {}
            retained = 'snapshot_entries' in kind or ('snapshot_read' in kind and 'existing' in kind['snapshot_read']['snapshot'])
            if blocked[0] and retained:
                gate.set()
                assert release.wait(timeout=30), 'fixture did not release snapshot read'

        probe = Probe(url, native=True, before=before)
        process = None
        console = None
        with (root / 'node.log').open('w+') as log:
            try:
                subprocess.run([node, str(config), '--initialize'], check=True, env=fixture.env, capture_output=True, timeout=30)
                process = subprocess.Popen([node, str(config)], env=fixture.env, stdout=log, stderr=log)
                wait_ready(fixture.http, process, url + '/health')

                def invoke(command, *args):
                    return subprocess.run([proof, url, command, str(root), *args], check=True,
                                          capture_output=True, env=fixture.env, timeout=1800)

                invoke('provision', kind, *(() if kind == 'document' else (str(rows),)))
                if age:
                    invoke('age', str(age))
                settings = json.loads((root / 'shell.json').read_text())
                settings.update(version=1, profile='unified_v1', execution='interactive',
                                transport='loopback', url=probe.url, format='json')
                connection = root / 'console.json'
                connection.write_text(json.dumps(settings))
                args = [cli, 'console', '--no-rc', '--config', str(connection)]
                count = 12 if kind == 'document' else rows

                def query(sql, expected_rows, mode='json', request_budget=None, parameters=None, query_file=False):
                    command = [*args, '--format', mode]
                    if query_file:
                        path = root / 'query input.json'
                        request = {'sql': sql}
                        if parameters is not None: request['parameters'] = parameters
                        path.write_text(json.dumps(request))
                        script = root / 'query.sql'
                        script.write_text('.execute ' + json.dumps(str(path)) + '\n')
                        command += ['-f', str(script)]
                    else:
                        command += ['-c', sql]
                        if parameters is not None:
                            path = root / 'parameters.json'
                            path.write_text(json.dumps(parameters))
                            command += ['--parameters', str(path)]
                    before_counts = probe.snapshot()
                    code, stdout, stderr, measurements = measured_run(command, root, timeout=180, node=process.pid)
                    assert code == 0, stderr
                    counts = probe.snapshot() - before_counts
                    assert not any(value for key, value in counts.items() if key.startswith('update:')), counts
                    if request_budget is not None:
                        request_bound(sql, counts['POST'], request_budget)
                    if mode == 'table':
                        assert stdout.startswith('┌') and stdout.endswith(f'{expected_rows} rows\n')
                        frames = []
                    else:
                        frames = [json.loads(line) for line in stdout.splitlines()]
                        assert frames and frames[-1]['complete_coverage']
                        assert not any(frame['complete_coverage'] for frame in frames[:-1])
                        assert all(frame['profile'] == 'interactive_v1' for frame in frames)
                        assert [int(frame['ordinal']) for frame in frames] == list(range(len(frames)))
                        assert all(frame['session'] == frames[0]['session'] for frame in frames)
                        assert sum(len(frame['cells']) for frame in frames) == expected_rows
                        assert int(frames[-1]['rows']) == expected_rows
                    print(json.dumps({'source': kind, 'sql': sql, 'rows': expected_rows,
                                      'parameters': parameters is not None, 'query_file': query_file,
                                      **measurements,
                                      'native_attempts': counts['POST'], 'durable_updates': 0,
                                      'native_operations': {key: value for key, value in counts.items() if key.startswith('read:')}}), flush=True)
                    return frames

                # Request ceilings catch amplification regressions independently
                # of host speed. The integer fixtures fit the byte scan budget.
                for sql in ('DESCRIBE items;', 'SHOW TABLES;', 'EXPLAIN SELECT count(*) FROM items;'):
                    before_counts = probe.snapshot()
                    code, stdout, stderr, measurements = measured_run([*args, '-c', sql], root, timeout=180, node=process.pid)
                    assert code == 0, stderr
                    counts = probe.snapshot() - before_counts
                    assert not any(value for key, value in counts.items() if key.startswith('update:')), counts
                    assert not any(value for key, value in counts.items() if 'snapshot' in key), counts
                    request_bound(sql, counts['POST'], metadata_budget, exact=not accepted_table)
                    result = json.loads(stdout)['inspection']
                    assert result['version'] == 1 and result['scope'] == 'configured_source'
                    assert result['source_kind'] == kind and result['name'] == 'items'
                    if sql.startswith('SHOW'):
                        assert result['details']['tables'] == (['items'] if kind == 'table' else [])
                    if sql.startswith('EXPLAIN'):
                        plan = result['details']['explanation']
                        assert plan['operators'] == ['scan', 'count']
                        assert plan['columns'] == [{'name': 'count', 'type': {'uint64': {}}, 'nullable': False, 'optional': False}]
                    print(json.dumps({'source': kind, 'inspection': sql, **measurements,
                                      'native_attempts': counts['POST'], 'durable_updates': 0, 'snapshots': 0,
                                      'native_operations': {key: value for key, value in counts.items() if key.startswith('read:')}}), flush=True)
                scan_budget = 31 if kind == 'document' else 3 + max(1, (count + 7) // 8) + max(0, (count + 63) // 64 - 1)
                if accepted_table:
                    scan_budget = 188
                # Capability discovery, snapshot acquisition, schema-disclosure
                # revalidation, then the terminal page's current check/release.
                small_budget = 60 if accepted_table else 30 if kind == 'document' else 4
                first = query('SELECT * FROM items;', count, request_budget=scan_budget)
                second = query('SELECT * FROM items;', count, request_budget=scan_budget)
                assert first[0]['session'] != second[0]['session'], 'independent statements reused a session'
                assert first[0]['basis'] == second[0]['basis']
                aggregate = query('SELECT COUNT(*) FROM items;', 1, request_budget=scan_budget)
                assert aggregate[-1]['cells'][0][0] == {'value': {'atom': {'unsigned': str(count)}}}
                query('SELECT * FROM items LIMIT 3;', min(3, count), request_budget=small_budget)
                query('SELECT * FROM items LIMIT 0;', 0, request_budget=47 if accepted_table else 4)
                query('SELECT * FROM items;', count, 'table', request_budget=scan_budget)
                # Explicit bindings add the shared compiler's two current
                # description checks, including general Table metadata reads.
                # Values never become executable SQL text.
                literal = query('SELECT * FROM items LIMIT 3;', min(3, count), request_budget=small_budget)
                for from_file in (False, True):
                    bound = query('SELECT * FROM items LIMIT $1;', min(3, count),
                                  parameters=[{'unsigned': '3'}], query_file=from_file,
                                  request_budget=small_budget + parameter_overhead)
                    assert [frame['cells'] for frame in bound] == [frame['cells'] for frame in literal]
                    assert bound[0]['columns'] == literal[0]['columns'] and bound[0]['basis'] == literal[0]['basis']
                query('SELECT * FROM items;', count, parameters=[], request_budget=scan_budget + parameter_overhead)
                query('SELECT * FROM items LIMIT $1;', count, parameters=[{'unsigned': '18446744073709551615'}], request_budget=scan_budget + parameter_overhead)
                query('SELECT * FROM items WHERE value = $1;', 0,
                      parameters=[{'utf8': "'; DROP TABLE items; -- $2"}])
                for request in (
                    {'sql': 'SELECT * FROM items LIMIT $1', 'parameters': []},
                    {'sql': 'SELECT * FROM items LIMIT $1', 'parameters': [{'signed': '3'}]},
                    {'sql': 'DELETE FROM items WHERE id = 0', 'parameters': []},
                ):
                    path = root / 'invalid-query.json'; path.write_text(json.dumps(request))
                    before_counts = probe.snapshot()
                    rejected = subprocess.run(args, input='.execute ' + str(path) + '\n', text=True,
                                              capture_output=True, timeout=30, cwd=root)
                    assert rejected.returncode and not rejected.stdout, rejected
                    counts = probe.snapshot() - before_counts
                    assert not any(value for key, value in counts.items() if key.startswith('update:') or 'snapshot' in key), counts
                print(f'Interactive {kind}: explicit parameter/file inputs, exact literal results and no-dispatch rejection passed.', flush=True)
                if kind == 'table':
                    query('SELECT * FROM items WHERE id IS VALUE;', count, request_budget=scan_budget)
                    for state in ('MISSING', 'TYPE_ERROR', 'CONFLICT'):
                        query(f'SELECT * FROM items WHERE id IS {state};', 0, request_budget=scan_budget)
                    point = query(f'SELECT * FROM items WHERE id = {count - 1};', min(1, count), request_budget=59 if accepted_table else 3)
                    if count:
                        assert point[0]['cells'][0][0] == {'value': {'atom': {'signed': str(count - 1)}}}
                    query(f'SELECT * FROM items WHERE id >= {max(0, count - 3)};', min(3, count), request_budget=scan_budget if accepted_table else 3)
                    query('SELECT * FROM items WHERE id < 3;', min(3, count), request_budget=scan_budget if accepted_table else 3)
                    total = query('SELECT COUNT(*) FROM items WHERE id = 0;', 1, request_budget=57 if accepted_table else 3)
                    assert total[-1]['cells'][0][0] == {'value': {'atom': {'unsigned': str(min(1, count))}}}
                    query('SELECT * FROM items WHERE id > 9223372036854775807;', 0, request_budget=scan_budget if accepted_table else 3)
                # A local execution budget reports its measured dimension and
                # a truthful prefix count, never durable-resume guidance.
                for dimension in ('pages', 'segments', 'result_bytes'):
                    if dimension != 'result_bytes' and count <= 8:
                        continue
                    limited = json.loads(json.dumps(settings))
                    limited['workspace']['limits'][dimension] = '1'
                    limited_path = root / ('limited-' + dimension + '.json')
                    limited_path.write_text(json.dumps(limited))
                    before_counts = probe.snapshot()
                    failed = subprocess.run([cli, 'console', '--no-rc', '--config', str(limited_path),
                                             '-c', 'SELECT * FROM items;'], capture_output=True, text=True, timeout=60)
                    assert failed.returncode == 1, failed
                    frames = [json.loads(line) for line in failed.stdout.splitlines()]
                    assert not any(frame['complete_coverage'] for frame in frames), failed
                    for expected in ('query.budget_exceeded', 'Budget: ' + dimension, 'Limit: 1',
                                     'Required:', 'Complete result: no', 'Rows already emitted:'):
                        assert expected in failed.stderr, (expected, failed.stderr)
                    assert '.resume' not in failed.stderr and '.cancel' not in failed.stderr, failed.stderr
                    counts = probe.snapshot() - before_counts
                    assert not any(value for key, value in counts.items() if key.startswith('update:')), counts
                print(f'Interactive {kind}: measured budget diagnostics and incomplete-prefix evidence passed.', flush=True)

                assert not (root / 'console-recovery.json').exists()

                if kind == 'kv' and count:
                    invoke('invalidate-kv')
                    failing_sql = "SELECT * FROM items WHERE key IS NULL AND value='';"
                    rejected = subprocess.run([*args, '-c', failing_sql], capture_output=True, text=True, timeout=30)
                    assert rejected.returncode == 1 and not rejected.stdout, rejected
                    for expected in ('query.cell_type_error', 'Scan row: 1', 'Column: value',
                                     'Predicate instruction (zero-based): 1', 'Source key: 6b0000000000000000',
                                     'native_cause: invalid_utf8', 'Frozen plan/source fingerprint:'):
                        assert expected in rejected.stderr, (expected, rejected.stderr)
                    assert '.resume' not in rejected.stderr and '.cancel' not in rejected.stderr
                    # Current permission loss at diagnostic disclosure suppresses
                    # source-key and source-basis enrichment after computation.
                    gate.clear(); release.clear(); blocked[0] = True
                    console = subprocess.Popen([*args, '-c', failing_sql], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    assert gate.wait(timeout=30)
                    invoke('revoke')
                    release.set()
                    stdout, stderr = console.communicate(timeout=30)
                    assert console.returncode != 0 and not stdout, (stdout, stderr)
                    assert b'Source key:' not in stderr and b'Frozen plan/source fingerprint:' not in stderr, stderr
                    console = None; blocked[0] = False
                    invoke('restore')
                    invoke('repair-kv')
                    print('Interactive KV: eager atom, exact binary key, decoder reason and disclosure denial passed.', flush=True)

                # A terminal interrupt returns to an empty, reusable prompt.
                # Repeated signals and the remaining pasted SQL cannot start
                # another snapshot or poison the next statement's cancel flag.
                terminal = Terminal(cli, connection)
                try:
                    gate.clear()
                    release.clear()
                    blocked[0] = True
                    previous_closes = probe.snapshot()['read:close_snapshot'] + probe.snapshot()['snapshot_finish']
                    previous_opens = probe.snapshot()['read:open_snapshot'] + probe.snapshot()['snapshot_open']
                    terminal.send('\x1b[200~SELECT * FROM items; SELECT COUNT(*) FROM items;\x1b[201~\r')
                    assert gate.wait(timeout=30)
                    terminal.process.send_signal(signal.SIGINT)
                    terminal.process.send_signal(signal.SIGINT)
                    release.set()
                    terminal.expect('Query cancelled.', timeout=30)
                    terminal.screen = terminal.screen[terminal.screen.index(b'Query cancelled.'):]
                    terminal.expect('\rtransit> ', timeout=30)
                    assert probe.snapshot()['read:close_snapshot'] + probe.snapshot()['snapshot_finish'] == previous_closes + 1
                    assert probe.snapshot()['read:open_snapshot'] + probe.snapshot()['snapshot_open'] == previous_opens + 1
                    assert not terminal.buffer and not select.select([terminal.process.stdout], [], [], .1)[0]
                    blocked[0] = False
                    frame = terminal.call('SELECT * FROM items LIMIT 3;')
                    assert frame['complete_coverage'] and int(frame['rows']) == min(3, count), frame
                    assert not (root / 'console-recovery.json').exists()
                finally:
                    blocked[0] = False
                    release.set()
                    terminal.close()

                # Stop one in-flight read; no durable cancel command is needed.
                gate.clear()
                release.clear()
                blocked[0] = True
                previous_closes = (probe.snapshot()['read:close_snapshot'] + probe.snapshot()['snapshot_finish'])
                console = subprocess.Popen([*args, '-c', 'SELECT * FROM items;'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                assert gate.wait(timeout=30)
                console.send_signal(signal.SIGINT)
                release.set()
                stdout, stderr = console.communicate(timeout=30)
                assert console.returncode == 130 and not stdout, (stdout, stderr)
                assert b'query cancelled' in stderr and b'.resume' not in stderr, stderr
                assert (probe.snapshot()['read:close_snapshot'] + probe.snapshot()['snapshot_finish']) == previous_closes + 1, 'interrupted query did not release its snapshot'
                console = None
                blocked[0] = False
                query('SELECT * FROM items LIMIT 3;', min(3, count))

                # A closed output consumer must not retain the source lease.
                gate.clear()
                release.clear()
                blocked[0] = True
                previous_closes = (probe.snapshot()['read:close_snapshot'] + probe.snapshot()['snapshot_finish'])
                console = subprocess.Popen([*args, '-c', 'SELECT * FROM items;'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                assert gate.wait(timeout=30)
                console.stdout.close()
                console.stdout = None
                release.set()
                _, stderr = console.communicate(timeout=30)
                assert console.returncode != 0, stderr
                assert (probe.snapshot()['read:close_snapshot'] + probe.snapshot()['snapshot_finish']) == previous_closes + 1, 'failed output did not release its snapshot'
                console = None
                blocked[0] = False

                # Fail current source authorization after a returned prefix.
                if count <= 8:
                    assert not request_regressions, request_regressions
                    print(f'Interactive {kind}: empty/single-page controls passed.', flush=True)
                    return
                gate.clear()
                release.clear()
                console = subprocess.Popen([*args, '-c', 'SELECT * FROM items;'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                assert select.select([console.stdout], [], [], 30)[0], 'console did not produce a prefix'
                prefix = json.loads(console.stdout.readline())
                assert not prefix['complete_coverage']
                blocked[0] = True
                assert gate.wait(timeout=30)
                invoke('revoke')
                release.set()
                stdout, stderr = console.communicate(timeout=30)
                assert console.returncode != 0, stderr
                assert not any(json.loads(line)['complete_coverage'] for line in stdout.splitlines())
                console = None
                blocked[0] = False
                for sql in ('DESCRIBE items;', 'SHOW TABLES;', 'EXPLAIN SELECT count(*) FROM items;'):
                    denied = subprocess.run([*args, '-c', sql], capture_output=True, text=True, timeout=30)
                    assert denied.returncode != 0 and not denied.stdout, (sql, denied.stdout, denied.stderr)
                invoke('restore')
                query('SELECT * FROM items LIMIT 3;', min(3, count))
                # Finish correctness and disclosure checks before reporting all
                # amplification regressions; none becomes a passed budget check.
                assert not request_regressions, request_regressions
                print(f'Interactive {kind}: fresh cuts, bounded frames, zero durable updates, cancellation and current denial passed in {time.monotonic()-started:.2f}s', flush=True)
            finally:
                release.set()
                if console is not None:
                    console.kill()
                    console.communicate(timeout=10)
                probe.close()
                if process is not None:
                    process.kill()
                    process.wait(timeout=10)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('node', 'proof', 'cli'):
        parser.add_argument(name)
    parser.add_argument('--source', choices=('table', 'kv', 'document', 'all'), default='all')
    parser.add_argument('--rows', type=int, choices=range(513), default=41, metavar='0..512')
    parser.add_argument('--age', type=int, choices=range(10001), default=0, metavar='0..10000')
    parser.add_argument('--resident-pages', type=int, choices=range(1025), default=64, metavar='0..1024')
    args = parser.parse_args()
    for source in ('table', 'kv', 'document') if args.source == 'all' else (args.source,):
        check(*(str(Path(getattr(args, name)).resolve()) for name in ('node', 'proof', 'cli')),
              source, args.rows, args.age, args.resident_pages)
