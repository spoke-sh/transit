#!/usr/bin/env python3
"""Archive matching language packages and the public Zig source dependency closure."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from package_release import ROOT, archive, sha256
from release_identity import current


def package(packages, output, notices):
    manifest = json.loads((packages / 'sdk-manifest.json').read_text())
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT):
        revision += '-dirty'
    identity = current()
    version = identity['release']
    if manifest['source_revision'] != revision or manifest['release'] != version:
        raise ValueError('SDK packages do not match this source revision/version')
    epoch = int(subprocess.check_output(['git', 'show', '-s', '--format=%ct', 'HEAD'], cwd=ROOT))
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError('SDK archive output must be empty')
    with tempfile.TemporaryDirectory(prefix='transit-sdk-archive-') as temporary:
        temporary = Path(temporary)
        for language, files in manifest['packages'].items():
            stage = temporary / language
            stage.mkdir()
            for name, expected in files.items():
                source = packages / name
                if not source.resolve().is_relative_to(packages.resolve()) or sha256(source) != expected:
                    raise ValueError(f'SDK package checksum/path mismatch: {name}')
                shutil.copy2(source, stage / source.name)
            shutil.copytree(notices, stage / 'notices')
            shutil.copy2(packages / 'sdk-manifest.json', stage / 'sdk-manifest.json')
            name = f'transit-sdk-{language}-{version}-linux-x86_64'
            archive(stage, output / f'{name}.tar.gz', name, epoch)
        # The public Zig manifest has relative shared-package dependencies.
        # Ship their tracked closure, preserving paths, and the real consumer.
        stage = temporary / 'zig'
        prefixes = ('sdks/zig', 'packages/zig', 'third_party', 'examples/work-items')
        paths = subprocess.check_output(['git', 'ls-files', '-z', '--', *prefixes,
                                         'VERSION', 'LICENSE', 'flake.lock'], cwd=ROOT).decode().split('\0')
        for name in filter(None, paths):
            destination = stage / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, destination)
            if name == 'VERSION':
                destination.write_text(version + '\n')
            elif destination.name == 'build.zig.zon' and not name.startswith('third_party/'):
                text = destination.read_text()
                text = text.replace('.version = "' + identity['base_version'] + '"', '.version = "' + version + '"')
                destination.write_text(text)
        shutil.copytree(notices, stage / 'notices')
        shutil.copy2(packages / 'sdk-manifest.json', stage / 'sdk-manifest.json')
        name = f'transit-sdk-zig-{version}-source'
        archive(stage, output / f'{name}.tar.gz', name, epoch)
    manifest['assets'] = {path.name: sha256(path) for path in sorted(output.iterdir())}
    (output / 'sdk-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Packaged SDK release assets: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packages', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--notices', required=True, type=Path)
    args = parser.parse_args()
    package(args.packages.resolve(), args.output.resolve(), args.notices.resolve())
