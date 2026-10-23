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
from table_console import atom


def terminal(fixture, identity):
    deadline = time.monotonic() + 90
    while True:
        value = fixture.sql_session(dict(status=dict(operation=identity)))['operation']
        assert value['identity'] == identity
        if value['phase'] == 'terminal':
            return value
        assert time.monotonic() < deadline, value
        time.sleep(.1)


def pending(fixture, boundary, key):
    boundary.pause()
    process = subprocess.Popen([fixture.cli, 'console', '--no-rc', '--format', 'json'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        cwd=fixture.root, text=True, env={'PATH': '/unavailable'})
    process.stdin.write(f'INSERT INTO items (id,value) VALUES ({key},100);\n')
    process.stdin.flush()
    try:
        deadline = time.monotonic() + 60
        while not boundary.observed.exists():
            assert process.poll() is None and time.monotonic() < deadline, 'No direct execution attempt'
            time.sleep(.05)
        binding = json.loads(boundary.observed.read_text())
        # Status remains available in a newly opened native session while execution
        # is refused. The durable ledger and Table binding name the same work.
        values = fixture.sql_operations()
        matches = [entry for entry in values
                   if int(entry['identity']['id']) == binding['identity']['operation']]
        assert len(matches) == 1 and matches[0]['phase'] != 'terminal', values
        return matches[0]['identity'], binding
    finally:
        if process.poll() is None:
            process.kill()
        process.communicate(timeout=10)


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
        fixture.sql_session(dict(cancel=identity))
        value = terminal(fixture, identity)
        assert value['outcome'] == 'cancelled' and value['matched'] == value['changed'] == 0, value
        boundary.resume()
        fixture.stop()
        fixture.start()
        fixture.ready(timeout=300)
        assert terminal(fixture, identity)['outcome'] == 'cancelled'
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '1'
        fixture.stop()
        success = True
        print('Installed direct faults: control/read availability during blocked execution, killed caller, abrupt restart, exact recovery and durable cancellation passed.', flush=True)
    finally:
        boundary.resume()
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed direct fault evidence retained at {fixture.root}', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])
