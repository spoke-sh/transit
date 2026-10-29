"""Verify published registry objects using empty registry credential stores."""
import json
import os
import platform
from pathlib import Path
import subprocess
import tempfile

from package_release import BINARIES, ROOT, sha256
from release_identity import current

release_identity = current(clean=True)
version, tag = release_identity['release'], release_identity['tag']
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
with tempfile.TemporaryDirectory(prefix='transit-registry-proof-') as temporary:
    root = Path(temporary)
    auth = root / 'containers-auth.json'
    auth.write_text('{"auths": {}}\n')
    environment = os.environ | {'DOCKER_CONFIG': str(root / 'docker'),
                                'REGISTRY_AUTH_FILE': str(auth),
                                'HELM_REGISTRY_CONFIG': str(root / 'helm.json')}
    manifest_path = root / 'release-manifest.json'
    subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location', '--proto', '=https',
                    '--proto-redir', '=https', '--output', str(manifest_path),
                    f'https://github.com/spoke-sh/transit/releases/download/{tag}/release-manifest.json'], check=True)
    manifest = json.loads(manifest_path.read_text())
    assert manifest['release'] == version and manifest['source_revision'] == revision
    for name in BINARIES:
        reference = f'ghcr.io/spoke-sh/{name}:{version}'
        subprocess.run(['docker', 'pull', reference], env=environment, check=True)
        identity = subprocess.check_output(['docker', 'image', 'inspect', '--format', '{{.Id}}', reference],
                                           env=environment, text=True).strip()
        architecture = {'x86_64': 'amd64', 'aarch64': 'arm64'}[platform.machine()]
        assert identity == manifest['images'][name]['platforms']['linux/' + architecture]['config'], name
        raw = subprocess.check_output(['skopeo', 'inspect', '--raw', 'docker://' + reference], env=environment)
        import hashlib
        assert 'sha256:' + hashlib.sha256(raw).hexdigest() == manifest['images'][name]['digest'], name
    identity = subprocess.check_output(['docker', 'run', '--rm', '--network=none', '--read-only',
                                       f'ghcr.io/spoke-sh/transit:{version}', '--version'],
                                      env=environment, text=True).strip()
    assert identity == f'Transit {version} (git {revision}; CLI contract 1)', identity
    subprocess.run(['helm', 'pull', '--version', version, '--destination', str(root),
                    'oci://ghcr.io/spoke-sh/transit/charts/transit'], env=environment, check=True)
    chart = root / f'transit-{version}.tgz'
    assert sha256(chart) == manifest['assets'][chart.name]
print('Published registry objects: anonymous image identities, CLI execution and chart bytes passed')
