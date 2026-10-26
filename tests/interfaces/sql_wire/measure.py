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


def foundation(postgres, mysql_options, executables):
    """Matched bounded read/write controls with exact cross-protocol readback."""
    import hashlib
    import shutil
    from performance.mutations.mutation_latency import distribution
    paths = ('postgres_literal', 'postgres_prepared', 'mysql_literal', 'mysql_prepared')
    cases = (
        ('point', 'SELECT id FROM wire_rows WHERE id=101', [(101,)]),
        ('range', 'SELECT id FROM wire_rows WHERE id>=101 AND id<=103', [(101,), (102,), (103,)]),
        ('full', 'SELECT id FROM wire_rows', [(101,), (102,), (103,), (104,)]),
        ('empty', 'SELECT id FROM wire_rows WHERE id=999', []),
        ('limit_zero', 'SELECT id FROM wire_rows LIMIT 0', []),
    )
    report = dict(profile='storage_foundation_database_wire', status='running',
                  source_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                  source_dirty=bool(subprocess.check_output(['git','status','--porcelain'])),
                  build_revision=os.environ.get('STORAGE_FOUNDATION_BUILD_REVISION'),
                  rows=4, warmups=1, read_repetitions=20, mutation_repetitions=3,
                  read_order='Unordered selection; the oracle sorts rows after timing.',
                  samples=[], errors=[], executables={},
                  limits='Sequential local disk/TLS observations after builds finish. Retained connections; one excluded warmup per read case/path. Read p95 has 20 samples; mutation medians have three, no tail claim. Synthetic scalar profile; no nested SQL wire support or production SLO is implied.')
    for name, binary in (executables | {name: shutil.which(name) for name in ('ursula', 'minio')}).items():
        report['executables'][name] = hashlib.sha256(Path(binary).read_bytes()).hexdigest() if binary else None
    try:
        with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
            cursors = (my.cursor(), my.cursor(prepared=True))
            def execute(path, sql, read=False):
                if path.startswith('postgres'):
                    cursor = pg.execute(sql, prepare=path.endswith('prepared'))
                else:
                    cursor = cursors[int(path.endswith('prepared'))]
                    cursor.execute(sql)
                return cursor.fetchall() if read else cursor.rowcount
            for iteration in range(21):
                for path in paths:
                    for case, sql, expected in cases:
                        start = time.monotonic_ns()
                        rows = execute(path, sql, True)
                        elapsed = time.monotonic_ns() - start
                        assert sorted(rows) == expected, (path, case, rows)
                        if iteration:
                            report['samples'].append(dict(path=path, case=case, elapsed_ns=elapsed))
                if iteration and iteration % 5 == 0:
                    print(json.dumps(dict(profile='storage_foundation_database_wire_progress', phase='reads',
                                          completed=iteration * len(paths) * len(cases), total=400)), flush=True)
            for iteration in range(3):
                for path in paths:
                    for case, sql in (
                        ('insert', 'INSERT INTO wire_rows (id,n) VALUES (999,1)'),
                        ('update', 'UPDATE wire_rows SET n=2 WHERE id=999'),
                        ('delete', 'DELETE FROM wire_rows WHERE id=999'),
                    ):
                        start = time.monotonic_ns()
                        changed = execute(path, sql)
                        elapsed = time.monotonic_ns() - start
                        assert changed == 1, (path, case, changed)
                        report['samples'].append(dict(path=path, case=case, elapsed_ns=elapsed))
                        other = 'mysql_literal' if path.startswith('postgres') else 'postgres_literal'
                        expected = [] if case == 'delete' else [(999, 1 if case == 'insert' else 2)]
                        assert execute(other, 'SELECT id,n FROM wire_rows WHERE id=999', True) == expected
                print(json.dumps(dict(profile='storage_foundation_database_wire_progress', phase='mutations',
                                      completed=(iteration + 1) * len(paths) * 3, total=36)), flush=True)
            for cursor in cursors:
                cursor.close()
        grouped = {}
        for sample in report['samples']:
            grouped.setdefault(sample['path'] + ':' + sample['case'], []).append(sample['elapsed_ns'])
        report['distributions'] = {name: distribution(values) for name, values in grouped.items()}
        report['status'] = 'complete'
    except BaseException as error:
        report['status'] = 'failed'
        report['errors'].append(type(error).__name__ + ': ' + str(error))
        raise
    finally:
        print(json.dumps(report), flush=True)
    return report
