#!/usr/bin/env python3
"""Combine qualified SDK assets with the runtime release before publication."""
import argparse
import json
from pathlib import Path
import shutil

from package_release import sha256


def assemble(runtime, sdks):
    manifest = json.loads((runtime / 'release-manifest.json').read_text())
    sdk = json.loads((sdks / 'sdk-manifest.json').read_text())
    for field in ('release', 'source_revision', 'definition'):
        if sdk[field] != manifest[field]:
            raise ValueError(f'SDK/runtime {field} mismatch')
    if set(sdk['packages']) != {'python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam', 'go'}:
        raise ValueError('incomplete SDK language set')
    expected = set(sdk['assets']) | {'sdk-manifest.json'}
    if {path.name for path in sdks.iterdir()} != expected:
        raise ValueError('incomplete SDK archive set')
    for name, digest in sdk['assets'].items():
        if Path(name).name != name or sha256(sdks / name) != digest:
            raise ValueError(f'SDK archive checksum/path mismatch: {name}')
    for name in sorted(expected):
        if (runtime / name).exists():
            raise ValueError(f'duplicate release asset: {name}')
    for name in sorted(expected):
        shutil.copy2(sdks / name, runtime / name)
        manifest['assets'][name] = sha256(runtime / name)
    manifest['sdks'] = {key: sdk[key] for key in ('target', 'compiler', 'glibc_minimum', 'packages')}
    (runtime / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (runtime / 'SHA256SUMS').write_text(''.join(
        f'{sha256(path)}  {path.name}\n' for path in sorted(runtime.iterdir())
        if path.is_file() and path.name != 'SHA256SUMS'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runtime', type=Path)
    parser.add_argument('sdks', type=Path)
    args = parser.parse_args()
    assemble(args.runtime, args.sdks)
