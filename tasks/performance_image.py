"""Freeze the last promoted nightly OCI image before a performance campaign."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from release_channel import channel
from release_identity import validate


def digest(value, prefix=''):
    if not isinstance(value, str) or not re.fullmatch(re.escape(prefix) + '[0-9a-f]{64}', value):
        raise ValueError('invalid content digest')
    return value


def selection(repository, descriptor, manifest_bytes, checksums_bytes, *, candidate_tag=None, channel_commit=None):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('invalid repository')
    manifest = json.loads(manifest_bytes)
    identity = validate(manifest['identity'])
    if identity['channel'] != 'nightly' or manifest['source_revision'] != identity['source_revision'] or manifest['release'] != identity['release']:
        raise ValueError('nightly release identity mismatch')
    checksum = hashlib.sha256(manifest_bytes).hexdigest()
    matches = re.findall(rb'^([0-9a-f]{64})  release-manifest\.json$', checksums_bytes, re.MULTILINE)
    if matches != [checksum.encode()]:
        raise ValueError('manifest checksum mismatch')
    if candidate_tag is None:
        if descriptor is None or descriptor['version'] != 1 or descriptor['identity'] != identity:
            raise ValueError('missing or mismatched promoted nightly')
        if digest(descriptor['manifest_sha256']) != checksum or digest(descriptor['checksums_sha256']) != hashlib.sha256(checksums_bytes).hexdigest():
            raise ValueError('nightly channel digest mismatch')
        if not isinstance(channel_commit, str) or not re.fullmatch('[0-9a-f]{40}', channel_commit):
            raise ValueError('missing channel commit')
        if type(descriptor['workflow_run']) is not int or descriptor['workflow_run'] <= 0:
            raise ValueError('missing publication run')
    elif descriptor is not None or identity['tag'] != candidate_tag:
        raise ValueError('candidate tag mismatch')
    image = manifest['images']['transit']
    digest(image['digest'], 'sha256:')
    if set(image['platforms']) != {'linux/amd64', 'linux/arm64'}:
        raise ValueError('incomplete native image set')
    for value in image['platforms'].values():
        digest(value['manifest'], 'sha256:')
        digest(value['config'], 'sha256:')
    return dict(version=1, selection='promoted-nightly' if candidate_tag is None else 'explicit-unpromoted-candidate',
                repository=repository, channel_commit=channel_commit,
                publication_run=descriptor['workflow_run'] if descriptor else None,
                identity=identity, definition=digest(manifest['definition']),
                manifest_sha256=checksum, checksums_sha256=hashlib.sha256(checksums_bytes).hexdigest(),
                image=f'ghcr.io/{repository.lower()}@{image["digest"]}', platforms=image['platforms'])


def resolve(repository, candidate_tag=None):
    tip, descriptor = (None, None) if candidate_tag else channel(repository)
    if candidate_tag is None and descriptor is None:
        raise ValueError('no promoted nightly; publication must complete before the scheduled campaign')
    tag = candidate_tag or validate(descriptor['identity'])['tag']
    if not re.fullmatch(r'nightly-[0-9]{8}-g[0-9a-f]{12}', tag):
        raise ValueError('invalid nightly tag')
    with tempfile.TemporaryDirectory(prefix='transit-performance-release-') as temporary:
        root = Path(temporary)
        subprocess.run(['gh', 'release', 'download', tag, '--repo', repository,
                        '--pattern', 'release-manifest.json', '--pattern', 'SHA256SUMS', '--dir', str(root)],
                       check=True, timeout=120)
        return selection(repository, descriptor, (root / 'release-manifest.json').read_bytes(),
                         (root / 'SHA256SUMS').read_bytes(), candidate_tag=candidate_tag, channel_commit=tip)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', default=os.environ.get('GITHUB_REPOSITORY', 'spoke-sh/transit'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--candidate-tag', help='explicit manual investigation only; never a promoted-nightly fallback')
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    try:
        value = resolve(args.repository, args.candidate_tag)
    except Exception as error:
        args.output.write_text(json.dumps(dict(status='failed', error_type=type(error).__name__)) + '\n')
        raise
    args.output.write_text(json.dumps(value, indent=2) + '\n')
    print(value['image'])


if __name__ == '__main__':
    main()
