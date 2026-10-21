"""Installed local SQL lifecycle using public administration and real database CLIs."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import time

from server import Fixture, children, command, freeze_executables as freeze
from storage import free_port


def call(argv, *, env=None, timeout=300, retry_observation=False):
    deadline = time.monotonic()+timeout
    while True:
        result = subprocess.run(list(map(str, argv)), env=env, capture_output=True, text=True, timeout=max(1, deadline-time.monotonic()))
        if result.returncode == 0:
            return result.stdout.strip()
        transient = any(cause in result.stderr for cause in ('AuthorityUnavailable', 'AuthorityTimeout', 'HttpCapacity', 'HttpConnectionClosing', 'ConnectionResetByPeer'))
        if not retry_observation or not transient or time.monotonic() >= deadline:
            raise AssertionError((argv[:3], result.stdout, result.stderr))
        # Only an explicitly selected observation or saved-operation recovery
        # may use this path. It is never used for a database SQL submission.
        time.sleep(.2)


def denied(argv, *, env=None):
    result = subprocess.run(list(map(str, argv)), env=env, capture_output=True, text=True, timeout=40)
    assert result.returncode != 0, ('Unexpected admission', argv[:3], result.stdout)
    return result.stderr


def wait_status(fixture, predicate, timeout=240):
    deadline = time.monotonic() + timeout
    observed = None
    while time.monotonic() < deadline:
        assert fixture.process.poll() is None, Path(fixture.logs[-1].name).read_text()
        try:
            observed = json.loads((fixture.installation / 'sql/status.json').read_text())
            if predicate(observed):
                return observed
        except FileNotFoundError:
            pass
        time.sleep(.2)
    raise AssertionError(('SQL readiness deadline', observed))


def account(status, name):
    return next(item for item in status['accounts'] if item['name'] == name)


def apply(fixture, input_path, name, mode='prepare'):
    profile = fixture.installation / 'sql/authorization.yaml'
    saved = fixture.root / f'{name}.saved.json'
    deadline = time.monotonic()+60
    while True:
        prepared = subprocess.run([fixture.cli, 'auth', mode, '--config', str(profile), '--file', str(input_path), '--output', str(saved)], capture_output=True, text=True, timeout=40)
        if prepared.returncode == 0:
            break
        # A generated proposal can lag another explicit policy publication by
        # one supervisor tick. Nothing was sent or saved: wait for its refreshed
        # revision. Once saved, only apply that exact operation below.
        refreshed = mode in ('prepare', 'prepare-set') and 'StaleAuthorizationRevision' in prepared.stderr
        unavailable = any(cause in prepared.stderr for cause in ('AuthorityUnavailable', 'AuthorityTimeout', 'HttpCapacity', 'HttpConnectionClosing', 'ConnectionResetByPeer'))
        assert (refreshed or unavailable) and not saved.exists() and time.monotonic() < deadline, prepared.stderr
        time.sleep(.3)
    for _ in range(16):
        result = json.loads(call([fixture.cli, 'auth', 'apply', '--config', profile, '--file', saved, '--steps', '64'], retry_observation=True))
        if not result.get('pending'):
            assert result.get('terminal', {}).get('status') == 'published', result
            return result
    raise AssertionError('Authorization apply exceeded its proof work budget')


def policy(fixture, sql, name):
    source, plan = fixture.root / f'{name}.sql', fixture.root / f'{name}.plan.json'
    source.write_text(sql)
    call([fixture.cli, 'catalog', 'compile-authorization', '--config', fixture.installation / 'sql/catalog.yaml', '--file', source, '--output', plan], retry_observation=True)
    return apply(fixture, plan, name, 'prepare-plan')


def enroll(fixture, name):
    folder = fixture.installation / 'sql/accounts' / name
    status = wait_status(fixture, lambda s: account(s, name)['state'] in ('awaiting_role', 'awaiting_binding', 'bound'))
    if account(status, name)['state'] == 'awaiting_role':
        apply(fixture, folder / 'create-role.json', f'{name}-role')
        wait_status(fixture, lambda s: account(s, name)['state'] == 'awaiting_binding')
    if account(status, name)['state'] != 'bound':
        apply(fixture, folder / 'bind-credential.json', f'{name}-binding')
    wait_status(fixture, lambda s: account(s, name)['state'] == 'bound')
    if name != 'owner':
        apply(fixture, folder / 'access.json', f'{name}-access', 'prepare-set')
    print(f'Local SQL: explicit {name} role, credential and access enrollment passed.', flush=True)


def closed(port):
    with socket.socket() as peer:
        assert peer.connect_ex(('127.0.0.1', port)) != 0, port


def run(cli, node, host, board, gateway, *, bundle=None):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    started = time.monotonic()
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    gateway = str(Path(gateway).resolve())
    fixture = Fixture(cli, node, host)
    if bundle:
        fixture.cli = str(Path(bundle).resolve() / 'bin/transit')
        fixture.config.pop('executables')  # Exercise installed adjacent discovery.
    else:
        freeze(fixture)
        gateway = fixture.config['executables']['sql_gateway']
    fixture.config['applications'] = {'port': free_port()}
    fixture.config['board'] = {'port': free_port()}
    fixture.config['sql'] = {'accounts': [dict(name='dormant', role='unused', password_file='absent.password')]}
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    print(f'Local SQL proof: {fixture.root}', flush=True)
    try:
        fixture.start()
        report = fixture.ready()
        assert report['sql'] is None
        assert not (fixture.installation / 'sql').exists()
        assert not any('transit-sql-gateway' in command(pid) for pid in children(fixture.process.pid))
        fixture.stop()
        print('Local SQL: disabled installation has no SQL process or enrollment.', flush=True)
        passwords = {name: secrets.token_hex(24) for name in ('owner', 'writer', 'reader')}
        accounts = []
        for name, password in passwords.items():
            path = fixture.root / f'{name}.password'
            path.write_text(password)
            path.chmod(0o600)
            accounts.append(dict(name=name, role='local_owner' if name == 'owner' else name, password_file=str(path)))
        pg_port, mysql_port, health_port = free_port(), free_port(), free_port()
        fixture.config['sql'] = {'postgres': {'port': pg_port}, 'mysql': {'port': mysql_port},
            'health_port': health_port, 'request_timeout_ms': 30000, 'command_ms': 270000,
            'idle_ms': 270000, 'drain_ms': 1000, 'accounts': accounts}
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready(timeout=300)
        # An unfinished enrollment survives an ordinary stop without allocating
        # another principal, ledger or key. Private records are observed, never edited.
        wait_status(fixture, lambda s: account(s, 'owner')['state'] == 'awaiting_binding')
        retained = {name: (fixture.installation / 'sql/accounts' / name / 'account.json').read_bytes() for name in passwords}
        fixture.stop()
        fixture.start()
        fixture.ready(timeout=300)
        for name, before in retained.items():
            assert (fixture.installation / 'sql/accounts' / name / 'account.json').read_bytes() == before
        for name in passwords:
            enroll(fixture, name)
        status = wait_status(fixture, lambda s: s['service']['state'] == 'accepting' and all(a['initialized'] for a in s['accounts']))
        ca = status['service']['ca_file']

        def pg_args(name='owner'):
            env = os.environ.copy()
            env.update(PGPASSWORD=passwords[name], PGSSLMODE='verify-full', PGSSLROOTCERT=ca, PGHOSTADDR='127.0.0.1')
            args = ['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-h', 'localhost', '-p', str(pg_port), '-U', name, '-d', 'transit', '-c']
            return args, env

        def mysql_args(name='owner'):
            defaults = fixture.root / f'{name}.cnf'
            defaults.write_text(f'[client]\npassword={passwords[name]}\n')
            defaults.chmod(0o600)
            return ['mysql', f'--defaults-file={defaults}', '--protocol=TCP', '-h', 'localhost', '-P', str(mysql_port), '-u'+name, '-Dtransit', '--ssl-mode=VERIFY_IDENTITY', f'--ssl-ca={ca}', '--batch', '--skip-column-names', '--default-character-set=utf8mb4', '-e']

        def pg(sql, name='owner', reject=False):
            args, env = pg_args(name)
            return (denied if reject else call)([*args, sql], env=env)

        def mysql(sql, name='owner', reject=False):
            return (denied if reject else call)([*mysql_args(name), sql])

        profile = fixture.installation / 'sql/accounts/owner/control.json'
        def controls(*args):
            return json.loads(call([gateway, 'control', profile, *map(str, args)], retry_observation=True))

        assert pg('SELECT 1') == mysql('SELECT 1') == '1'
        assert pg('SHOW DATABASES') == 'transit'
        assert pg('SHOW sql.postgres.port') == str(pg_port)
        pg('CREATE TABLE shared_rows (id BIGINT PRIMARY KEY, label UTF8)')
        pg('SELECT * FROM shared_rows', 'reader', reject=True)
        mysql("INSERT INTO shared_rows (id,label) VALUES (1,'unauthorized')", 'writer', reject=True)
        discovery = fixture.root / 'discovery.sql'
        discovery.write_text('GRANT SELECT ON TABLE public.shared_rows TO reader;')
        assert 'CatalogDenied' in denied([fixture.cli, 'catalog', 'compile-authorization', '--config', fixture.installation / 'sql/catalog.yaml', '--file', discovery, '--output', fixture.root / 'ungranted-discovery.json'])
        apply(fixture, fixture.installation / 'sql/catalog-access.json', 'catalog-discovery', 'prepare-set')
        policy(fixture, 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.shared_rows TO writer;', 'writer-data')
        policy(fixture, 'GRANT SELECT ON TABLE public.shared_rows TO reader;', 'reader-data')
        mysql("INSERT INTO shared_rows (id,label) VALUES (1,'snow ☃')", 'writer')
        assert pg('SELECT label FROM shared_rows WHERE id=1', 'reader') == 'snow ☃'
        pg('UPDATE shared_rows SET label=NULL WHERE id=1', 'writer')
        assert mysql('SELECT COUNT(*) FROM shared_rows WHERE label IS NULL', 'reader') == '1'
        mysql('DELETE FROM shared_rows WHERE id=1', 'reader', reject=True)
        print('Local SQL: both verified TLS CLIs share Unicode/NULL data with explicit writer/reader grants.', flush=True)

        # A fresh owner generation rejects an old configuration even in an empty
        # marker directory. No activation marker is removed to claim ownership.
        old = json.loads((fixture.installation / 'sql/gateway.json').read_text())
        fixture.stop()
        fixture.start()
        fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        assert pg('SELECT COUNT(*) FROM shared_rows', 'reader') == '1'
        marker = fixture.root / 'stale-activation'
        marker.mkdir(mode=0o700)
        old['activation_directory'] = str(marker)
        old['postgres_port'] = old['mysql_port'] = old['health_port'] = None
        stale = fixture.root / 'stale-gateway.json'
        stale.write_text(json.dumps(old))
        denied([gateway, stale])

        policy(fixture, 'REVOKE SELECT ON TABLE public.shared_rows FROM reader CASCADE;', 'reader-revoke')
        pg('SELECT * FROM shared_rows', 'reader', reject=True)
        fixture.stop()
        fixture.config['sql']['mysql'] = None
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        closed(mysql_port)
        assert pg('SELECT COUNT(*) FROM shared_rows', 'writer') == '1'
        pg('SELECT * FROM shared_rows', 'reader', reject=True)
        policy(fixture, 'GRANT SELECT ON TABLE public.shared_rows TO reader;', 'reader-regrant')
        assert pg('SELECT COUNT(*) FROM shared_rows', 'reader') == '1'
        print('Local SQL: retained data, native fencing, PostgreSQL-only exposure and persistent revocation passed.', flush=True)

        # Rotate through the existing public credential control. The input file
        # is deliberately left unchanged afterwards: startup must not restore it.
        previous = passwords['owner']
        passwords['owner'] = secrets.token_hex(24)
        rotation = fixture.root / 'rotated.password'
        rotation.write_text(passwords['owner']); rotation.chmod(0o600)
        call([gateway, 'control', profile, 'credential', rotation, fixture.installation / 'sql/accounts/owner/verifier.json', '2'])
        args, env = pg_args()
        denied([*args, 'SELECT 1'], env=env | {'PGPASSWORD': previous})
        assert pg('SELECT 1') == '1'
        fixture.stop()
        fixture.config['sql']['postgres'] = None
        fixture.config['sql']['mysql'] = {'port': mysql_port}
        fixture.config['sql']['accounts'] = [a | {'enabled': a['name'] != 'reader'} for a in accounts]
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        closed(pg_port)
        mysql('SELECT COUNT(*) FROM shared_rows', 'reader', reject=True)
        assert mysql('SELECT COUNT(*) FROM shared_rows', 'writer') == '1'
        assert mysql('SELECT 1') == '1'
        mysql('DELETE FROM shared_rows WHERE id=1', 'writer')
        assert mysql('SELECT COUNT(*) FROM shared_rows', 'writer') == '0'
        print('Local SQL: MySQL-only exposure, disabled account, password rotation and DELETE passed.', flush=True)

        # Lose the client response after an operation reaches the durable ledger.
        # Observe its identity; never submit this SQL a second time.
        before = {e['operation'] for e in controls('list')['entries']}
        lost = subprocess.Popen([*mysql_args(), "INSERT INTO shared_rows (id,label) VALUES (2,'retained')"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic()+180
            operation = None
            while time.monotonic() < deadline:
                fresh = [e for e in controls('list')['entries'] if e['operation'] not in before and e['phase'] in ('active', 'terminal')]
                if fresh:
                    assert len(fresh) == 1
                    assert fresh[0]['phase'] == 'active', 'The proof must interrupt accepted, unfinished work'
                    operation = fresh[0]['operation']; break
                assert lost.poll() is None, lost.communicate()
                time.sleep(.3)
            assert operation is not None
        finally:
            if lost.poll() is None: lost.kill()
            lost.communicate(timeout=10)
        fixture.stop(kill=True)
        fixture.config['sql']['mysql'] = None
        fixture.config['sql']['accounts'] = [a for a in accounts if a['name'] != 'owner']
        fixture.config['sql']['tls'] = {'certificate_file': 'missing.pem', 'key_file': 'missing.key', 'ca_file': 'missing-ca.pem'}
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'recovery')
        closed(pg_port); closed(mysql_port)
        deadline = time.monotonic()+300
        while True:
            result = controls('status', operation)
            if result['terminal'] is not None:
                assert result['terminal']['state'] == 'applied', result
                break
            assert time.monotonic() < deadline, result
            time.sleep(.5)
        fixture.stop()
        fixture.config['sql']['postgres'] = {'port': pg_port}
        fixture.config['sql']['accounts'] = accounts
        fixture.config['sql']['tls'] = {}
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        assert pg('SELECT COUNT(*) FROM shared_rows WHERE id=2', 'reader') == '1'
        assert controls('status', operation)['terminal']['state'] == 'applied'
        print('Local SQL: lost response recovered by original operation identity with both listeners disabled and no PEM access.', flush=True)

        # Expired supplied material withdraws admission but leaves recovery and
        # the public administrator available. Replace trust explicitly afterwards.
        trust = fixture.root / 'replacement-trust'
        trust.mkdir(mode=0o700)
        cert, key, expired = trust/'server.pem', trust/'server.key', trust/'expired.pem'
        call(['openssl', 'req', '-x509', '-newkey', 'ec', '-pkeyopt', 'ec_paramgen_curve:prime256v1',
            '-nodes', '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1',
            '-keyout', key, '-out', cert])
        key.chmod(0o600)
        call(['openssl', 'x509', '-in', cert, '-signkey', key, '-not_before', '20000101000000Z', '-not_after', '20010101000000Z', '-out', expired])
        fixture.stop()
        fixture.config['sql']['tls'] = dict(certificate_file=str(expired), key_file=str(key), ca_file=str(expired))
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready(timeout=300)
        status = wait_status(fixture, lambda s: s['service']['state'] == 'recovery')
        assert status['service']['tls_error'] == 'InvalidTlsCredentials', status
        closed(pg_port)
        assert controls('status', operation)['terminal']['state'] == 'applied'
        fixture.stop()
        fixture.config['sql']['tls'] = dict(certificate_file=str(cert), key_file=str(key), ca_file=str(cert))
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        args, env = pg_args()
        denied([*args, 'SELECT 1'], env=env)  # The previous CA cannot authorize the new leaf.
        ca = str(cert)
        assert pg('SELECT COUNT(*) FROM shared_rows WHERE id=2', 'reader') == '1'
        print('Local SQL: expired trust blocks admission without blocking recovery; explicit TLS replacement and client CA update passed.', flush=True)
        print(json.dumps({'local_sql': 'passed', 'installed_bundle': bundle is not None, 'elapsed_seconds': round(time.monotonic()-started, 3)}), flush=True)
        success = True
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Local SQL evidence retained at {fixture.root}', file=sys.stderr, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('binaries', nargs='*')
    args = parser.parse_args()
    if args.bundle:
        root = args.bundle.resolve()
        run(*(root/'bin'/name for name in ('transit', 'transit-node', 'transit-query-host', 'transit-board', 'transit-sql-gateway')), bundle=root)
    else:
        assert len(args.binaries) == 5
        run(*args.binaries)
