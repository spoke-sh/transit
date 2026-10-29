#!/usr/bin/env python3
"""Select and promote verified nightlies without moving immutable release tags."""
import argparse
import base64
from datetime import datetime
import json
import os
from pathlib import Path
import subprocess

from release_identity import ROOT, current, describe, validate

BRANCH = 'release-channels'


def api(repository, path, *, method='GET', data=None, missing=False):
    args = ['gh', 'api', f'repos/{repository}/{path}', '--method', method]
    if data is not None:
        args += ['--input', '-']
    result = subprocess.run(args, input=json.dumps(data) if data is not None else None,
                            text=True, capture_output=True)
    if result.returncode:
        if missing and '(HTTP 404)' in result.stderr:
            return None
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout) if result.stdout.strip() else None


def channel(repository):
    ref = api(repository, f'git/ref/heads/{BRANCH}', missing=True)
    if ref is None:
        return None, None
    tip = ref['object']['sha']
    content = api(repository, f'contents/nightly.json?ref={tip}')
    return tip, json.loads(base64.b64decode(content['content']))


def prepare(repository, kind, publish, output):
    source = current(clean=True)
    date = None
    if kind == 'nightly':
        # A rerun on another day keeps the original run's identity.
        run = api(repository, f'actions/runs/{os.environ["GITHUB_RUN_ID"]}')
        date = datetime.fromisoformat(run['created_at'].replace('Z', '+00:00')).strftime('%Y%m%d')
    identity = describe(source['base_version'], source['source_revision'], source['source_date_epoch'], kind, date)
    skip = False
    if kind == 'nightly' and publish:
        _, previous = channel(repository)
        if previous is not None:
            validate(previous['identity'])
            skip = previous['identity']['source_revision'] == identity['source_revision']
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(identity, indent=2) + '\n')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
        for key, value in {'version': identity['release'], 'tag': identity['tag'],
                           'revision': identity['source_revision'], 'channel': kind,
                           'publish': str(publish).lower(), 'skip': str(skip).lower()}.items():
            stream.write(f'{key}={value}\n')


def may_promote(previous, candidate):
    validate(candidate)
    if candidate['channel'] != 'nightly':
        raise ValueError('only a nightly identity can advance this channel')
    if previous is None:
        return True
    old = validate(previous['identity'])
    if old['source_revision'] == candidate['source_revision']:
        return False
    result = subprocess.run(['git', 'merge-base', '--is-ancestor', old['source_revision'],
                             candidate['source_revision']], cwd=ROOT)
    if result.returncode == 1:
        return False
    if result.returncode:
        raise RuntimeError('cannot establish nightly source ancestry')
    return True


def promote(directory, repository):
    manifest = json.loads((directory / 'release-manifest.json').read_text())
    identity = current(clean=True)
    if manifest['identity'] != identity:
        raise ValueError('promotion artifact/source identity mismatch')
    tip, previous = channel(repository)
    if not may_promote(previous, identity):
        print('Nightly channel already identifies this source or a newer source')
        return
    # This job runs only after every anonymous download check succeeds. The
    # immutable manifests remain authoritative while rolling OCI aliases update.
    for name in manifest['images']:
        reference = f'ghcr.io/{repository.lower()}' + ('' if name == 'transit' else '-' + name.removeprefix('transit-'))
        subprocess.run(['skopeo', 'copy', '--all', '--preserve-digests', f'docker://{reference}:{identity["release"]}',
                        f'docker://{reference}:nightly'], check=True)
    import hashlib
    descriptor = dict(version=1, identity=identity,
                      manifest_sha256=hashlib.sha256((directory / 'release-manifest.json').read_bytes()).hexdigest(),
                      checksums_sha256=hashlib.sha256((directory / 'SHA256SUMS').read_bytes()).hexdigest(),
                      workflow_run=int(os.environ['GITHUB_RUN_ID']))
    blob = api(repository, 'git/blobs', method='POST', data={
        'content': json.dumps(descriptor, indent=2) + '\n', 'encoding': 'utf-8'})
    tree_data = {'tree': [{'path': 'nightly.json', 'mode': '100644', 'type': 'blob', 'sha': blob['sha']}]}
    if tip:
        tree_data['base_tree'] = api(repository, f'git/commits/{tip}')['tree']['sha']
    tree = api(repository, 'git/trees', method='POST', data=tree_data)
    commit = api(repository, 'git/commits', method='POST', data={
        'message': f'chore(release): promote {identity["tag"]}', 'tree': tree['sha'], 'parents': [tip] if tip else []})
    if tip:
        # The new commit has the observed tip as its parent. A concurrent update
        # cannot be overwritten by this non-forced ref update.
        api(repository, f'git/refs/heads/{BRANCH}', method='PATCH', data={'sha': commit['sha'], 'force': False})
    else:
        api(repository, 'git/refs', method='POST', data={'ref': f'refs/heads/{BRANCH}', 'sha': commit['sha']})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    prepare_args = sub.add_parser('prepare')
    prepare_args.add_argument('--channel', choices=('stable', 'nightly'), required=True)
    prepare_args.add_argument('--publish', choices=('true', 'false'), required=True)
    prepare_args.add_argument('--output', type=Path, required=True)
    promote_args = sub.add_parser('promote')
    promote_args.add_argument('directory', type=Path)
    args = parser.parse_args()
    repository = os.environ['GITHUB_REPOSITORY']
    if args.command == 'prepare':
        prepare(repository, args.channel, args.publish == 'true', args.output)
    else:
        promote(args.directory, repository)
