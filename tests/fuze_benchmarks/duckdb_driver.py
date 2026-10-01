"""Pinned development comparator; host acquisition is separate from DuckDB."""
import gzip
import csv
import ctypes as c
import hashlib
import json
import os
from pathlib import Path
import resource
import sys
import tempfile
import time
import duckdb
import _duckdb
import pyarrow as pa
import pyarrow.compute as pc

assert duckdb.__version__ == '1.5.2' and pa.__version__ == '23.0.0'


def emit(value):
    print(json.dumps(value), flush=True)


def read_chars():
    with open('/proc/self/io', 'rb') as source: data = source.read()
    before = int(next(line.split(b':')[1] for line in data.splitlines() if line.startswith(b'rchar:')))
    return before, before + len(data)


class ArenaStats:
    """Pinned DuckDB's statically linked jemalloc arena counters, not malloc calls.

    Includes tcache fills. Size-class bytes include allocator rounding. Epoch
    refreshes observe counters without flushing caches or changing allocation.
    """
    def __init__(self):
        self.lib = c.CDLL(_duckdb.__file__)
        self.ctl = self.lib.duckdb_je_mallctl
        self.ctl.argtypes = [c.c_char_p, c.c_void_p, c.POINTER(c.c_size_t), c.c_void_p, c.c_size_t]
        self.ctl.restype = c.c_int
        assert self.get('config.stats', c.c_bool)
        self.classes = []
        for counts, kind, sizes in [('arenas.nbins', 'bins', 'bin'), ('arenas.nlextents', 'lextents', 'lextent')]:
            for index in range(self.get(counts, c.c_uint)):
                self.classes.append((f'stats.arenas.4096.{kind}.{index}.nmalloc', self.get(f'arenas.{sizes}.{index}.size')))

    def get(self, key, typ=c.c_size_t):
        value = typ(); size = c.c_size_t(c.sizeof(value))
        result = self.ctl(key.encode(), c.byref(value), c.byref(size), None, 0)
        if result: raise RuntimeError(f'Pinned jemalloc counter {key} unavailable: {result}')
        return value.value

    def snapshot(self):
        epoch = c.c_uint64(); update = c.c_uint64(1); size = c.c_size_t(c.sizeof(epoch))
        assert self.ctl(b'epoch', c.byref(epoch), c.byref(size), c.byref(update), size.value) == 0
        count = size_bytes = 0
        for key, width in self.classes:
            n = self.get(key, c.c_uint64)
            count += n; size_bytes += width * n
        return count, size_bytes, self.get('stats.allocated')


class Meter:
    def __init__(self):
        self.arena = ArenaStats()
        self.process = c.CDLL(None)
        self.snapshot = self.process.transit_benchmark_allocations
        self.snapshot.argtypes = [c.POINTER(c.c_uint64)]
        self.snapshot.restype = None
        # A real intercepted allocation independently checks the measurement
        # boundary before any timed phase. Never accept an inert zero counter.
        self.process.malloc.argtypes = [c.c_size_t]
        self.process.malloc.restype = c.c_void_p
        self.process.free.argtypes = [c.c_void_p]
        self.process.free.restype = None
        before = self.counters()
        pointer = self.process.malloc(12345)
        if not pointer: raise MemoryError()
        after = self.counters()
        self.process.free(pointer)
        assert after[0] > before[0] and after[1] >= before[1] + 12345

    def counters(self):
        result = (c.c_uint64 * 3)()
        self.snapshot(result)
        return tuple(result)

    def begin(self):
        pool = pa.default_memory_pool()
        self.allocations = pool.num_allocations()
        self.allocated_bytes = pool.total_bytes_allocated()
        self.read_chars = read_chars()[1]
        self.arena_before = self.arena.snapshot()
        self.process_before = self.counters()
        self.cpu = time.process_time_ns()
        self.started = time.perf_counter_ns()

    def end(self, phase, rows=0, export_bytes=0, first_batch_ns=None):
        elapsed = time.perf_counter_ns() - self.started
        cpu = time.process_time_ns() - self.cpu
        chars = read_chars()[0] - self.read_chars
        counters = self.counters()
        arena = self.arena.snapshot()
        pool = pa.default_memory_pool()
        emit(dict(phase=phase, elapsed_ns=elapsed, cpu_ns=cpu, rows=rows, export_bytes=export_bytes,
            first_batch_ns=first_batch_ns, source_bytes_read=chars, read_byte_scope='process read syscalls, including reader metadata',
            allocations=counters[0] - self.process_before[0], allocated_bytes=counters[1] - self.process_before[1],
            reallocations=counters[2] - self.process_before[2], jemalloc_arena_requests=arena[0] - self.arena_before[0],
            jemalloc_size_class_bytes=arena[1] - self.arena_before[1],
            end_live_bytes=None, jemalloc_end_live_bytes=arena[2], peak_live_bytes=None, arrow_allocations=pool.num_allocations() - self.allocations,
            arrow_allocated_bytes=pool.total_bytes_allocated() - self.allocated_bytes,
            arrow_peak_live_bytes=pool.max_memory(), allocation_scope='Successful process glibc allocation requests including Python/foreign glue; separate jemalloc/PyArrow counters'))


def type_name(typ):
    name, value = next(iter(typ.items()))
    scalar = dict(int8='TINYINT', int16='SMALLINT', int32='INTEGER', int64='BIGINT', int128='HUGEINT',
        uint8='UTINYINT', uint16='USMALLINT', uint32='UINTEGER', uint64='UBIGINT', uint128='UHUGEINT',
        float32='FLOAT', float64='DOUBLE', boolean='BOOLEAN', utf8='VARCHAR', binary='BLOB',
        date='DATE', time='TIME', uuid='UUID', interval='INTERVAL', json='JSON')
    if name in scalar: return scalar[name]
    if name == 'decimal': return f'DECIMAL({value["precision"]},{value["scale"]})'
    if name == 'timestamp': return 'TIMESTAMPTZ' if value == 'utc' else 'TIMESTAMP'
    if name == 'list': return type_name(value['type']) + '[]'
    if name == 'array': return type_name(value['element']['type']) + f'[{value["length"]}]'
    if name == 'structure': return 'STRUCT(' + ','.join('"' + f['name'].replace('"', '""') + '" ' + type_name(f['type']) for f in value) + ')'
    raise ValueError('Comparator fixture type is unsupported: ' + name)


def literal(value):
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, int): return str(value)
    if isinstance(value, str): return "'" + value.replace("'", "''") + "'"
    if isinstance(value, list): return '[' + ','.join(map(literal, value)) + ']'
    if isinstance(value, dict): return '{' + ','.join(literal(k) + ':' + literal(v) for k, v in value.items()) + '}'
    raise TypeError(value)


def reader_sql(name, paths, options):
    return name + '(' + literal(paths) + ', ' + ','.join(key + '=' + literal(value) for key, value in options.items()) + ')'


def read(connection, name, paths, options):
    return connection.sql('SELECT * FROM ' + reader_sql(name, paths, options))


def main(config):
    options = config['options']; mode = options['mode']; form = options['format']
    captures = []
    connection = duckdb.connect(config={'threads': '1', 'memory_limit': '64MB',
        'preserve_insertion_order': 'true', 'autoinstall_known_extensions': 'false', 'autoload_known_extensions': 'false'})
    try:
        connection.execute('LOAD jemalloc')
        meter = Meter(); meter.begin()
        encoded_total = expanded_total = 0
        identities = []
        for index, path in enumerate(config['paths']):
            original = sys.stdin.buffer if path == '-' else open(path, 'rb')
            encoded = tempfile.TemporaryFile()
            try:
                while chunk := original.read(65536):
                    encoded_total += len(chunk)
                    if encoded_total > options['max_scan_bytes']: raise ValueError('encoded quota exceeded')
                    encoded.write(chunk)
            finally:
                if path != '-': original.close()
            encoded.seek(0)
            capture = tempfile.TemporaryFile(); digest = hashlib.sha256()
            try:
                stream = gzip.GzipFile(fileobj=encoded) if config.get('gzip') else encoded
                while chunk := stream.read(65536):
                    expanded_total += len(chunk)
                    if expanded_total > options['max_scan_bytes']: raise ValueError('expanded quota exceeded')
                    capture.write(chunk); digest.update(chunk)
                capture.flush(); capture.seek(0)
            except BaseException:
                capture.close(); raise
            finally:
                encoded.close()
            captures.append(capture)
            identities.append(dict(source=index, length=os.fstat(capture.fileno()).st_size, digest=digest.hexdigest()))
        meter.end('capture_python')
        for identity in identities: emit(identity)
        paths = [f'/proc/self/fd/{capture.fileno()}' for capture in captures]
        types = {f['name']: type_name(f['type']) for f in json.loads(config['schema_json'])['type']['structure']} if config.get('schema_json') else {}
        samples = -1 if mode == 'full' else options.get('sample_records', 1024)
        meter.begin()
        if form == 'csv':
            kwargs = dict(header=True, delim=',', quote='"', escape='"', nullstr='', strict_mode=True,
                ignore_errors=False, parallel=False, union_by_name=True, compression='none', max_line_size=65536,
                sample_size=samples, buffer_size=262144, auto_type_candidates=['BIGINT', 'BOOLEAN', 'VARCHAR'])
            if mode == 'explicit': kwargs.update(auto_detect=False, columns=types)
            else:
                kwargs['auto_detect'] = True
                if types: kwargs['types'] = types
                if mode == 'raw': kwargs['all_varchar'] = True
            if mode == 'explicit':
                # Explicit DuckDB columns are positional. Inspect each bounded
                # fixture header, order its columns accordingly, then project
                # by name before UNION ALL. Keep this host work in discovery.
                selects = []
                headers = []
                projection = ','.join('"' + name.replace('"', '""') + '"' for name in types)
                for path in paths:
                    with open(path, newline='') as stream: header = next(csv.reader(stream))
                    if len(header) != len(types) or set(header) != set(types): raise ValueError('Unexpected explicit fixture header')
                    headers.append(header)
                    local = {**kwargs, 'columns': {name: types[name] for name in header}}
                    selects.append('SELECT ' + projection + ' FROM ' + reader_sql('read_csv', [path], local))
                relation = connection.sql(' UNION ALL '.join(selects))
                kwargs['benchmark_header_alignment'] = headers
            else:
                relation = read(connection, 'read_csv', paths, kwargs)
        elif mode == 'raw':
            kwargs = dict(format='newline_delimited', maximum_object_size=65536)
            quoted = '[' + ','.join("'" + p + "'" for p in paths) + ']'
            relation = connection.sql(f"SELECT json AS record FROM read_json_objects({quoted}, format='newline_delimited', maximum_object_size=65536)")
        else:
            kwargs = dict(format='newline_delimited', union_by_name=True, sample_size=samples,
                maximum_depth=16, maximum_object_size=65536, ignore_errors=False, compression='uncompressed')
            if mode == 'explicit': kwargs['columns'] = types
            relation = read(connection, 'read_json', paths, kwargs)
            if types and mode != 'explicit':
                # JSON columns is a complete schema. Resolve inferred fields and
                # rebind a merged schema; retain this extra discovery in timing.
                merged = dict(zip(relation.columns, map(str, relation.types)))
                merged.update(types)
                relation = read(connection, 'read_json', paths, {**kwargs, 'columns': merged})
        schema = dict(zip(relation.columns, map(str, relation.types)))
        meter.end('discovery_bind')
        emit(dict(schema=schema, reader_options=kwargs, memory_limit='64MB', threads=1, preserve_insertion_order=True))
        relation.create_view('input')
        meter.begin()
        query = connection.sql(config.get('sql', 'SELECT * FROM input'))
        meter.end('compile_bind')
        # DuckDB's public streaming API fuses scan/conversion with Arrow batch
        # construction. Never label this as isolated decode or subtract timings.
        meter.begin(); rows = 0; id_sum = 0; cached = None
        with relation.to_arrow_reader(batch_size=config['batch_rows']) as reader:
            for batch in reader:
                if cached is None: cached = batch
                rows += batch.num_rows
                if config.get('expected_id_sum') is not None:
                    id_sum += pc.sum(batch.column(batch.schema.get_field_index('id'))).as_py() or 0
        assert rows == config['expected_rows']
        if config.get('expected_id_sum') is not None: assert id_sum == config['expected_id_sum']
        meter.end('scan_convert_arrow', rows)
        meter.begin(); exported = 0
        assert cached is not None
        for _ in range(config['export_iterations']):
            sink = pa.BufferOutputStream()
            with pa.ipc.new_stream(sink, cached.schema) as writer: writer.write_batch(cached)
            exported += len(sink.getvalue())
        meter.end('export_cached_batch', cached.num_rows * config['export_iterations'], exported)
        meter.begin(); emitted = 0; first_batch = None; result_sum = 0
        with query.to_arrow_reader(batch_size=config['batch_rows']) as reader:
            for batch in reader:
                emitted += batch.num_rows
                if config.get('expected_result_sum') is not None:
                    index = batch.schema.get_field_index('id') if 'id' in batch.schema.names else 0
                    result_sum += pc.sum(batch.column(index)).as_py() or 0
                if first_batch is None: first_batch = time.perf_counter_ns() - meter.started
        assert emitted == config['expected_output_rows']
        if config.get('expected_result_sum') is not None:
            assert result_sum == config['expected_result_sum']
            # DuckDB SUM(BIGINT) exports HUGEINT as Arrow decimal128. Equality
            # above proves the integer fixture oracle before JSON conversion.
            result_sum = int(result_sum)
        meter.end('scan_convert_execute_arrow', emitted, first_batch_ns=first_batch)
        emit(dict(complete=True, scanned=rows, id_sum=id_sum if config.get('expected_id_sum') is not None else None,
            result_sum=result_sum if config.get('expected_result_sum') is not None else None,
            encoded_bytes=encoded_total, expanded_bytes=expanded_total, build=connection.sql('PRAGMA version').fetchall(),
            rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss))
    finally:
        connection.close()
        for capture in captures: capture.close()


if __name__ == '__main__':
    main(json.loads(Path(sys.argv[1]).read_text()))
