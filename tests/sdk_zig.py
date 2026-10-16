"""Build a real application outside the checkout through the public Zig SDK."""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix='transit-sdk-zig-') as directory:
    target = Path(directory)
    # Copy source only: no cache, generated outputs, local data or sibling app
    # build artifacts can satisfy this consumer's declared dependencies.
    prefixes = ('sdks/zig/', 'packages/zig/', 'third_party/', 'examples/work-items/')
    paths = subprocess.check_output(['git', 'ls-files', '-z', '--', *[p.rstrip('/') for p in prefixes]], cwd=ROOT).decode().split('\0')
    for name in paths:
        if not name or not name.startswith(prefixes):
            continue
        source = ROOT / name
        destination = target / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    application = target / 'examples/work-items'
    subprocess.run(['zig', 'build', '-Doptimize=ReleaseSafe', '-j2'], cwd=application, check=True)
    worker = application / 'zig-out/bin/transit-work-items'
    result = subprocess.check_output([str(application / 'zig-out/bin/work-items'), 'manifest', str(worker)], cwd=target)
    declaration = json.loads(result)
    assert declaration['application'] == 'work-items'
    assert declaration['roles'][0]['artifact']['path'] == str(worker)
    assert {caller['name'] for caller in declaration['callers']} == {'operator', 'writer', 'inspector'}
    print('Zig SDK: isolated application builds and emits its real installation declaration')
