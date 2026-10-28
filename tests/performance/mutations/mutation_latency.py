#!/usr/bin/env python3
"""Owned durable Table latency experiment; failures retain recovery evidence."""
import argparse
from collections import defaultdict
import ctypes
import json
import math
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import threading
import time

from performance.console.console_latency import digest, override
from harness import http_probe
from harness.processes import children
from interfaces.installation.server import Fixture
from storage.providers.pages import metrics, sample_process
from interfaces.cli.table_console import results as table_results, atom
from harness.services import free_port


class Console:
    """One persistent process, bounded simultaneous stdout/stderr draining."""
    def __init__(self, fixture, config=None, executable=None, mode='json'):
        self.mode = mode
        args = ([executable, str(config)] if executable else
                [fixture.cli, 'console', '--no-rc', '--format', mode,
                 *(['--config', str(config)] if config else [])])
        self.process = subprocess.Popen(args, cwd=fixture.root, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        env={'PATH': '/unavailable'})
        self.buffers = [bytearray(), bytearray()]
        if not executable:
            self.process.stdin.write(b'.timer on\n')
            self.process.stdin.flush()

    def call(self, sql):
        started = time.monotonic_ns()
        self.last_measurement = {'elapsed_ns': 0, 'timing': None}
        self.process.stdin.write((sql.rstrip(';') + ';\n').encode())
        self.process.stdin.flush()
        output = timing = failure = None
        phases = None
        query_frames = []
        table_lines = []
        with selectors.DefaultSelector() as selector:
            for index, pipe in enumerate((self.process.stdout, self.process.stderr)):
                selector.register(pipe, selectors.EVENT_READ, index)
            while output is None or timing is None:
                self.last_measurement['elapsed_ns'] = time.monotonic_ns() - started
                if time.monotonic_ns() - started > 330_000_000_000:
                    raise TimeoutError('mutation caller exceeded deadline; outcome unknown')
                for key, _ in selector.select(.1):
                    data = os.read(key.fileobj.fileno(), 65536)
                    if not data:
                        self.last_measurement['elapsed_ns'] = time.monotonic_ns() - started
                        if failure is not None:
                            raise RuntimeError(failure)
                        raise RuntimeError('caller exited before complete result: ' + self.buffers[1].decode())
                    self.buffers[key.data].extend(data)
                    if len(self.buffers[key.data]) > 2 * 1024 * 1024:
                        raise ValueError('caller output bound')
                for index in (0, 1):
                    while b'\n' in self.buffers[index]:
                        line, _, rest = self.buffers[index].partition(b'\n')
                        self.buffers[index] = bytearray(rest)
                        if index == 0:
                            if output is not None:
                                raise ValueError('unexpected multiple result pages')
                            if getattr(self, 'mode', 'json') == 'table':
                                table_lines.append(line.decode())
                                if len(table_lines) > 140:
                                    raise ValueError('benchmark table row budget exceeded')
                                if (re.fullmatch(rb'\d+ rows; complete coverage', line) or
                                        line.startswith(b'Statement completed.')):
                                    output = '\n'.join(table_lines) + '\n'
                                continue
                            value = json.loads(line)
                            if query_frames or value.get('profile') == 'sql_result_v1':
                                query_frames.append(value)
                                if len(query_frames) > 130:
                                    raise ValueError('benchmark query row budget exceeded')
                                if value.get('complete_coverage'):
                                    decoded = table_results(query_frames)
                                    assert len(decoded) == 1, decoded
                                    output = decoded[0]
                            else:
                                output = value
                        elif line.startswith(b'{'):
                            diagnostic = json.loads(line)
                            if 'timing' in diagnostic:
                                timing = line.decode()
                                phases = diagnostic['timing']['phases']
                                self.last_measurement.update(elapsed_ns=time.monotonic_ns() - started,
                                                             timing=timing, phase_ms=phases)
                            else:
                                # Keep only fixed diagnostic categories. Facts,
                                # source text and operation identities stay in
                                # the original local recovery evidence.
                                failure = diagnostic['code']
                                for field in ('code', 'cause', 'outcome', 'stage'):
                                    self.last_measurement[field] = diagnostic.get(field)
                                for fact in diagnostic.get('facts', []):
                                    if fact and fact['field'] == 'native_cause' and fact.get('value'):
                                        self.last_measurement['native_cause'] = fact['value']['text']
                        elif line.startswith(b'Time: '):
                            timing = line.decode()
                            phases = {key: int(value) for key, value in re.findall(r'(\w+) (\d+) ms', timing)}
                            self.last_measurement.update(elapsed_ns=time.monotonic_ns() - started, timing=timing, phase_ms=phases)
                        elif line:
                            # A human diagnostic spans several lines and can
                            # precede its deferred timing line. Keep only the
                            # fixed cause category, never identities or facts.
                            failure = failure or line.decode()
                            cause = re.fullmatch(rb'Cause: ([A-Za-z0-9_]+)\.', line)
                            if cause:
                                self.last_measurement['cause'] = cause[1].decode()
                            native = re.fullmatch(rb'NativeCause: ([A-Za-z0-9_]+)\.', line)
                            if native:
                                self.last_measurement['native_cause'] = native[1].decode()
                if failure is not None and timing is not None:
                    self.last_measurement['elapsed_ns'] = time.monotonic_ns() - started
                    raise RuntimeError(failure)
        return output, {'elapsed_ns': time.monotonic_ns() - started, 'timing': timing,
                        'phase_ms': phases}

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=10)
        self.process.stdout.close()
        self.process.stderr.close()


def distribution(values):
    ordered = sorted(values)
    result = {'samples': len(ordered), 'min_ms': ordered[0] / 1e6,
              'max_ms': ordered[-1] / 1e6}
    # Nearest rank, explicitly empirical. Small runs must not masquerade as tails.
    for label, fraction, minimum in [('p50', .5, 2), ('p95', .95, 20), ('p99', .99, 100)]:
        result[label + '_ms'] = ordered[math.ceil(fraction * len(ordered)) - 1] / 1e6 if len(ordered) >= minimum else None
    return result


def schema_profile(name):
    """Synthetic wider storage controls; the original narrow fixture is unchanged."""
    def text_cell(value):
        return {'value': {'atom': {'utf8': value}}}
    if name == 'narrow':
        return None, []
    if name == 'wide':
        values = [f'column-{index:02}-' + 'x' * 54 for index in range(30)]
        columns = [f"c{index} UTF8 NOT NULL DEFAULT '{value}'" for index, value in enumerate(values)]
        expected = [text_cell(value) for value in values]
    elif name == 'nested':
        label = 'nested-' + 'y' * 121
        values = [None if index % 8 == 0 else f'tag-{index:02}-' + 'z' * 42 for index in range(32)]
        literals = ','.join('NULL' if value is None else f"'{value}'" for value in values)
        columns = [f"payload STRUCT(label UTF8, tags LIST(UTF8)) DEFAULT STRUCT('{label}',LIST({literals}))"]
        expected = [{'value': {'structure': [text_cell(label), {'value': {'list': [
            {'null': {}} if value is None else text_cell(value) for value in values]}}]}}]
    else:
        raise ValueError('unknown synthetic schema profile')
    return 'CREATE TABLE items (id INT64 PRIMARY KEY, value INT64, ' + ','.join(columns) + ')', expected


def completion_timeline(events, started, completed, principal=10):
    """Correlate only fixed native identities, never decode SQL/value payloads.

    These are proxy request/response observations, not fsync or commit instants.
    A worker/caller read can finish before the commit receipt reaches its sender.
    Missing or ambiguous evidence remains explicitly incomplete.
    """
    observed = [e for e in events if e.get('response_ns', -1) >= started
                and e.get('response_ns', completed + 1) <= completed and e.get('status') == 200]
    sends = [e for e in observed if e.get('operation') == 'update:send'
             and e.get('principal') == principal]
    if len(sends) != 1:
        return {'complete': False, 'reason': 'missing_or_multiple_admissions'}
    send = sends[0]
    same = [e for e in observed if e.get('pid') == send['pid'] and e.get('input') == send['position']]
    views = [e for e in same if e.get('operation') == 'update:open_view']
    turns = [e for e in same if e.get('operation') in ('update:turn', 'update:turn_with_versions')]
    if len(views) != 1 or len(turns) != 1:
        return {'complete': False, 'reason': 'missing_or_multiple_worker_stages'}
    view, turn = views[0], turns[0]
    reads = [e for e in observed if e.get('operation') == 'read:process'
             and e.get('principal') == principal and e.get('pid') == send['pid']
             and e.get('position', 0) >= send['position']
             and 'head_input' in e and (e['head_input'] is None or e['head_input'] > send['position'])]
    if not reads:
        return {'complete': False, 'reason': 'missing_processed_observation'}
    read = min(reads, key=lambda e: e['response_ns'])
    def stage(event):
        return {'start_ns': event['start_ns'] - started,
                'response_ns': event['response_ns'] - started,
                'work': event.get('work')}
    return {'complete': True, 'admission': stage(send), 'view': stage(view), 'turn': stage(turn),
            'processed_observed_ns': read['response_ns'] - started,
            'caller_complete_ns': completed - started,
            'after_turn_receipt_ns': max(0, read['response_ns'] - turn['response_ns']),
            'observation_precedes_turn_receipt': read['response_ns'] < turn['response_ns'],
            'after_processed_observation_ns': completed - read['response_ns'],
            'caller_process_reads': sum(e.get('operation') == 'read:process' and e.get('principal') == principal for e in observed),
            'caller_wait_requests': sum(e.get('operation') == 'read:process' and e.get('principal') == principal and e.get('wait_hint', False) for e in observed)}


def supervisor_evidence(root):
    """Retain bounded fixed restart causes even when the workload completes."""
    path = root / 'manager-0.stderr'
    if not path.exists():
        return {'available': False, 'truncated': False, 'restarts': []}
    with path.open('rb') as log:
        data = log.read(65537)
    known = {'AuthorityTimeout', 'AuthorityUnavailable', 'ChildExited',
             'ColdBucketCreationFailed', 'HttpConnectionClosing', 'HttpCapacity',
             'RoleReadinessTimeout'}
    causes = re.findall(rb'^error: server role failed; retrying the same installation: ([A-Za-z0-9_]{1,64})$',
                        data[:65536], re.M)
    return {'available': True, 'truncated': len(data) > 65536 or len(causes) > 4,
            'restarts': [cause.decode() if cause.decode() in known else 'other' for cause in causes[:4]]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('cli', 'node', 'host'):
        parser.add_argument(name)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeat', type=int, default=3, choices=range(1001),
                        help='mutation repetitions; zero selects only read controls after setup')
    parser.add_argument('--schema-profile', choices=('narrow', 'wide', 'nested'), default='narrow')
    parser.add_argument('--rows', type=int, default=0, choices=range(100001))
    parser.add_argument('--age', type=int, default=0, choices=range(100001), help='extra retained mutations at fixed row cardinality')
    parser.add_argument('--resident-pages', type=int, choices=range(1025))
    parser.add_argument('--worker-interval-ms', type=int, choices=range(1, 60001))
    parser.add_argument('--idle-ms', type=int, default=0, choices=range(60001))
    parser.add_argument('--instrument', action='store_true')
    parser.add_argument('--native-metrics', action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument('--build-revision', help='declared build source; binary hashes remain authoritative')
    parser.add_argument('--readers', type=int, default=0, choices=range(5))
    parser.add_argument('--read-repeat', type=int, default=0, choices=range(1001),
                        help='independently verified point/range/full/empty read controls after mutations')
    parser.add_argument('--client', help='persistent public Zig caller executable (no console rendering)')
    args = parser.parse_args()
    if args.repeat == 0 and args.read_repeat == 0:
        parser.error('select mutation repetitions or read controls')
    if args.client and args.schema_profile != 'narrow':
        parser.error('wide/nested profiles require the typed console verifier')
    if args.read_repeat and not 8 <= args.rows <= 120:
        parser.error('read controls require 8..120 seed rows within the owned console output budget')
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    report = {'status': 'running', 'samples': [], 'errors': [], 'unknown_outcomes': 0,
              'reader_queries': [0] * args.readers, 'reader_failures': [],
              'controls': {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
              'caller': 'client' if args.client else 'console',
              'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              'source_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'])),
              'driver_sha256': digest(__file__),
              'probe_sha256': digest(http_probe.__file__),
              'clock': 'monotonic_ns', 'percentiles': 'empirical nearest rank; p95 requires 20, p99 requires 100 samples per case'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    def save():
        temp = args.output.with_suffix('.tmp')
        temp.write_text(json.dumps(report, indent=2) + '\n')
        temp.replace(args.output)
    save()
    fixture = Fixture(args.cli, args.node, args.host)
    report['fixture'] = str(fixture.root)
    save()
    probes, shells, threads, reader_errors = {}, [], [], []
    stop = threading.Event()
    try:
        for role in ('node', 'query_host'):
            frozen = fixture.root / role
            shutil.copy2(fixture.config['executables'][role], frozen)
            fixture.config['executables'][role] = str(frozen)
        report['executables'] = {role: digest(path) for role, path in {'cli': fixture.cli, **fixture.config['executables']}.items()}
        memory_targets = {str(Path(path).resolve()): role for role, path in fixture.config['executables'].items()}
        def observe_memory():
            # Read outside timed requests. HWM is a process lifetime observation,
            # not an allocator bound or the sum of simultaneous process RSS.
            observed = {}
            for pid in children(fixture.process.pid):
                try:
                    role = memory_targets.get(str(Path(f'/proc/{pid}/exe').resolve(strict=True)))
                except (FileNotFoundError, ProcessLookupError):
                    continue
                if role:
                    sample_process(pid, observed.setdefault(role, metrics()))
            return observed
        if args.client:
            frozen = fixture.root / 'mutation-client'
            shutil.copy2(args.client, frozen)
            args.client = str(frozen)
            report['executables']['client'] = digest(frozen)
        fields = {'resident_pages': args.resident_pages}
        gate = fixture.root / 'probe-gate' if args.instrument else None
        if args.instrument:
            real_port = free_port()
            fields.update(port=real_port)
            if args.native_metrics:
                fields['request_metrics'] = True
        override(fixture, 'node', fields, gate)
        override(fixture, 'query_host', {'interval_ms': args.worker_interval_ms,
                 'idle_max_interval_ms': 0 if args.worker_interval_ms is not None else None})
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        if gate:
            deadline = time.monotonic() + 90
            while not gate.exists():
                assert fixture.process.poll() is None, 'fixture exited during startup'
                assert time.monotonic() < deadline, 'measurement gate timeout'
                time.sleep(.02)
            probes['native'] = http_probe.Probe(f'http://127.0.0.1:{real_port}', fixture.config['ports']['node'], native=True)
            Path(str(gate) + '.ready').touch()
        fixture.ready()
        config = fixture.root / 'reader.json'
        config.write_text(json.dumps(fixture.console_config()))
        verifier = Console(fixture, config)
        shells.append(verifier)
        writer_config = None
        if args.client:
            writer_config = fixture.root / 'client.json'
            writer_config.write_text(json.dumps({'url': fixture.url, 'seed_file': str(fixture.installation / 'caller.seed'),
                'connection': fixture.record()['default_table']['connection']}))
        writer = Console(fixture, writer_config, args.client)
        shells.append(writer)
        creation, expected_extra = schema_profile(args.schema_profile)
        report['schema_profile'] = {'name': args.schema_profile, 'columns': 2 + len(expected_extra),
                                    'creation_sql': creation, 'setup': []}
        if creation:
            for statement in ('DROP TABLE items', creation):
                try:
                    result, measurement = writer.call(statement)
                except Exception:
                    report['unknown_outcomes'] += 1
                    report['failed_sample'] = {'case': 'schema_setup', **writer.last_measurement}
                    raise
                assert result['completion']['outcome'] in ('applied', 'unchanged'), result
                assert result['completion']['pending_restart'] is False, result
                report['schema_profile']['setup'].append(measurement)
                save()

        def mutate(sql, affected, case=None):
            if case and args.idle_ms:
                time.sleep(args.idle_ms / 1000)
            before = {name: probe.snapshot() for name, probe in probes.items()}
            native = probes.get('native')
            started = time.monotonic_ns() - native.started_ns if native else None
            try:
                result, measurement = writer.call(sql)
            except Exception:
                report['unknown_outcomes'] += 1
                report['failed_sample'] = {'case': case, **writer.last_measurement, 'attempts': {name: dict(probe.snapshot() - before[name]) for name, probe in probes.items()}}
                raise
            completed = time.monotonic_ns() - native.started_ns if native else None
            changed = 0 if case == 'update_same' else affected
            if args.client:
                outcome = result['direct_table']['rows']['committed']['outcome']
                assert (outcome['matched'], outcome['affected']) == (str(affected), str(changed)), result
            else:
                outcome = result['completion']
                assert outcome['outcome'] in ('applied', 'unchanged') and outcome['pending_restart'] is False, result
                assert (outcome['counts']['matched'], outcome['counts']['changed']) == (str(affected), str(changed)), result
            if case:
                if native:
                    measurement['completion_timeline'] = completion_timeline(native.trace()['retained'], started, completed)
                report['samples'].append({'case': case, **measurement,
                    'attempts': {name: dict(probe.snapshot() - before[name]) for name, probe in probes.items()}})
                save()

        # Positive seed keys never overlap the measured negative keys.
        for offset in range(0, args.rows, 3):
            keys = range(offset + 1, min(offset + 4, args.rows + 1))
            mutate('INSERT INTO items (id,value) VALUES ' + ','.join(f'({key},100)' for key in keys), len(keys))
        mutate('INSERT INTO items (id,value) VALUES (0,100)', 1)
        for index in range(args.age):
            mutate(f'UPDATE items SET value={index} WHERE id=0', 1)
        idle_before = {name: probe.snapshot() for name, probe in probes.items()}
        time.sleep(1)
        report['idle_attempts'] = {name: dict(probe.snapshot() - idle_before[name]) for name, probe in probes.items()}
        report['resident_before'] = observe_memory()
        reader_counts = report['reader_queries']
        def read(index):
            shell = None
            try:
                path = fixture.root / f'reader-{index}.json'
                # Each reader owns its console process and server SQL session.
                path.write_text(json.dumps(fixture.console_config()))
                shell = Console(fixture, path)
                while not stop.is_set():
                    value, _ = shell.call('SELECT COUNT(*) FROM items;')
                    count = int(atom(value, 'unsigned'))
                    assert args.rows + 1 <= count <= args.rows + 4, count
                    reader_counts[index] += 1
            except Exception as error:
                reader_errors.append(str(error))
                measurement = getattr(shell, 'last_measurement', {})
                report['reader_failures'].append({'reader': index, **{
                    field: measurement[field] for field in ('elapsed_ns', 'phase_ms', 'code', 'cause', 'outcome', 'stage', 'native_cause')
                    if field in measurement}})
            finally:
                if shell:
                    shell.close()
        for index in range(args.readers):
            thread = threading.Thread(target=read, args=(index,))
            thread.start()
            threads.append(thread)
        for _ in range(args.repeat):
            for case, sql, count in [
                ('insert_1', 'INSERT INTO items (id,value) VALUES (-1,100)', 1),
                ('update_1', 'UPDATE items SET value=200 WHERE id=-1', 1),
                ('update_same', 'UPDATE items SET value=200 WHERE id=-1', 1),
                ('update_absent', 'UPDATE items SET value=200 WHERE id=-9', 0),
                ('delete_1', 'DELETE FROM items WHERE id=-1', 1),
                ('delete_absent', 'DELETE FROM items WHERE id=-1', 0),
                ('insert_3', 'INSERT INTO items (id,value) VALUES (-1,1),(-2,2),(-3,3)', 3),
            ]:
                mutate(sql, count, case)
                # Public independent read of the selected row, outside timing.
                value, _ = verifier.call('SELECT * FROM items WHERE id=-1;')
                expected = [] if case.startswith('delete') else [1 if case == 'insert_3' else 100 if case == 'insert_1' else 200]
                assert [int(row[1]['value']['atom']['signed']) for row in value['rows']] == expected, value
                assert all(row[2:] == expected_extra for row in value['rows']), value
            for key in (-1, -2, -3):
                mutate(f'DELETE FROM items WHERE id={key}', 1)
        value, _ = verifier.call('SELECT COUNT(*) FROM items;')
        assert int(atom(value, 'unsigned')) == args.rows + 1, value
        stop.set()
        for thread in threads:
            thread.join(timeout=340)
            assert not thread.is_alive(), 'reader did not stop'
        assert not reader_errors, reader_errors
        report['reader_queries'] = reader_counts
        if args.read_repeat:
            report['read_samples'] = []
            report['read_order'] = 'Unordered selection; the oracle sorts rows after timing.'
            for _ in range(args.read_repeat):
                for case, sql, keys in (
                    ('point', 'SELECT * FROM items WHERE id=1', [1]),
                    ('range', 'SELECT * FROM items WHERE id>=1 AND id<=8', list(range(1, 9))),
                    ('full', 'SELECT * FROM items', list(range(args.rows + 1))),
                    ('empty', 'SELECT * FROM items WHERE id=-9', []),
                    ('limit_zero', 'SELECT * FROM items LIMIT 0', []),
                ):
                    before = {name: probe.snapshot() for name, probe in probes.items()}
                    value, measurement = verifier.call(sql)
                    rows = sorted(value['rows'], key=lambda row: int(row[0]['value']['atom']['signed']))
                    assert [int(row[0]['value']['atom']['signed']) for row in rows] == keys, value
                    for key, row in zip(keys, rows, strict=True):
                        expected_value = args.age - 1 if key == 0 and args.age else 100
                        assert int(row[1]['value']['atom']['signed']) == expected_value, value
                        assert row[2:] == expected_extra, value
                    report['read_samples'].append({'case': case, **measurement,
                        'attempts': {name: dict(probe.snapshot() - before[name]) for name, probe in probes.items()}})
                    save()
            reads = defaultdict(list)
            for sample in report['read_samples']:
                reads[sample['case']].append(sample['elapsed_ns'])
            report['read_distributions'] = {key: distribution(values) for key, values in reads.items()}
        grouped = defaultdict(list)
        for sample in report['samples']:
            grouped[sample['case']].append(sample['elapsed_ns'])
        report['distributions'] = {key: distribution(values) for key, values in grouped.items()}
        report['resident_after'] = observe_memory()
        report['resident_limits'] = 'Outside timed requests: Linux process HWM and maxima across same-role children; not summed RSS, exact allocations or a cardinality-independent provider bound.'
        report['status'] = 'complete'
    except BaseException as error:
        report['status'] = 'failed'
        report['errors'].append(f'{type(error).__name__}: {error}')
        raise
    finally:
        stop.set()
        for shell in shells:
            shell.close()
        for thread in threads:
            thread.join(timeout=340)
        fixture.cleanup()
        report['supervisor'] = supervisor_evidence(fixture.root)
        for probe in probes.values():
            probe.close()
        if 'native' in probes:
            report['native_trace'] = probes['native'].trace()
        save()
        if report['status'] == 'complete':
            shutil.rmtree(fixture.root)
        else:
            print('Retained owned failure evidence: ' + str(fixture.root), flush=True)
    print(json.dumps({'report': str(args.output), 'status': report['status'], 'distributions': report['distributions']}), flush=True)


if __name__ == '__main__':
    main()
