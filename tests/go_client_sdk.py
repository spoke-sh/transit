"""Exercise installed Go artifacts through the shared real-authority schedule."""
import os
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
from sdk_raw_client import run as schedule

ROOT = Path(__file__).resolve().parents[1]


def run(node, cli, library, artifacts):
    def install(target):
        for name, folder in (('transit-go', 'sdk'), ('transit-go-native', 'native')):
            with tarfile.open(Path(artifacts).resolve() / f'{name}-0.2.0.tar.gz') as archive:
                archive.extractall(target / folder, filter='data')
        source = target / 'consumer-source'
        source.mkdir()
        shutil.copy2(ROOT / 'tests/go_client_sdk/main.go', source / 'main.go')
        (source / 'go.mod').write_text('''module transit-go-consumer-proof

go 1.26.0

require github.com/spoke-sh/transit/sdks/go v0.2.0
replace github.com/spoke-sh/transit/sdks/go => ../sdk
''')
        env = {k: v for k, v in os.environ.items() if k not in
               ('LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CGO_CFLAGS', 'CGO_LDFLAGS', 'GOFLAGS')}
        env.update(GOWORK='off', GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off', CGO_ENABLED='1',
                   GOEXPERIMENT='cgocheck2', TRANSIT_GO_NATIVE_DIRECTORY=str(target / 'native/lib'))
        subprocess.run(['go', 'build', '-race', '-trimpath', '-o', str(target / 'consumer'), '.'],
                       cwd=source, env=env, check=True)
        # Build a real foreign-definition consumer. Matching ABI version alone
        # must not admit the actual library with a different generated header.
        probe_config = target / 'probe.json'
        probe_config.write_text(json.dumps(dict(url='http://127.0.0.1:1', pid=1, seed='unused')))
        header = target / 'sdk/internal/nativeclient/transit_client.h'
        original = header.read_text()
        foreign, count = re.subn(r'(#define TRANSIT_CLIENT_ABI_DEFINITION )"[a-f0-9]{64}"',
                                r'\g<1>"' + '0' * 64 + '"', original)
        assert count == 1
        header.write_text(foreign)
        subprocess.run(['go', 'build', '-race', '-trimpath', '-o', str(target / 'foreign'), '.'],
                       cwd=source, env=env, check=True)
        subprocess.run([target / 'foreign', 'incompatible', probe_config], cwd=target, env=env, check=True)
        header.write_text(original)
        subprocess.run(['go', 'build', '-trimpath', '-o', str(target / 'without-cgo'), '.'],
                       cwd=source, env=dict(env, CGO_ENABLED='0', GOEXPERIMENT=''), check=True)
        subprocess.run([target / 'without-cgo', 'incompatible', probe_config], cwd=target, env=env, check=True)
        shutil.copy2(ROOT / 'examples/go-client/main.go', source / 'main.go')
        subprocess.run(['go', 'build', '-race', '-trimpath', '-o', str(target / 'example'), '.'],
                       cwd=source, env=env, check=True)
        shutil.rmtree(source)
        shutil.rmtree(target / 'sdk')
        # Only the installed executable and explicit native runtime remain.
        def invoke(mode, config):
            result = subprocess.check_output([target / 'consumer', mode, config], cwd=target, env=env, timeout=30)
            if mode in ('first', 'recover'):
                example = json.loads(config.read_text())
                example.pop('spawn'); example.pop('accepted')
                example.update(native_directory=env['TRANSIT_GO_NATIVE_DIRECTORY'], realm=72,
                               principal=65536, sequence=1, value='wide')
                if mode == 'first': example['pending'] = str(target / 'example-pending.json')
                example_config = target / 'example.json'
                example_config.write_text(json.dumps(example))
                output = subprocess.check_output([target / 'example', 'prepare' if mode == 'first' else 'dispatch',
                    example_config], cwd=target, env=env, timeout=30)
                if mode == 'first':
                    assert Path(example['pending']).read_bytes() == Path(json.loads(config.read_text())['pending']).read_bytes()
                else:
                    assert json.loads(output) == json.loads(result)
            return result
        return invoke
    schedule(node, cli, library, install, 'Go', ROOT / '.cache/bindings/go/raw-evidence.json')


if __name__ == '__main__':
    run(*sys.argv[1:])
