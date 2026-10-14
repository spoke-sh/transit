"""Bounded phase observations with explicit client and process measurement limits."""
import json
from pathlib import Path
import statistics
import time

import psycopg
import mysql.connector
from faults import PostgreSQL, frame


def run(postgres, mysql_options, pid):
    names = ('postgres_connect','mysql_connect','postgres_prepare','mysql_prepare',
             'postgres_first_row','postgres_complete','mysql_first_row','mysql_complete',
             'postgres_write','mysql_write')
    samples = {name:[] for name in names}
    def elapsed(start):
        return round((time.perf_counter_ns()-start)/1e6,3)
    for i in range(6):
        start = time.perf_counter_ns()
        pg = psycopg.connect(**postgres)
        if i: samples['postgres_connect'].append(elapsed(start))
        pg.close()
        start = time.perf_counter_ns()
        my = mysql.connector.connect(**mysql_options)
        if i: samples['mysql_connect'].append(elapsed(start))
        my.close()
    wire = PostgreSQL(postgres)
    try:
        with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
            pg.execute('CREATE TABLE wire_measure (id BIGINT PRIMARY KEY)')
            read = my.cursor()
            write = my.cursor(prepared=True)
            for i in range(6):
                start = time.perf_counter_ns()
                wire.sock.sendall(frame(b'P',b'\0SELECT id FROM wire_rows WHERE id=$1\0\0\0')+frame(b'S'))
                assert (b'1',b'') in wire.until(b'Z')
                if i: samples['postgres_prepare'].append(elapsed(start))
                start = time.perf_counter_ns()
                statement = my.cmd_stmt_prepare(b'SELECT id FROM wire_rows WHERE id=?')
                if i: samples['mysql_prepare'].append(elapsed(start))
                my.cmd_stmt_close(statement['statement_id'])
                start = time.perf_counter_ns()
                wire.sock.sendall(frame(b'Q',b'SELECT id FROM wire_rows\0'))
                first = wire.until(b'D',b'E')
                assert first[-1][0] == b'D'
                if i: samples['postgres_first_row'].append(elapsed(start))
                rest = wire.until(b'Z')
                assert sum(tag == b'D' for tag,_ in rest) == 3
                if i: samples['postgres_complete'].append(elapsed(start))
                start = time.perf_counter_ns()
                read.execute('SELECT id FROM wire_rows')
                assert read.fetchone() is not None
                if i: samples['mysql_first_row'].append(elapsed(start))
                assert len(read.fetchall()) == 3
                if i: samples['mysql_complete'].append(elapsed(start))
                start = time.perf_counter_ns()
                assert pg.execute('INSERT INTO wire_measure (id) VALUES (%s)',(i,),prepare=True).rowcount == 1
                if i: samples['postgres_write'].append(elapsed(start))
                start = time.perf_counter_ns()
                write.execute('INSERT INTO wire_measure (id) VALUES (%s)',(100+i,))
                assert write.rowcount == 1
                if i: samples['mysql_write'].append(elapsed(start))
            read.close()
            write.close()
    finally:
        wire.close()
    status = dict(line.split(':',1) for line in Path(f'/proc/{pid}/status').read_text().splitlines() if ':' in line)
    memory = {name:int(status[name].split()[0]) for name in ('VmRSS','VmHWM')}
    result = dict(profile='database_wire_phases',unit='ms',samples=samples,median={name:statistics.median(values) for name,values in samples.items()},gateway_memory_kib=memory,warmups=1,repetitions=5,rows=4,
                  limits='Connect includes verified TLS, authentication and driver startup. Preparation excludes execution. First-row/complete use raw PostgreSQL frames and unbuffered Connector/Python, including driver and transport work. Writes include durable admission and observed completion. RSS is a Linux process sample; HWM covers this activation, not an allocator bound. Timings are sequential local observations, not an SLO or an encoding-only benchmark.')
    print(json.dumps(result),flush=True)
    return result
