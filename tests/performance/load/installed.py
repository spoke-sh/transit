"""Finite installed managed-work and connection-pressure measurements."""
import argparse
from contextlib import ExitStack, contextmanager
import ctypes
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import re
import secrets
import shutil
import socket
import subprocess
import sys
import time

from harness.local_installation import freeze_executables
from harness.sql_placement import Probe
from interfaces.installation.server import Fixture
from interfaces.sql_sessions.local import Client
from interfaces.sql_sessions.storage import text
from performance.console import resources
from runner.capture import directory, provenance
from runner.paths import ROOT

DRIVERS = ('performance/load/installed.py', 'performance/load/report.py',
           'performance/sdk/report.py', 'performance/console/resources.py',
           'harness/local_installation.py', 'harness/sql_placement.py', 'harness/processes.py',
           'harness/phases.py', 'harness/services.py', 'interfaces/installation/server.py',
           'interfaces/sql_sessions/local.py', 'interfaces/sql_sessions/native.py',
           'interfaces/sql_sessions/result_frame.py', 'interfaces/sql_sessions/storage.py',
           'interfaces/cli/table_console.py', 'interfaces/cli/console.py',
           'query/unified/unified_shell.py', 'runner/capture.py', 'runner/paths.py', 'runner/launch.py')


def digest(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def read(client, sql, maximum=1000):
    batch = client.execute(sql)['batch']
    cursor, rows = batch['cursor'], []
    try:
        while True:
            rows.extend(batch['rows'])
            assert len(rows) <= maximum, 'measurement result exceeded its bound'
            if batch['complete']:
                assert batch['completion']['rows'] == len(rows)
                return rows
            batch = client.call(dict(fetch=dict(cursor=cursor, batch=batch['batch'] + 1)))['batch']
    finally:
        client.call(dict(close_result=cursor))
        client.results.pop(tuple(cursor), None)


def integers(rows):
    result = []
    for row in rows:
        assert len(row) == 1
        raw = bytes.fromhex(row[0])
        assert len(raw) == 9 and raw[0] == 3
        result.append(int.from_bytes(raw[1:], 'little', signed=True))
    return sorted(result)


def process_snapshot(fixture):
    pids = resources.tree([fixture.process.pid])
    observed = [resources.process(pid, 'installation') for pid in sorted(pids)]
    assert resources.tree([fixture.process.pid]) == pids, 'installation changed during snapshot'
    return observed


def cpu_snapshot(fixture):
    result = {}
    for pid in resources.tree([fixture.process.pid]):
        value = Path(f'/proc/{pid}/stat').read_text()
        fields = value[value.rindex(')') + 2:].split()
        result[pid] = (resources.start_ticks(value), int(fields[11]) + int(fields[12]))
    return result


class Recorder:
    def __init__(self, file):
        self.file = file

    def emit(self, value):
        line = json.dumps(value)
        self.file.write(line + '\n')
        self.file.flush()
        print(line, flush=True)

    @contextmanager
    def sample(self, case, index=0, fixture=None, probe=None):
        record = dict(phase='sample', case=case, index=index, outcome='incomplete')
        before = probe.snapshot() if probe else None
        cpu = cpu_snapshot(fixture) if fixture else None
        started = time.perf_counter_ns()
        try:
            yield record
            record['elapsed_ns'] = time.perf_counter_ns() - started
            if probe:
                record['local_attempts'] = probe.delta(before)
            if fixture:
                after = cpu_snapshot(fixture)
                assert cpu.keys() == after.keys() and all(cpu[p][0] == after[p][0] for p in cpu), 'process changed during sample'
                ticks = sum(after[p][1] - cpu[p][1] for p in cpu)
                assert ticks >= 0
                record['installation_cpu_ns'] = ticks * 1_000_000_000 // os.sysconf('SC_CLK_TCK')
            record['outcome'] = 'complete'
        except BaseException as error:
            record.update(outcome='failed', error_type=type(error).__name__)
            raise
        finally:
            record.setdefault('elapsed_ns', time.perf_counter_ns() - started)
            self.emit(record)


def head(client):
    rows = read(client, 'SHOW DATAFLOW perf_projection', 1)
    assert len(rows) == 1 and len(rows[0]) == 1
    return json.loads(text(rows[0][0]))['observation']['head']


def settle(client, expected_revision, expected_rows, record):
    deadline = time.monotonic() + 180
    foreground = []
    pending = 0
    while True:
        observed = head(client)
        assert observed['blocked'] == 'none', 'managed execution was blocked'
        pending += int(observed['pending'] is not None)
        began = time.perf_counter_ns()
        assert integers(read(client, 'SELECT id FROM perf_input WHERE id = 0')) == [0]
        foreground.append(time.perf_counter_ns() - began)
        if observed['revision'] >= expected_revision and observed['pending'] is None:
            assert integers(read(client, 'SELECT id FROM perf_output')) == list(range(expected_rows))
            record.update(verified=True, rows=expected_rows, revision=observed['revision'],
                          foreground_ns=foreground, pending_observations=pending,
                          observation_polls=len(foreground))
            return observed['revision']
        assert time.monotonic() < deadline and len(foreground) < 2000, 'managed completion deadline exceeded'
        time.sleep(.05)


def managed(fixture, args, recorder):
    fixture.console('CREATE TABLE perf_input (id BIGINT PRIMARY KEY);\nCREATE TABLE perf_output (id BIGINT PRIMARY KEY);')
    for start in range(0, args.rows, 20):
        fixture.console('INSERT INTO perf_input VALUES ' + ','.join(f'({i})' for i in range(start, min(args.rows, start+20))) + ';')
    fixture.console('CREATE DATAFLOW perf_projection INTO perf_output AS SELECT id FROM perf_input;\nAUTHORIZE DATAFLOW perf_projection;')
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        probe = Probe(fixture)
        for index in range(args.repeat):
            with recorder.sample('foreground_baseline', index, fixture, probe) as sample:
                assert integers(read(client, 'SELECT id FROM perf_input WHERE id = 0')) == [0]
                sample['verified'] = True
        with recorder.sample('activation', fixture=fixture, probe=probe) as sample:
            fixture.console('ACTIVATE DATAFLOW perf_projection;')
            revision = settle(client, 1, args.rows, sample)
        for index in range(args.repeat):
            with recorder.sample('source_update', index, fixture, probe) as sample:
                fixture.console(f'INSERT INTO perf_input VALUES ({args.rows + index});')
                sample['submission_ns'] = time.perf_counter_ns()
                revision = settle(client, revision + 1, args.rows + index + 1, sample)
                # This starts after the source command returned, not at an inferred fsync.
                sample['after_source_return_ns'] = time.perf_counter_ns() - sample.pop('submission_ns')
        # No client observation inside this interval; maintenance remains enabled.
        with recorder.sample('idle', fixture=fixture, probe=probe) as sample:
            time.sleep(1)
            sample['verified'] = True
        recorder.emit(dict(phase='resources', case='settled', processes=process_snapshot(fixture)))
    finally:
        client.close()
    with recorder.sample('retained_restart') as sample:
        fixture.stop()
        started = time.perf_counter_ns()
        fixture.start()
        fixture.ready()
        sample['ready_ns'] = time.perf_counter_ns() - started
        client = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            assert integers(read(client, 'SELECT id FROM perf_output')) == list(range(args.rows + args.repeat))
            assert head(client)['revision'] >= revision
        finally:
            client.close()
        sample.update(verified=True, first_verified_ns=time.perf_counter_ns()-started)
    fixture.console('RETIRE DATAFLOW perf_projection;')


def configure_connections(fixture, args):
    password = secrets.token_hex(24)
    path = fixture.root / 'measurement.password'
    path.write_text(password)
    path.chmod(0o600)
    ports = dict(postgres=fixture.reserve_port(), mysql=fixture.reserve_port())
    fixture.config['sql'].update({name: dict(port=port) for name, port in ports.items()})
    fixture.config['sql']['accounts'] = [dict(name='measurement', role='local_owner', bootstrap_owner=True, password_file=str(path))]
    # Preserve ordinary connection/authentication/deadline defaults. Peer counts
    # deliberately straddle the default per-account bound (8) when requested.
    return password, ports


def connections(fixture, args, recorder, configured):
    import psycopg
    import mysql.connector
    password, ports = configured
    status = json.loads((fixture.installation / 'sql/status.json').read_text())
    ca = status['service']['ca_file']
    factories = {
        'postgres': lambda: psycopg.connect(host='localhost', hostaddr='127.0.0.1', port=ports['postgres'],
            user='measurement', password=password, dbname='transit', sslmode='verify-full', sslrootcert=ca,
            connect_timeout=10, autocommit=True),
        'mysql': lambda: mysql.connector.connect(host='localhost', port=ports['mysql'], user='measurement',
            password=password, database='transit', ssl_ca=ca, ssl_verify_cert=True, ssl_verify_identity=True,
            connection_timeout=10, read_timeout=30, write_timeout=30, autocommit=True, use_pure=True,
            charset='utf8mb4', collation='utf8mb4_0900_bin', sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'),
    }
    def query(connection):
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
            assert cursor.fetchall() == [(1,)]
    native = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        for protocol, connect in factories.items():
            for index in range(args.repeat):
                with recorder.sample(protocol + '_connect', index, fixture) as sample:
                    connection = connect()
                    try:
                        query(connection)
                        sample['verified'] = True
                    finally:
                        connection.close()
            with ExitStack() as peers:
                connection = connect()
                peers.callback(connection.close)
                for index in range(args.repeat):
                    with recorder.sample(protocol + '_warm', index, fixture) as sample:
                        query(connection)
                        sample['verified'] = True
                accepted, refused = 0, 0
                for index in range(args.peers):
                    with recorder.sample(protocol + '_idle_peer', index) as sample:
                        try:
                            peer = connect()
                        except (psycopg.Error, mysql.connector.Error) as error:
                            # Startup currently maps final-admission refusal to
                            # authentication SQLSTATE too. Retain that exact
                            # outcome; do not claim it proves capacity exhaustion.
                            state = getattr(error, 'sqlstate', None)
                            if state not in ('53000', '53300', '28000', '28P01'):
                                raise
                            refused += 1
                            sample.update(verified=True, admitted=False, sqlstate=state)
                        else:
                            peers.callback(peer.close)
                            query(peer)
                            accepted += 1
                            sample.update(verified=True, admitted=True)
                recorder.emit(dict(phase='resources', case=protocol + '_idle', admitted=accepted,
                                   refused=refused, processes=process_snapshot(fixture)))
                for index in range(args.repeat):
                    with recorder.sample(protocol + '_loaded', index, fixture) as sample:
                        query(connection)
                        sample['verified'] = True
                    with recorder.sample(protocol + '_control', index, fixture) as sample:
                        native.call(dict(operations=dict(after=0)))
                        sample['verified'] = True
            # Bound partial startup peers separately from authenticated sessions.
            with ExitStack() as partial:
                for _ in range(min(args.peers, 3)):
                    peer = partial.enter_context(socket.create_connection(('127.0.0.1', ports[protocol]), timeout=5))
                    peer.sendall(b'\x00')
                with recorder.sample(protocol + '_partial_control', fixture=fixture) as sample:
                    native.call(dict(operations=dict(after=0)))
                    sample['verified'] = True
        recorder.emit(dict(phase='resources', case='after_peers', processes=process_snapshot(fixture)))
    finally:
        native.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('cli', 'node', 'host'):
        parser.add_argument('--'+name, type=Path, required=True)
    parser.add_argument('--binary-revision', required=True)
    parser.add_argument('--profile', choices=('managed', 'connections'), required=True)
    parser.add_argument('--repeat', type=int, choices=range(1, 101), default=3)
    parser.add_argument('--rows', type=int, choices=range(1, 901), default=16)
    parser.add_argument('--peers', type=int, choices=range(1, 17), default=4)
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.binary_revision):
        parser.error('--binary-revision must be the full source commit')
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    evidence = directory(ROOT / '.cache/performance/installed/campaign.json') / 'observations.jsonl'
    print(f'Installed measurement: {evidence}', file=sys.stderr)
    fixture, success = None, False
    with evidence.open('x') as file:
        recorder = Recorder(file)
        recorder.emit(dict(phase='campaign', outcome='started'))
        try:
            fixture = Fixture(args.cli, args.node, args.host)
            freeze_executables(fixture)
            configured = configure_connections(fixture, args) if args.profile == 'connections' else None
            fixture.path.write_text(json.dumps(fixture.config))
            version = subprocess.check_output([fixture.cli, '--version'], text=True).strip()
            assert args.binary_revision in version and 'dirty' not in version, 'build a clean attributed measurement binary'
            recorder.emit(dict(phase='manifest', profile=args.profile, rows=args.rows, repeat=args.repeat, peers=args.peers,
                source=provenance(ROOT), binary_revision=args.binary_revision, cli_version=version,
                binaries={role: digest(path) for role, path in dict(cli=fixture.cli, **fixture.config['executables']).items()},
                drivers={path: digest(ROOT/'tests'/path) for path in DRIVERS},
                system=platform.platform(), machine=platform.machine(), cpus=os.cpu_count(), load=os.getloadavg(),
                host_id=digest('/proc/sys/kernel/random/boot_id'), storage_device=fixture.root.stat().st_dev,
                toolchain=subprocess.check_output(['zig', 'version'], text=True).strip(),
                maintenance='enabled', durability='native-local synchronous', cache='OS and server retained; no eviction',
                build_mode='ReleaseSafe', tls='required; verified generated local CA' if configured else 'native Unix peer',
                client_versions=dict(python=platform.python_version(), **{
                    name: importlib.metadata.version(name) for name in
                    (('psycopg', 'mysql-connector-python') if configured else ())}),
                sql_limits=dict(request_timeout_ms=5000, command_ms=30000, connections=64,
                                connections_per_account=8, authentications=4),
                instrumentation='typed attempt and procfs snapshots outside timers; includes background work',
                allocations=None, copies=None, bounds=dict(result_rows=1000, observation_seconds=180, polls=2000)))
            with recorder.sample('startup') as sample:
                fixture.start()
                fixture.ready()
                sample.update(verified=True, definition=fixture.record()['definition'])
            if args.profile == 'managed':
                managed(fixture, args, recorder)
            else:
                connections(fixture, args, recorder, configured)
            success = True
        finally:
            try:
                if fixture:
                    fixture.cleanup()
                    if success:
                        shutil.rmtree(fixture.root)
            except BaseException:
                success = False
                raise
            finally:
                if fixture and not success:
                    print(f'Failed installation retained at {fixture.root}', file=sys.stderr)
                recorder.emit(dict(phase='campaign', outcome='complete' if success else 'failed'))


if __name__ == '__main__':
    main()
