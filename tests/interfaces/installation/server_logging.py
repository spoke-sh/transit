"""Real terminal/piped server logging and standalone service failure boundaries."""
import ctypes
import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import socket
import subprocess
import sys
import time

from harness.processes import children
from interfaces.installation.server import Fixture
from harness.local_installation import freeze_executables
from interfaces.installation.server_sql import wait_status

TEXT = re.compile(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z (DEBUG|INFO|WARN|ERROR) \[[a-z-]+\] ')


def service_failures(binaries):
    for binary in binaries:
        for format in ('text', 'json'):
            for level in ('info', 'off', 'private-invalid-level'):
                result = subprocess.run([str(binary)], env=os.environ | {'LOG_FORMAT': format, 'LOG_LEVEL': level},
                                        capture_output=True, text=True, timeout=10)
                assert result.returncode == 1 and not result.stdout, result
                assert 'private-invalid-level' not in result.stderr
                lines = result.stderr.splitlines()
                if level == 'off':
                    assert not lines, result
                    continue
                assert lines and sum('service.failed' in line for line in lines) == 1, result
                if format == 'json':
                    for line in lines:
                        record = json.loads(line)
                        assert record['schema_version'] == 1
                        if record['event']['name'] == 'service.failed':
                            assert record['event']['level'] == 'err' and record['event']['outcome'] == 'failed'
                else:
                    assert all(TEXT.match(line) and '{' not in line for line in lines), result
    print('Service logging: text/JSON failures, invalid logging configuration, off, and clean stdout passed.', flush=True)


def start(fixture, terminal, environment):
    log = (fixture.root / f'manager-{len(fixture.logs)}.stderr').open('wb')
    fixture.logs.append(log)
    master, slave = pty.openpty() if terminal else (None, None)
    fixture.process = subprocess.Popen([fixture.cli, 'server', '--no-ui', '--config', str(fixture.path)],
        stdin=subprocess.DEVNULL, stdout=slave if terminal else subprocess.PIPE, stderr=log,
        cwd=fixture.root, env={'PATH': '/unavailable', 'LANG': 'C'} | environment)
    if terminal:
        os.close(slave)
        fixture.process.stdout = os.fdopen(master, 'rb', buffering=0)
        deadline = time.monotonic() + 300
        while 'server.ready ' not in Path(log.name).read_text():
            assert fixture.process.poll() is None, Path(log.name).read_text()
            assert time.monotonic() < deadline, fixture.root
            time.sleep(.1)
    else:
        fixture.ready(timeout=300)
    wait_status(fixture, lambda s: s['service']['state'] == 'accepting' and all(a['initialized'] for a in s['accounts']))
    return Path(log.name)


def busy_observation(fixture, log):
    """Exhaust data admission without killing the authority or SQL owner."""
    before = children(fixture.process.pid)
    notices = log.read_text().count('"name":"sql.connect.postgres"')
    port = fixture.config['ports']['node']
    observed = None
    for _ in range(6):
        peers = []
        try:
            for _ in range(4):
                peer = socket.create_connection(('127.0.0.1', port), timeout=3)
                peers.append(peer)
                peer.sendall(f'POST /v1/query HTTP/1.1\r\nHost: localhost:{port}\r\nContent-Length: 100\r\n\r\nx'.encode())
            deadline = time.monotonic() + 1.5
            while time.monotonic() < deadline:
                observed = json.loads((fixture.installation / 'sql/status.json').read_text())['service']
                if observed['state'] == 'busy':
                    break
                time.sleep(.025)
        finally:
            for peer in peers:
                peer.close()
        if observed['state'] == 'busy':
            break
    assert observed['state'] == 'busy' and observed['error_type'] == 'HttpCapacity', observed
    assert observed['postgres_port'] is None, 'An incomplete observation claimed current readiness'
    wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
    assert children(fixture.process.pid) == before, 'Admission pressure restarted a role'
    time.sleep(.1)
    events = [json.loads(line)['event'] for line in log.read_text().splitlines()]
    busy = [e for e in events if e.get('operation') == 'busy']
    assert busy and all(e['level'] == 'warn' and e['error_type'] == 'HttpCapacity' for e in busy), busy
    attempts = [e for e in events if e['name'] == 'transit.client.request'
                and e.get('error_type') == 'HttpCapacity']
    assert attempts and all(e['level'] == 'warn' and e['status'] == 503
                            and e['route'] in ('/v1/query', '/v1/command') for e in attempts), attempts
    assert log.read_text().count('"name":"sql.connect.postgres"') == notices, 'Repeated hint without listener replacement'


def run(cli, node, host, board, gateway):
    service_failures([node, host, board, gateway])
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(board)
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(gateway)
    fixture = Fixture(cli, node, host)
    freeze_executables(fixture)
    fixture.config['applications'] = {'port': fixture.reserve_port()}
    pg_port = fixture.reserve_port()
    fixture.config['sql'].update(postgres={'port': pg_port}, tls={'mode': 'disabled'}, drain_ms=1000,
        accounts=[dict(name='owner', role='local_owner', authentication='trust', bootstrap_owner=True)])
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    try:
        # No logging config: defaults are readable even with unrelated ambient LOG_*.
        text_path = start(fixture, True, {'LOG_FORMAT': 'json'})
        # Native-only bootstrap defers all Table maintenance. After the owner
        # is provisioned, the same startup must restore the configured defaults.
        node_config = json.loads((fixture.installation / 'node.json').read_text())
        assert node_config['table'] is not None
        maintenance = node_config['storage']['maintenance']
        assert maintenance['flush']['enabled'] and maintenance['archive']['enabled'] and maintenance['compact'], maintenance
        time.sleep(.2)  # Let the bounded writer publish the just-observed ready transition.
        before = text_path.read_text().count('sql.connect.postgres ')
        time.sleep(2)
        assert before >= 1 and text_path.read_text().count('sql.connect.postgres ') == before
        assert not select.select([fixture.process.stdout], [], [], 0)[0], 'Terminal stdout contains a machine receipt'
        fixture.stop()
        lines = text_path.read_text().splitlines()
        assert all(TEXT.match(line) and '{' not in line for line in lines), lines
        assert any('server.ready ' in line for line in lines)
        assert any('server.stopped ' in line for line in lines)
        # A deferred first health check is starting, not an unexplained outage.
        # An actual native failure during startup still needs a truthful error,
        # followed by confirmed recovery before connection instructions appear.
        first_accepting = next((index for index, line in enumerate(lines)
                                if 'sql.status ' in line and 'operation="accepting"' in line), len(lines))
        # After confirmed readiness, losing a health observation can itself
        # establish unavailable without an additional native error code.
        unavailable = [line for line in lines[:first_accepting]
                       if 'sql.status ' in line and 'operation="unavailable"' in line]
        assert all('outcome=failed' in line and re.search(r' error_type="[^"]+"', line)
                   for line in unavailable), unavailable
        states = [line.split('sql.status ', 1)[1] for line in lines if 'sql.status ' in line]
        assert states and 'operation="accepting"' in states[-1], states
        assert json.loads((fixture.installation / 'sql/status.json').read_text())['service']['error_type'] is None
        assert all(left != right for left, right in zip(states, states[1:])), states
        for launch in fixture.installation.glob('*.launch.json'):
            environment = {v['name']: v['value'] for v in json.loads(launch.read_text())['environment']}
            assert environment['LOG_FORMAT'] == 'text' and environment['LOG_LEVEL'] == 'info', launch

        fixture.config['logging'] = {'format': 'text', 'level': 'warn'}
        fixture.path.write_text(json.dumps(fixture.config))
        json_path = start(fixture, False, {'TRANSIT_LOGGING__FORMAT': 'json', 'TRANSIT_LOGGING__LEVEL': 'info'})
        result = subprocess.run(['psql', '-XAt', '-h', '127.0.0.1', '-p', str(pg_port), '-U', 'owner', '-d', 'transit',
                                 '-c', 'SHOW logging.format', '-c', 'SHOW logging.level'],
                                env=os.environ | {'PGSSLMODE': 'disable'}, capture_output=True, text=True, timeout=60)
        assert result.returncode == 0 and result.stdout.splitlines() == ['json', 'info'], result
        busy_observation(fixture, json_path)
        fixture.kill_role('/sql/gateway.json')
        deadline = time.monotonic() + 60
        while not any(json.loads(line).get('event', {}).get('error_type') == 'GatewayOwnerUnavailable' for line in json_path.read_text().splitlines()):
            assert fixture.process.poll() is None and time.monotonic() < deadline, json_path.read_text()
            time.sleep(.1)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        fixture.stop()
        records = [json.loads(line) for line in json_path.read_text().splitlines()]
        assert records and all(r['schema_version'] == 1 and r['service_name'] == 'transit' for r in records)
        assert {r['event']['name'] for r in records} >= {'server.startup', 'server.ready', 'server.stopped', 'sql.status', 'sql.connect.postgres'}
        failures = [r['event'] for r in records if r['event'].get('error_type') == 'GatewayOwnerUnavailable']
        assert failures and all(e['level'] == 'err' and e['outcome'] == 'failed' for e in failures), failures
        for launch in list(fixture.installation.glob('*.launch.json')) + [fixture.installation / 'sql/gateway.launch.json']:
            environment = {v['name']: v['value'] for v in json.loads(launch.read_text())['environment']}
            assert environment['LOG_FORMAT'] == 'json' and environment['LOG_LEVEL'] == 'info', launch
        off_path = start(fixture, False, {'TRANSIT_LOGGING__LEVEL': 'off'})
        fixture.stop()
        assert not off_path.read_bytes(), off_path.read_text()
        success = True
        print('Server logging: default terminal text, piped readiness JSON, SQL transitions, explicit child environments, restart, and SHOW/environment precedence passed.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Logging evidence retained at {fixture.root}', file=sys.stderr, flush=True)


if __name__ == '__main__':
    run(*(Path(arg).resolve() for arg in sys.argv[1:]))
