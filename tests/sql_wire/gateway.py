"""Pinned database drivers against the real TLS gateway and disk-backed owners."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from storage import Fixture, free_port, wait_ready
from cold_storage import ColdStore
import psycopg
import mysql.connector


def run(node, catalog, ledger, host, gateway, configuration_host, console, slice="all"):
    assert slice in ("all","faults","controls","cli","settings","lifecycle","benchmark","sessions")
    node, catalog, ledger, host, gateway, configuration_host = [str(Path(p).resolve()) for p in (node, catalog, ledger, host, gateway, configuration_host)]
    with ColdStore() as cold, Fixture(cold.config()) as store:
        root = store.root
        session_port = free_port()
        native_port, sql_port, mysql_port, health_port = free_port(), free_port(), free_port(), free_port()
        url = f'http://127.0.0.1:{native_port}'
        public = json.loads(subprocess.check_output([catalog, 'public'], timeout=10))
        node_config = root / 'node.json'
        node_config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000), ursula_url=store.url, bucket='sql-wire-gateway', journal='authority', port=native_port, resident_pages=8, request_timeout_ms=30000,request_metrics=True)))
        processes, logs = [], []
        probe = None
        def start(binary, config, *before):
            log = (root / f'process-{len(logs)}.log').open('w+')
            logs.append(log)
            child = subprocess.Popen([binary, *before, str(config)], stdout=log, stderr=subprocess.STDOUT)
            processes.append(child)
            return child
        def call(binary, mode, *args, via=None):
            result = subprocess.run([binary, via or url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=300)
            if result.returncode:
                raise RuntimeError(f'{mode}: {result.stderr[-8000:]}')
            return json.loads(result.stdout)
        def controls(*args):
            result = subprocess.run([gateway, 'control', str(root/'sql-control.json'), *map(str,args)], capture_output=True, text=True, timeout=40)
            if result.returncode:
                assert not result.stdout, 'Failed control inspection disclosed output'
            assert result.returncode == 0, result.stderr
            return json.loads(result.stdout)
        def inventory():
            page = controls('list')
            entries = page['entries']
            while page['next']:
                assert len(entries) < 128, 'Fixture inventory exceeded its expected size'
                cursor = root/'inventory-cursor.json'
                cursor.write_text(json.dumps(page['next']))
                page = controls('list',cursor)
                entries.extend(page['entries'])
            assert len({entry['operation'] for entry in entries}) == len(entries)
            return entries
        settings_binding = None
        settings_port = free_port()
        def configure():
            call(ledger, 'app-config', sql_port)
            configuration = json.loads((root/'sql-gateway.json').read_text())
            if settings_binding is not None:
                configuration['settings'] = dict(url=f'http://127.0.0.1:{settings_port}', binding=settings_binding)
            configuration['mysql_port'] = mysql_port
            if slice == 'sessions':
                configuration['native'] = dict(instance=[81]*16, port=session_port, tls=dict(certificate_file=str(root/'certificate.pem'), key_file=str(root/'key.pem')))
            configuration['health_port'] = health_port
            configuration['drain_ms'] = 1000
            configuration['request_timeout_ms'] = 30000
            configuration['limits'] = dict(connections=8,connections_per_account=8,authentications=4,command_ms=270000,idle_ms=270000)
            (root/'sql-gateway.json').write_text(json.dumps(configuration))
        def certificate():
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost', '-keyout', str(root/'key.pem'), '-out', str(root/'certificate.pem')], capture_output=True, check=True, timeout=30)
            (root/'key.pem').chmod(0o600)
        started = time.monotonic()
        try:
            subprocess.run([node, str(node_config), '--initialize'], capture_output=True, check=True, timeout=30)
            authority = start(node, node_config)
            wait_ready(store.http, authority, url + '/health')
            call(catalog, 'provision')
            call(catalog, 'initialize')
            call(catalog, 'pump')
            call(catalog, 'external-provision')
            call(catalog, 'pump')
            # Catalog administration and external DDL retain principal 1234;
            # this gateway alone sequences Table principal 1235.
            call(ledger, 'provision-empty', 1235)
            assert call(ledger, 'raw-denied')['raw_denied']
            settings_binding = call(ledger, 'configuration')
            from settings import start_configuration
            settings_source = start_configuration(root,configuration_host,settings_port,url,settings_binding,start)

            call(catalog, 'host')
            configure()
            certificate()
            start(host, root/'host.json')
            start(host, root/'courier-config.json')
            bootstrap = start(gateway, root/'sql-gateway.json', '--initialize')
            assert controls('prepare','initialize')['state'] == 'prepared'
            assert controls('submit')['processed']
            assert bootstrap.wait(timeout=20) == 0
            call(ledger, 'fence')
            configure()
            server = start(gateway, root/'sql-gateway.json')
            deadline = time.monotonic()+30
            while True:
                assert server.poll() is None, 'Gateway exited during startup'
                try:
                    with socket.create_connection(('127.0.0.1', sql_port), timeout=1):
                        break
                except ConnectionRefusedError:
                    assert time.monotonic() < deadline
                    time.sleep(.02)
            from clients import run as clients, run_cli, connection_options as client_options
            if slice == 'sessions':
                from sql_sessions.native import run as sessions
                def restart_sessions(peer=False):
                    nonlocal server
                    server.kill()
                    server.wait(timeout=10)
                    call(ledger, 'fence')
                    configure()
                    if peer:
                        configuration = json.loads((root/'sql-gateway.json').read_text())
                        configuration['native']['socket'] = str(root/'native.sock')
                        configuration['native']['port'] = None
                        configuration['native']['tls'] = None
                        configuration['postgres_port'] = configuration['mysql_port'] = None
                        configuration['accounts'][0]['authentication'] = 'peer'
                        configuration['accounts'][0]['peer_uid'] = os.geteuid()
                        credential_path = Path(configuration['accounts'][0]['verifier_file'])
                        credential = json.loads(credential_path.read_text())
                        credential['verifier'] = None
                        credential['revision'] += 1
                        credential_path.write_text(json.dumps(credential))
                        (root/'sql-gateway.json').write_text(json.dumps(configuration))
                    server = start(gateway, root/'sql-gateway.json')
                    deadline = time.monotonic() + 30
                    while True:
                        try:
                            if peer:
                                with socket.socket(socket.AF_UNIX) as connection:
                                    connection.connect(str(root/'native.sock'))
                            else:
                                with socket.create_connection(('127.0.0.1', session_port), timeout=1):
                                    pass
                            break
                        except (ConnectionRefusedError, FileNotFoundError):
                            assert server.poll() is None and time.monotonic() < deadline
                            time.sleep(.02)
                sessions(root, session_port, client_options(root,sql_port,mysql_port)[0], restart_sessions, str(Path(console).resolve()))
                return
            if slice == 'cli':
                run_cli(root,sql_port,mysql_port)
                print(json.dumps(dict(profile='database_wire_cli',seconds=round(time.monotonic()-started,3),fresh_fixture=True,both_protocols=True)),flush=True)
                return
            if slice == 'all':
                options,mysql_options = clients(root,sql_port,mysql_port)
            else:
                options,mysql_options = client_options(root,sql_port,mysql_port)
                with psycopg.connect(**options) as connection:
                    connection.execute('CREATE TABLE wire_rows (id BIGINT PRIMARY KEY, n UINT64, f FLOAT64, b BOOLEAN, label UTF8, payload BINARY)')
            if slice == 'benchmark':
                with psycopg.connect(**options) as connection:
                    connection.execute('INSERT INTO wire_rows (id) VALUES (101),(102),(103),(104)')
                from measure import foundation
                foundation(options,mysql_options,dict(node=node,catalog=catalog,ledger=ledger,host=host,gateway=gateway,configuration_host=configuration_host))
                return
            from settings import run as settings_proof
            settings_proof(root,options,mysql_options,settings_source,lambda mode: call(ledger,mode))
            if slice == 'settings':
                return
            if slice == 'lifecycle':
                with psycopg.connect(**options) as connection:
                    connection.execute('INSERT INTO wire_rows (id) VALUES (1),(2),(3),(4)')
                from lifecycle import capacity, drain
                capacity(options,health_port)
                drain(server,options,health_port)
                return
            # Both adapters select the NOLOGIN data role through SET-only
            # membership. Neither the verifier nor the private reader can
            # preserve that authority after membership revocation.
            with psycopg.connect(**options) as pg, mysql.connector.connect(**mysql_options) as my:
                assert pg.execute('SELECT 1').fetchone() == (1,)
                cursor = my.cursor()
                cursor.execute('SELECT 1'); assert cursor.fetchone() == (1,)
                assert call(catalog, 'external-role', 'deny')['selected'] is False
                try:
                    for execute, error in ((lambda: pg.execute('SELECT 1'), psycopg.Error),
                                           (lambda: cursor.execute('SELECT 1'), mysql.connector.Error)):
                        try: execute()
                        except error: pass
                        else: raise AssertionError('Retained SQL session survived selected-role revocation')
                    for connect, error in ((lambda: psycopg.connect(**options), psycopg.Error),
                                           (lambda: mysql.connector.connect(**mysql_options), mysql.connector.Error)):
                        try: connect().close()
                        except error: pass
                        else: raise AssertionError('SQL login substituted private reader authority')
                finally:
                    assert call(catalog, 'external-role', 'allow')['selected']
            print(json.dumps(dict(profile='database_wire_selected_role',set_only=True,revoked_sessions=True,revoked_logins=True,raw_reader_denied=True)),flush=True)
            from faults import run as faults
            faults(root, options, mysql_options, controls, lambda allowed:call(ledger,'native-read-allow' if allowed else 'native-read-deny'))
            from authority import run as authority_checks
            authority_checks(options,mysql_options,lambda allowed:call(catalog,'external-write-grants','allow' if allowed else 'deny'),inventory)
            page = controls('list')
            operation = page['entries'][0]['operation']
            assert controls('status',operation)['terminal']['state'] == 'applied'
            assert controls('prepare','reconcile',operation)['state'] == 'prepared'
            assert not controls('pending')['processed']
            assert controls('submit')['processed']
            assert controls('submit')['processed']
            # An exited activation cannot be reused. Fencing creates eligibility.
            server.kill()
            server.wait(timeout=10)
            stale = subprocess.run([gateway,str(root/'sql-gateway.json')],capture_output=True,text=True,timeout=20)
            assert stale.returncode != 0 and 'FreshOwnershipRequired' in stale.stderr
            call(ledger,'fence')
            configure()
            old_certificate = root/'old-certificate.pem'
            old_certificate.write_bytes((root/'certificate.pem').read_bytes())
            certificate()
            server = start(gateway,root/'sql-gateway.json')
            deadline = time.monotonic()+20
            while True:
                try:
                    connection = psycopg.connect(**options)
                    break
                except psycopg.OperationalError:
                    assert server.poll() is None and time.monotonic()<deadline
                    time.sleep(.05)
            with connection:
                assert connection.execute('SELECT COUNT(*) FROM wire_rows').fetchone() == (3,)
                assert connection.execute('INSERT INTO wire_rows (id) VALUES (200)').rowcount == 1
            for connect,error in ((lambda:psycopg.connect(**(options|dict(sslrootcert=str(old_certificate)))),psycopg.Error),
                                  (lambda:mysql.connector.connect(**(mysql_options|dict(ssl_ca=str(old_certificate)))),mysql.connector.Error)):
                try:
                    connect().close()
                except error:
                    pass
                else:
                    raise AssertionError('Old certificate trust admitted the replacement server')
            with mysql.connector.connect(**mysql_options) as verified:
                cursor = verified.cursor()
                cursor.execute('SELECT COUNT(*) FROM wire_rows')
                assert cursor.fetchone() == (4,)
                cursor.close()
            print(json.dumps(dict(profile='database_wire_certificate_rotation',both_protocols=True,old_trust_rejected=True,new_trust_verified=True)),flush=True)
            from measure import run as measure
            measure(options,mysql_options,lambda sql:call(catalog,"select",sql))
            if slice != 'controls':
                from values import run as values
                values(options,mysql_options,controls,inventory)
            from schema import run as schema
            schema(options,mysql_options,lambda operation,sql:call(catalog,'external-ddl-admin',operation,sql))
            if slice in ('all','controls'):
                from phases import run as phases
                phases(options,mysql_options,server.pid)
                # Instrument a fresh activation separately from direct timings.
                # The probe retains bounded counters, never SQL or credentials.
                server.kill()
                server.wait(timeout=10)
                call(ledger,'fence')
                configure()
                from latency_probe import Probe
                probe = Probe(url,native=True)
                configuration = json.loads((root/'sql-gateway.json').read_text())
                configuration['native_url'] = probe.url
                (root/'sql-gateway.json').write_text(json.dumps(configuration))
                server = start(gateway,root/'sql-gateway.json')
                deadline = time.monotonic()+30
                while True:
                    try:
                        psycopg.connect(**options).close()
                        break
                    except psycopg.OperationalError:
                        assert server.poll() is None and time.monotonic()<deadline
                        time.sleep(.05)
                from costs import run as costs
                costs(options,mysql_options,lambda sql:call(catalog,'select',sql,via=probe.url),probe)
            from lifecycle import capacity, drain
            capacity(options,health_port)
            drain(server,options,health_port)
            objects = cold.data_objects()
            assert objects > 0, 'No data reached the cold-store fixture'
            print(json.dumps(dict(profile='database_wire_cold_storage',data_objects=objects,file_bytes=cold.file_bytes(),hot_bytes=8*1024*1024,cache_bytes=8*1024*1024,resident_pages=8)),flush=True)
            print(json.dumps(dict(profile='database_native_gateway', slice=slice, psycopg=psycopg.__version__, connector=mysql.connector.__version__, driver_matrix=slice=='all',wide_values=slice!='controls', seconds=round(time.monotonic()-started, 3))))
        finally:
            if sys.exc_info()[0]:
                # Let bounded telemetry flush before terminating the fixtures.
                time.sleep(.3)
            for child in reversed(processes):
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            if probe:
                probe.close()
            if sys.exc_info()[0]:
                for log in logs:
                    log.flush()
                    log.seek(0)
                    sys.stderr.write(log.read()[-10000:])
            for log in logs:
                log.close()
    if slice == 'all':
        # The CLI lifecycle has its own history so expanding it does not change
        # the existing wide-row measurement's retained state or observation bound.
        # Both schedules must pass for the complete gateway task to succeed.
        run(node,catalog,ledger,host,gateway,configuration_host,console,'cli')


if __name__ == '__main__':
    run(*sys.argv[1:])
