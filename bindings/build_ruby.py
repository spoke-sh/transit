"""Build independent Ruby gems with version-matched native port dependencies."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def build(output, names, native_prefix=ROOT / 'zig-out'):
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
                shutil.copy2(native_prefix / 'bin' / f'transit-{family}-host', target / 'native' / f'transit-{family}-host')
            manifest, = target.glob('*.gemspec')
            subprocess.run(['gem', 'build', manifest.name, '--quiet'], cwd=target, check=True)
            artifact, = target.glob('*.gem')
            shutil.copy2(artifact, output / artifact.name)
            print(f'Built {artifact.name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('packages', nargs='*')
    parser.add_argument('--native-prefix', type=Path, default=ROOT / 'zig-out')
    args = parser.parse_args()
    build(args.output, args.packages or ['transit-native-client', 'transit-client', 'transit-native-station', 'transit-station', 'examples/station-sdk/ruby'], args.native_prefix.resolve())
