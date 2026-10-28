"""Native/provider attempt attribution through the existing bounded HTTP probe."""
from contextlib import ExitStack
import json
import os
import socket
import time

import psycopg
import mysql.connector

from interfaces.sql_wire.lifecycle import close_observed


def run(postgres,mysql_options,native,probe):
    observations=[]
    def sample(name,execute):
        before=probe.snapshot()
        start=time.perf_counter_ns()
        execute()
        elapsed=round((time.perf_counter_ns()-start)/1e6,3)
        after=probe.snapshot()
        observations.append(dict(path=name,elapsed_ms=elapsed,counters=dict(after-before)))
    with ExitStack() as cleanup, psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        # Retain descriptors solely to join peer closure after both client
        # contexts finish. A returned close() does not release the server's
        # authenticated slot or finish clearing its session reserve.
        peers = [cleanup.enter_context(socket.socket(fileno=os.dup(descriptor)))
                 for descriptor in (pg.pgconn.socket, my._socket.sock.fileno())]
        # This stack exits after the client contexts, preserving their normal
        # transaction and protocol teardown before observing EOF.
        for peer in peers:
            cleanup.callback(close_observed, peer.fileno(), lambda: None)
        text=my.cursor()
        prepared=my.cursor(prepared=True)
        sample('idle_100ms',lambda:time.sleep(.1))
        sql='SELECT id FROM wire_rows WHERE id=101'
        def native_read():
            rows=native(sql)['rows']
            assert len(rows)==1 and rows[0][0]['cell']['value']['atom']['signed']=='101'
        def pg_read(prepared):
            rows=pg.execute('SELECT id FROM wire_rows WHERE id=%s',(101,),prepare=True).fetchall() if prepared else pg.execute(sql).fetchall()
            assert rows==[(101,)]
        def my_read(cursor,prepared):
            cursor.execute('SELECT id FROM wire_rows WHERE id=%s',(101,)) if prepared else cursor.execute(sql)
            assert cursor.fetchall()==[(101,)]
        sample('native_process',native_read)
        sample('postgres_literal',lambda:pg_read(False))
        sample('postgres_prepared',lambda:pg_read(True))
        sample('mysql_literal',lambda:my_read(text,False))
        sample('mysql_prepared',lambda:my_read(prepared,True))
        text.close()
        prepared.close()
    assert all(item['counters'].get('work:responses',0)>0 for item in observations[1:])
    result=dict(profile='database_wire_native_costs',observations=observations,
                limits='One cold preparation/read per path through a bounded HTTP diagnostic proxy; this changes transport costs and is separate from unproxied timings. Counts cover gateway and explicit native caller attempts during each wall-clock window, including concurrent account maintenance. Data and authority work come from completed x-transit-work responses. Byte counters are HTTP JSON payloads, not TLS/database-wire traffic. No payloads or credentials are retained; no causal subtraction or speedup claim.')
    print(json.dumps(result),flush=True)
    return result
