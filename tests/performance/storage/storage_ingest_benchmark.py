#!/usr/bin/env python3
"""Matched disk ingestion and acceptance measurements with fresh-process readback."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import tempfile

import performance.storage.storage_benchmark as common

require = common.require


def validate(sample, owner, rows, operation):
    record = sample['record']
    require(record['complete'] is True and record['build_mode'] == 'safe', 'Missing ReleaseSafe completion')
    count = 16 if owner == 'table' else 1
    expected = common.oracle(range(rows, rows + count) if operation == 'ingest' else range(rows + count))
    for field, value in expected.items():
        require(record[field] == value, f'Independent {owner} {field} mismatch')
    require(record['visited'] == expected['count'] and record['visited_sum'] == expected['sum'] and
            record['visited_digest'] == expected['digest'], 'Incomplete readback or write coverage')
    position = rows // 16 + 2 if owner == 'table' else 7 + (rows + 1) * 3
    require(record['position'] == position and record['checkpoint'] == 0, 'Wrong accepted position')
    require(record['image_peak_rss_kib'] > 0, 'Missing executable RSS')
    phases = record['phases']
    names = ['physical_open', 'recover'] + (['prepare', 'commit'] if owner == 'native' and operation == 'ingest' else
                                          ['ingest'] if operation == 'ingest' else
                                          ['verify'] if owner == 'table' else ['measure'])
    require([phase['name'] for phase in phases] == names, 'Incomplete phase coverage')
    for phase in phases:
        require(phase['elapsed_ns'] > 0, 'Missing phase timing')
        require(phase['peak_live_bytes'] >= max(phase['baseline_live_bytes'], phase['end_live_bytes']), 'Invalid allocation peak')
        require(all(value >= 0 for value in phase['counters'].values()), 'Invalid owner counters')
        if owner == 'table':
            require(phase['timed_appends'] == phase['counters']['wal_appends'], 'Incomplete append attribution')
            require(0 <= phase['wal_append_ns'] <= phase['elapsed_ns'], 'Invalid append timing')
        else:
            require(phase['wal_append_ns'] is None and phase['timed_appends'] == 0, 'Invented native append timing')
    if operation == 'ingest':
        write = phases[-1]
        require(write['counters']['wal_appends'] == 1 and write['counters']['wal_syncs'] > 0, 'Write has no single durable acceptance')
        if owner == 'table':
            require(write['wal_append_ns'] > 0, 'Missing Table append timing')
        else:
            require(phases[-2]['counters']['wal_appends'] == 2, 'Missing native input/view preparation')
    else:
        require(all(phase['counters']['wal_appends'] == 0 and phase['counters']['object_puts'] == 0 for phase in phases), 'Verification publishes work')


def summarize(samples, repetitions):
    arms = {}
    for sample in samples:
        if not sample['warmup']:
            key = tuple(sample[name] for name in ('owner', 'rows', 'cache', 'mode'))
            arms.setdefault(key, []).append(sample)
    result = []
    for key, values in arms.items():
        require(len(values) == repetitions and {value['repetition'] for value in values} == set(range(repetitions)), 'Incomplete repetition set')
        timings = {}
        for name in (['ingest', 'wal_append'] if key[0] == 'table' else ['prepare', 'commit']):
            observations = sorted(next(phase['wal_append_ns'] if name == 'wal_append' else phase['elapsed_ns']
                                       for phase in item['write']['record']['phases']
                                       if phase['name'] == ('ingest' if name == 'wal_append' else name)) for item in values)
            timings[name] = dict(n=len(observations), p50_ns=statistics.median(observations), min_ns=min(observations), max_ns=max(observations))
            if len(observations) >= 31:
                timings[name]['p95_ns'] = observations[math.ceil(.95 * len(observations)) - 1]
        result.append(dict(owner=key[0], rows=key[1], cache=key[2], mode=key[3], timings=timings))
    return result


def retained(files):
    return {name: files[name] for name in ('bytes', 'allocated_bytes')} | {'files': len(files['files'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--table-rows', type=common.sizes, default=[128, 1024])
    parser.add_argument('--native-rows', type=common.sizes, default=[16, 64])
    parser.add_argument('--repetitions', type=int, default=31)
    parser.add_argument('--cache', choices=['warm', 'cold', 'both'], default='both')
    parser.add_argument('--cpu', type=int, default=min(os.sched_getaffinity(0)))
    parser.add_argument('--timeout', type=float, default=300)
    args = parser.parse_args()
    require(args.repetitions > 0 and args.cpu in os.sched_getaffinity(0), 'Invalid repetitions or CPU')
    require(all(16 <= rows <= 1048560 and rows % 16 == 0 for rows in args.table_rows), 'Invalid Table sizes')
    require(all(0 < rows < 1048576 for rows in args.native_rows), 'Invalid native sizes')
    require(args.table_rows or args.native_rows, 'Empty matrix')
    binary = args.binary.resolve()
    caches = ['warm', 'cold'] if args.cache == 'both' else [args.cache]
    report = dict(version=1, profile='matched disk owner ingestion', status='running',
                  revision=common.git('rev-parse', 'HEAD'), dirty=bool(common.git('status', '--porcelain')),
                  binary_sha256=common.digest(binary), driver_sha256=common.digest(__file__),
                  common_driver_sha256=common.digest(common.__file__), probe_sha256=common.digest(common.ROOT / 'tests/performance/storage/storage_benchmark.zig'),
                  lock_sha256=common.digest(common.ROOT / 'flake.lock'), compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
                  system=platform.platform(), cpu=args.cpu,
                  cpu_model=Path('/proc/cpuinfo').read_text().split('model name\t: ', 1)[-1].split('\n', 1)[0],
                  address_space_limit=common.AS_LIMIT,
                  repetitions=args.repetitions, warmups=1, caches=caches, table_sizes=args.table_rows,
                  native_sizes=args.native_rows, fixtures=[], samples=[])
    common.save(args.output, report)
    try:
        with tempfile.TemporaryDirectory(prefix='transit-ingest-benchmark-', dir='/var/tmp') as temporary:
            root = Path(temporary)
            frozen = root / 'probe'
            shutil.copy2(binary, frozen)
            require(common.digest(frozen) == report['binary_sha256'], 'Executable changed while freezing it')
            binary = frozen
            report['filesystem'] = subprocess.check_output(['stat', '-f', '-c', '%T', str(root)], text=True).strip()
            for owner, counts in [('table', args.table_rows), ('native', args.native_rows)]:
                for rows in counts:
                    base = root / f'{owner}-{rows}'
                    base.mkdir()
                    setup = common.execute(binary, owner, 'init', base, rows, 'scan', args.cpu, args.timeout)
                    common.validate(setup, owner, 'init', rows, 'scan', 'baseline')
                    inventory = common.manifest(base)
                    identity = hashlib.sha256(json.dumps(inventory['files'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()
                    report['fixtures'].append(dict(owner=owner, rows=rows, inventory_sha256=identity, retained=retained(inventory), setup=setup))
                    modes = ['point', 'bulk'] if owner == 'table' else ['turn']
                    for cache in caches:
                        for repetition in range(-1, args.repetitions):
                            for mode in modes if repetition % 2 == 0 else reversed(modes):
                                candidate = root / 'sample'
                                shutil.copytree(base, candidate)
                                try:
                                    pages = common.condition(candidate, inventory['files'], cache)
                                    load = os.getloadavg()
                                    write = common.execute(binary, owner, 'ingest', candidate, rows, mode, args.cpu, args.timeout)
                                    validate(write, owner, rows, 'ingest')
                                    count = rows + (16 if owner == 'table' else 1)
                                    readback = common.execute(binary, owner, 'verify' if owner == 'table' else 'measure', candidate, count, mode if owner == 'table' else 'scan', args.cpu, args.timeout)
                                    validate(readback, owner, rows, 'verify')
                                    after = common.manifest(candidate)
                                    report['samples'].append(dict(owner=owner, rows=rows, mode=mode, cache=cache,
                                                                  repetition=repetition, warmup=repetition == -1,
                                                                  host_load=load, input_pages=pages, write=write, readback=readback,
                                                                  retained_before=retained(inventory), retained_after=retained(after)))
                                    common.save(args.output, report)
                                finally:
                                    shutil.rmtree(candidate)
                        print(f'{owner}/{rows}/{cache}: verified write and reopen samples complete', flush=True)
                    require(common.manifest(base) == inventory, 'Measurement changed shared baseline')
            expected = (len(args.table_rows) * 2 + len(args.native_rows)) * len(caches) * (args.repetitions + 1)
            require(len(report['samples']) == expected, 'Incomplete ingestion matrix')
            report['summary'] = summarize(report['samples'], args.repetitions)
            report['status'] = 'passed'
    except BaseException as error:
        report['status'] = 'failed'
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        common.save(args.output, report)
    print(f'Local ingestion measurements: {len(report["samples"])} verified samples; {args.output}')


if __name__ == '__main__':
    main()
