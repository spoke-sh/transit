#!/usr/bin/env python3
"""Publish a qualified release without replacing existing versioned bytes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from package_release import BINARIES, ROOT, sha256
from version import check


def run(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def registry_config(reference):
    result = subprocess.run(['skopeo', 'inspect', '--raw', f'docker://{reference}'], capture_output=True, text=True)
    if result.returncode:
        # Only a registry's explicit missing-manifest response permits a new tag.
        # Authentication, transport and rate-limit errors stop publication.
        if 'manifest unknown' in result.stderr.lower() or 'manifest_unknown' in result.stderr.lower():
            return None
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)


def publish(directory, repository):
    manifest = json.loads((directory / 'release-manifest.json').read_text())
    version, revision = manifest['release'], manifest['source_revision']
    if len(revision) != 40:
        raise ValueError('publishing requires a clean source commit')
    tag = f'v{version}'
    check(ROOT, tag)
    if run(['git', 'rev-parse', 'HEAD'], cwd=ROOT) != revision:
        raise ValueError('artifact revision does not identify the tagged source')
    registry = f'ghcr.io/{repository.lower()}'
    with tempfile.TemporaryDirectory(prefix='transit-publish-') as temporary:
        temporary = Path(temporary)
        # Verify the complete artifact set before any external mutation.
        run(['sha256sum', '--check', 'SHA256SUMS'], cwd=directory)
        run(['sha256sum', '--check', 'SHA256SUMS'], cwd=directory / 'images')
        if set(manifest['images']) != set(BINARIES):
            raise ValueError('incomplete image set')
        if {path.stem for path in (directory / 'images').glob('*.tar')} != set(BINARIES):
            raise ValueError('incomplete image archives')
        for path in sorted((directory / 'images').glob('*.tar')):
            name = path.stem
            reference = registry if name == 'transit' else f'{registry}-{name.removeprefix("transit-")}'
            reference += f':{version}'
            run(['docker', 'load', '--input', str(path)])
            local = f'transit-release/{name}:{version}'
            identity = run(['docker', 'image', 'inspect', '--format', '{{.Id}}', local])
            if identity != manifest['images'][name]:
                raise ValueError(f'image identity mismatch: {name}')
            remote = registry_config(reference)
            if remote is not None:
                if remote.get('config', {}).get('digest') != identity:
                    raise ValueError(f'refusing to replace published image {reference}')
            else:
                run(['skopeo', 'copy', f'docker-daemon:{local}', f'docker://{reference}'])
        chart_ref = f'{registry}/charts/transit:{version}'
        chart = directory / f'transit-{version}.tgz'
        if registry_config(chart_ref) is None:
            run(['helm', 'push', str(chart), f'oci://{registry}/charts'])
        else:
            run(['helm', 'pull', f'oci://{registry}/charts/transit', '--version', version,
                 '--destination', str(temporary)])
            if sha256(temporary / chart.name) != sha256(chart):
                raise ValueError(f'refusing to replace published chart {chart_ref}')
        releases = json.loads(run(['gh', 'api', f'repos/{repository}/releases', '--paginate', '--slurp']))
        existing = next((r for page in releases for r in page if r['tag_name'] == tag), None)
        if existing is None:
            notes = temporary / 'notes.md'
            notes.write_text(f'Transit {version}, source `{revision}`.\n\n'
                             'Static Linux x86_64/ARM64 executables, Linux x86_64 SDK packages, the Zig source '
                             'closure, versioned handbook/specifications, Homebrew formula, SHA-256 checksums '
                             'and exact contract definition are attached. macOS and Windows executables '
                             'are not available.\n\n'
                             f'Container: `ghcr.io/{repository.lower()}:{version}`. '
                             f'Helm: `oci://ghcr.io/{repository.lower()}/charts/transit`, version `{version}`.\n\n'
                             'See the tagged repository distribution guide for configuration, retained-data '
                             'compatibility and the published component set.\n')
            run(['gh', 'release', 'create', tag, '--repo', repository, '--verify-tag', '--draft',
                 '--title', f'Transit {version}', '--notes-file', str(notes)])
            existing = {'assets': [], 'draft': True}
        assets = {asset['name'] for asset in existing['assets']}
        for path in sorted(directory.iterdir()):
            if not path.is_file():
                continue
            if path.name in assets:
                run(['gh', 'release', 'download', tag, '--repo', repository, '--pattern', path.name,
                     '--dir', str(temporary), '--clobber'])
                if sha256(temporary / path.name) != sha256(path):
                    raise ValueError(f'refusing to replace published asset {path.name}')
            else:
                if not existing['draft']:
                    raise ValueError('published release has an incomplete artifact set')
                run(['gh', 'release', 'upload', tag, str(path), '--repo', repository])
        if existing['draft']:
            run(['gh', 'release', 'edit', tag, '--repo', repository, '--draft=false'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    publish(args.directory.resolve(), os.environ['GITHUB_REPOSITORY'])
