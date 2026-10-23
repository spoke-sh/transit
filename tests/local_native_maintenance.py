"""Exercise local maintenance in the node which owns the actual storage lock."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.request

from storage import free_port, wait_ready


def run(node, caller):
    with tempfile.TemporaryDirectory(prefix='transit-local-maintenance-') as temporary:
        root = Path(temporary)
        public = json.loads(subprocess.check_output([caller, 'public'], timeout=10))
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        seed = root / 'maintenance.key'
        seed.write_text('09' * 32)
        seed.chmod(0o600)
        config = {'profile': 'native_v1', 'genesis': {
            'realm': 42, 'root_key': public, 'max_clock_error_ms': 10000,
            'allow_history_trim': True}, 'local_directory': str(root / 'native'),
            'port': port, 'resident_pages': 1, 'request_timeout_ms': 10000}
        config_file = root / 'node.json'
        config_file.write_text(json.dumps(config))
        manifest = root / 'expected.json'
        log_path = root / 'node.log'
        child = None

        def floor():
            data = (root / 'native' / 'wal' / 'part-0.meta').read_bytes()
            assert len(data) == 128 and data[:8] == b'LWMT\x01\x00\x00\x00'
            assert hashlib.sha256(data[:96]).digest() == data[96:]
            return int.from_bytes(data[64:72], 'little')

        def invoke(phase):
            subprocess.run([caller, url, phase, str(manifest)], check=True, timeout=60)

        def await_condition(check):
            until = time.monotonic() + 30
            while not check():
                assert child.poll() is None, 'local node exited'
                if time.monotonic() > until:
                    raise TimeoutError('local maintenance condition')
                time.sleep(0.025)

        def stop():
            nonlocal child
            if child is not None:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
                child = None

        with log_path.open('w') as log:
            def start(*args):
                nonlocal child
                child = subprocess.Popen([node, str(config_file), *args], stdout=log,
                                         stderr=subprocess.STDOUT, env={**os.environ, 'LOG_FORMAT': 'json'})
                wait_ready(http, child, url + '/health')

            try:
                start('--bootstrap')
                invoke('maintenance-seed')
                expected = json.loads(manifest.read_text())
                assert floor() == 0, 'no opt-in maintenance was running'
                stop()
                config['maintenance'] = {'principal': 131072, 'seed_file': str(seed),
                                         'interval_ms': 10, 'operation_timeout_ms': 10000}
                config_file.write_text(json.dumps(config))
                start()
                await_condition(lambda: floor() >= expected['checkpoint'])
                invoke('maintenance-check')
                # Reopen after physical trimming: retained authority still owns
                # all outcomes, dependent lifetimes and undispatched effects.
                stop()
                start()
                invoke('maintenance-check')
                invoke('maintenance-revoke')
                offset = log_path.stat().st_size
                await_condition(lambda: '"error_type":"Forbidden"' in log_path.read_text()[offset:])
                retained_floor = floor()
                stop()
                offset = log_path.stat().st_size
                start()
                await_condition(lambda: '"error_type":"Forbidden"' in log_path.read_text()[offset:])
                assert floor() == retained_floor, 'revoked maintenance trimmed history after restart'
                invoke('maintenance-grant')
                await_condition(lambda: floor() > retained_floor)
                invoke('maintenance-check')
            except BaseException:
                sys.stderr.write(log_path.read_text()[-12000:])
                raise
            finally:
                stop()
    print('Local maintenance: owned lifecycle scans, accepted-floor trim, restart and current revocation passed.')
