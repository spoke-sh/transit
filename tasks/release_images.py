"""Build scratch images from the verified static release bundle; never push."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time

from package_release import BINARIES, sha256
from release_oci import blob, exported, checksums, copy_image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory', type=Path)
parser.add_argument('--diagnostics', type=Path, help='retain public image configurations for failed export diagnosis')
args = parser.parse_args()
directory = args.directory.resolve()
manifest = json.loads((directory / 'release-manifest.json').read_text())
version = manifest['release']
architecture = manifest['target'].split('-')[0]
(directory / 'images').mkdir()
with tempfile.TemporaryDirectory(prefix='transit-images-') as temporary:
    root = Path(temporary)
    with tarfile.open(directory / f'transit-{version}-linux-{architecture}.tar.gz') as bundle:
        bundle.extractall(root, filter='data')
    source = root / f'transit-{version}-linux-{architecture}'
    context = root / 'context'
    context.mkdir()
    (context / 'data').mkdir()
    (context / 'tmp').mkdir()
    shutil.copytree(source / 'notices', context / 'notices')
    for name in BINARIES:
        shutil.copy2(source / 'bin' / name, context / 'executable')
        (context / 'Dockerfile').write_text(
            'FROM scratch\nCOPY executable /bin/' + name + '\nCOPY notices /usr/share/transit/notices\n'
            'COPY --chown=65532:65532 data /data\nCOPY --chmod=1777 tmp /tmp\n'
            'USER 65532:65532\nWORKDIR /data\nENV HOME=/tmp PATH=/bin\n'
            f'LABEL org.opencontainers.image.source="https://github.com/spoke-sh/transit" '
            f'org.opencontainers.image.version="{version}" '
            f'org.opencontainers.image.revision="{manifest["source_revision"]}"\n'
            f'ENTRYPOINT ["/bin/{name}"]\n' + ('CMD ["server"]\n' if name == 'transit' else ''))
        image = f'transit-release/{name}:{version}'
        subprocess.run(['docker', 'build', '--network=none', '--build-arg',
                        f'SOURCE_DATE_EPOCH={manifest["source_date_epoch"]}', '--tag', image, str(context)], check=True)
        if name == 'transit':
            subprocess.run(['docker', 'run', '--rm', '--network=none', '--read-only', image, '--version'], check=True)
            container = subprocess.check_output([
                'docker', 'run', '--detach', '--init', '--network=none', '--read-only',
                '--tmpfs', '/tmp:rw,mode=1777', '--tmpfs', '/data:rw,uid=65532,gid=65532',
                image, 'server', '--no-ui'], text=True).strip()
            try:
                command = ['docker', 'exec', container, '/bin/transit', 'console', '--no-rc', '-c']
                deadline = time.monotonic() + 180
                while True:
                    ready = subprocess.run([*command, 'SHOW TABLES'], capture_output=True, text=True, timeout=30)
                    if ready.returncode == 0:
                        break
                    if time.monotonic() >= deadline or subprocess.check_output(
                            ['docker', 'inspect', '--format', '{{.State.Running}}', container], text=True).strip() != 'true':
                        raise RuntimeError('container SQL readiness failed: ' + subprocess.check_output(
                            ['docker', 'logs', container], text=True, stderr=subprocess.STDOUT))
                    time.sleep(1)
                subprocess.run([*command, 'CREATE TABLE release_probe (id BIGINT PRIMARY KEY)'], check=True)
                subprocess.run([*command, 'INSERT INTO release_probe VALUES (31)'], check=True, timeout=30)
                rows = subprocess.check_output([*command, 'SELECT id FROM release_probe'], text=True, timeout=30)
                if '31' not in rows:
                    raise RuntimeError('container query did not return its accepted row')
            finally:
                subprocess.run(['docker', 'stop', '--timeout', '30', container], check=True)
                subprocess.run(['docker', 'rm', container], check=True)
        layout = directory / 'images' / name
        copy_image('docker-daemon:' + image, f'oci:{layout}:{version}', '--format', 'oci')
        original = json.loads(subprocess.check_output(['docker', 'image', 'inspect', image]))[0]
        if args.diagnostics:
            args.diagnostics.mkdir(parents=True, exist_ok=True)
            descriptor, = json.loads((layout / 'index.json').read_text())['manifests']
            converted = json.loads(blob(layout, descriptor))
            # These images contain only release executables, notices and literal
            # Dockerfile settings. Do not retain container/installation state.
            (args.diagnostics / (name + '.json')).write_text(json.dumps({
                'release': version, 'source_revision': manifest['source_revision'],
                'architecture': architecture, 'docker': {
                    key: original[key] for key in ('Id', 'Config', 'RootFS')},
                'oci': json.loads(blob(layout, converted['config'])),
            }, indent=2) + '\n')
        manifest.setdefault('images', {})[name] = exported(layout, architecture, original)
(directory / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(directory / 'SHA256SUMS').write_text(''.join(f'{sha256(path)}  {path.name}\n'
                                           for path in sorted(directory.iterdir())
                                           if path.is_file() and path.name != 'SHA256SUMS'))
checksums(directory / 'images')
