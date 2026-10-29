#!/usr/bin/env python3
"""Combine qualified SDK assets with the runtime release before publication."""
import argparse
import json
from pathlib import Path
import shutil

from package_release import sha256
from release_brew import formula
from release_oci import combine, checksums


def assemble(runtime, sdks, arm64=None, handbook=None, arm64_sdks=None):
    manifest = json.loads((runtime / 'release-manifest.json').read_text())
    sdk = json.loads((sdks / 'sdk-manifest.json').read_text())
    for field in ('release', 'source_revision', 'definition', 'identity'):
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
    additional_sdk = None
    additional_sdk_files = {}
    if arm64_sdks is not None:
        additional_sdk = json.loads((arm64_sdks / 'sdk-manifest.json').read_text())
        for field in ('release', 'source_revision', 'definition', 'identity'):
            if additional_sdk[field] != manifest[field]:
                raise ValueError(f'ARM64 SDK/runtime {field} mismatch')
        if additional_sdk['target'] != 'aarch64-linux-gnu.2.28' or sdk['target'] != 'x86_64-linux-gnu.2.28':
            raise ValueError('incorrect SDK architecture')
        if set(additional_sdk['packages']) != set(sdk['packages']):
            raise ValueError('incomplete ARM64 SDK language set')
        if {path.name for path in arm64_sdks.iterdir()} != set(additional_sdk['assets']) | {'sdk-manifest.json'}:
            raise ValueError('incomplete ARM64 SDK archive set')
        for name, digest in additional_sdk['assets'].items():
            if Path(name).name != name or sha256(arm64_sdks / name) != digest:
                raise ValueError(f'ARM64 SDK checksum/path mismatch: {name}')
            if name.startswith('transit-sdk-zig-'):
                continue  # One architecture-independent source closure is shipped.
            if name in expected or (runtime / name).exists():
                raise ValueError(f'duplicate release asset: {name}')
            additional_sdk_files[name] = arm64_sdks / name
        additional_sdk_files['sdk-manifest-linux-aarch64.json'] = arm64_sdks / 'sdk-manifest.json'
    arm_asset = None
    if arm64 is not None:
        arm = json.loads((arm64 / 'release-manifest.json').read_text())
        for field in ('release', 'source_revision', 'definition', 'identity', 'flake_lock_sha256'):
            if arm[field] != manifest[field]:
                raise ValueError(f'ARM64/runtime {field} mismatch')
        if arm['target'] != 'aarch64-linux-musl' or manifest['target'] != 'x86_64-linux-musl':
            raise ValueError('incorrect runtime architecture')
        for name, digest in arm['assets'].items():
            if Path(name).name != name or sha256(arm64 / name) != digest:
                raise ValueError(f'ARM64 archive checksum/path mismatch: {name}')
        arm_asset = f'transit-{manifest["release"]}-linux-aarch64.tar.gz'
        if arm_asset not in arm['assets'] or (runtime / arm_asset).exists():
            raise ValueError('missing or duplicate ARM64 archive')
        manifest['platforms'] = {name: {key: data[key] for key in ('target', 'binaries')}
                                 for name, data in (('x86_64', manifest), ('aarch64', arm))}
    handbook_files = set()
    if handbook is not None:
        docs = json.loads((handbook / 'handbook-manifest.json').read_text())
        for field in ('release', 'source_revision', 'definition', 'identity'):
            if docs[field] != manifest[field]:
                raise ValueError(f'handbook/runtime {field} mismatch')
        handbook_files = set(docs['assets']) | {'handbook-manifest.json'}
        if {path.name for path in handbook.iterdir()} != handbook_files:
            raise ValueError('incomplete handbook archive set')
        for name, digest in docs['assets'].items():
            if Path(name).name != name or sha256(handbook / name) != digest or (runtime / name).exists():
                raise ValueError(f'handbook archive checksum/path mismatch: {name}')
    for name in sorted(expected):
        shutil.copy2(sdks / name, runtime / name)
        manifest['assets'][name] = sha256(runtime / name)
    for name, source in additional_sdk_files.items():
        shutil.copy2(source, runtime / name)
        manifest['assets'][name] = sha256(runtime / name)
    if arm_asset:
        manifest['images'] = combine(runtime / 'images', arm64 / 'images',
                                     manifest['images'], arm['images'], manifest['release'])
        checksums(runtime / 'images')
        shutil.copy2(arm64 / arm_asset, runtime / arm_asset)
        manifest['assets'][arm_asset] = sha256(runtime / arm_asset)
        (runtime / 'transit.rb').write_text(formula(manifest))
        manifest['assets']['transit.rb'] = sha256(runtime / 'transit.rb')
    for name in sorted(handbook_files):
        shutil.copy2(handbook / name, runtime / name)
        manifest['assets'][name] = sha256(runtime / name)
    manifest['sdks'] = {item['target']: {key: item[key] for key in ('compiler', 'glibc_minimum', 'packages')}
                        for item in (sdk, additional_sdk) if item is not None}
    (runtime / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (runtime / 'SHA256SUMS').write_text(''.join(
        f'{sha256(path)}  {path.name}\n' for path in sorted(runtime.iterdir())
        if path.is_file() and path.name != 'SHA256SUMS'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runtime', type=Path)
    parser.add_argument('sdks', type=Path)
    parser.add_argument('--arm64', required=True, type=Path)
    parser.add_argument('--handbook', required=True, type=Path)
    parser.add_argument('--arm64-sdks', required=True, type=Path)
    args = parser.parse_args()
    assemble(args.runtime, args.sdks, args.arm64, args.handbook, args.arm64_sdks)
