"""Install release artifacts in a private prefix and exercise their public runtime."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tempfile

from interfaces.installation.release import run as runtime


def checksums(directory):
    result = {}
    for line in (directory / 'SHA256SUMS').read_text().splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([A-Za-z0-9_.-]+)', line)
        if not match or match[2] in result:
            raise ValueError('malformed or duplicate release checksum')
        result[match[2]] = match[1]
    for name in ('release-manifest.json', 'install.sh'):
        actual = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        if result.get(name) != actual:
            raise ValueError(f'release checksum mismatch: {name}')
    return result


def run(version, revision, artifacts=None):
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
        raise ValueError('invalid release version')
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('a clean expected source revision is required')
    with tempfile.TemporaryDirectory(prefix='transit-published-') as temporary:
        root = Path(temporary)
        directory = artifacts.resolve() if artifacts else root / 'downloads'
        if artifacts is None:
            directory.mkdir()
            for name in ('SHA256SUMS', 'release-manifest.json', 'install.sh'):
                subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location',
                                '--proto', '=https', '--proto-redir', '=https', '--tlsv1.2',
                                '--output', str(directory / name),
                                f'https://github.com/spoke-sh/transit/releases/download/v{version}/{name}'], check=True)
        checksums(directory)
        manifest = json.loads((directory / 'release-manifest.json').read_text())
        if manifest['release'] != version or manifest['source_revision'] != revision:
            raise ValueError('release metadata does not match the selected version/source')
        prefix = root / 'installed prefix'
        args = ['sh', str(directory / 'install.sh'), '--version', version, '--prefix', str(prefix)]
        if artifacts is not None:
            args += ['--from', str(directory)]
        # No inherited language/module configuration or developer tool discovery.
        environment = {'HOME': str(root), 'PATH': '/usr/bin:/bin', 'LANG': 'C'}
        subprocess.run(args, cwd=root, env=environment, check=True)
        identity = subprocess.check_output([str(prefix / 'bin/transit'), '--version'],
                                           cwd=root, env={'PATH': '/unavailable'}, text=True).strip()
        assert identity == f'Transit {version} (git {revision}; CLI contract 1)', identity
        binaries = manifest.get('platforms', {}).get(platform.machine(), manifest)['binaries']
        for name, expected in binaries.items():
            actual = hashlib.sha256((prefix / 'bin' / name).read_bytes()).hexdigest()
            assert actual == expected['sha256'], name
        runtime(prefix)
        # A second installation must preserve the selected executable and refuse replacement.
        before = os.readlink(prefix / 'bin/transit')
        repeated = subprocess.run(args, cwd=root, env=environment, capture_output=True, text=True)
        assert repeated.returncode and 'already exists' in repeated.stderr, repeated
        assert os.readlink(prefix / 'bin/transit') == before
    print('Release installation: verified package identities, isolated prefix, runtime and replacement refusal passed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--artifacts', type=Path, help='downloaded CI artifacts; omit to fetch the public GitHub Release')
    args = parser.parse_args()
    run(args.version, args.revision, args.artifacts)
