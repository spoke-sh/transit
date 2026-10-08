"""Build installed Node artifacts with package-owned native executable discovery."""
import json
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def build(output: Path, packages: list[str], native_prefix: Path = ROOT / 'zig-out') -> None:
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    for name in packages:
        source = ROOT / name if '/' in name else ROOT / 'packages/ts' / name
        manifest = json.loads((source / 'package.json').read_bytes())
        if not name.startswith('transit-native-'):
            subprocess.run(['vp', 'exec', '--filter', manifest['name'], 'tsc'], cwd=ROOT, check=True)
        with tempfile.TemporaryDirectory(prefix='transit-node-package-') as temporary:
            staging = Path(temporary)
            # Published dependencies are exact versions, never workspace/source paths.
            for dependency, version in manifest.get('dependencies', {}).items():
                manifest['dependencies'][dependency] = version.removeprefix('workspace:')
            manifest['packageManager'] = json.loads((ROOT / 'package.json').read_bytes())['packageManager']
            (staging / 'package.json').write_text(json.dumps(manifest, indent=2) + '\n')
            for name_or_directory in manifest['files'] + ['README.md']:
                path = source / name_or_directory
                if path.is_dir(): shutil.copytree(path, staging / name_or_directory, dirs_exist_ok=True)
                elif path.is_file(): shutil.copy2(path, staging / name_or_directory)
            if name.startswith('transit-native-'):
                family = name.removeprefix('transit-native-')
                executable = native_prefix / 'bin' / f'transit-{family}-host'
                if not executable.is_file(): raise SystemExit(f'Missing native artifact: {executable}')
                (staging / 'bin').mkdir(exist_ok=True)
                shutil.copy2(executable, staging / 'bin' / executable.name)
            subprocess.run(['vp', 'env', 'exec', '--package-manager', manifest['packageManager'],
                'pnpm', 'pack', '--pack-destination', str(output)], cwd=staging, check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('packages', nargs='*')
    parser.add_argument('--native-prefix', type=Path, default=ROOT / 'zig-out')
    args = parser.parse_args()
    build(args.output, args.packages or ['transit-native-client', 'transit-client',
        'transit-native-station', 'transit-station-sdk', 'examples/station-sdk/typescript'], args.native_prefix.resolve())
