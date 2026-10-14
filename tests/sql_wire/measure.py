"""Small retained end-to-end observations, not an operator benchmark or SLO."""
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time

import psycopg
import mysql.connector


def run(postgres, mysql_options, native):
    samples = {name:[] for name in ('native_process','postgres_literal','postgres_prepared','mysql_literal','mysql_prepared')}
    sql = 'SELECT id FROM wire_rows WHERE id=101'
    # All samples read the same one-row selection in the same disk-backed
    # authority. One warm-up per path is excluded; five observations are retained.
    with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        text = my.cursor()
        prepared = my.cursor(prepared=True)
        for i in range(6):
            for name in samples:
                start = time.perf_counter_ns()
                if name == 'native_process':
                    rows = native(sql)['rows']
                    assert len(rows) == 1 and len(rows[0]) == 1
                    assert rows[0][0]['cell']['value']['atom']['signed'] == '101'
                elif name.startswith('postgres'):
                    rows = pg.execute('SELECT id FROM wire_rows WHERE id=%s',(101,),prepare=True).fetchall() if name.endswith('prepared') else pg.execute(sql).fetchall()
                    assert rows == [(101,)]
                else:
                    cursor = prepared if name.endswith('prepared') else text
                    cursor.execute('SELECT id FROM wire_rows WHERE id=%s',(101,)) if name.endswith('prepared') else cursor.execute(sql)
                    assert cursor.fetchall() == [(101,)]
                elapsed = (time.perf_counter_ns()-start)/1e6
                if i: samples[name].append(round(elapsed,3))
        text.close(); prepared.close()
    cpu = next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')),platform.processor())
    value = dict(profile='database_wire_measurement',source_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),tracked_changes=subprocess.run(['git','diff','--quiet']).returncode != 0,system=platform.system(),machine=platform.machine(),processor=cpu,available_cpus=len(os.sched_getaffinity(0)),rows=4,selected_rows=1,warmups=1,repetitions=5,unit='ms',samples=samples,median={name:statistics.median(values) for name,values in samples.items()},limits='Native includes a fresh process and compilation; drivers retain a connection and prepared handles. Sequential local observations include authority and TLS costs; other proof/build tasks may compete for resources. No throughput, speedup or production latency claim.')
    print(json.dumps(value),flush=True)
    return value
