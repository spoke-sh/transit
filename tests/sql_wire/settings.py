"""Settings parity and current configuration authority through real TLS drivers."""
import json
from pathlib import Path
import time
import urllib.request
import psycopg
import mysql.connector


def start_configuration(root, binary, port, upstream, binding, start):
    source = root / 'transit.yaml'
    # Only the gateway and configuration owner run in this placement. Executable
    # paths are validated inputs; this proof never launches the other services.
    source.write_text(json.dumps(dict(installation=str(root),realm=46,ports=dict(gateway=port),executables={name:binary for name in ('minio','ursula','node','query_host','board')})))
    deployment = root / 'configuration-deployment.json'
    deployment.write_text(json.dumps(dict(source=str(source),checkpoint=str(root/'configuration.json'),gateway=str(root/'configuration-gateway.json'),binding=binding,upstream=upstream,port=port)))
    child = start(binary,deployment)
    deadline = time.monotonic()+30
    while True:
        assert child.poll() is None, 'Configuration owner exited'
        try:
            with urllib.request.urlopen(f'http://127.0.0.1:{port}/health',timeout=1) as reply:
                assert reply.status == 200
                return source
        except OSError:
            assert time.monotonic()<deadline
            time.sleep(.05)


def run(root, postgres, mysql_options, source, policy):
    with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        cursor = my.cursor()
        assert pg.execute('SHOW DATABASES').fetchall() == [('data',)]
        cursor.execute('SHOW DATABASES'); assert cursor.fetchall() == [('data',)]
        assert pg.execute('SHOW SCHEMAS').fetchall()
        cursor.execute('SHOW SCHEMAS'); assert cursor.fetchall()
        assert pg.execute('SHOW query.statement_timeout',prepare=True).fetchone() == ('0',)
        cursor.execute('SHOW query.statement_timeout'); assert cursor.fetchone() == ('0',)
        for execute in (pg.execute,cursor.execute):
            execute("SET query.statement_timeout = '30s'")
        assert pg.execute('SHOW query.statement_timeout').fetchone() == ('30000',)
        cursor.execute('SHOW query.statement_timeout'); assert cursor.fetchone() == ('30000',)
        for execute in (pg.execute,cursor.execute):
            execute('RESET ALL')
        assert pg.execute('SHOW query.statement_timeout').fetchone() == ('0',)
        definition = json.loads(source.read_text())
        definition['gateway_allowed_hosts'] = ['settings-proof.example:18080']
        definition['query'] = dict(statement_timeout='5s',statement_timeout_ceiling='10s')
        source.write_text(json.dumps(definition))
        operation = pg.execute('SELECT transit_reload_conf()',prepare=True).fetchone()[0]
        assert len(operation)==32
        cursor.execute("SELECT value FROM transit_settings() WHERE name='gateway_allowed_hosts'")
        assert json.loads(cursor.fetchone()[0]) == ['settings-proof.example:18080']
        cursor.execute('SELECT transit_reload_conf()'); assert len(cursor.fetchone()[0])==32
        # Reload affects newly opened sessions. Both earlier sessions keep their
        # captured defaults; resetting cannot silently switch generations.
        assert pg.execute('SHOW query.statement_timeout').fetchone()==('0',)
        cursor.execute('SHOW query.statement_timeout'); assert cursor.fetchone()==('0',)
        with psycopg.connect(**postgres) as fresh:
            assert fresh.execute('SHOW query.statement_timeout').fetchone()==('5000',)
            assert fresh.execute('SHOW query.statement_timeout_ceiling').fetchone()==('10000',)
            try:
                fresh.execute("SET query.statement_timeout='11s'")
            except psycopg.Error:
                pass
            else:
                raise AssertionError('Administrator ceiling was bypassed')
            fresh.execute('SET query.statement_timeout=1')
            try:
                fresh.execute('SELECT * FROM transit_settings()').fetchall()
            except psycopg.Error:
                pass
            else:
                raise AssertionError('One-millisecond deadline did not bound metadata I/O')
        count = len(pg.execute('SELECT ordinal FROM transit_config_reloads()').fetchall())
        policy('configuration-deny')
        try:
            for execute, exception in ((pg.execute,psycopg.Error),(cursor.execute,mysql.connector.Error)):
                try:
                    execute('SELECT transit_reload_conf()')
                except exception:
                    pass
                else:
                    raise AssertionError('Revoked reload remained available')
            assert len(pg.execute('SELECT ordinal FROM transit_config_reloads()').fetchall())==count
            assert pg.execute('SHOW realm').fetchone()==('46',)
        finally:
            policy('configuration-allow')
            definition.pop('query')
            source.write_text(json.dumps(definition))
            pg.execute('SELECT transit_reload_conf()').fetchone()
        cursor.close()
    print('SQL configuration: PostgreSQL/MySQL settings, SET/RESET, authorized reload, paged metadata, and revocation passed.',flush=True)
