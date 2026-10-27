#!/usr/bin/env python3
"""Paired local owner measurements; no service, synthetic timer or memory store."""
import argparse
import ctypes
import hashlib
import json
import math
import mmap
import os
from pathlib import Path
import platform
import resource
import shutil
import statistics
import struct
import subprocess
import tempfile
import time

from runner.paths import ROOT
RECORD_BYTES = 1024
AS_LIMIT = 2 * 1024**3


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def oracle(ids):
    result = bytearray(32)
    count = total = 0
    for index in ids:
        value = index * 17 - 9
        body = f'row-{index:012d}'.encode() + bytes([97 + index % 26]) * (RECORD_BYTES - 16)
        for at, byte in enumerate(hashlib.sha256(struct.pack('<Qq', index, value) + body).digest()):
            result[at] ^= byte
        count += 1
        total += value
    return dict(count=count, sum=total, digest=result.hex())


def manifest(directory):
    files = []
    for path in sorted(directory.rglob('*')):
        require(not path.is_symlink(), 'Fixture contains a symlink')
        if path.is_file():
            stat = path.stat()
            files.append(dict(path=str(path.relative_to(directory)), bytes=stat.st_size,
                              allocated_bytes=stat.st_blocks * 512, sha256=digest(path)))
    return dict(files=files, bytes=sum(item['bytes'] for item in files),
                allocated_bytes=sum(item['allocated_bytes'] for item in files))


def residency(path):
    size = path.stat().st_size
    if not size:
        return 0, 0
    with path.open('rb') as source, mmap.mmap(source.fileno(), size, access=mmap.ACCESS_COPY) as mapping:
        pages = (size + mmap.PAGESIZE - 1) // mmap.PAGESIZE
        flags = (ctypes.c_ubyte * pages)()
        address = ctypes.addressof(ctypes.c_char.from_buffer(mapping))
        libc = ctypes.CDLL(None, use_errno=True)
        libc.mincore.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
        if libc.mincore(address, size, flags):
            raise OSError(ctypes.get_errno(), 'mincore failed')
        return pages, sum(flag & 1 for flag in flags)


class CacheConditionError(ValueError):
    def __init__(self, cache, observations):
        self.observations = observations
        super().__init__(f'Fixture {cache} page-cache conditioning failed: {json.dumps(observations, sort_keys=True)}')


def condition(directory, files, cache):
    require(cache in ('warm', 'cold'), 'Unknown cache condition')
    observations = []
    pending = files
    started = time.monotonic()
    for _ in range(3):
        for item in pending:
            path = directory / item['path']
            with path.open('rb') as stream:
                if cache == 'cold':
                    os.fsync(stream.fileno())
                    os.posix_fadvise(stream.fileno(), 0, 0, os.POSIX_FADV_DONTNEED)
                else:
                    while stream.read(65536):
                        pass
        # Observe the entire fixture after conditioning, rather than declaring
        # success from individual files observed during the conditioning sweep.
        pages = resident = 0
        pending = []
        mismatches = []
        for item in files:
            count, present = residency(directory / item['path'])
            pages += count
            resident += present
            if present != (0 if cache == 'cold' else count):
                pending.append(item)
                if len(mismatches) < 8:
                    mismatches.append(dict(path=item['path'], pages=count, resident_pages=present))
        observations.append(dict(pages=pages, resident_pages=resident, mismatched_files=len(pending),
                                 first_mismatches=mismatches))
        if not pending:
            return dict(files=len(files), pages=pages, resident_pages=resident,
                        conditioning_attempts=observations, conditioning_seconds=time.monotonic() - started)
    raise CacheConditionError(cache, observations)


def execute(binary, owner, operation, directory, rows, mode, cpu, timeout):
    command = [str(binary), owner, operation, str(directory), '--rows', str(rows), mode]

    def limits():
        os.sched_setaffinity(0, {cpu})
        resource.setrlimit(resource.RLIMIT_AS, (AS_LIMIT, AS_LIMIT))

    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        start = time.monotonic()
        child = subprocess.Popen(command, stdout=out, stderr=err, preexec_fn=limits)
        while True:
            pid, status, usage = os.wait4(child.pid, os.WNOHANG)
            if pid:
                child.returncode = os.waitstatus_to_exitcode(status)
                break
            if time.monotonic() - start > timeout:
                child.kill()
                _, status, usage = os.wait4(child.pid, 0)
                child.returncode = os.waitstatus_to_exitcode(status)
                raise TimeoutError(f'{owner}/{operation}/{mode} exceeded {timeout}s')
            time.sleep(.01)
        out.seek(0)
        err.seek(0)
        stdout, stderr = out.read(), err.read()
        require(child.returncode == 0, f'{owner}/{operation}/{mode}: exit {child.returncode}: {stderr.decode(errors="replace")[-4000:]}')
        record = json.loads(stdout)
        return dict(record=record, wall_seconds=time.monotonic() - start,
                    user_seconds=usage.ru_utime, system_seconds=usage.ru_stime,
                    wait4_peak_rss_kib=usage.ru_maxrss, minor_faults=usage.ru_minflt,
                    major_faults=usage.ru_majflt, input_blocks=usage.ru_inblock,
                    output_blocks=usage.ru_oublock, voluntary_switches=usage.ru_nvcsw,
                    involuntary_switches=usage.ru_nivcsw)


def validate_inventory(phase, owner, read_only=False):
    counters = phase['counters']
    names = ('inventory_wal_appends', 'inventory_wal_bytes', 'inventory_wal_syncs', 'inventory_wal_startup_frames')
    require(all(name in counters and counters[name] >= 0 for name in names), 'Missing allocation WAL attribution')
    if owner == 'table':
        require(all(counters[name] == 0 for name in names), 'Standalone Table fixture has no allocation WAL')
    elif counters['object_puts']:
        require(counters['inventory_wal_appends'] >= counters['object_puts'] and
                counters['inventory_wal_bytes'] > 0 and counters['inventory_wal_syncs'] > 0,
                'Native object creation lacks durable inventory attribution')
    if read_only:
        require(counters['inventory_wal_appends'] == 0 and counters['inventory_wal_bytes'] == 0,
                'Read unexpectedly changes allocation history')


def validate(sample, owner, operation, rows, mode, variant):
    record = sample['record']
    require(record['complete'] is True and record['build_mode'] == 'safe', 'Missing ReleaseSafe completion')
    expected = oracle(range(rows) if owner == 'native' or operation == 'init' else
                      range(rows // 2 - 2, rows // 2 + 2))
    if operation == 'checkpoint':
        expected = oracle([])
    for name, value in expected.items():
        actual = record[name]
        require(actual == value, f'Independent {owner} {name} mismatch: {actual} != {value}')
    visited = 0 if operation == 'checkpoint' else (4 if operation == 'measure' and owner == 'table' and mode == 'range' else rows)
    require(record['visited'] == visited, 'Incomplete or extra rows')
    visited_values = oracle([]) if operation == 'checkpoint' else (expected if visited == 4 and owner == 'table' and operation == 'measure' and mode == 'range' else oracle(range(rows)))
    require(record['visited_digest'] == visited_values['digest'] and record['visited_sum'] == visited_values['sum'], 'Independent visited values mismatch')
    names = [phase['name'] for phase in record['phases']]
    require(names == ['physical_open', 'recover', operation], 'Missing, duplicate or reordered phases')
    require(record['image_peak_rss_kib'] > 0, 'Missing executable RSS')
    for phase in record['phases']:
        validate_inventory(phase, owner, operation == 'measure')
        require(phase['elapsed_ns'] > 0, 'Missing phase timing')
        require(phase['peak_live_bytes'] >= max(phase['baseline_live_bytes'], phase['end_live_bytes']), 'Invalid allocation peak')
        require(all(value >= 0 for value in phase['counters'].values()), 'Invalid owner counters')
    if operation == 'measure':
        require(all(phase['counters']['wal_appends'] == 0 and phase['counters']['object_puts'] == 0 for phase in record['phases']), 'Read unexpectedly publishes work')
        if owner == 'table':
            require(record['position'] == rows // 16 + 1 + (variant == 'checkpoint'), 'Wrong Table position')
            require(record['checkpoint'] == (rows // 16 + 1 if variant == 'checkpoint' else 0), 'Wrong Table checkpoint')
            require(record['phases'][1]['counters']['table_replay_frames'] == (1 if variant == 'checkpoint' else rows // 16 + 1), 'Wrong Table replay coverage')
        else:
            require(record['position'] == 7 + rows * 3 + (variant == 'checkpoint'), 'Wrong native position')
            require(record['checkpoint'] == (7 + rows * 3 if variant == 'checkpoint' else 0), 'Wrong native floor')


def summary(samples, repetitions):
    grouped = {}
    for sample in samples:
        if sample['warmup']:
            continue
        key = (sample['owner'], sample['rows'], sample['cache'], sample['variant'], sample['mode'])
        grouped.setdefault(key, []).append(sample)
    result = []
    for key, items in grouped.items():
        require(len(items) == repetitions and {item['repetition'] for item in items} == set(range(repetitions)), 'Incomplete repetition set')
        phases = {}
        for name in ('physical_open', 'recover', 'measure'):
            values = sorted(next(phase['elapsed_ns'] for phase in item['record']['phases'] if phase['name'] == name) for item in items)
            phases[name] = dict(n=len(values), p50_ns=statistics.median(values), min_ns=min(values), max_ns=max(values))
            if len(values) >= 31:
                phases[name]['p95_ns'] = values[math.ceil(.95 * len(values)) - 1]
        result.append(dict(owner=key[0], rows=key[1], cache=key[2], variant=key[3], mode=key[4], phases=phases,
                           max_image_rss_kib=max(item['record']['image_peak_rss_kib'] for item in items)))
    return result


def save(path, report):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_suffix(path.suffix + '.pending')
    with pending.open('w') as output:
        json.dump(report, output, indent=2)
        output.write('\n')
        output.flush()
        os.fsync(output.fileno())
    pending.replace(path)


def sizes(value):
    return [int(item) for item in value.split(',')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--table-rows', type=sizes, default=[128, 1024])
    parser.add_argument('--native-rows', type=sizes, default=[16, 64])
    parser.add_argument('--repetitions', type=int, default=31)
    parser.add_argument('--cache', choices=['warm', 'cold', 'both'], default='both')
    parser.add_argument('--cpu', type=int, default=min(os.sched_getaffinity(0)))
    parser.add_argument('--timeout', type=float, default=300)
    args = parser.parse_args()
    require(args.repetitions > 0 and args.cpu in os.sched_getaffinity(0), 'Invalid repetitions or CPU')
    require(all(16 <= count <= 1048576 and count % 16 == 0 for count in args.table_rows), 'Table sizes must be multiples of 16')
    require(all(0 < count <= 1048576 for count in args.native_rows), 'Invalid native size')
    binary = args.binary.resolve()
    caches = ['warm', 'cold'] if args.cache == 'both' else [args.cache]
    report = dict(version=1, status='running', profile='paired local disk owners',
                  measurement='percentiles' if args.repetitions >= 31 else 'smoke',
                  revision=git('rev-parse', 'HEAD'), dirty=bool(git('status', '--porcelain')),
                  binary_sha256=digest(binary), driver_sha256=digest(__file__),
                  probe_sha256=digest(ROOT / 'tests/performance/storage/storage_benchmark.zig'), lock_sha256=digest(ROOT / 'flake.lock'),
                  compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
                  system=platform.platform(), cpu=args.cpu, cpu_model=Path('/proc/cpuinfo').read_text().split('model name\t: ', 1)[-1].split('\n', 1)[0],
                  address_space_limit=AS_LIMIT, repetitions=args.repetitions, warmups=1,
                  caches=caches, table_sizes=args.table_rows, native_sizes=args.native_rows,
                  fixtures=[], setup=[], samples=[])
    save(args.output, report)
    try:
        with tempfile.TemporaryDirectory(prefix='transit-storage-benchmark-', dir='/var/tmp') as temporary:
            root = Path(temporary)
            report['filesystem'] = subprocess.check_output(['stat', '-f', '-c', '%T', str(root)], text=True).strip()
            for owner, counts in [('table', args.table_rows), ('native', args.native_rows)]:
                for count in counts:
                    base = root / f'{owner}-{count}-baseline'
                    base.mkdir()
                    sample = execute(binary, owner, 'init', base, count, 'scan', args.cpu, args.timeout)
                    validate(sample, owner, 'init', count, 'scan', 'baseline')
                    report['setup'].append(dict(owner=owner, rows=count, operation='init', **sample))
                    checkpoint = root / f'{owner}-{count}-checkpoint'
                    shutil.copytree(base, checkpoint)
                    sample = execute(binary, owner, 'checkpoint', checkpoint, count, 'scan', args.cpu, args.timeout)
                    validate(sample, owner, 'checkpoint', count, 'scan', 'checkpoint')
                    report['setup'].append(dict(owner=owner, rows=count, operation='checkpoint', **sample))
                    bases = {'baseline': base, 'checkpoint': checkpoint}
                    manifests = {variant: manifest(directory) for variant, directory in bases.items()}
                    for variant, evidence in manifests.items():
                        encoded = json.dumps(evidence['files'], sort_keys=True, separators=(',', ':')).encode()
                        report['fixtures'].append(dict(owner=owner, rows=count, variant=variant,
                                                       file_count=len(evidence['files']), bytes=evidence['bytes'],
                                                       allocated_bytes=evidence['allocated_bytes'],
                                                       inventory_sha256=hashlib.sha256(encoded).hexdigest()))
                    save(args.output, report)
                    arms = [(variant, mode) for variant in bases for mode in (['scan', 'range'] if owner == 'table' else ['scan'])]
                    for cache in caches:
                        for repetition in range(-1, args.repetitions):
                            # Reverse the paired order on each repetition. This
                            # does not reserve the CPU or isolate the filesystem.
                            order = arms if repetition % 2 == 0 else list(reversed(arms))
                            for variant, mode in order:
                                evidence = condition(bases[variant], manifests[variant]['files'], cache)
                                load = os.getloadavg()
                                sample = execute(binary, owner, 'measure', bases[variant], count, mode, args.cpu, args.timeout)
                                validate(sample, owner, 'measure', count, mode, variant)
                                report['samples'].append(dict(owner=owner, rows=count, variant=variant, mode=mode, cache=cache,
                                                              repetition=repetition, warmup=repetition == -1, input_pages=evidence,
                                                              host_load=load, **sample))
                                save(args.output, report)
                    for variant, directory in bases.items():
                        require(manifest(directory) == manifests[variant], 'Measurement changed fixture contents or retained allocation')
                    print(f'{owner}: {count} rows, {len(arms)} arms, {len(caches)} cache conditions complete', flush=True)
            expected = (len(args.table_rows) * 4 + len(args.native_rows) * 2) * len(caches) * (args.repetitions + 1)
            require(len(report['samples']) == expected, 'Incomplete owner matrix')
            report['summary'] = summary(report['samples'], args.repetitions)
            report['status'] = 'passed'
    except BaseException as error:
        report['status'] = 'failed'
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        save(args.output, report)
    print(f'Local owner measurements: {len(report["samples"])} verified raw samples; {args.output}')


if __name__ == '__main__':
    main()
