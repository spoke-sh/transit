"""Retained native startup rejects missing/foreign authority without mutation."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from harness.native import Fixture
from harness.services import free_port, wait_ready


def run(node, caller):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, 'public'], timeout=10))
        config = dict(profile='native_v1', genesis=dict(realm=42, root_key=public),
                      local_directory=str(fixture.native_directory), port=free_port())
        path = fixture.root / 'node.json'
        path.write_text(json.dumps(config))
        with (fixture.root / 'node.log').open('w+') as log:
            subprocess.run([node, str(path), '--initialize'], check=True, timeout=30, stdout=log, stderr=log)
            def inventory():
                return {str(file.relative_to(fixture.native_directory)): hashlib.sha256(file.read_bytes()).hexdigest()
                        for file in fixture.native_directory.rglob('*') if file.is_file()}
            before = inventory()
            child = subprocess.Popen([node, str(path)], stdout=log, stderr=log)
            try:
                wait_ready(fixture.http, child, f"http://127.0.0.1:{config['port']}/health")
            finally:
                child.kill(); child.wait(timeout=10)
            assert inventory() == before, 'Ordinary recovery changed retained contents'
            # Current-v1 config is strict, even when initialization is requested.
            for obsolete in ({'ursula_url': 'http://127.0.0.1:1'}, {'bucket': 'old'}, {'journal': 'old'}):
                path.write_text(json.dumps(config | obsolete))
                for args in ([], ['--initialize']):
                    rejected = subprocess.run([node, str(path), *args], capture_output=True, timeout=20)
                    assert rejected.returncode != 0 and b'UnknownField' in rejected.stderr, rejected.stderr
                    assert inventory() == before
            path.write_text(json.dumps(config | {'genesis': dict(realm=43, root_key=public)}))
            rejected = subprocess.run([node, str(path)], capture_output=True, timeout=20)
            assert rejected.returncode != 0, 'Foreign genesis opened retained authority'
            assert inventory() == before
            path.write_text(json.dumps(config))
            marker = fixture.native_directory / '.native-owner'
            original = marker.read_bytes()
            assert original
            for change in (b'foreign definition', b''):
                marker.write_bytes(change)
                damaged = inventory()
                rejected = subprocess.run([node, str(path)], capture_output=True, timeout=20)
                assert rejected.returncode != 0, 'Invalid native identity was adopted'
                assert inventory() == damaged, 'Rejected recovery repaired identity'
            marker.write_bytes(original)
            assert inventory() == before
        print('Native recovery: unchanged retained startup, obsolete configuration, foreign genesis and malformed identity rejection passed.')


if __name__ == '__main__':
    run(*sys.argv[1:])
