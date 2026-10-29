"""Pinned database drivers against the real TLS gateway and local durable owners."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import socket
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request

from harness.services import free_port, free_ports, wait_ready
from runner.capture import identity, provenance
from runner.paths import ROOT
import psycopg
import mysql.connector


@contextmanager
def directory(binaries):
    # Nix removes its TMPDIR on shell exit, including failed-run evidence.
    root = Path(tempfile.mkdtemp(prefix='transit-direct-sql-wire-', dir='/var/tmp'))
    try:
        yield root
    except BaseException:
        # The inner fixture joins its processes before this handler. Keep the
        # original absolute paths, accepted history and exact executables for
        # original-outcome inspection; never create a replacement installation.
        print(f'Failed SQL wire installation retained privately at {root}', file=sys.stderr, flush=True)
        try:
            saved = root / 'executables'
            saved.mkdir(mode=0o700)
            records = []
            for role, binary in binaries.items():
                target = saved / role
                shutil.copy2(binary, target)
                records.append(dict(role=role, **identity(target)))
            (root / 'failure-source.json').write_text(json.dumps(dict(source=provenance(ROOT), binaries=records), indent=2)+'\n')
        except OSError as error:
            print(f'Failed to preserve complete binary evidence: {type(error).__name__}', file=sys.stderr, flush=True)
        raise
    else:
        shutil.rmtree(root)


def run(node, catalog, ledger, host, gateway, configuration_host, console, slice="all", repeat="5", instrumentation=""):
    assert slice in ("all","faults","controls","cli","settings","lifecycle","benchmark","schema","sessions","sessions-basic","sessions-kv","sessions-table","transactions","console-statements")
    assert instrumentation in ('', '--instrument')
    instrumented = instrumentation == '--instrument'
    assert not instrumented or slice == 'console-statements'
    repeat = int(repeat)
    assert 1 <= repeat <= 100
    node, catalog, ledger, host, gateway, configuration_host = [str(Path(p).resolve()) for p in (node, catalog, ledger, host, gateway, configuration_host)]
    binaries = dict(node=node, catalog=catalog, ledger=ledger, host=host, gateway=gateway,
                    configuration_host=configuration_host, console=str(Path(console).resolve()))
    if slice == 'console-statements':
        import hashlib
        import platform
        print(json.dumps(dict(profile='console_statements_tls_control', source=provenance(ROOT),
                              binaries={role: identity(Path(path)) for role, path in binaries.items()},
                              driver_sha256=hashlib.sha256((ROOT / 'tests/performance/console/statements.py').read_bytes()).hexdigest(),
                              platform=platform.platform(), load=os.getloadavg(), repeat=repeat,
                              native_request_timeout_ms=30000, instrumented=instrumented,
                              probe_scope='SQL gateway upstream only' if instrumented else None,
                              limits='TLS component control; not the default installed server. Small sequential samples; no isolated load or tail SLO.')), flush=True)
    with directory(binaries) as root:
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        session_port, native_port, sql_port, mysql_port, health_port, settings_port = free_ports(6)
        url = f'http://127.0.0.1:{native_port}'
        public = json.loads(subprocess.check_output([catalog, 'public'], timeout=10))
        node_config = root / 'node.json'
        node_settings = dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000), local_directory=str(root/'native'), port=native_port, resident_pages=8, request_timeout_ms=30000,request_metrics=True)
        node_config.write_text(json.dumps(node_settings))
        processes, logs = [], []
        probe = None
        session_faults = None
        settings_faults = None
        def start(binary, config, *before):
            log = (root / f'process-{len(logs)}.log').open('w+')
            logs.append(log)
            child = subprocess.Popen([binary, *before, str(config)], stdout=log, stderr=subprocess.STDOUT)
            processes.append(child)
            return child
        def call(binary, mode, *args, via=None):
            result = subprocess.run([binary, via or url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=1800 if mode == 'session-sources' else 300)
            if result.returncode:
                raise RuntimeError(f'{mode}: {result.stderr[-8000:]}')
            return json.loads(result.stdout)
        def controls(*args):
            deadline, refusals = time.monotonic()+30, 0
            while True:
                result = subprocess.run([gateway, 'control', str(root/'sql-control.json'), *map(str,args)], capture_output=True, text=True, timeout=40)
                # Repeat only pure inspection when native capacity refuses it.
                # Never prepare/submit another control or replay SQL here.
                if not result.returncode or args[0] not in ('list', 'status') or not any(cause in result.stderr for cause in ('HttpCapacity', 'StaleStateResource')) or time.monotonic() >= deadline:
                    break
                assert not result.stdout, 'Failed control inspection disclosed output'
                refusals += 1
                time.sleep(.05)
            if refusals:
                print(json.dumps(dict(profile='database_wire_control_observation_retry', operation=args[0], refused_reads=refusals)), flush=True)
            if result.returncode:
                assert not result.stdout, 'Failed control inspection disclosed output'
            assert result.returncode == 0, result.stderr
            return json.loads(result.stdout)
        def inventory():
            page = controls('list')
            entries = [entry for entry in page['entries'] if entry]
            while page['next']:
                assert len(entries) < 128, 'Fixture inventory exceeded its expected size'
                page = controls('list',page['next'])
                entries.extend(entry for entry in page['entries'] if entry)
            assert len({entry['id'] for entry in entries}) == len(entries)
            return entries
        settings_binding = None
        def configure():
            call(ledger, 'app-config', sql_port)
            configuration = json.loads((root/'sql-gateway.json').read_text())
            if settings_binding is not None:
                configuration['settings'] = dict(url=settings_faults.url if settings_faults is not None else f'http://127.0.0.1:{settings_port}', binding=settings_binding)
            configuration['mysql_port'] = mysql_port
            if slice in ('sessions', 'sessions-basic', 'sessions-kv', 'sessions-table', 'transactions', 'console-statements'):
                configuration['native'] = dict(instance=[81]*16, port=session_port, tls=dict(certificate_file=str(root/'certificate.pem'), key_file=str(root/'key.pem')))
                configuration['accounts'][0]['sources'] = json.loads((root/'session-sources.json').read_text()) if slice in ('sessions', 'sessions-kv', 'sessions-table') else []
                if session_faults is not None:
                    configuration['native_url'] = session_faults.url
                if instrumented:
                    configuration['native_url'] = probe.url
            configuration['health_port'] = health_port
            configuration['drain_ms'] = 1000
            configuration['request_timeout_ms'] = 30000
            configuration['limits'] = dict(connections=8,connections_per_account=8,authentications=4,command_ms=270000,idle_ms=270000,session_lease_ms=270000)
            (root/'sql-gateway.json').write_text(json.dumps(configuration))
        def certificate():
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost', '-keyout', str(root/'key.pem'), '-out', str(root/'certificate.pem')], capture_output=True, check=True, timeout=30)
            (root/'key.pem').chmod(0o600)
        started = time.monotonic()
        try:
            subprocess.run([node, str(node_config), '--initialize'], capture_output=True, check=True, timeout=30)
            authority = start(node, node_config)
            wait_ready(http, authority, url + '/health')
            call(catalog, 'provision')
            authority.terminate()
            authority.wait(timeout=10)
            node_settings['table'] = json.loads((root/'catalog-node.json').read_text())
            node_config.write_text(json.dumps(node_settings))
            authority = start(node, node_config)
            wait_ready(http, authority, url + '/health')
            call(catalog, 'initialize')
            call(catalog, 'external-provision')
            # Catalog administration and external DDL retain principal 1234;
            # this gateway alone sequences Table principal 1235.
            call(ledger, 'provision-empty', 1235)
            assert call(ledger, 'raw-denied')['raw_denied']
            settings_binding = call(ledger, 'configuration')
            from interfaces.sql_wire.settings import start_configuration
            settings_source = start_configuration(root,configuration_host,settings_port,url,settings_binding,start)
            if slice in ('all', 'settings'):
                from interfaces.sql_sessions.faults import Faults
                settings_faults = Faults(f'http://127.0.0.1:{settings_port}')

            if slice in ('sessions', 'sessions-basic', 'sessions-kv', 'sessions-table', 'transactions'):
                from interfaces.sql_sessions.faults import Faults
                session_faults = Faults(url)
            if slice in ('sessions', 'sessions-kv', 'sessions-table'):
                call(ledger, 'session-sources', *([slice.removeprefix('sessions-')] if slice in ('sessions-kv', 'sessions-table') else []))
            if instrumented:
                from harness.http_probe import Probe
                probe = Probe(url, native=True)
            configure()
            certificate()
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
            from interfaces.sql_wire.clients import run as clients, run_cli, connection_options as client_options
            if slice == 'console-statements':
                from performance.console.statements import tls
                tls(root, session_port, str(Path(console).resolve()), repeat,
                    probes={'native': probe} if instrumented else {})
                return
            if slice in ('sessions', 'sessions-basic', 'sessions-kv', 'sessions-table', 'transactions'):
                from interfaces.sql_sessions.native import run as sessions
                source_processes = {}
                def select_source(name):
                    # Run the selected owner/requester pair within the node's
                    # four wait lanes. Pausing the other pairs also exercises
                    # recovery while independent durable work cannot advance.
                    for source, group in source_processes.items():
                        for child in group:
                            assert child.poll() is None
                            child.send_signal(signal.SIGCONT if source == name else signal.SIGSTOP)
                    if name is not None and name not in source_processes:
                        source_processes[name] = [start(host, root/f'session-{name}-{role}.json') for role in ('source', 'requester', 'courier')]
                def restart_sessions(peer=False, wire=True, session_lease_ms=None, transaction_limits=None):
                    nonlocal server
                    server.kill()
                    server.wait(timeout=10)
                    call(ledger, 'fence')
                    configure()
                    if transaction_limits is not None:
                        configuration = json.loads((root/'sql-gateway.json').read_text())
                        configuration['accounts'][0]['execution']['transaction_limits'] = transaction_limits
                        (root/'sql-gateway.json').write_text(json.dumps(configuration))
                    if session_lease_ms is not None:
                        configuration = json.loads((root/'sql-gateway.json').read_text())
                        configuration['limits']['session_lease_ms'] = session_lease_ms
                        (root/'sql-gateway.json').write_text(json.dumps(configuration))
                    if not wire:
                        configuration = json.loads((root/'sql-gateway.json').read_text())
                        configuration['postgres_port'] = configuration['mysql_port'] = None
                        (root/'sql-gateway.json').write_text(json.dumps(configuration))
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
                if slice == 'transactions':
                    from interfaces.sql_sessions.transactions import run as transactions
                    transactions(root, session_port, *client_options(root, sql_port, mysql_port), restart_sessions, session_faults, lambda allowed: call(catalog, 'external-role', 'allow' if allowed else 'deny'))
                    return
                sessions(root, session_port, client_options(root,sql_port,mysql_port)[0], restart_sessions, str(Path(console).resolve()), lambda allowed: call(catalog, 'external-role', 'allow' if allowed else 'deny'), select_source, lambda: call(ledger, 'source-pin-status'), {'sessions-basic': (), 'sessions-kv': (('kv', 41),), 'sessions-table': (('table', 41),)}.get(slice), session_faults, lambda: server.pid)
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
            if slice == 'schema':
                from interfaces.sql_wire.schema import run as schema
                schema(options,mysql_options,lambda operation,sql:call(catalog,'external-ddl-admin',operation,sql))
                return
            if slice == 'benchmark':
                with psycopg.connect(**options) as connection:
                    connection.execute('INSERT INTO wire_rows (id) VALUES (101),(102),(103),(104)')
                from interfaces.sql_wire.measure import foundation
                foundation(options,mysql_options,dict(node=node,catalog=catalog,ledger=ledger,host=host,gateway=gateway,configuration_host=configuration_host))
                return
            from interfaces.sql_wire.settings import run as settings_proof
            settings_proof(root,options,mysql_options,settings_source,lambda mode: call(ledger,mode),settings_faults)
            if slice == 'settings':
                return
            if slice == 'lifecycle':
                with psycopg.connect(**options) as connection:
                    connection.execute('INSERT INTO wire_rows (id) VALUES (1),(2),(3),(4)')
                from interfaces.sql_wire.lifecycle import capacity, drain
                capacity(options,health_port)
                drain(server,options,health_port)
                return
            # Both adapters select the NOLOGIN data role through SET-only
            # membership. The verifier cannot
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
                        else: raise AssertionError('SQL login bypassed selected-role authority')
                finally:
                    assert call(catalog, 'external-role', 'allow')['selected']
            print(json.dumps(dict(profile='database_wire_selected_role',set_only=True,revoked_sessions=True,revoked_logins=True,raw_reader_denied=True)),flush=True)
            from interfaces.sql_wire.faults import run as faults
            faults(root, options, mysql_options, controls, inventory,
                   lambda allowed:call(catalog,'external-read-grants','allow' if allowed else 'deny'),
                   lambda allowed:call(catalog,'external-write-grants','allow' if allowed else 'deny'))
            from interfaces.sql_wire.authority import run as authority_checks
            authority_checks(options,mysql_options,lambda allowed:call(catalog,'external-write-grants','allow' if allowed else 'deny'),inventory)
            page = controls('list')
            operation = page['entries'][0]['id']
            assert controls('status',operation)['terminal']['state'] == 'applied'
            assert controls('status',operation)['terminal']['state'] == 'applied'
            # An exited activation cannot be reused. Fencing creates eligibility.
            server.kill()
            server.wait(timeout=10)
            stale = subprocess.run([gateway,str(root/'sql-gateway.json')],capture_output=True,text=True,timeout=20)
            assert stale.returncode != 0 and 'StaleGatewayCoordinator' in stale.stderr
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
            from interfaces.sql_wire.measure import run as measure
            measure(options,mysql_options,lambda sql:call(catalog,"select",sql))
            if slice != 'controls':
                from interfaces.sql_wire.values import run as values
                values(options,mysql_options,controls,inventory)
            from interfaces.sql_wire.schema import run as schema
            schema(options,mysql_options,lambda operation,sql:call(catalog,'external-ddl-admin',operation,sql))
            if slice in ('all','controls'):
                from interfaces.sql_wire.phases import run as phases
                phases(options,mysql_options,server.pid)
                # Instrument a fresh activation separately from direct timings.
                # The probe retains bounded counters, never SQL or credentials.
                server.kill()
                server.wait(timeout=10)
                call(ledger,'fence')
                configure()
                from harness.http_probe import Probe
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
                from interfaces.sql_wire.costs import run as costs
                costs(options,mysql_options,lambda sql:call(catalog,'select',sql,via=probe.url),probe)
            from interfaces.sql_wire.lifecycle import capacity, drain
            capacity(options,health_port)
            drain(server,options,health_port)
            assert any(path.is_file() for path in (root/'native').rglob('*'))
            print(json.dumps(dict(profile='database_wire_local_storage',resident_pages=8,
                                  tseg_segments=sum(1 for _ in (root/'native').rglob('*.tseg')))),flush=True)
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
            if settings_faults is not None:
                settings_faults.close()
            if session_faults is not None:
                session_faults.close()
                if sys.exc_info()[0]:
                    print('Recent session authority rejections:', session_faults.rejections, file=sys.stderr)
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
