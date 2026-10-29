"""Load shipped native SDK wheels on a clean Linux runner without Nix."""
import ctypes
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


def run(packages):
    manifest = json.loads((packages / 'sdk-manifest.json').read_text())
    definition = manifest['definition'].encode()
    with tempfile.TemporaryDirectory(prefix='transit-sdk-loader-') as temporary:
        root = Path(temporary)
        for family, library_name, check in (
                ('client', 'libtransit_client.so', 'transit_client_abi_definition_matches'),
                ('station', 'libtransit_station.so', 'station_abi_definition_matches')):
            wheel, = (packages / 'wheels').glob(f'transit_native_{family}-*.whl')
            expected = manifest['packages']['python'][str(wheel.relative_to(packages))]
            assert hashlib.sha256(wheel.read_bytes()).hexdigest() == expected
            with zipfile.ZipFile(wheel) as archive:
                archive.extractall(root / family)
            library, = (root / family).rglob(library_name)
            loaded = ctypes.CDLL(str(library))
            match = getattr(loaded, check)
            match.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
            match.restype = ctypes.c_uint32
            assert match(definition, len(definition)) == 1
            assert match(b'foreign', 7) == 0
            host, = (root / family).rglob(f'transit-{family}-host')
            host.chmod(0o755)
            started = subprocess.run([str(host)], cwd=root, env={'PATH': '/unavailable'},
                                     capture_output=True, text=True, timeout=10)
            assert started.returncode == 1 and 'ExpectedHostConfiguration' in started.stderr, started
    print('Shipped SDK wheels: native libraries, definition rejection and host loaders passed without Nix')


if __name__ == '__main__':
    run(Path(sys.argv[1]).resolve())
