"""Repeated fresh-process imports of the real installed Node SDK packages."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time

from performance.sdk.report import distribution
from runner.capture import directory, provenance
from runner.paths import ROOT
from sdk.consumer_registry import PERFORMANCE_CONSUMERS

PROGRAM = '''import assert from 'node:assert/strict';
const started = process.hrtime.bigint(), cpu = process.cpuUsage();
const client = await import('@transit/client');
const station = await import('@transit/station');
assert.equal(typeof client.Client.open, 'function');
assert.equal(typeof station.catalog.Client.open, 'function');
assert.equal(typeof station.relational.Client.open, 'function');
for (const name of ['@transit/client', '@transit/station']) {
  assert.ok(import.meta.resolve(name).startsWith(new URL('./node_modules/', import.meta.url).href));
}
const used = process.cpuUsage(cpu);
console.log(JSON.stringify({complete:true, import_ns:Number(process.hrtime.bigint()-started),
 cpu_ns:(used.user+used.system)*1000, peak_rss_bytes:process.resourceUsage().maxRSS*1024}));
'''


def first_metadata(script, config, env, target, expected, table):
    from harness.processes import joined
    from performance.console.resources import tree
    from performance.sdk.workload import verify
    from sdk.sdk_unified import Consumer

    started = time.perf_counter_ns()
    consumer = Consumer(['node', str(script), str(config)], env, target, read_timeout=60)
    try:
        result = consumer.call(dict(operation='lookup', name=table))
        verify(result, expected)
        first_result_ns = time.perf_counter_ns() - started
        info = consumer.call(dict(operation='info'))
    finally:
        owned = tree([consumer.child.pid])
        closing = time.perf_counter_ns()
        try:
            assert consumer.child.poll() is None, 'Consumer exited before joined close'
            consumer.close()
            assert consumer.child.returncode == 0
        finally:
            consumer.close()
            joined(owned)
        close_ns = time.perf_counter_ns() - closing
    return dict(complete=True, first_result_ns=first_result_ns, import_ns=info['import_ns'],
                open_ns=info['open_ns'], close_ns=close_ns, peak_rss_bytes=info['peak_rss_bytes'],
                import_cpu_ns=None, cpu_scope='unavailable; native hosts are separate processes')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--node-packages', required=True, type=Path)
    parser.add_argument('--repeat', type=int, default=5, choices=range(1, 101), metavar='1..100')
    parser.add_argument('--first-metadata', type=Path, metavar='CLIENT.json',
                        help='open installed Catalog/Query clients and verify metadata against an existing service')
    parser.add_argument('--table', default='sdk_items')
    parser.add_argument('--expected-rows', type=int, default=70, choices=range(1001))
    parser.add_argument('--expected-columns', type=int, default=2, choices=range(1, 257))
    args = parser.parse_args()
    evidence = directory(ROOT / '.cache/performance/sdk/imports.json') / 'observations.jsonl'
    print(f'Installed import observations: {evidence}', file=sys.stderr)
    root = Path(tempfile.mkdtemp(prefix='transit-sdk-import-', dir='/var/tmp'))
    success = False
    with evidence.open('x') as file:
        def emit(record):
            line = json.dumps(record)
            file.write(line+'\n'); file.flush()
            print(line, flush=True)
        emit(dict(phase='campaign', outcome='started'))
        try:
            target = root / 'node'
            source, installer = PERFORMANCE_CONSUMERS['node']
            env, artifacts = installer(args.node_packages, target)
            script = target / 'imports.mjs'
            if args.first_metadata:
                script.write_bytes((ROOT / source).read_bytes())
                config = target / 'client.json'
                shutil.copy2(args.first_metadata, config)
                config.chmod(0o600)
            else:
                script.write_text(PROGRAM)
            emit(dict(phase='manifest', source=provenance(ROOT), repeat=args.repeat,
                      artifacts=artifacts, driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                      installer_sha256=hashlib.sha256((ROOT/'tests/sdk/direct_sdk_catalog.py').read_bytes()).hexdigest(),
                      program_sha256=hashlib.sha256(script.read_bytes()).hexdigest(),
                      profile='first_metadata' if args.first_metadata else 'module_import',
                      service_configuration_sha256=hashlib.sha256(config.read_bytes()).hexdigest() if args.first_metadata else None,
                      expected=dict(table=args.table, rows=args.expected_rows, columns=args.expected_columns) if args.first_metadata else None,
                      helpers={path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in
                               ('tests/sdk/sdk_unified.py', 'tests/harness/processes.py', 'tests/performance/console/resources.py', 'tests/performance/sdk/workload.py')},
                      node=subprocess.check_output(['node','--version'],text=True).strip(),
                      system=platform.platform(), cpus=os.cpu_count(), load=os.getloadavg(),
                      host_id=hashlib.sha256(Path('/proc/sys/kernel/random/boot_id').read_bytes()).hexdigest(),
                      cache='fresh Node/native-host processes; retained OS/service caches' if args.first_metadata else 'fresh Node process; retained OS pages; no client opened',
                      limits='read-only metadata and joined close; no query result, pin, write or service startup' if args.first_metadata else 'module import only; no native host, network or service result'))
            samples = []
            for index in range(args.repeat):
                sample = dict(phase='first_metadata' if args.first_metadata else 'import', index=index, outcome='incomplete')
                started = time.perf_counter_ns()
                try:
                    if args.first_metadata:
                        value = first_metadata(script, config, env, target,
                                               dict(rows=args.expected_rows, columns=args.expected_columns), args.table)
                    else:
                        result = subprocess.run(['node',str(script)],cwd=target,env=env,capture_output=True,text=True,timeout=60)
                        assert result.returncode == 0, result.stderr
                        value = json.loads(result.stdout)
                    assert value['complete'] is True
                    for key in (('import_ns','open_ns','first_result_ns','close_ns','peak_rss_bytes') if args.first_metadata else ('import_ns','cpu_ns','peak_rss_bytes')):
                        assert type(value[key]) is int and value[key] > 0
                    sample.update(outcome='complete', **value)
                except BaseException as error:
                    sample.update(outcome='failed', error_type=type(error).__name__)
                    raise
                finally:
                    sample['launch_ns'] = time.perf_counter_ns() - started
                    emit(sample)
                samples.append(sample)
            summary = dict(phase='summary', import_time=distribution([s['import_ns'] for s in samples]),
                           launch_time=distribution([s['launch_ns'] for s in samples]),
                           qualification='metadata-only observations with joined client close; no service startup or tail SLO' if args.first_metadata else 'module-only observations; sample count is not a tail SLO')
            if args.first_metadata:
                summary['first_result_time'] = distribution([s['first_result_ns'] for s in samples])
            emit(summary)
            success = True
        finally:
            try:
                if success:
                    success = False
                    shutil.rmtree(root)
                    success = True
                else:
                    print(f'Failed import fixture retained at {root}', file=sys.stderr)
            finally:
                emit(dict(phase='campaign', outcome='complete' if success else 'failed'))


if __name__ == '__main__':
    main()
