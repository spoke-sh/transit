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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--node-packages', required=True, type=Path)
    parser.add_argument('--repeat', type=int, default=5, choices=range(1, 101))
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
            _, installer = PERFORMANCE_CONSUMERS['node']
            env, artifacts = installer(args.node_packages, target)
            script = target / 'imports.mjs'
            script.write_text(PROGRAM)
            emit(dict(phase='manifest', source=provenance(ROOT), repeat=args.repeat,
                      artifacts=artifacts, driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                      installer_sha256=hashlib.sha256((ROOT/'tests/sdk/direct_sdk_catalog.py').read_bytes()).hexdigest(),
                      program_sha256=hashlib.sha256(PROGRAM.encode()).hexdigest(),
                      node=subprocess.check_output(['node','--version'],text=True).strip(),
                      system=platform.platform(), cpus=os.cpu_count(), load=os.getloadavg(),
                      host_id=hashlib.sha256(Path('/proc/sys/kernel/random/boot_id').read_bytes()).hexdigest(),
                      cache='fresh Node process; retained OS pages; no client opened',
                      limits='module import only; no native host, network or service result'))
            samples = []
            for index in range(args.repeat):
                sample = dict(phase='import', index=index, outcome='incomplete')
                started = time.perf_counter_ns()
                try:
                    result = subprocess.run(['node',str(script)],cwd=target,env=env,capture_output=True,text=True,timeout=60)
                    assert result.returncode == 0, result.stderr
                    value = json.loads(result.stdout)
                    assert value['complete'] is True
                    for key in ('import_ns','cpu_ns','peak_rss_bytes'):
                        assert type(value[key]) is int and value[key] > 0
                    sample.update(outcome='complete', **value)
                except BaseException as error:
                    sample.update(outcome='failed', error_type=type(error).__name__)
                    raise
                finally:
                    sample['launch_ns'] = time.perf_counter_ns() - started
                    emit(sample)
                samples.append(sample)
            emit(dict(phase='summary', import_time=distribution([s['import_ns'] for s in samples]),
                      launch_time=distribution([s['launch_ns'] for s in samples]),
                      qualification='module-only observations; sample count is not a tail SLO'))
            success = True
        finally:
            try:
                if success:
                    shutil.rmtree(root)
                else:
                    print(f'Failed import fixture retained at {root}', file=sys.stderr)
            finally:
                emit(dict(phase='campaign', outcome='complete' if success else 'failed'))


if __name__ == '__main__':
    main()
