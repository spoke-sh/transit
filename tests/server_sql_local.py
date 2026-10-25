"""Real local SQL clients: transport policy, recorded owner bootstrap and revocation."""
import argparse
import ctypes
import json
from operation_helpers import operations
import os
from pathlib import Path
import shutil
import sys

from server import Fixture
from server_sql import account, apply, call, denied, freeze, wait_status


def run(cli, node, host, board, gateway, *, bundle=None, source_install=False):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = Fixture(cli, node, host)
    if bundle:
        fixture.cli = str(Path(bundle).resolve() / 'bin/transit')
        fixture.config.pop('executables')  # Installed adjacent Transit artifacts.
    else:
        freeze(fixture)
    fixture.config['sql'] = {'native': {'local': False}}
    fixture.config['applications'] = {'port': fixture.reserve_port()}
    fixture.config['board'] = {'port': fixture.reserve_port()}
    pg_port, mysql_port = fixture.reserve_port(), fixture.reserve_port()
    sql = dict(native={'local': False}, postgres={'port': pg_port}, mysql={'port': mysql_port},
               health_port=fixture.reserve_port(), tls={'mode': 'disabled'}, accounts=[],
               drain_ms=1000, request_timeout_ms=30000, command_ms=270000, idle_ms=270000)
    fixture.config['sql'] = sql
    success = False
    print(f'Local SQL authentication proof: {fixture.root}', flush=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('PG', 'MYSQL'))}
    env['PGCONNECT_TIMEOUT'] = '10'

    def pg(query, mode='disable', user='owner', reject=False, password=None):
        selected = dict(env, PGSSLMODE=mode)
        if password is not None:
            selected['PGPASSWORD'] = password
        if mode == 'verify-full':
            selected['PGSSLROOTCERT'] = str(fixture.installation / 'sql/tls/ca.pem')
        return (denied if reject else call)(['psql', '-XAtw', '-v', 'ON_ERROR_STOP=1', '-h', 'localhost',
            '-p', pg_port, '-U', user, '-d', 'transit', '-c', query], env=selected)

    def mysql(query, mode='DISABLED', user='owner', reject=False, password=None):
        selected = dict(env)
        if password is not None:
            selected['MYSQL_PWD'] = password  # Isolated proof-only credential.
        args = ['mysql', '--no-defaults', '--no-login-paths', '--protocol=TCP', '-h', 'localhost', '-P', mysql_port,
                '-u', user, '-D', 'transit', '--ssl-mode='+mode, '--batch', '--skip-column-names',
                '--default-character-set=utf8mb4']
        if mode == 'VERIFY_IDENTITY':
            args.append('--ssl-ca='+str(fixture.installation / 'sql/tls/ca.pem'))
        return (denied if reject else call)([*args, '-e', query], env=selected)

    def start(first=False):
        if first:
            # Exercise the documented YAML shape, including duration strings.
            base = "\n".join(f'{key}: {json.dumps(value)}' for key, value in fixture.config.items() if key != 'sql')
            fixture.path.write_text(base + f'''
sql:
  postgres:
    port: {pg_port}
  mysql:
    port: {mysql_port}
  health_port: {sql['health_port']}
  tls:
    mode: disabled
  drain_ms: 1s
  request_timeout_ms: 30s
  command_ms: 270s
  idle_ms: 270s
  accounts:
    - name: owner
      role: local_owner
      authentication: trust
      bootstrap_owner: true
''')
        else:
            fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready(timeout=300)
        return wait_status(fixture, lambda s: s['service']['state'] == 'accepting' and
                           all(item['initialized'] for item in s['accounts']))

    try:
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.refusal('sql.accounts')
        assert not fixture.installation.exists()
        sql['accounts'] = [dict(name='owner', role='local_owner', authentication='trust', bootstrap_owner=True)]
        status = start(first=True)
        folder = fixture.installation / 'sql/accounts/owner'
        retained = json.loads((folder / 'account.json').read_text())
        assert retained['bootstrap_owner'] and retained['journal']['receipts'][12] is not None
        assert not (folder / 'bind-credential.json').exists()
        assert json.loads((folder / 'verifier.json').read_text())['verifier'] is None
        assert not list((fixture.installation / 'sql/tls').iterdir())
        assert status['service']['ca_file'] is None and status['service']['tls_mode'] == 'disabled'
        assert account(status, 'owner')['postgres_command'] == f'psql -h localhost -p {pg_port} -U owner -d transit'
        assert '--ssl-mode=DISABLED' in account(status, 'owner')['mysql_command']
        assert pg('SELECT 1') == mysql('SELECT 1') == '1'
        # Default psql negotiation must also work without any TLS flags.
        assert pg('SELECT 1', mode='prefer') == '1'
        pg('SELECT 1', mode='require', reject=True)
        mysql('SELECT 1', mode='REQUIRED', reject=True)
        pg('SELECT 1', user='unknown', reject=True)
        mysql('SELECT 1', user='unknown', reject=True)
        pg('CREATE TABLE local_rows (id BIGINT PRIMARY KEY, label UTF8)')
        pg("INSERT INTO local_rows (id, label) VALUES (1, 'snow ☃')")
        assert mysql('SELECT label FROM local_rows') == 'snow ☃'
        mysql('UPDATE local_rows SET label = NULL WHERE id = 1')
        assert pg('SELECT COUNT(*) FROM local_rows WHERE label IS NULL') == '1'
        assert pg('SHOW sql.tls.mode') == 'disabled'
        print('Local SQL: first initialization bootstraps owner; both real CLIs share data without TLS/password files.', flush=True)
        fixture.stop()

        password = 'local-auth-proof-secret'
        password_file = fixture.root / 'password'
        password_file.write_text(password); password_file.chmod(0o600)
        sql['accounts'].append(dict(name='password_owner', role='local_owner', bootstrap_owner=True, password_file=str(password_file)))
        sql['tls']['mode'] = 'optional'
        start()
        for operation, mode in ((pg, 'disable'), (pg, 'verify-full'), (mysql, 'DISABLED'), (mysql, 'VERIFY_IDENTITY')):
            assert operation('SELECT COUNT(*) FROM local_rows', mode=mode) == '1'
        assert pg('SELECT 1', user='password_owner', password=password) == '1'
        assert pg('SELECT 1', mode='verify-full', user='password_owner', password=password) == '1'
        assert mysql('SELECT 1', mode='VERIFY_IDENTITY', user='password_owner', password=password) == '1'
        assert 'requires TLS' in mysql('SELECT 1', user='password_owner', password=password, reject=True)
        pg('SELECT 1', user='password_owner', password='wrong', reject=True)
        print('Local SQL: optional TLS accepts both transports; SCRAM works on plaintext and MySQL passwords require TLS.', flush=True)
        fixture.stop()

        sql['tls']['mode'] = 'required'
        start()
        assert 'TLS is required' in pg('SELECT 1', reject=True)
        assert 'TLS is required' in mysql('SELECT 1', reject=True)
        assert pg('SELECT 1', mode='verify-full') == mysql('SELECT 1', mode='VERIFY_IDENTITY') == '1'
        fixture.stop()

        # Return to trust only and revoke the native credential through the
        # public API. Restart cannot publish the completed bootstrap again.
        sql['tls']['mode'] = 'disabled'
        sql['accounts'].pop()
        start()
        control = json.loads((folder / 'control.json').read_text())
        identity = json.loads((folder / 'verifier.json').read_text())
        query = fixture.root / 'identity.json'; query.write_text('{"identity":{}}')
        observed = json.loads(call([operations(), 'auth', 'read', '--config', fixture.installation / 'sql/authorization.yaml',
                                   '--file', query], retry_observation=True))['observation']['body']['authorization']
        change = fixture.root / 'disable-owner.json'
        change.write_text(json.dumps(dict(expected_revision=observed['revision'], action=dict(disable_credential=dict(
            principal=identity['principal'], expected_epoch=identity['credential_epoch'])))))
        apply(fixture, change, 'disable-owner')
        pg('SELECT 1', reject=True)
        mysql('SELECT 1', reject=True)
        fixture.stop()
        status = start()
        wait_status(fixture, lambda s: account(s, 'owner')['state'] == 'unavailable')
        pg('SELECT 1', reject=True)
        mysql('SELECT 1', reject=True)
        after = json.loads((folder / 'account.json').read_text())
        assert after['identity'] == retained['identity'] and after['principals'] == retained['principals']
        assert after['journal']['receipts'][12] == retained['journal']['receipts'][12]
        assert not (folder / 'bind-credential.json').exists()
        print('Local SQL: required TLS rejects plaintext; revoked trust login stays revoked across restart with unchanged bootstrap receipt.', flush=True)
        success = True
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Local authentication evidence retained at {fixture.root}', file=sys.stderr, flush=True)


def bootstrap_fault(cli, node, host, board, gateway):
    from server import joined
    from server_application_faults import descendants, install_peer, wait_file
    fixture = Fixture(cli, node, host)
    freeze(fixture)
    install_peer(fixture)
    fixture.config['applications'] = {'port': fixture.reserve_port()}
    fixture.config['board'] = {'port': fixture.reserve_port()}
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    print(f'Owner bootstrap fault proof: {fixture.root}', flush=True)
    try:
        fixture.start(); fixture.ready(); fixture.stop()
        owner_role = fixture.record()['authorization_steps'][0]
        fixture.config['sql'] = dict(native={'local': False}, postgres={'port': fixture.reserve_port()}, health_port=fixture.reserve_port(),
            tls={'mode': 'disabled'}, drain_ms=1000,
            accounts=[dict(name='owner', role='local_owner', authentication='trust', bootstrap_owner=True)])
        fixture.path.write_text(json.dumps(fixture.config))
        (fixture.root / 'drop-next').write_text(json.dumps(dict(command='authorization', principal=0,
            binding_role=owner_role, label='owner-binding')))
        fixture.start()
        wait_file(fixture.root / 'dropped-owner-binding.json', timeout=180)
        path = fixture.installation / 'sql/accounts/owner/account.json'
        frozen = json.loads(path.read_text())
        assert frozen['journal']['pending']['index'] == 12
        assert 'publish' in frozen['journal']['pending']['signed']['request']['command']['authorization']
        assert frozen['journal']['receipts'][12] is None
        owned = descendants(fixture.process.pid)
        fixture.stop(kill=True); joined(owned)
        (fixture.root / 'release-owner-binding').touch()
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        wait_file(fixture.root / 'retried-owner-binding')
        after = json.loads(path.read_text())
        assert after['identity'] == frozen['identity'] and after['principals'] == frozen['principals']
        assert after['journal']['receipts'][12] is not None and after['journal']['pending'] is None
        assert after['initialized'] and after['login_role'] == owner_role
        assert not (path.parent / 'bind-credential.json').exists()
        env = dict(os.environ, PGSSLMODE='disable')
        assert call(['psql', '-XAtw', '-h', 'localhost', '-p', fixture.config['sql']['postgres']['port'],
                     '-U', 'owner', '-d', 'transit', '-c', 'SELECT 1'], env=env) == '1'
        print('Local SQL: accepted owner binding survives reply loss and SIGKILL; exact publish retry, same identity and usable login.', flush=True)
        success = True
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Owner bootstrap fault evidence retained at {fixture.root}', file=sys.stderr, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    placement = parser.add_mutually_exclusive_group()
    placement.add_argument('--bundle', type=Path)
    placement.add_argument('--source-install', type=Path)
    parser.add_argument('binaries', nargs='*')
    args = parser.parse_args()
    if args.bundle or args.source_install:
        root = (args.bundle or args.source_install).resolve()
        binaries = [root / 'bin' / name for name in ('transit', 'transit-node', 'transit-query-host', 'transit-board', 'transit-sql-gateway')]
        run(*binaries, bundle=root, source_install=args.source_install is not None)
        bootstrap_fault(*binaries)
    else:
        assert len(args.binaries) == 5
        run(*args.binaries)
        bootstrap_fault(*args.binaries)
