"""Actual independent Board connections, with a byte-preserving local tunnel."""
from contextlib import contextmanager
import json
import os
import select
import socket
import socketserver
import subprocess
import threading
from runner.paths import ROOT
from interfaces.installation.server_sql import apply, enroll, policy, wait_status


@contextmanager
def tunnel(port):
    # Keep the public localhost:port origin unchanged, as with ssh -L on a
    # separate client. A second loopback address stands in for that client.
    class Forward(socketserver.BaseRequestHandler):
        def handle(self):
            with socket.create_connection(('127.0.0.1', port), timeout=10) as upstream:
                peers = [self.request, upstream]
                try:
                    while True:
                        ready, _, _ = select.select(peers, [], [], 30)
                        if not ready:
                            return
                        for peer in ready:
                            data = peer.recv(65536)
                            if not data:
                                return
                            peers[1 if peer is self.request else 0].sendall(data)
                except (ConnectionError, TimeoutError):
                    return
    class Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True
    with Server(('127.0.0.2', port), Forward) as server:
        worker = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': .05})
        worker.start()
        try:
            yield f'http://localhost:{port}', f'http://127.0.0.2:{port}'
        finally:
            server.shutdown()
            worker.join(timeout=5)
            assert not worker.is_alive()


def configure(fixture):
    """Provision distinct read-only subjects through the public policy owner."""
    for name in ('board_catalog', 'board_sql'):
        enroll(fixture, name)
    wait_status(fixture, lambda s: all(a['initialized'] for a in s['accounts']))
    apply(fixture, fixture.installation / 'sql/catalog-access.json', 'board-profile-discovery', 'prepare-set')
    for name in ('board_catalog', 'board_sql'):
        policy(fixture, f'GRANT SELECT ON TABLE public.metrics TO {name};', name + '-select')
    account_dir = fixture.installation / 'sql/accounts/board_catalog'
    account = json.loads((account_dir / 'account.json').read_text())
    sql_account = json.loads((fixture.installation / 'sql/accounts/board_sql/account.json').read_text())
    assert account['principals']['table'] != sql_account['principals']['table']
    catalog = json.loads((fixture.installation / 'node.json').read_text())['table']['catalog']
    return dict(catalog=dict(seed_file=str(account_dir / 'table.seed'), connection=dict(
        scope=dict(catalog['scope'], catalog=str(catalog['scope']['catalog'])),
        branch=str(catalog['branch']), audience=catalog['audience'],
        principal=account['principals']['table'], role=None)),
        sql=dict(version=1, endpoint=f"http://127.0.0.1:{fixture.config['sql']['native']['http']['port']}",
                 account='board_sql', database='transit', authentication='trust', request_timeout_ms=2000))


def qualify(fixture, config_file, connections, browser):
    definition = fixture.record()['definition']
    for profile, keys in [('inspection', ()), ('catalog', ('catalog',)), ('sql', ('sql',)), ('both', ('catalog', 'sql'))]:
        fixture.stop()
        config_file.write_text(json.dumps({key: connections[key] for key in keys}))
        fixture.start()
        fixture.ready()
        with tunnel(fixture.config['board']['port']) as (origin, forwarded):
            headers = {'Host': origin.removeprefix('http://'), 'Origin': origin, 'Content-Type': 'application/json'}
            def request(route, action=None, expected=200, extra=None):
                return json.loads(fixture.request('/api/v1/' + route, headers | (extra or {}), expected,
                    base_url=forwarded, method='GET' if action is None else 'POST',
                    body=None if action is None else json.dumps(dict(definition=definition, action=action)).encode()))
            observed = request('deployment')['features']
            assert (observed['catalog'], observed['sql']) == ('catalog' in keys, 'sql' in keys)
            assert request('storage')['backend'] == 'local'
            assert request('deployment', expected=403, extra={'Origin': 'http://foreign.invalid'})['err'] == 'InvalidOrigin'
            assert request('deployment', expected=403, extra={'Host': 'foreign.invalid'})['err'] == 'InvalidOrigin'
            tables = request('catalog', dict(tables=dict(namespace=1, cursor=None)), 200 if 'catalog' in keys else 404)
            if 'catalog' in keys:
                entries = [item for item in tables['catalog']['tables']['entries'] if item]
                for _ in range(4):
                    cursor = tables['catalog']['tables']['next']
                    if cursor is None:
                        break
                    tables = request('catalog', dict(tables=dict(namespace=1, cursor=cursor)))
                    entries.extend(item for item in tables['catalog']['tables']['entries'] if item)
                assert tables['catalog']['tables']['next'] is None
                assert [item['name'] for item in entries] == ['metrics'], entries
            else:
                assert tables['err'] == 'QueryDisabled'
            info = request('sql-read', dict(describe={}), 200 if 'sql' in keys else 404)
            if 'sql' in keys:
                assert 'description' in info
                identity = '00000000000000000000000000b03001'
                result = request('sql-read', dict(run=dict(id=identity, sql='SELECT id FROM metrics LIMIT 1', expected_definition=None)))
                assert result['result']['view']['rows'], result
                assert request('sql-read', dict(close=identity)) == {'closed': {}}
            else:
                assert info['err'] == 'QueryDisabled'
            if browser:
                subprocess.run(['vp', 'exec', '--filter', '@transit/board-web', 'playwright', 'test', 'profiles.spec.ts'],
                    cwd=ROOT, env=dict(os.environ, BOARD_TEST_URL=origin, BOARD_PROFILE=profile,
                        BOARD_TUNNEL='1'), check=True)
        print(json.dumps(dict(board_profile=profile, actual_configuration=True, tunnel=True,
                              separate_read_subjects=True, status='passed')), flush=True)
