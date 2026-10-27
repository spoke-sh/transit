#!/usr/bin/env python3
"""Local owner growth under an enforced process address-space ceiling."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

import performance.storage.storage_benchmark as common

require = common.require
BODY_BYTES = 16384


def validate(sample, owner, rows, operation, limit):
    record = sample['record']
    require(record['complete'] is True and record['build_mode'] == 'safe', 'Missing ReleaseSafe completion')
    require(record['fixture_body_bytes'] == BODY_BYTES, 'Wrong growth payload configuration')
    expected = common.oracle(range(rows))
    for name, value in expected.items():
        require(record[name] == value, f'Independent {owner} {name} mismatch')
    require(record['visited'] == rows and record['visited_sum'] == expected['sum'] and
            record['visited_digest'] == expected['digest'], 'Incomplete growth coverage')
    require(record['position'] == (rows // 16 + 1 if owner == 'table' else 7 + rows * 3), 'Wrong accepted position')
    require(record['checkpoint'] == 0, 'Unexpected maintenance')
    require(0 < record['image_peak_rss_kib'] * 1024 <= limit and
            0 < record['image_peak_virtual_kib'] * 1024 <= limit, 'Memory ceiling not established')
    phases = record['phases']
    final = 'init' if operation == 'init' else 'verify-all' if owner == 'table' else 'measure'
    require([phase['name'] for phase in phases] == ['physical_open', 'recover', final], 'Incomplete phase coverage')
    for phase in phases:
        require(phase['elapsed_ns'] > 0, 'Missing timing')
        require(max(phase['baseline_live_bytes'], phase['end_live_bytes']) <= phase['peak_live_bytes'] <= limit, 'Invalid allocation accounting')
        require(all(value >= 0 for value in phase['counters'].values()), 'Invalid owner counters')
        if operation != 'init':
            require(phase['counters']['wal_appends'] == 0 and phase['counters']['object_puts'] == 0, 'Readback writes state')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--table-rows', type=common.sizes, default=[2048, 8192])
    parser.add_argument('--native-rows', type=common.sizes, default=[512, 2048])
    parser.add_argument('--owner', choices=('both', 'table', 'native'), default='both',
                        help='Qualify one owner independently, preserving its full growth matrix')
    parser.add_argument('--memory-mib', type=int, default=128)
    parser.add_argument('--cpu', type=int, default=min(os.sched_getaffinity(0)))
    parser.add_argument('--timeout', type=float, default=1800)
    parser.add_argument('--smoke', action='store_true', help='Validate the harness without requiring data larger than the ceiling')
    args = parser.parse_args()
    require(32 <= args.memory_mib <= 2048 and args.cpu in os.sched_getaffinity(0), 'Invalid memory or CPU limit')
    require(math.isfinite(args.timeout) and args.timeout > 0, 'Invalid child time guard')
    require(all(16 <= rows <= 1048576 and rows % 16 == 0 for rows in args.table_rows), 'Invalid Table sizes')
    require(all(0 < rows <= 1048576 for rows in args.native_rows), 'Invalid native sizes')
    for sizes in (args.table_rows, args.native_rows):
        require(sizes == sorted(set(sizes)) and len(sizes) >= (1 if args.smoke else 2), 'Growth requires increasing fixture sizes')
    common.AS_LIMIT = args.memory_mib * 1024**2
    common.RECORD_BYTES = BODY_BYTES
    binary = args.binary.resolve()
    owners = [(owner, sizes) for owner, sizes in [('table', args.table_rows), ('native', args.native_rows)]
              if args.owner in ('both', owner)]
    report = dict(version=1, profile='memory growth smoke' if args.smoke else 'bounded local owner growth', status='running',
                  owners=[owner for owner, _ in owners],
                  requested_fixtures=[dict(owner=owner, rows=rows) for owner, sizes in owners for rows in sizes],
                  child_timeout_seconds=args.timeout,
                  revision=common.git('rev-parse', 'HEAD'), dirty=bool(common.git('status', '--porcelain')),
                  binary_sha256=common.digest(binary), driver_sha256=common.digest(__file__),
                  common_driver_sha256=common.digest(common.__file__), probe_sha256=common.digest(common.ROOT / 'tests/performance/storage/storage_benchmark.zig'),
                  lock_sha256=common.digest(common.ROOT / 'flake.lock'), compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
                  system=platform.platform(), cpu=args.cpu, address_space_limit=common.AS_LIMIT,
                  host_memtotal=next(line.split(':', 1)[1].strip() for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemTotal:')),
                  body_bytes=BODY_BYTES, fixtures=[])
    common.save(args.output, report)
    try:
        with tempfile.TemporaryDirectory(prefix='transit-storage-growth-', dir='/var/tmp') as temporary:
            root = Path(temporary)
            # Keep later developer builds from changing the running proof.
            frozen = root / 'probe'
            shutil.copy2(binary, frozen)
            require(common.digest(frozen) == report['binary_sha256'], 'Executable changed while freezing it')
            report['filesystem'] = subprocess.check_output(['stat', '-f', '-c', '%T', str(root)], text=True).strip()
            for owner, sizes in owners:
                exceeded = False
                for rows in sizes:
                    directory = root / 'fixture'
                    directory.mkdir()
                    try:
                        setup = common.execute(frozen, owner, 'init', directory, rows, 'scan', args.cpu, args.timeout)
                        validate(setup, owner, rows, 'init', common.AS_LIMIT)
                        inventory = common.manifest(directory)
                        pages = common.condition(directory, inventory['files'], 'cold')
                        readback = common.execute(frozen, owner, 'verify-all' if owner == 'table' else 'measure', directory, rows, 'bulk' if owner == 'table' else 'scan', args.cpu, args.timeout)
                        validate(readback, owner, rows, 'verify', common.AS_LIMIT)
                        require(common.manifest(directory) == inventory, 'Readback changed accepted storage')
                        exceeds = inventory['bytes'] > common.AS_LIMIT
                        exceeded |= exceeds
                        identity = hashlib.sha256(json.dumps(inventory['files'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()
                        report['fixtures'].append(dict(owner=owner, rows=rows, inventory_sha256=identity,
                                                       file_count=len(inventory['files']), retained_bytes=inventory['bytes'],
                                                       allocated_bytes=inventory['allocated_bytes'], exceeds_address_space=exceeds,
                                                       cold_input_pages=pages, setup=setup, readback=readback))
                        common.save(args.output, report)
                        print(f'{owner}/{rows}: verified growth, {inventory["bytes"]} retained bytes, {common.AS_LIMIT} process limit', flush=True)
                    finally:
                        shutil.rmtree(directory)
                require(args.smoke or exceeded, f'{owner} data did not exceed the process ceiling')
            require(len(report['fixtures']) == sum(len(sizes) for _, sizes in owners), 'Incomplete growth matrix')
            report['status'] = 'passed'
    except BaseException as error:
        report['status'] = 'failed'
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        common.save(args.output, report)
    print(f'Local growth proof: {len(report["fixtures"])} verified fixtures; {args.output}')


if __name__ == '__main__':
    main()
