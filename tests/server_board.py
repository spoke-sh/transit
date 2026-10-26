#!/usr/bin/env python3
"""Actual embedded Board, explicit grants, UI toggles and owned disk recovery."""
import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

from harness.processes import children, command, joined
from server_applications import Applications
from server_application_faults import ExistingKey, native, post, install_peer, arm, wait_file, descendants
from harness.services import free_port


class Board(Applications):
    def __init__(self, cli, node, host, board):
        super().__init__(cli, node, host)
        port = free_port()
        while port in [*self.config['ports'].values(), self.config['applications']['port']]:
            port = free_port()
        self.config.update(version=1, board={'port': port})
        self.config['executables']['board'] = str(Path(board).resolve())
        self.path.write_text(json.dumps(self.config))
        self.no_ui = False
        self.board_url = f'http://127.0.0.1:{port}'

    def ready(self, timeout=120):
        report = super().ready(timeout)
        assert report['ui'] == ('disabled' if self.no_ui else 'ready'), report
        assert report['board_url'] == (None if self.no_ui else self.board_url), report
        owned = [pid for pid in children(self.process.pid) if '/board.json' in command(pid)]
        assert len(owned) == (0 if self.no_ui else 1), owned
        return report

    def request(self, path, headers=None, expected=200, *, base_url=None, method='GET', body=None):
        deadline = time.monotonic() + 10
        while True:
            try:
                result = self.http.open(urllib.request.Request((base_url or self.board_url) + path,
                    headers=headers or {}, method=method, data=body), timeout=5)
            except urllib.error.HTTPError as error:
                result = error
            with result:
                status, data = result.status, result.read()
            capacity = False
            if status == 503 and method == 'GET' and expected == 200:
                failure = json.loads(data)
                diagnostic = failure.get('diagnostic') or {}
                capacity = (failure.get('err') == 'Unavailable'
                    and diagnostic.get('cause') == 'AuthorityUnavailable'
                    and any(fact and fact['field'] == 'native_cause'
                        and fact['value'] == {'text': 'HttpCapacity'} for fact in diagnostic.get('facts', [])))
            if status == 429 or (status == 409 and expected == 200) or capacity:
                assert time.monotonic() < deadline, (status, data)
                time.sleep(.15)
                continue
            assert status == expected, (status, data)
            return data

    def atlas(self):
        return json.loads(self.request('/api/v1/atlas'))

    def visible(self, resource):
        # This fixture deliberately fits in one eight-resource page.
        return any(item and int(item['id']) == resource for item in self.atlas()['resources']['entries'])

    def revoke(self, command_value):
        root = ExistingKey(self.root, self.installation / 'root.seed')
        os.kill(self.process.pid, signal.SIGSTOP)
        try:
            current = post(self.config['ports']['node'], '/v1/query', native(root, 73, 0, {'capabilities': {}}))
            return post(self.config['ports']['node'], '/v1/command', native(root, 73, 0, command_value, current['principal_sequence'] + 1))
        finally:
            os.kill(self.process.pid, signal.SIGCONT)


def lifecycle(cli, node, host, board, worker, operator):
    fixture = Board(cli, node, host, board)
    success = False
    started = time.monotonic()
    print(f'Board server proof: {fixture.root}', flush=True)
    try:
        fixture.no_ui = True
        fixture.start()
        fixture.ready()
        initial = fixture.record()
        assert initial['board_receipts'] == [None] * 3
        seed = (fixture.installation / 'board.seed').read_bytes()
        declaration = json.loads(subprocess.check_output([str(Path(operator).resolve()), 'manifest', str(Path(worker).resolve())], text=True))
        declaration.update(version=1, inspection=[{'resource': declaration['resources'][0]['name'], 'permissions': 3}])
        manifest = fixture.root / 'application.json'
        manifest.write_text(json.dumps(declaration))
        fixture.app('install', '--file', manifest, '--operation', 'install')
        before = fixture.active()
        resource = before['resources'][0]['id']
        hidden = dict(declaration, application='hidden', inspection=[])
        hidden_path = fixture.root / 'hidden.json'
        hidden_path.write_text(json.dumps(hidden))
        fixture.app('install', '--file', hidden_path, '--operation', 'hidden')
        hidden_id = fixture.active('hidden')['resources'][0]['id']
        fixture.stop()
        fixture.no_ui = False
        fixture.start()
        fixture.ready()
        fixture.active()
        deadline = time.monotonic() + 15
        while not fixture.visible(resource):
            assert time.monotonic() < deadline
            time.sleep(.1)
        assert not fixture.visible(hidden_id)
        atlas = fixture.atlas()
        assert int(atlas['realm']) == 73 and int(atlas['identity']['principal']) == 25
        assert atlas['identity']['permissions'] == 16
        html = fixture.request('/').decode()
        scripts = re.findall(r'src="([^"]+\.js)"', html)
        assert scripts, html
        assert len(fixture.request(scripts[0])) > 100_000
        capabilities = json.loads(fixture.request('/api/v1/capabilities'))
        assert not capabilities['query_enabled']
        # Use both real URLs, including their default Host headers. The default
        # server enables the alias even when Board uses a non-default port.
        port = fixture.config['board']['port']
        origins = (fixture.board_url, f'http://localhost:{port}')
        for origin in origins:
            headers = {'Origin': origin}
            assert fixture.request('/', base_url=origin).decode() == html
            assert len(fixture.request(scripts[0], base_url=origin)) > 100_000
            assert json.loads(fixture.request('/health', headers, base_url=origin))['ready']
            local_atlas = json.loads(fixture.request('/api/v1/atlas', headers, base_url=origin))
            assert int(local_atlas['identity']['principal']) == 25
            for route, error in (('query', 'QueryDisabled'), ('relational', 'QueryDisabled'), ('application', 'NotFound')):
                # Disabled workspaces are reached only after Host/Origin checks.
                path = '/api/v1/' + route
                response = fixture.request(path, headers | {'Content-Type': 'application/json'},
                    base_url=origin, method='POST', body=b'{}', expected=404)
                assert json.loads(response)['err'] == error
                fixture.request(path, {'Content-Type': 'application/json'},
                    base_url=origin, method='POST', body=b'{}', expected=403)
            for other in (*[item for item in origins if item != origin],
                          f'https://localhost:{port}', f'http://localhost:{port + 1}',
                          'http://foreign.invalid', 'null'):
                for path, method, body in (('/health', 'GET', None), ('/api/v1/query', 'POST', b'{}')):
                    response = fixture.request(path, {'Origin': other, 'Content-Type': 'application/json'},
                        base_url=origin, method=method, body=body, expected=403)
                    assert json.loads(response)['err'] == 'InvalidOrigin'
            for name in ('Forwarded', 'X-Forwarded-Host', 'X-Forwarded-Proto', 'X-Forwarded-For'):
                fixture.request('/health', {name: 'foreign.invalid'}, base_url=origin, expected=403)
        for host_header in ('foreign.invalid', f'localhost:{port + 1}', f'localhost.evil:{port}',
                            f'localhost.:{port}', f'127.0.0.2:{port}', f'[::1]:{port}', 'localhost'):
            fixture.request('/health', {'Host': host_header}, expected=403)
        board_record = fixture.record()['board_receipts']
        assert all(board_record)
        replacement = fixture.root / 'replacement.json'
        role = before['roles'][0]
        declared_role = declaration['roles'][0]
        replacement.write_text(json.dumps(dict(application=declaration['application'], role=role['name'], expected_revision=role['revision'], contract=declared_role['contract'], artifact=declared_role['artifact'], configuration=declared_role['configuration'])))
        fixture.app('replace', '--file', replacement, '--operation', 'replace')
        after = fixture.active(previous=role['generation'])
        assert after['resources'][0]['id'] == resource and after['roles'][0]['pid'] == role['pid']
        assert fixture.visible(resource)
        fixture.revoke({'grant_resource': {'resource': resource, 'subject': 25, 'permissions': 0}})
        assert not fixture.visible(resource)
        fixture.stop()
        # An occupied UI port blocks default startup; explicit headless startup
        # does not bind or preflight the disabled listener.
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(('127.0.0.1', fixture.config['board']['port']))
            listener.listen()
            fixture.refusal('address already in use')
            fixture.no_ui = True
            fixture.start()
            fixture.ready()
            fixture.stop()
        fixture.no_ui = False
        fixture.start()
        fixture.ready()
        fixture.active()
        assert not fixture.visible(resource)
        assert fixture.record()['board_receipts'] == board_record
        assert fixture.record()['provision'] == initial['provision']
        assert (fixture.installation / 'board.seed').read_bytes() == seed
        # Board, node and storage crashes share bounded restart and same history.
        for match in ('/board.json', '/transit-node ', '"unified_requester":'):
            fixture.kill_role(match)
            fixture.ready()
            assert fixture.record()['board_receipts'] == board_record
            assert not fixture.visible(resource)
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        fixture.revoke({'revoke': 25})
        assert fixture.process.wait(timeout=20) == 1
        assert any('server.failed' in line and 'role="board"' in line and 'error_type="AccessDenied"' in line
            for line in Path(fixture.logs[-1].name).read_text().splitlines())
        fixture.stop()
        fixture.start()
        assert fixture.process.wait(timeout=45) == 1
        assert fixture.record()['board_receipts'] == board_record
        fixture.stop()
        fixture.no_ui = True
        fixture.start()
        fixture.ready()
        fixture.stop()
        success = True
        print(f'Board defaults/toggles, embedded assets, app replacement, revocation and owned failures: passed in {time.monotonic() - started:.2f}s', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Board failure evidence retained: {fixture.root}', file=sys.stderr)


def interrupted(cli, node, host, board, worker=None, operator=None):
    fixture = Board(cli, node, host, board)
    install_peer(fixture)
    success = False
    try:
        fixture.no_ui = True
        fixture.start()
        fixture.ready()
        fixture.stop()
        effect, index = 'board', 0
        label = 'board-principal'
        if worker is not None:
            # Install an explicitly inspected app while Board has no principal.
            fixture.start()
            fixture.ready()
            declaration = json.loads(subprocess.check_output([str(Path(operator).resolve()), 'manifest', str(Path(worker).resolve())], text=True))
            declaration.update(version=1, inspection=[{'resource': declaration['resources'][0]['name'], 'permissions': 3}])
            manifest = fixture.root / 'application.json'
            manifest.write_text(json.dumps(declaration))
            fixture.app('install', '--file', manifest, '--operation', 'inspect-app')
            resource = fixture.active()['resources'][0]['id']
            fixture.stop()
            effect, label = 'inspection', 'board-application'
            (fixture.root / 'drop-next').write_text(json.dumps(dict(command='grant_resource', label=label, principal=0, resource=resource)))
        else:
            arm(fixture, 'create_principal', label, principal=0)
        fixture.no_ui = False
        fixture.start()
        wait_file(fixture.root / f'dropped-{label}.json')
        record_path = fixture.installation / 'applications/work-items/record.json'
        frozen = fixture.record()['pending'] if worker is None else json.loads(record_path.read_text())['pending']
        assert frozen['effect'] == (effect if worker is None else {effect: {}})
        if worker is None:
            assert frozen['index'] == index
        owned = descendants(fixture.process.pid)
        fixture.stop(kill=True)
        joined(owned)
        fixture.start()
        fixture.ready()
        wait_file(fixture.root / f'retried-{label}')
        dropped = json.loads((fixture.root / f'dropped-{label}.json').read_text())
        accepted = json.loads(bytes.fromhex(dropped['receipt']))
        if worker is None:
            assert fixture.record()['board_receipts'][0] == accepted['position']
        else:
            fixture.active()
            assert fixture.visible(resource)
            checkpoint = json.loads(record_path.read_text())
            assert checkpoint['inspection_next'] == 1
            receipts = [json.loads(path.read_text()) for path in (record_path.parent / 'receipts').glob('*.json')]
            assert sum(receipt['position'] == accepted['position'] for receipt in receipts) == 1
        assert fixture.record()['pending'] is None
        success = True
        print(f'Board {label} lost reply and manager death: exact request/receipt recovered', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Board interruption evidence retained: {fixture.root}', file=sys.stderr)


def preflight(cli, node, host, board):
    fixture = Board(cli, node, host, board)
    success = False
    try:
        original = json.loads(json.dumps(fixture.config))
        for port in [*original['ports'].values(), original['applications']['port']]:
            fixture.config['board'] = {'port': port}
            fixture.path.write_text(json.dumps(fixture.config))
            fixture.refusal('must be different')
            assert not fixture.installation.exists()
        fixture.config = json.loads(json.dumps(original))
        fixture.config['board']['public_origin'] = 'http://foreign.invalid'
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.refusal('board.public_origin must match the Board loopback listener')
        fixture.config = json.loads(json.dumps(original))
        fixture.config['executables']['board'] = str(fixture.root / 'absent')
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.refusal('file not found')
        assert not fixture.installation.exists()
        fixture.config = original
        selected = fixture.root / 'selected-board'
        shutil.copyfile(board, selected)
        selected.chmod(0o700)
        fixture.config['executables']['board'] = str(selected)
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready()
        os.kill(fixture.process.pid, signal.SIGINT)
        assert fixture.process.wait(timeout=20) == 0
        fixture.stop()
        record = fixture.record()
        with selected.open('ab') as artifact:
            artifact.write(b'changed artifact')
        fixture.refusal('configuration or executable differs from the recorded installation')
        fixture.no_ui = True
        fixture.refusal('configuration or executable differs from the recorded installation')
        assert fixture.record() == record
        success = True
        print('Board fresh default, Ctrl-C, all listener conflicts, missing and changed artifacts: passed', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Board preflight evidence retained: {fixture.root}', file=sys.stderr)


def incompatible(cli, node, host, board):
    fixture = Board(cli, node, host, board)
    success = False
    try:
        # A healthy listener with no Board API is not a usable UI. This test peer
        # is explicitly configured before installation, never found on PATH.
        peer = fixture.root / 'false-board'
        peer.write_text('#!' + sys.executable + "\n" +
            "import json,sys\nfrom http.server import BaseHTTPRequestHandler,HTTPServer\n" +
            "class Peer(BaseHTTPRequestHandler):\n" +
            " def log_message(self,*args): pass\n" +
            " def do_GET(self):\n  self.send_response(200)\n  self.send_header('Content-Length','2')\n  self.end_headers()\n  self.wfile.write(b'{}')\n" +
            "HTTPServer(('127.0.0.1',json.load(open(sys.argv[1]))['port']),Peer).serve_forever()\n")
        peer.chmod(0o700)
        fixture.config['executables']['board'] = str(peer)
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        assert fixture.process.wait(timeout=60) == 1
        assert fixture.process.stdout.read() == b''
        assert 'InvalidBoardResponse' in Path(fixture.logs[-1].name).read_text()
        fixture.stop()
        fixture.no_ui = True
        fixture.start()
        fixture.ready()
        fixture.stop()
        success = True
        print('Healthy incompatible Board never reports ready; explicit headless recovery passed', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Board incompatible evidence retained: {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    # Installation identity pins every executable. Concurrent builds may replace
    # zig-out files; run the whole recovery schedule against owned frozen copies.
    artifacts = Path(tempfile.mkdtemp(prefix='transit-board-proof-artifacts-', dir='/var/tmp'))
    success = False
    try:
        binaries = []
        for argument in sys.argv[1:]:
            target = artifacts / Path(argument).name
            shutil.copy2(Path(argument).resolve(), target)
            binaries.append(str(target))
        sql_gateway = artifacts / 'transit-sql-gateway'
        shutil.copy2(Path(sys.argv[1]).resolve().parent / 'transit-sql-gateway', sql_gateway)
        os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(sql_gateway)
        preflight(*binaries[:4])
        incompatible(*binaries[:4])
        lifecycle(*binaries)
        interrupted(*binaries[:4])
        interrupted(*binaries)
        success = True
    finally:
        if success:
            shutil.rmtree(artifacts)
        else:
            print(f'Board proof artifacts retained: {artifacts}', file=sys.stderr)
