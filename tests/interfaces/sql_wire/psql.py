"""Real psql 18 meta-commands over the shared authorized catalog projections.

Invoked by gateway.py's cli/all slices. SQL comes from the independent installed
client, not production templates. Expected names, types and failures are fixed.
"""
import os
import re
import struct
import subprocess

import psycopg

from interfaces.sql_wire.faults import PostgreSQL, frame


def run(root, options, role, inventory):
    env = os.environ.copy()
    env['LC_MESSAGES'] = 'C'
    env.update(PGPASSWORD=options['password'], PGSSLMODE='verify-full',
               PGSSLROOTCERT=options['sslrootcert'], PGHOSTADDR=options['hostaddr'])
    base = ['psql', '-XAtw', '-v', 'ON_ERROR_STOP=1', '-h', options['host'],
            '-p', str(options['port']), '-U', options['user'], '-d', options['dbname']]

    def invoke(command, *, echo=False, failure=False, headings=False):
        result = subprocess.run([*base, *(['-E'] if echo else []),
                                 *(['-P', 'tuples_only=off'] if headings else []), '-c', command],
                                env=env, capture_output=True, text=True, timeout=180)
        assert (result.returncode != 0) == failure, (command, result.stdout, result.stderr)
        return result

    with psycopg.connect(**options) as pg:
        # More than one native catalog page, created in reverse name order.
        names = [f'psql_meta_{i:02d}' for i in range(10)]
        for name in reversed(names):
            pg.execute(f'CREATE TABLE {name} (id BIGINT PRIMARY KEY)')
        pg.execute('CREATE TABLE "psql_雪.O\'Brien" (id BIGINT, label UTF8 DEFAULT \'it\'\'s\')')
        # More than one wire metadata batch, with a schema-bound primary key.
        pg.execute('CREATE TABLE psql_wide (id BIGINT PRIMARY KEY, ' +
                   ', '.join(f'column_{i:02d} BIGINT' for i in range(40)) + ')')
        before = {entry['id'] for entry in inventory()}
        listed = invoke(r'\dt psql_meta_*').stdout.strip().splitlines()
        assert listed == [f'public|{name}|table|' for name in names], listed
        assert 'public|psql_wide|table|' in invoke(r'\d').stdout.splitlines()
        assert invoke(r'\dt public.psql_meta_0?').stdout.strip().splitlines() == listed
        assert invoke(r'\dt no_such_table').stdout.strip() == ''
        assert invoke(r'\dn').stdout.strip() == 'public|'
        assert invoke(r'\dn pub*').stdout.strip() == 'public|'
        assert invoke(r'\l').stdout.strip() == 'data||UTF8||||||'
        assert invoke(r'\l dat*').stdout.strip() == 'data||UTF8||||||'
        quoted = invoke('\\d "psql_雪.O\'Brien"').stdout
        assert "'it''s'" in quoted and 'label|utf8|' in quoted, quoted
        detailed = invoke(r'\d public.psql_wide', echo=True, headings=True).stdout
        assert 'id|int64|' in detailed and 'column_39|int64|' in detailed, detailed
        assert 'PRIMARY KEY' in detailed and 'transit' in detailed, detailed
        queries = re.findall(r'/\*+ QUERY \*+/\n(.*?)\n/\*+/', detailed, re.S)
        columns = next(sql for sql in queries if 'FROM pg_catalog.pg_attribute a' in sql)
        # A changed predicate cannot be ignored by the compatibility layer.
        for sql in ('SELECT * FROM pg_catalog.pg_class', columns + ' SELECT 1',
                    columns.replace('ORDER BY a.attnum', 'ORDER BY a.attnum DESC')):
            try:
                pg.execute(sql, prepare=False)
            except psycopg.Error as error:
                assert error.sqlstate == '0A000', (sql, error)
                assert 'admitted work' not in str(error), error
                if sql != columns + ' SELECT 1':
                    assert 'catalog query' in str(error), error
            else:
                raise AssertionError('Unknown catalog query succeeded')
        assert 'Unsupported psql name pattern' in invoke(r'\dt (a|b)', failure=True).stderr
        assert 'Unsupported PostgreSQL catalog query' in invoke(r'\du', failure=True).stderr
        # Inspection does not allocate a durable SQL operation.
        assert {entry['id'] for entry in inventory()} == before

    held = PostgreSQL(options)
    try:
        held.sock.sendall(frame(b'P', b'hold\0' + columns.encode() + b'\0\0\0') +
                          frame(b'B', b'portal\0hold\0\0\0\0\0\0\0') +
                          frame(b'E', b'portal\0' + struct.pack('!I', 1)) + frame(b'H'))
        replies = held.until(b's', b'E')
        assert sum(tag == b'D' for tag, _ in replies) == 1 and replies[-1][0] == b's', replies
        assert role(False)['selected'] is False
        try:
            held.sock.sendall(frame(b'E', b'portal\0' + struct.pack('!I', 1)) + frame(b'S'))
            replies = held.until(b'Z')
            assert any(tag == b'E' and b'42501' in value for tag, value in replies), replies
            assert not any(tag in (b'D', b'C') for tag, _ in replies), replies
        finally:
            assert role(True)['selected']
    finally:
        held.close()
    print('psql 18: catalog pages, patterns, quoted names, wide descriptions, primary keys, unsupported queries and suspended metadata revocation passed.', flush=True)
