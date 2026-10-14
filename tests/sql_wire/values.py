"""Wire values, shared literal relational plans and session-incarnation checks."""
import json
import struct
import time

import psycopg
import mysql.connector
from faults import PostgreSQL, cancel, frame


def run(postgres,mysql_options):
    with psycopg.connect(**postgres) as pg:
        pg.execute("CREATE TABLE wire_defaults (id BIGINT PRIMARY KEY, label UTF8 DEFAULT 'fallback', required UTF8 NOT NULL)")
        pg.execute('INSERT INTO wire_defaults (id,required) VALUES (%s,%s)',(1,'present'),prepare=True)
        pg.execute('INSERT INTO wire_defaults (id,label,required) VALUES (%s,%s,%s)',(2,None,'present'),prepare=True)
        assert pg.execute('SELECT label FROM wire_defaults WHERE id=1').fetchone() == ('fallback',)
        assert pg.execute('SELECT label FROM wire_defaults WHERE id=2').fetchone() == (None,)
        try:
            pg.execute('UPDATE wire_defaults SET required=%s WHERE id=%s',(None,1),prepare=True)
        except psycopg.errors.NotNullViolation:
            pass
        else:
            raise AssertionError('Required field accepted NULL')
        assert pg.execute('SELECT required FROM wire_defaults WHERE id=1').fetchone() == ('present',)
        columns = ','.join(f'b{i} BINARY' for i in range(8))
        pg.execute('CREATE TABLE wire_large (id BIGINT PRIMARY KEY, label UTF8, payload BINARY,'+columns+')')
        label = '列'*1365+'x'
        payload = bytes(range(256))*16
        names = 'id,label,payload,'+','.join(f'b{i}' for i in range(8))
        statement = 'INSERT INTO wire_large ('+names+') VALUES ('+','.join(['%s']*11)+')'
        started = time.monotonic()
        print(json.dumps(dict(profile='database_wire_large_row',phase='begin',variable_bytes=10*4096)),flush=True)
        assert pg.execute(statement,(1,label,payload,*([payload]*8)),prepare=True).rowcount == 1
        print(json.dumps(dict(profile='database_wire_large_row',phase='complete',seconds=round(time.monotonic()-started,3))),flush=True)
        try:
            pg.execute('INSERT INTO wire_large (id,label) VALUES (%s,%s)',(2,'x'*4097),prepare=True)
        except psycopg.errors.ProgramLimitExceeded:
            pass
        else:
            raise AssertionError('Oversized bound cell was admitted')
        with pg.cursor(binary=True) as cursor:
            cursor.execute('SELECT label,payload FROM wire_large WHERE id=%s',(1,),prepare=True)
            assert cursor.fetchone() == (label,payload)
        sql = 'SELECT a.id, SUM(b.id) AS total FROM wire_rows a JOIN wire_rows b ON a.id=b.id GROUP BY a.id'
        assert sorted(pg.execute(sql).fetchall()) == [(101,101),(102,102),(103,103),(200,200)]
    with mysql.connector.connect(**mysql_options) as my:
        cursor = my.cursor(prepared=True)
        cursor.execute('SELECT label,payload FROM wire_large WHERE id=%s',(1,))
        assert cursor.fetchone() == (label,payload)
        cursor.close()
        cursor = my.cursor()
        cursor.execute(sql)
        assert sorted(cursor.fetchall()) == [(101,101),(102,102),(103,103),(200,200)]
        cursor.close()
    old = PostgreSQL(postgres)
    old_key = old.key
    old.close()
    wire = PostgreSQL(postgres)
    try:
        wire.sock.sendall(frame(b'P',b'hold\0SELECT id FROM wire_rows\0\0\0')+frame(b'B',b'portal\0hold\0\0\0\0\0\0\0')+frame(b'E',b'portal\0'+struct.pack('!I',1))+frame(b'H'))
        assert wire.until(b's',b'E')[-1][0] == b's'
        cancel(postgres,old_key)
        wire.sock.sendall(frame(b'E',b'portal\0'+struct.pack('!I',1))+frame(b'H'))
        replies = wire.until(b's',b'E')
        assert sum(tag == b'D' for tag,_ in replies) == 1 and replies[-1][0] == b's'
        wire.sock.sendall(frame(b'S'))
        wire.until(b'Z')
        # The transport may split an application frame at every byte boundary.
        for byte in frame(b'Q',b'SELECT 1\0'):
            wire.sock.sendall(bytes([byte]))
        assert any(tag == b'D' for tag,_ in wire.until(b'Z'))
    finally:
        wire.close()
    print(json.dumps(dict(profile='database_wire_values',utf8_bytes=len(label.encode()),binary_bytes=len(payload),variable_bytes_per_row=10*4096,oversized_binding_rejected=True,defaults_and_null=True,required_rejection=True,literal_relational=True,stale_cancel=True,fragmented_query=True)),flush=True)
