"""Check private catalog failure retention; no provider durability is inferred."""
from pathlib import Path
import select
import subprocess
import sys
import tempfile

from catalog_native import retain_recovery_fixture
from cold_storage import ColdStore
from storage import Fixture


def run(retain=retain_recovery_fixture):
    cold = ColdStore()
    try:
        objects = cold.root / cold.bucket
        for name in ('pages/bucket/stream/snapshots/one/xl.meta',
                     'pages/bucket/_packs/00000000/empty.bin',
                     'bucket-startup/xl.meta'):
            path = objects / name
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.name == 'empty.bin': path.mkdir()
            else: path.write_bytes(b'metadata')
        assert cold.data_objects() == 0, 'Metadata or empty object directory counted as data'
        for count, name in enumerate(('pages/bucket/stream/chunks/one.bin/xl.meta',
                                      'pages/bucket/_packs/00000000/two.bin/xl.meta'), 1):
            path = objects / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'object metadata')
            assert cold.data_objects() == count, 'Cold chunks and shared packs must both count'
    finally:
        cold.__exit__(None, None, None)
    with tempfile.TemporaryDirectory(prefix='transit-retention-control-') as parent:
        destination = Path(parent) / 'catalog.json'
        fixture, cold = Fixture(), ColdStore()
        recovery = {}
        try:
            (fixture.root / 'authority-evidence').write_bytes(b'private authority history')
            (cold.root / 'object-evidence').write_bytes(b'private cold object')
            # Exercise the native process lifecycle without starting a provider
            # or weakening its disk-space guard. The fixture owns this child.
            cold.process = subprocess.Popen(
                [sys.executable, '-c', 'import time; print("ready", flush=True); time.sleep(60)'],
                stdout=subprocess.PIPE,
            )
            cold.pid = cold.process.pid
            assert select.select([cold.process.stdout], [], [], 5)[0], 'Child readiness deadline'
            assert cold.process.stdout.readline() == b'ready\n'
            retain(fixture, cold, destination, recovery)
            assert cold.process.poll() is not None, 'Retention moved live provider state'
            retained = Path(recovery['retained_fixture'])
            assert (retained / 'authority-evidence').read_bytes() == b'private authority history'
            assert (retained / 'cold-store/object-evidence').read_bytes() == b'private cold object'
            assert Path(recovery['retained_cold_fixture']) == retained / 'cold-store'
        finally:
            cold.__exit__(None, None, None)
            if cold.process is not None:
                cold.process.stdout.close()
            fixture.__exit__(None, None, None)
        assert (retained / 'cold-store/object-evidence').read_bytes() == b'private cold object'

        class Unjoined:
            def poll(self): return None
            def terminate(self): pass
            def kill(self): pass
            def wait(self, timeout): raise subprocess.TimeoutExpired('unjoined-control', timeout)

        fixture, cold = Fixture(), ColdStore()
        recovery = {}
        try:
            (fixture.root / 'authority-evidence').write_bytes(b'private authority history')
            (cold.root / 'object-evidence').write_bytes(b'private cold object')
            cold.process = Unjoined()
            try:
                retain(fixture, cold, destination, recovery)
            except subprocess.TimeoutExpired:
                pass
            else:
                raise AssertionError('Retention accepted an unjoined provider')
            assert Path(recovery['retained_fixture'], 'authority-evidence').exists()
            assert (cold.root / 'object-evidence').read_bytes() == b'private cold object'
            assert 'retained_cold_fixture' not in recovery
            try:
                cold.__exit__(None, None, None)
            except RuntimeError as error:
                assert 'did not join' in str(error)
            else:
                raise AssertionError('Cleanup accepted an unjoined provider')
            assert (cold.root / 'object-evidence').exists(), 'Cleanup discarded unjoined state'
        finally:
            cold.process = None  # The injected object never created a child.
            cold.__exit__(None, None, None)
            fixture.__exit__(None, None, None)
    print('Catalog fixture: cold chunks/packs counted; native child joined before retention; unjoined state remains private and retained.', flush=True)


if __name__ == '__main__':
    run()
