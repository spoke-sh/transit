"""Build independent Ruby gems with version-matched native port dependencies."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def build(output, names):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    for name in names:
        with tempfile.TemporaryDirectory(prefix='transit-gem-') as temporary:
            target = Path(temporary)
            source = ROOT / name if '/' in name else ROOT / 'packages/ruby' / name
            shutil.copytree(source, target, dirs_exist_ok=True)
            if name.startswith('transit-native-'):
                family = name.removeprefix('transit-native-')
                (target / 'native').mkdir()
                shutil.copy2(ROOT / 'zig-out/bin' / f'transit-{family}-host', target / 'native' / f'transit-{family}-host')
            manifest, = target.glob('*.gemspec')
            subprocess.run(['gem', 'build', manifest.name, '--quiet'], cwd=target, check=True)
            artifact, = target.glob('*.gem')
            shutil.copy2(artifact, output / artifact.name)
            print(f'Built {artifact.name}')


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2:] or ['transit-native-client', 'transit-client', 'transit-native-station', 'transit-station', 'examples/station-sdk/ruby'])
