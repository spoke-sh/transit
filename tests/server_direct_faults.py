"""Installed direct writes retain identity across blocked execution and restart."""
import ctypes
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from server_direct_boundary import FaultFixture
from table_console import atom, records


def terminal(fixture, identity):
    deadline = time.monotonic() + 90
    while True:
        value = fixture.sql_session(dict(status=dict(operation=identity)))['operation']
        assert value['identity'] == identity
        if value['phase'] == 'terminal':
            return value
        assert time.monotonic() < deadline, value
        time.sleep(.1)


def pending(fixture, boundary, key=None, *, sql=None):
    boundary.pause()
    # Keep the caller alive throughout the 60-second dispatch-observation
    # window; this proof kills it after capturing its original binding.
    connection = fixture.console_config()
    connection['request_timeout_ms'] = 120000
    path = fixture.root / 'fault-console-connection.json'
    path.write_text(json.dumps(connection))
    process = subprocess.Popen([fixture.cli, 'console', '--no-rc', '--format', 'json', '--config', str(path)],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        cwd=fixture.root, text=True, env={'PATH': '/unavailable'})
    process.stdin.write((sql or f'INSERT INTO items (id,value) VALUES ({key},100)') + ';\n')
    process.stdin.flush()
    captured = False
    try:
        deadline = time.monotonic() + 60
        while not boundary.observed.exists():
            assert process.poll() is None and time.monotonic() < deadline, 'No direct execution attempt'
            time.sleep(.05)
        binding = json.loads(boundary.observed.read_text())
        # Status remains available in a newly opened native session while execution
        # is refused. The durable ledger and Table binding name the same work.
        values = fixture.sql_operations()
        original = binding['identity']['operation'] if 'identity' in binding else binding['operation']
        matches = [entry for entry in values if int(entry['identity']['id']) == original]
        assert len(matches) == 1 and matches[0]['phase'] != 'terminal', values
        captured = True
        return matches[0]['identity'], binding
    finally:
        if process.poll() is None:
            process.kill()
        stdout, stderr = process.communicate(timeout=10)
        if not captured:
            print(f'Unobserved direct caller exit: {process.returncode}', file=sys.stderr)
            print('Unobserved direct caller stdout:', stdout, file=sys.stderr)
            print('Unobserved direct caller stderr:', stderr, file=sys.stderr)


def run(cli, node, host, board, gateway):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = FaultFixture(cli, node, host)
    boundary = fixture.boundary
    success = False
    print(f'Direct installed fault proof: {fixture.root}', flush=True)
    try:
        fixture.start()
        fixture.ready(timeout=300)
        identity, binding = pending(fixture, boundary, 1)
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '0'
        fixture.stop(kill=True)
        boundary.observed.unlink()
        fixture.start()
        fixture.ready(timeout=300)
        value = fixture.sql_session(dict(status=dict(operation=identity)))['operation']
        assert value['identity'] == identity and value['phase'] != 'terminal', value
        assert json.loads(boundary.observed.read_text()) == binding
        boundary.resume()
        fixture.sql_session(dict(resume=identity))
        value = terminal(fixture, identity)
        assert value['outcome'] == 'applied' and value['matched'] == value['changed'] == 1, value
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '1'
        identity, _ = pending(fixture, boundary, 2)
        fixture.sql_session(dict(cancel=dict(operation=identity)))
        value = terminal(fixture, identity)
        assert value['outcome'] == 'cancelled' and value['matched'] == value['changed'] == 0, value
        boundary.resume()
        fixture.stop()
        fixture.start()
        fixture.ready(timeout=300)
        assert terminal(fixture, identity)['outcome'] == 'cancelled'
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '1'
        schema_identity, schema_binding = pending(fixture, boundary, sql='CREATE SCHEMA recovered_namespace')
        assert 'recovered_namespace' not in {row['schema'] for row in records(fixture.console('SHOW SCHEMAS;\n')[-1])}
        fixture.stop(kill=True)
        boundary.observed.unlink()
        fixture.start()
        fixture.ready(timeout=300)
        assert json.loads(boundary.observed.read_text()) == schema_binding
        boundary.resume()
        fixture.sql_session(dict(resume=schema_identity))
        value = terminal(fixture, schema_identity)
        assert value['outcome'] == 'applied' and value['matched'] == value['changed'] == 0, value
        assert 'recovered_namespace' in {row['schema'] for row in records(fixture.console('SHOW SCHEMAS;\n')[-1])}
        cancelled_schema, _ = pending(fixture, boundary, sql='DROP SCHEMA recovered_namespace')
        fixture.sql_session(dict(cancel=dict(operation=cancelled_schema)))
        assert terminal(fixture, cancelled_schema)['outcome'] == 'cancelled'
        boundary.resume()
        assert 'recovered_namespace' in {row['schema'] for row in records(fixture.console('SHOW SCHEMAS;\n')[-1])}
        fixture.stop()
        success = True
        print('Installed direct faults: Table and namespace control/read availability during blocked execution, killed caller, abrupt restart, exact recovery and durable cancellation passed.', flush=True)
    finally:
        boundary.resume()
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed direct fault evidence retained at {fixture.root}', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])
