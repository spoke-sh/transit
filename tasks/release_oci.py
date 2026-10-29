"""Assemble verified native OCI layouts into deterministic multi-architecture images."""
import hashlib
import json
from pathlib import Path
import shutil

INDEX = 'application/vnd.oci.image.index.v1+json'
IMAGE = 'application/vnd.oci.image.manifest.v1+json'
PLATFORMS = {'x86_64': 'amd64', 'aarch64': 'arm64'}


def blob(layout, descriptor):
    digest = descriptor['digest']
    if not isinstance(digest, str) or len(digest) != 71 or not digest.startswith('sha256:'):
        raise ValueError('invalid OCI blob digest')
    if any(c not in '0123456789abcdef' for c in digest[7:]):
        raise ValueError('invalid OCI blob digest')
    path = layout / 'blobs/sha256' / digest[7:]
    data = path.read_bytes()
    if len(data) != descriptor['size'] or hashlib.sha256(data).hexdigest() != digest[7:]:
        raise ValueError('OCI blob checksum/size mismatch')
    return data


def native(layout, architecture, config):
    index = json.loads((layout / 'index.json').read_text())
    if index['schemaVersion'] != 2 or len(index['manifests']) != 1:
        raise ValueError('expected exactly one native OCI image')
    descriptor = index['manifests'][0]
    if descriptor['mediaType'] != IMAGE:
        raise ValueError('expected a native OCI manifest')
    manifest = json.loads(blob(layout, descriptor))
    settings = json.loads(blob(layout, manifest['config']))
    if (settings['os'], settings['architecture'], manifest['config']['digest']) != ('linux', PLATFORMS[architecture], config):
        raise ValueError('OCI native architecture/config mismatch')
    for layer in manifest['layers']:
        blob(layout, layer)
    return {key: descriptor[key] for key in ('mediaType', 'digest', 'size')} | {
        'platform': {'os': 'linux', 'architecture': PLATFORMS[architecture]}}


def combine(first, second, images, arm_images, version):
    if set(images) != set(arm_images):
        raise ValueError('incomplete ARM64 image set')
    result, indexes = {}, {}
    # Check every supplied image before changing any destination layout.
    for name in sorted(images):
        descriptors = [native(first / name, 'x86_64', images[name]['config']),
                       native(second / name, 'aarch64', arm_images[name]['config'])]
        value = {'schemaVersion': 2, 'mediaType': INDEX, 'manifests': descriptors}
        data = json.dumps(value, separators=(',', ':'), sort_keys=True).encode()
        digest = 'sha256:' + hashlib.sha256(data).hexdigest()
        indexes[name] = (data, {'mediaType': INDEX, 'digest': digest, 'size': len(data),
                              'annotations': {'org.opencontainers.image.ref.name': version}})
        result[name] = {'digest': digest, 'platforms': {
            'linux/' + descriptor['platform']['architecture']: {
                'manifest': descriptor['digest'], 'config': owner[name]['config']}
            for descriptor, owner in zip(descriptors, (images, arm_images))}}
    for name, (data, descriptor) in indexes.items():
        layout = first / name
        for path in (second / name / 'blobs/sha256').iterdir():
            destination = layout / 'blobs/sha256' / path.name
            if destination.exists() and destination.read_bytes() != path.read_bytes():
                raise ValueError('conflicting OCI content-addressed blob')
            shutil.copy2(path, destination)
        (layout / 'blobs/sha256' / descriptor['digest'][7:]).write_bytes(data)
        (layout / 'index.json').write_text(json.dumps({'schemaVersion': 2, 'manifests': [descriptor]}, separators=(',', ':')))
    return result


def checksums(directory):
    (directory / 'SHA256SUMS').write_text(''.join(
        f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(directory)}\n'
        for path in sorted(directory.rglob('*')) if path.is_file() and path.name != 'SHA256SUMS'))
