"""Build portable Linux SDK packages through their existing owning builders."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TARGET = 'x86_64-linux-gnu.2.28'
BUILDERS = {'python': 'wheels', 'node': 'node', 'rust': 'rust', 'ruby': 'ruby',
            'c': 'c', 'java': 'java', 'dotnet': 'dotnet', 'beam': 'beam', 'go': 'go'}
SYSTEM_LIBRARIES = {'libc.so.6', 'libpthread.so.0', 'libdl.so.2', 'libm.so.6',
                    'librt.so.1', 'ld-linux-x86-64.so.2'}


def command(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def native(family, jobs):
    arguments = ['prefix'] if family == 'c-sdk' else ['fixture-clients', '-Dsdk-examples=false']
    output = command(['zig', 'build', *arguments, '-Dtarget=' + TARGET,
                      '-Dcpu=baseline', '-Doptimize=ReleaseSafe', f'-j{jobs}'],
                     cwd=ROOT / 'bindings' if family == 'c-sdk' else ROOT)
    return Path(json.loads(output)['prefix'])


def relocate(source, destination):
    shutil.copytree(source, destination)
    metadata = json.loads((destination / 'build.json').read_text())
    if metadata['optimize'] != 'safe' or not metadata['target'].endswith('-gnu.2.28'):
        raise ValueError('release SDKs require the matching ReleaseSafe glibc 2.28 build')
    for name in metadata['artifacts']:
        path = destination / name
        if path.read_bytes()[:4] != b'\x7fELF':
            continue
        dynamic = command(['readelf', '-d', str(path)])
        needed = set(re.findall(r'\(NEEDED\).*\[([^\]]+)\]', dynamic))
        if any(item not in SYSTEM_LIBRARIES and not item.startswith('libtransit_') for item in needed):
            raise ValueError(f'undeclared native dependency: {path}: {needed}')
        # Zig's C SDK graph also emits a relative build-cache search directory.
        # An installed consumer must resolve sibling libraries without that tree.
        subprocess.run(['patchelf', '--set-rpath', '$ORIGIN' if path.parent.name == 'lib' else '$ORIGIN/../lib',
                        str(path)], check=True)
        headers = command(['readelf', '-l', '-d', '-V', str(path)])
        if '/nix/store/' in headers or '.zig-cache/' in headers:
            raise ValueError(f'nonportable loader or library search path: {path}')
        if any(int(minor) > 28 for minor in re.findall(r'GLIBC_2\.(\d+)', headers)):
            raise ValueError(f'native artifact requires glibc newer than 2.28: {path}')
        if 'INTERP' in headers and '/lib64/ld-linux-x86-64.so.2' not in headers:
            raise ValueError(f'unexpected native interpreter: {path}')
    return metadata


def build(output, jobs):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError('SDK release output must be empty')
    version = (ROOT / 'VERSION').read_text().strip()
    revision = command(['git', 'rev-parse', 'HEAD'], cwd=ROOT)
    if command(['git', 'status', '--porcelain'], cwd=ROOT):
        revision += '-dirty'
    epoch = command(['git', 'show', '-s', '--format=%ct', 'HEAD'], cwd=ROOT)
    environment = os.environ | {'SOURCE_DATE_EPOCH': epoch}
    native_prefix = native('clients', jobs)
    sdk_prefix = native('c-sdk', jobs)
    with tempfile.TemporaryDirectory(prefix='transit-release-sdks-') as temporary:
        temporary = Path(temporary)
        portable = temporary / 'native'
        c_sdk = temporary / 'c-sdk'
        metadata = relocate(native_prefix, portable)
        relocate(sdk_prefix, c_sdk)
        # Keep the packaged native owner and its headers/contracts available for
        # independent installed-consumer checks and provenance inspection.
        native_output = output / 'native'
        shutil.copytree(portable, native_output)
        shutil.copytree(c_sdk, output / 'c-sdk')
        for language, directory in BUILDERS.items():
            args = [sys.executable, '-B', str(ROOT / f'bindings/build_{language}.py'),
                    str(output / directory), '--native-prefix', str(portable)]
            if language == 'c':
                args += ['--sdk-prefix', str(c_sdk)]
            subprocess.run(args, cwd=ROOT, env=environment, check=True)
        definition = json.loads((portable / 'contracts/client.json').read_text())['definition']
        manifest = dict(version=1, release=version, source_revision=revision,
                        definition=definition, target=TARGET, optimize='ReleaseSafe',
                        compiler=metadata['compiler'], glibc_minimum='2.28',
                        native_build=metadata, packages={})
        for language, directory in BUILDERS.items():
            manifest['packages'][language] = {str(path.relative_to(output)): sha256(path)
                                             for path in sorted((output / directory).iterdir()) if path.is_file()}
            if not manifest['packages'][language]:
                raise ValueError(f'no packages produced for {language}')
        (output / 'sdk-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Portable SDK packages: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--jobs', type=int, default=2)
    args = parser.parse_args()
    build(args.output, args.jobs)
