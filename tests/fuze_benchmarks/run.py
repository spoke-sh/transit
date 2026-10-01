"""Reproducible bounded-file matrix with raw repetitions and fail-closed reports."""
import argparse
import csv
import ctypes
import datetime
import gzip
import hashlib
import io
import json
import mmap
import os
from pathlib import Path
import platform
import resource
import signal
import statistics
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
DEFINITION = 'transit.fuze.benchmarks.v1'
TYPES = 'transit.fuze.types.v1.2026-09-30'
SHAPES = ('narrow', 'wide', 'nested', 'sparse', 'decimal', 'identifiers', 'multifile', 'gzip', 'pipe')
MODES = ('explicit', 'partial', 'sampled', 'full', 'raw')


def digest(path):
    with Path(path).open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def field(name, typ, **flags):
    return dict(name=name, type=typ, nullable=False, optional=False, **flags)


def fixture(directory, shape, count):
    form = 'jsonl' if shape in ('nested', 'sparse', 'decimal') else 'csv'
    paths = [directory / f'{shape}-{n}.{form}' for n in range(2 if shape == 'multifile' else 1)]
    fields = [field('id', {'int64': {}})]
    if shape == 'wide': fields += [field(f'c{n:02}', {'utf8': {}}) for n in range(24)]
    elif shape == 'nested':
        fields += [field('items', {'list': {'type': {'int64': {}}, 'nullable': True}}),
            field('payload', {'structure': [field('flag', {'boolean': {}}), field('name', {'utf8': {}})]})]
    elif shape == 'sparse': fields += [dict(name='value', type={'int64': {}}, nullable=True, optional=True)]
    elif shape == 'decimal': fields += [field('amount', {'decimal': {'precision': 8, 'scale': 3}})]
    elif shape == 'identifiers': fields += [field('identifier', {'utf8': {}})]
    else: fields += [field('value', {'int64': {}})]
    for index, path in enumerate(paths):
        with path.open('w', newline='') as out:
            names = [f['name'] for f in fields]
            if index: names.reverse()
            writer = csv.DictWriter(out, fieldnames=names, lineterminator='\n')
            if form == 'csv': writer.writeheader()
            start = count * index // len(paths); end = count * (index + 1) // len(paths)
            for n in range(start, end):
                row = dict(id=n)
                if shape == 'wide': row.update({f'c{i:02}': f'column-{i:02}-' + 'x' * 24 for i in range(24)})
                elif shape == 'nested': row.update(items=[n, None, n + 1], payload=dict(flag=n % 2 == 0, name=f'name-{n % 17}'))
                elif shape == 'sparse':
                    if n % 3: row['value'] = n if n % 5 else None
                elif shape == 'decimal': row['amount'] = n % 1000 + 0.125
                elif shape == 'identifiers': row['identifier'] = f'00{n:08}'
                else: row['value'] = 100000 + n % 101
                if form == 'csv': writer.writerow(row)
                else: out.write(json.dumps(row, separators=(',', ':')) + '\n')
            out.flush(); os.fsync(out.fileno())
    expanded = [dict(length=p.stat().st_size, digest=digest(p)) for p in paths]
    if shape == 'gzip':
        compressed = paths[0].with_suffix('.csv.gz')
        with paths[0].open('rb') as src, compressed.open('wb') as target, gzip.GzipFile(fileobj=target, mode='wb', mtime=0, filename='') as out:
            while chunk := src.read(65536): out.write(chunk)
        paths = [compressed]
    return dict(shape=shape, format=form, paths=paths, fields=fields, expanded=expanded,
        files=[dict(name=p.name, bytes=p.stat().st_size, sha256=digest(p)) for p in paths])


def config(fixture, mode, rows, batch_rows, projected, query='all'):
    actual_mode = 'sampled' if mode == 'partial' else mode
    fields = fixture['fields'] if mode == 'explicit' else fixture['fields'][:1] if mode == 'partial' else None
    sql = 'SELECT id FROM input' if projected and mode != 'raw' else 'SELECT * FROM input'
    output_rows = rows
    result_sum = None if mode == 'raw' else rows*(rows-1)//2
    if query == 'filter':
        sql = f'SELECT id FROM input WHERE id < {rows//4}'
        output_rows = rows//4
        result_sum = output_rows*(output_rows-1)//2
    elif query == 'count':
        sql = 'SELECT count(*) FROM input'
        output_rows, result_sum = 1, rows
    elif query == 'sum':
        sql = 'SELECT sum(id) FROM input'
        output_rows = 1
    return dict(paths=['-'] if fixture['shape'] == 'pipe' else list(map(str, fixture['paths'])),
        options=dict(format=fixture['format'], mode=actual_mode, sample_records=1024, sample_bytes=1024*1024,
            max_scan_bytes=4*1024*1024*1024, max_records=100_000_000, max_record_bytes=65536, max_fields=128),
        schema_json=json.dumps(dict(definition=TYPES, type=dict(structure=fields))) if fields else None,
        gzip=fixture['shape'] == 'gzip', sql=sql, batch_rows=batch_rows, export_iterations=20,
        expected_rows=rows, expected_id_sum=None if mode == 'raw' else rows*(rows-1)//2,
        expected_output_rows=output_rows, expected_result_sum=result_sum)


def residency(path):
    size = path.stat().st_size
    if not size: return dict(pages=0, resident=0)
    with path.open('rb') as source, mmap.mmap(source.fileno(), size, access=mmap.ACCESS_COPY) as mapping:
        pages = (size + mmap.PAGESIZE - 1) // mmap.PAGESIZE
        flags = (ctypes.c_ubyte * pages)()
        address = ctypes.addressof(ctypes.c_char.from_buffer(mapping))
        libc = ctypes.CDLL(None, use_errno=True)
        libc.mincore.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
        if libc.mincore(address, size, flags): raise OSError(ctypes.get_errno(), 'mincore failed')
        return dict(pages=pages, resident=sum(flag & 1 for flag in flags))


def condition(paths, cache):
    evidence = []
    for path in paths:
        with path.open('rb') as source:
            if cache == 'cold_input':
                os.fsync(source.fileno())
                os.posix_fadvise(source.fileno(), 0, 0, os.POSIX_FADV_DONTNEED)
            else:
                while source.read(65536): pass
        evidence.append(dict(name=path.name, **residency(path)))
    if cache == 'cold_input' and any(item['resident'] for item in evidence):
        raise ValueError('Requested cold input pages were not evicted')
    return evidence


def checked(records, expected, engine):
    names = [r['phase'] for r in records if 'phase' in r]
    required = ['capture', 'discovery', 'compile', 'scan_convert', 'export_cached_batch', 'scan_convert_execute'] if engine == 'transit' else ['capture_python', 'discovery_bind', 'compile_bind', 'scan_convert_arrow', 'export_cached_batch', 'scan_convert_execute_arrow']
    if names != required: raise ValueError('Incomplete, reordered or duplicated phases')
    if not records or records[-1].get('complete') is not True: raise ValueError('Missing completion')
    if records[-1]['scanned'] != expected['expected_rows']: raise ValueError('Incorrect scan count')
    if records[-1]['id_sum'] != expected['expected_id_sum']: raise ValueError('Incorrect result checksum')
    if 'expected_result_sum' in expected and records[-1]['result_sum'] != expected['expected_result_sum']: raise ValueError('Incorrect query checksum')
    if engine == 'transit' and records[-1]['build_mode'] != 'safe': raise ValueError('Expected ReleaseSafe build')
    for record in records:
        if 'phase' in record:
            if record['elapsed_ns'] <= 0 or record['cpu_ns'] < 0: raise ValueError('Invalid timing')
            if record.get('first_batch_ns') is not None and not 0 <= record['first_batch_ns'] <= record['elapsed_ns']: raise ValueError('Invalid first batch timing')
    return records


def invoke(command, configuration, fixture, directory, engine, timeout, cpu):
    path = directory / 'request.json'; path.write_text(json.dumps(configuration))
    env = {k: v for k, v in os.environ.items() if k not in ('LD_PRELOAD', 'LD_LIBRARY_PATH', 'PYTHONPATH', 'PYTHONHOME')}
    env.update({'TMPDIR': str(directory), 'OPENBLAS_NUM_THREADS': '1', 'OMP_NUM_THREADS': '1', 'MALLOC_ARENA_MAX': '2'})
    if engine == 'duckdb': env['LD_PRELOAD'] = str(ROOT/'zig-out/lib/libtransit-fuze-allocations.so')
    def limits():
        os.sched_setaffinity(0, {cpu})
        resource.setrlimit(resource.RLIMIT_AS, (4*1024**3, 4*1024**3))
    with (directory/'stdout').open('wb') as stdout, (directory/'stderr').open('wb') as stderr:
        start = time.perf_counter_ns()
        child = subprocess.Popen([*command, str(path)], env=env, stdout=stdout, stderr=stderr,
            stdin=subprocess.PIPE if fixture['shape'] == 'pipe' else subprocess.DEVNULL, preexec_fn=limits)
        feeder = None
        if child.stdin is not None:
            def feed():
                try:
                    with fixture['paths'][0].open('rb') as source:
                        while chunk := source.read(65536): child.stdin.write(chunk)
                except BrokenPipeError: pass
                finally: child.stdin.close()
            feeder = threading.Thread(target=feed); feeder.start()
        killed = False
        while True:
            pid, status, usage = os.wait4(child.pid, os.WNOHANG)
            if pid: break
            if time.perf_counter_ns() - start > timeout*10**9 and not killed:
                child.kill(); killed = True
            time.sleep(.005)
        child.returncode = os.waitstatus_to_exitcode(status)
        if feeder: feeder.join(timeout=10)
        wall = time.perf_counter_ns() - start
    result = dict(exit_code=child.returncode, timeout=killed, wall_ns=wall,
        cpu_user_s=usage.ru_utime, cpu_system_s=usage.ru_stime, peak_rss_kib=usage.ru_maxrss,
        block_inputs=usage.ru_inblock, block_outputs=usage.ru_oublock, minor_faults=usage.ru_minflt,
        major_faults=usage.ru_majflt, stderr=(directory/'stderr').read_text(), records=[])
    raw = (directory/'stdout').read_text()
    try:
        result['records'] = [json.loads(line) for line in raw.splitlines()]
    except (ValueError, TypeError) as error:
        result.update(validation_error=f'Invalid output records: {error}', raw_stdout=raw)
        return result
    if child.returncode == 0:
        try:
            checked(result['records'], configuration, engine)
            identities = [{k: r[k] for k in ('length', 'digest')} for r in result['records'] if 'source' in r]
            if identities != fixture['expanded']: raise ValueError('Captured content does not match fixture hashes')
        except (ValueError, KeyError, TypeError) as error:
            result['validation_error'] = str(error)
    return result


def summarize(samples):
    groups = {}
    for sample in samples:
        if sample['exit_code'] or sample.get('validation_error'): continue
        for record in sample['records']:
            if 'phase' not in record: continue
            key = tuple(sample[k] for k in ('shape', 'mode', 'cache', 'engine')) + (record['phase'],)
            groups.setdefault(key, []).append(record)
    result = []
    for key, rows in sorted(groups.items()):
        times = [r['elapsed_ns'] for r in rows]
        median = statistics.median(times)
        result.append(dict(zip(('shape', 'mode', 'cache', 'engine', 'phase'), key),
            samples=len(rows), min_ns=min(times), median_ns=median, max_ns=max(times),
            median_rows_per_second=statistics.median([r['rows']*1e9/r['elapsed_ns'] for r in rows])))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rows', type=int, default=4096)
    parser.add_argument('--repetitions', type=int, default=3)
    parser.add_argument('--shapes', nargs='+', choices=SHAPES, default=list(SHAPES))
    parser.add_argument('--modes', nargs='+', choices=MODES, default=list(MODES))
    parser.add_argument('--caches', nargs='+', choices=('cold_input', 'warm_input'), default=['cold_input', 'warm_input'])
    parser.add_argument('--engines', nargs='+', choices=('transit', 'duckdb'), default=['transit', 'duckdb'])
    parser.add_argument('--batch-rows', type=int, choices=(1, 8), default=8)
    parser.add_argument('--project-id', action='store_true')
    parser.add_argument('--query', choices=('all', 'filter', 'count', 'sum'), default='all')
    parser.add_argument('--timeout', type=int, default=300)
    args = parser.parse_args()
    if not 1 <= args.rows <= 100_000_000 or not 1 <= args.repetitions <= 20 or not 1 <= args.timeout <= 3600:
        parser.error('Invalid workload budget')
    if (args.project_id and args.query != 'all') or (args.query in ('filter', 'sum') and 'raw' in args.modes):
        parser.error('Projection selects the all query; filter/sum require typed modes')
    args.binary = args.binary.resolve(); args.output = args.output.resolve()
    report = dict(definition=DEFINITION, status='running', completed=False, samples=[], summary=[], fixtures=[])
    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_suffix('.tmp')
        temporary.write_text(json.dumps(report, indent=2) + '\n'); temporary.replace(args.output)
    save()
    try:
        python = os.environ['TRANSIT_FUZE_BENCH_PYTHON']
        comparator = Path(__file__).with_name('duckdb_driver.py')
        versions = json.loads(subprocess.check_output([python, '-c', 'import json,duckdb,pyarrow,_duckdb; print(json.dumps(dict(duckdb=duckdb.__version__,build=duckdb.sql("PRAGMA version").fetchall(),pyarrow=pyarrow.__version__,module=_duckdb.__file__)))'], text=True))
        versions['module_sha256'] = digest(versions['module'])
        affinity = sorted(os.sched_getaffinity(0)); cpu = affinity[0]
        report.update(started=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            revision=git('rev-parse', 'HEAD'), dirty=bool(git('status', '--porcelain')),
            binary=dict(path=str(args.binary), sha256=digest(args.binary)), comparator=versions,
            allocation_probe=dict(path=str(ROOT/'zig-out/lib/libtransit-fuze-allocations.so'), sha256=digest(ROOT/'zig-out/lib/libtransit-fuze-allocations.so')),
            toolchain=dict(zig=subprocess.check_output(['zig', 'version'], text=True).strip(), lock_sha256=digest(ROOT/'flake.lock')),
            harness={str(p.relative_to(ROOT)): digest(p) for p in Path(__file__).parent.glob('*') if p.is_file()},
            machine=dict(platform=platform.platform(), cpuinfo=Path('/proc/cpuinfo').read_text().split('\n\n')[0],
                affinity=affinity, selected_cpu=cpu, load=os.getloadavg(), meminfo=Path('/proc/meminfo').read_text()),
            parameters=dict(rows=args.rows, repetitions=args.repetitions, shapes=args.shapes, modes=args.modes,
                caches=args.caches, engines=args.engines, batch_rows=args.batch_rows, projected=args.project_id, query=args.query,
                timeout_seconds=args.timeout, process_address_space_bytes=4*1024**3, duckdb_memory_limit='64MB', duckdb_threads=1),
            limits=['Cold applies only to verified input page residency; captures are newly written and warm.',
                'DuckDB streaming combines decoding/execution with Arrow construction.',
                'DuckDB process glibc request counts include Python/glue and instrumentation overhead; jemalloc/PyArrow counters are separately scoped; read bytes include metadata.',
                'Per-process wall includes startup and up to 5ms reap polling; phase timers exclude this.',
                'Capture hosts differ: Zig CLI implementation and Python comparator copying.',
                'Cached-batch export contains at most eight rows; it is not full-source export throughput.'])
        with tempfile.TemporaryDirectory(prefix='transit-fuze-bench-', dir='/var/tmp') as work:
            directory = Path(work)
            report['filesystem'] = subprocess.check_output(['stat', '-f', '-c', '%T', str(directory)], text=True).strip()
            for shape in args.shapes:
                source = fixture(directory, shape, args.rows)
                report['fixtures'].append(dict(shape=shape, files=source['files'], expanded=source['expanded']))
                for mode in args.modes:
                    configuration = config(source, mode, args.rows, args.batch_rows, args.project_id, args.query)
                    for cache in args.caches:
                        for repetition in range(args.repetitions):
                            engines = args.engines if repetition % 2 == 0 else list(reversed(args.engines))
                            for engine in engines:
                                pages = condition(source['paths'], cache)
                                command = [str(args.binary)] if engine == 'transit' else [python, '-B', str(comparator)]
                                sample = invoke(command, configuration, source, directory, engine, args.timeout, cpu)
                                sample.update(semantics=('different null/missing states' if shape == 'sparse' else 'different inferred identifier types' if shape == 'identifiers' and mode in ('sampled', 'partial', 'full') else 'different inferred numeric domains' if shape == 'decimal' and mode in ('sampled', 'partial', 'full') else 'shared fixture values; distinct schemas and physical layouts'), shape=shape, mode=mode, cache=cache, engine=engine, repetition=repetition,
                                    input_pages=pages, config=configuration, host_load=os.getloadavg())
                                report['samples'].append(sample); save()
                                if sample['exit_code'] or sample.get('validation_error'): raise RuntimeError(f'{engine} {shape}/{mode} exited {sample["exit_code"]}: {sample.get("validation_error", sample["stderr"])}')
                                print(f'{engine} {shape}/{mode}/{cache} #{repetition + 1}: verified', flush=True)
        report.update(completed=True, status='passed', summary=summarize(report['samples']))
    except BaseException as error:
        report.update(status='failed', completed=False, error=str(error), summary=[])
        raise
    finally: save()


if __name__ == '__main__':
    main()
