#!/usr/bin/env python3
"""Measure owned local queries, with optional instrumented transport counts."""
import argparse
import ctypes
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import time

from harness.processes import children, command
from harness.local_installation import freeze_executables
from interfaces.installation.server import Fixture
from harness.http_probe import Probe
from runner.paths import ROOT


def digest(path):
    with open(path, 'rb') as binary:
        return hashlib.file_digest(binary, 'sha256').hexdigest()


def representation_sample(batch, historical=False):
    """Payload-only experiment, not a negotiated wire format or latency sample.

    Cell lengths make this private layout unambiguous. Schema/observation are
    counted separately; framing, alignment and codec negotiation are not modeled.
    Every compressed payload must round-trip byte-for-byte before being reported.
    """
    import pyarrow as pa
    rows = [[bytes.fromhex(cell) for cell in row] for row in batch['rows']]
    layouts = {
        'rows': [cell for row in rows for cell in row],
        'columns': [cell for column in zip(*rows) for cell in column],
    }
    result = dict(pyarrow=pa.__version__, layouts={},
                  schema_json_bytes=len(json.dumps(batch['schema'], separators=(',', ':')).encode()),
                  observation_json_bytes=len(json.dumps(batch['basis' if historical else 'observation'], separators=(',', ':')).encode()))
    for name, cells in layouts.items():
        payload = b''.join(len(cell).to_bytes(4, 'little') + cell for cell in cells)
        codecs = {}
        for codec in ('lz4', 'zstd'):
            start = time.perf_counter_ns()
            compressed = pa.compress(payload, codec=codec)
            encoded_ns = time.perf_counter_ns() - start
            start = time.perf_counter_ns()
            restored = pa.decompress(compressed, decompressed_size=len(payload), codec=codec)
            decoded_ns = time.perf_counter_ns() - start
            assert restored.to_pybytes() == payload, 'codec changed the result payload'
            codecs[codec] = dict(bytes=len(compressed), encode_ns=encoded_ns, decode_ns=decoded_ns)
        result['layouts'][name] = dict(bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest(), codecs=codecs)
    return result


def override(fixture, role, fields, probe_gate=None, stderr_path=None):
    """Change only this owned fixture's generated child configuration."""
    fields = {key: value for key, value in fields.items() if value is not None}
    if not fields and stderr_path is None:
        return
    executable = fixture.config['executables'][role]
    wrapper = fixture.root / (role + '-control')
    wrapper.write_text(f'''#!{sys.executable}
import json, os, sys, time
from pathlib import Path
bootstrap = sys.argv[1] == '--bootstrap-json'
config = json.loads(sys.argv[2] if bootstrap else Path(sys.argv[1]).read_text())
config.update({fields!r})
if bootstrap:
    sys.argv[2] = json.dumps(config)
else:
    Path(sys.argv[1]).write_text(json.dumps(config))
gate = {str(probe_gate) if probe_gate else None!r}
if gate:
    Path(gate).touch()
    deadline = time.monotonic() + 30
    while not Path(gate + '.ready').exists():
        if time.monotonic() > deadline: raise TimeoutError('measurement proxy not ready')
        time.sleep(0.01)
diagnostic_path = {str(stderr_path) if stderr_path else None!r}
if diagnostic_path:
    with open(diagnostic_path, 'ab', buffering=0) as diagnostic:
        os.dup2(diagnostic.fileno(), 2)
os.execv({executable!r}, [{executable!r}] + sys.argv[1:])
''')
    wrapper.chmod(0o700)
    fixture.config['executables'][role] = str(wrapper)


def local_trace(path):
    """Export only reviewed bounded fields; whole debug logs stay private."""
    retained = 0
    omitted = 0
    losses = dict(dropped=0, suppressed=0, sink_errors=0)
    with path.open('rb') as source:
        for line in source:
            if len(line) > 2048:
                raise ValueError('local trace record exceeds telemetry bound')
            record = json.loads(line)
            event = record.get('event', {})
            if record.get('name') == 'telemetry.loss':
                for key in losses:
                    losses[key] = max(losses[key], record.get('measurement', {}).get(key, 0))
            if event.get('name') not in ('transit.local.request', 'transit.client.request'):
                continue
            if retained == 8192:
                omitted += 1
                continue
            retained += 1
            print(json.dumps(dict(phase='local_trace', **{key: record.get(key) for key in
                ('time_unix_ms', 'duration_ns', 'trace_id', 'span_id', 'parent_span_id')},
                event={key: event.get(key) for key in
                       ('name', 'operation', 'route', 'outcome', 'error_type', 'wait_ns', 'work_ns')})), flush=True)
    print(json.dumps(dict(phase='local_trace_summary', retained=retained, omitted=omitted,
                          losses=losses)), flush=True)


def measured_run(args, cwd, timeout=420, node=None):
    """Drain both pipes, sample resident memory, and time the first output byte.

    First output is observable presentation latency, not an inferred server
    execution time. Memory is sampled every 20 ms and can miss shorter peaks.
    """
    started = time.monotonic()
    process = subprocess.Popen(args, cwd=cwd, stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               env={'PATH': '/unavailable'})
    first = None
    peak = 0
    node_peak = 0
    def node_cpu():
        fields = Path(f'/proc/{node}/stat').read_text().split()
        return sum(map(int, fields[13:15])) / os.sysconf('SC_CLK_TCK')
    before_cpu = node_cpu() if node is not None else None
    buffers = [bytearray(), bytearray()]
    try:
        with selectors.DefaultSelector() as selector:
            for index, pipe in enumerate((process.stdout, process.stderr)):
                selector.register(pipe, selectors.EVENT_READ, index)
            while selector.get_map():
                if time.monotonic() - started > timeout:
                    raise TimeoutError('console measurement exceeded deadline')
                try:
                    resident = int(Path(f'/proc/{process.pid}/statm').read_text().split()[1])
                    peak = max(peak, resident * os.sysconf('SC_PAGE_SIZE'))
                    if node is not None:
                        resident = int(Path(f'/proc/{node}/statm').read_text().split()[1])
                        node_peak = max(node_peak, resident * os.sysconf('SC_PAGE_SIZE'))
                except FileNotFoundError:
                    pass
                for key, _ in selector.select(timeout=0.02):
                    data = os.read(key.fileobj.fileno(), 65536)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    if key.data == 0 and first is None:
                        first = time.monotonic() - started
                    buffers[key.data].extend(data)
                    if len(buffers[key.data]) > 16 * 1024 * 1024:
                        raise ValueError('console output exceeds measurement bound')
        code = process.wait(timeout=10)
        metrics = {
            'seconds': time.monotonic() - started,
            'first_stdout_seconds': first, 'sampled_peak_rss_bytes': peak}
        if node is not None:
            metrics.update(node_sampled_peak_rss_bytes=node_peak, node_cpu_seconds=node_cpu() - before_cpu)
        return code, *(buffer.decode() for buffer in buffers), metrics
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=10)
        process.stdout.close()
        process.stderr.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for role in ('cli', 'node', 'host'):
        parser.add_argument(role)
    parser.add_argument('--resident-pages', type=int, choices=range(1025), metavar='0..1024')
    parser.add_argument('--worker-interval-ms', type=int, choices=range(1, 60001), metavar='1..60000')
    parser.add_argument('--single', action='store_true', help='measure only the first empty SELECT')
    parser.add_argument('--repeat', type=int, default=1, choices=range(1, 101), metavar='1..100')
    parser.add_argument('--cycles', type=int, default=1, choices=range(1, 51), metavar='1..50',
                        help='repeat a verified zero/one-row statement cycle in the same session; requires --statements --repeat 1')
    parser.add_argument('--warm-reads', type=int, default=1, choices=range(1, 101), metavar='1..100',
                        help='sample unchanged empty/one-row SELECTs per statement cycle; requires --statements --repeat 1')
    parser.add_argument('--statements', action='store_true',
                        help='persistent human table console: empty/warm SELECT, INSERT/UPDATE/DELETE, refreshed SELECT, verified JSON readback')
    parser.add_argument('--resources', action='store_true',
                        help='sample owned process/thread/RSS/PSS counts between timed statements (Linux)')
    parser.add_argument('--age-queries', type=int, default=0, choices=range(1001), metavar='0..1000',
                        help='execute this many unmeasured SELECTs before measurements')
    parser.add_argument('--remote-sql', action='store_true', help='historical installed gateway placement for matched controls')
    parser.add_argument('--instrument', action='store_true',
                        help='count typed local attempts, or HTTP attempts/work with --remote-sql; adds diagnostic overhead')
    parser.add_argument('--local-trace', action='store_true',
                        help='separate debug run with bounded local-owner/client duration records')
    parser.add_argument('--owner-metrics', action=argparse.BooleanOptionalAction, default=True,
                        help='also enable optional native owner-work response diagnostics')
    parser.add_argument('--rows', type=int, default=0, choices=range(513), metavar='0..512',
                        help='seed a fixed narrow/variable-width result workload')
    parser.add_argument('--historical-result-profile', action='store_true',
                        help='validate the frozen pre-result-model console baseline explicitly')
    parser.add_argument('--binary-revision', help='source revision of the frozen binaries being measured')
    parser.add_argument('--representations', action='store_true',
                        help='run separate payload-only row/column LZ4/Zstd experiments after timing samples')
    parser.add_argument('--startup-restarts', type=int, choices=range(11), metavar='0..10',
                        help='measure fresh startup and this many retained restarts, with phase logs and verified readback')
    parser.add_argument('--startup-ui', action='store_true',
                        help='include Board in the installed startup/readback workload')
    parser.add_argument('--startup-debug', action='store_true',
                        help='attribute startup operations in a separate debug diagnostic run')
    args = parser.parse_args()
    if (args.startup_ui or args.startup_debug) and args.startup_restarts is None:
        parser.error('--startup-ui and --startup-debug require --startup-restarts')
    if args.startup_restarts is not None and (args.statements or args.rows or args.single or args.age_queries or args.representations or args.historical_result_profile or args.instrument or args.local_trace or args.remote_sql or args.repeat != 1):
        parser.error('--startup-restarts is a separate startup/readback workload')
    if args.cycles > 1 and (not args.statements or args.repeat != 1):
        parser.error('--cycles requires --statements --repeat 1')
    if args.warm_reads > 1 and (not args.statements or args.repeat != 1):
        parser.error('--warm-reads requires --statements --repeat 1')
    if args.resources and not args.statements:
        parser.error('--resources requires --statements')
    if args.local_trace and (not args.instrument or args.remote_sql):
        parser.error('--local-trace requires --instrument with co-hosted SQL')
    if args.statements and (args.rows or args.single or args.age_queries or args.representations or args.historical_result_profile):
        parser.error('--statements uses its own fixed workload; select only repetitions and instrumentation/owner overrides')
    if args.historical_result_profile and not args.binary_revision:
        parser.error('--historical-result-profile requires --binary-revision')
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Fixture(args.cli, args.node, args.host)
    if args.startup_ui:
        fixture.no_ui = False
        fixture.config['board'] = dict(port=fixture.reserve_port())
    success = False
    probes = {}
    try:
        # Freeze all selected executables for the measurement and retained identity.
        freeze_executables(fixture)
        binaries = {'cli': fixture.cli, **fixture.config['executables']}
        node = binaries['node']
        node_fields = {'resident_pages': args.resident_pages}
        if args.instrument and args.remote_sql:
            # Proxy only SQL's upstream requests. Interposing the node's public
            # port also captures bootstrap/self-traffic and can block recovery
            # behind idle upstream connections or the proxy's occupied port.
            probes['native'] = Probe(f"http://127.0.0.1:{fixture.config['ports']['node']}", native=True)
            if args.owner_metrics:
                node_fields['request_metrics'] = True
            override(fixture, 'sql_gateway', {'native_url': probes['native'].url})
        trace_path = fixture.root / 'local-trace.jsonl' if args.local_trace else None
        if trace_path is not None:
            fixture.config['logging'] = dict(level='debug', format='json')
        if args.startup_restarts is not None:
            fixture.config['logging'] = dict(level='debug' if args.startup_debug else 'info', format='json')
        override(fixture, 'node', node_fields, stderr_path=trace_path)
        override(fixture, 'query_host', {'interval_ms': args.worker_interval_ms,
                                       'idle_max_interval_ms': 0 if args.worker_interval_ms is not None else None})
        fixture.path.write_text(json.dumps(fixture.config))
        print(json.dumps({'binary_revision': args.binary_revision, 'driver_sha256': digest(__file__),
              'driver_helpers': {name: digest(ROOT / 'tests' / name) for name in (
                  'performance/console/statements.py', 'performance/console/resources.py',
                  'performance/console/startup.py', 'harness/local_installation.py',
                  'interfaces/installation/server.py',
                  'performance/mutations/mutation_latency.py', 'harness/http_probe.py',
                  'harness/processes.py', 'harness/sql_placement.py')},
              'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'source_diff_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT)).hexdigest(),
              'system': platform.platform(), 'machine': platform.machine(), 'logical_cpus': os.cpu_count(),
              'load_average': os.getloadavg(),
              'sample_method': 'fresh startup and retained restarts; launch/readiness observation timed separately from console verification' if args.startup_restarts is not None else 'persistent console; first external elapsed time includes connection startup' if args.statements else 'sequential post-bootstrap; no timing warmup; RSS sampled every 20 ms',
              'executables': {role: digest(path) for role, path in
              binaries.items()}, 'source_rows': args.rows, 'historical_result_profile': args.historical_result_profile, 'instrumented': args.instrument,
              'age_queries': args.age_queries, 'repeat': args.repeat, 'cycles': args.cycles, 'warm_reads': args.warm_reads, 'execution': 'server_session',
              'resource_snapshots': args.resources,
              'local_trace': args.local_trace,
              'startup_restarts': args.startup_restarts,
              'startup_ui': args.startup_ui,
              'startup_debug': args.startup_debug,
              'cache_condition': 'new process for each start; OS caches are not evicted' if args.startup_restarts is not None else 'post-bootstrap; later queries share the node cache',
              'probe_scope': ('SQL gateway HTTP upstream only' if args.remote_sql else 'co-hosted SQL typed attempts; no per-operation HTTP trace') if args.instrument else None,
              'owner_metrics': args.instrument and args.remote_sql and args.owner_metrics,
              'overrides': {'resident_pages': args.resident_pages,
                            'worker_interval_ms': args.worker_interval_ms}}), flush=True)
        if args.startup_restarts is not None:
            from performance.console.startup import run
            run(fixture, args.startup_restarts)
            success = True
            return
        fixture.start()
        fixture.ready()
        if args.instrument and not args.remote_sql:
            from harness.sql_placement import Probe as LocalProbe
            probes['local'] = LocalProbe(fixture)
        invalid = subprocess.run([fixture.cli, 'console', '--no-rc'],
                                 input='.timer on\nCREATE KV items (UTF8);', cwd=fixture.root,
                                 capture_output=True, text=True, timeout=30,
                                 env={'PATH': '/unavailable'})
        assert invalid.returncode == 1 and not invalid.stdout, invalid
        assert 'Time: ' in invalid.stderr and 'error: ' in invalid.stderr, invalid.stderr
        authority = [pid for pid in children(fixture.process.pid)
                     if command(pid).startswith(node + ' ') and '--maintain' not in command(pid)]
        assert len(authority) == 1, authority

        def cpu():
            fields = Path(f'/proc/{authority[0]}/stat').read_text().split()
            return sum(map(int, fields[13:15])) / os.sysconf('SC_CLK_TCK')

        def idle_sample(phase):
            before_cpu, before = cpu(), time.monotonic()
            counters = {name: probe.snapshot() for name, probe in probes.items()}
            time.sleep(3)
            print(json.dumps({'phase': phase, 'seconds': time.monotonic() - before,
                              'node_cpu_seconds': cpu() - before_cpu,
                              'attempts': {name: dict(probe.snapshot() - counters[name])
                                           for name, probe in probes.items()}}), flush=True)

        # Readiness permits requests while startup discovery may still run.
        # Keep this window distinct from idle after verified statement work.
        idle_sample('idle')

        script = fixture.root / 'measurement.sql'
        def execute(mode, sql):
            script.write_text('.timer on\n' + sql + '\n')
            return measured_run([fixture.cli, 'console', '--no-rc', '--format', mode,
                                 '-f', str(script)], fixture.root, node=authority[0])

        if args.statements:
            from performance.console.statements import run
            from performance.console.resources import snapshot
            run(fixture, args.repeat, probes,
                resource_observer=(lambda pid: snapshot(fixture.process.pid, pid)) if args.resources else None,
                cpu_observer=cpu, cycles=args.cycles, warm_reads=args.warm_reads)
            idle_sample('idle_after_statements')
            success = True
            return

        if args.rows:
            # Independent setup operations stay inside the compiler's statement
            # limit. The measured reads begin only after every seed is accepted.
            statements = ['CREATE TABLE result_latency (id INT64, body TEXT);']
            for start in range(0, args.rows, 20):
                values = ','.join("(%d,'%s')" % (i, 'v' * (32 + i % 96))
                                  for i in range(start, min(start + 20, args.rows)))
                statements.append('INSERT INTO result_latency VALUES ' + values + ';')
            code, stdout, stderr, _ = execute('json', '\n'.join(statements))
            assert code == 0, (stdout, stderr)
            commands = [json.loads(line)['completion'] for line in stdout.splitlines()]
            changed = sum(int(command['changed'] if args.historical_result_profile else command['counts']['changed'])
                          for command in commands)
            assert changed == args.rows, commands

        for _ in range(args.age_queries):
            code, _, stderr, _ = execute('table', 'SELECT * FROM items;')
            assert code == 0, stderr

        # Sequential queries expose warm/history behavior as well as presentation.
        queries = [('table', 'SELECT * FROM items;'),
                   ('table', 'SELECT * FROM items;'),
                   ('json', 'SELECT * FROM items;'),
                   ('table', 'SELECT COUNT(*) FROM items;')]
        if args.rows:
            queries = [
                ('table', 'SELECT id FROM result_latency;'),
                ('json', 'SELECT id, body FROM result_latency;'),
                ('json', 'SELECT id, COUNT(*) AS rows FROM result_latency GROUP BY id;'),
                ('table', 'DESCRIBE result_latency;'),
                ('json', 'DESCRIBE result_latency;'),
                ('json', 'SHOW TABLES;'),
            ]
        selected = queries[:1] if args.single else queries
        for index, (mode, sql) in enumerate(selected * args.repeat):
            before_cpu = cpu()
            counters = {name: probe.snapshot() for name, probe in probes.items()}
            code, stdout, stderr, measurements = execute(mode, sql)
            assert code == 0, stderr
            assert re.fullmatch(r'Time: \d+ ms \((?:[a-z]+ \d+ ms, )*[a-z]+ \d+ ms\)\n', stderr), stderr
            if mode == 'json':
                frames = [json.loads(line) for line in stdout.splitlines()]
                expected_profile = 'sql_session_v1' if args.historical_result_profile else 'sql_result_v1'
                assert frames[0]['profile'] == expected_profile, frames[0]
                assert frames[-1]['complete_coverage'], frames[-1]
                rows = [frame['row']['value']['structure'] for frame in frames if 'row' in frame]
                assert int(frames[-1]['rows']) == len(rows), frames[-1]
                if sql.startswith('SELECT') and args.rows:
                    if 'GROUP BY' in sql:
                        actual = sorted((int(row[0]['value']['atom']['signed']), int(row[1]['value']['atom']['unsigned'])) for row in rows)
                        assert actual == [(i, 1) for i in range(args.rows)], actual
                    else:
                        actual = sorted((int(row[0]['value']['atom']['signed']), row[1]['value']['atom']['utf8']) for row in rows)
                        assert actual == [(i, 'v' * (32 + i % 96)) for i in range(args.rows)], actual
                elif sql.startswith('DESCRIBE'):
                    assert len(rows) == 2, rows
                elif sql.startswith('SHOW'):
                    assert len(rows) >= 2, rows
                else:
                    assert not rows, rows
            else:
                expected = 2 if sql.startswith('DESCRIBE') else args.rows if args.rows else 1 if 'COUNT' in sql else 0
                assert stdout.startswith('┌') and stdout.endswith(f'{expected} rows; complete coverage\n'), stdout
                if not args.historical_result_profile:
                    assert stdout.count('┌') == 1 and stdout.count('└') == 1, stdout
            print(json.dumps({'phase': 'query', 'index': index, 'mode': mode, 'sql': sql, **measurements,
                              'node_cpu_seconds': cpu() - before_cpu,
                              'stdout_bytes': len(stdout.encode()), 'timing': stderr.strip(),
                              'attempts': {name: dict(probe.snapshot() - counters[name])
                                           for name, probe in probes.items()}}), flush=True)
        if args.rows:
            from interfaces.sql_sessions.measurements import local_batches
            config, definition = fixture.console_config(), fixture.record()['definition']
            for repeat in range(args.repeat):
                for sql, expected in (
                    ('SELECT id FROM result_latency;', args.rows),
                    ('SELECT id, body FROM result_latency;', args.rows),
                    ('SELECT id, COUNT(*) AS rows FROM result_latency GROUP BY id;', args.rows),
                    ('DESCRIBE result_latency;', 2),
                    ('SHOW TABLES;', None),
                ):
                    counters = {name: probe.snapshot() for name, probe in probes.items()}
                    measured = local_batches(config, definition, sql, expected_rows=expected,
                                             historical=args.historical_result_profile)
                    measured.update(repeat=repeat, attempts={name: dict(probe.snapshot() - counters[name])
                                                            for name, probe in probes.items()})
                    print(json.dumps(measured), flush=True)
            print(json.dumps(local_batches(config, definition, 'SELECT id, body FROM result_latency;',
                                           expected_rows=args.rows, historical=args.historical_result_profile,
                                           slow_ms=50)), flush=True)
            if args.representations:
                print(json.dumps(local_batches(config, definition, 'SELECT id, body FROM result_latency;',
                                               expected_rows=args.rows, historical=args.historical_result_profile,
                                               representation=representation_sample)), flush=True)
        success = True
    finally:
        fixture.cleanup()
        try:
            if args.local_trace and (success or (fixture.root / 'local-trace.jsonl').exists()):
                local_trace(fixture.root / 'local-trace.jsonl')
        except BaseException:
            success = False
            raise
        finally:
            for probe in probes.values():
                probe.close()
            if success:
                shutil.rmtree(fixture.root)
            else:
                print(f'Latency fixture retained at {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    main()
