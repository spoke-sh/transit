#!/usr/bin/env python3
"""Package the static Linux runtime and existing Helm chart without publishing."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BINARIES = ('transit', 'transit-admin', 'transit-node', 'transit-query-host',
            'transit-board', 'transit-delivery', 'transit-station-controller')


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def archive(source, destination, prefix, epoch):
    with destination.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w') as bundle:
            for path in sorted(source.rglob('*')):
                if not path.is_file():
                    continue
                info = bundle.gettarinfo(str(path), str(Path(prefix) / path.relative_to(source)))
                info.uid = info.gid = 0
                info.uname = info.gname = ''
                info.mtime = epoch
                info.mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
                with path.open('rb') as stream:
                    bundle.addfile(info, stream)


def package(prefix, output):
    architecture = platform.machine()
    if platform.system() != 'Linux' or architecture not in ('x86_64', 'aarch64'):
        raise ValueError('release packaging requires its native Linux x86_64/ARM64 runner')
    from release_identity import current
    identity_record = current()
    version = identity_record['release']
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT):
        revision += '-dirty'
    identity = f'Transit {version} (git {revision}; CLI contract 1)\n'
    actual = subprocess.check_output([str(prefix / 'bin/transit'), '--version'], text=True)
    if actual != identity:
        raise ValueError(f'build provenance mismatch: expected {identity!r}, got {actual!r}')
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError('release output must be empty')
    epoch = int(subprocess.check_output(['git', 'show', '-s', '--format=%ct', 'HEAD'], cwd=ROOT))
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    manifest = dict(version=1, release=version, source_revision=revision, definition=definition,
                    identity=identity_record, target=f'{architecture}-linux-musl', optimize='ReleaseSafe', source_date_epoch=epoch,
                    flake_lock_sha256=sha256(ROOT / 'flake.lock'), binaries={})
    with tempfile.TemporaryDirectory(prefix='transit-package-') as temporary:
        stage = Path(temporary) / 'bundle'
        (stage / 'bin').mkdir(parents=True)
        for name in BINARIES:
            binary = prefix / 'bin' / name
            headers = subprocess.check_output(['readelf', '-l', str(binary)], text=True)
            dynamic = subprocess.check_output(['readelf', '-d', str(binary)], text=True)
            if 'INTERP' in headers or '(NEEDED)' in dynamic:
                raise ValueError(f'{name} is not a standalone static executable')
            shutil.copy2(binary, stage / 'bin' / name)
            manifest['binaries'][name] = dict(sha256=sha256(binary), version=version)
        shutil.copytree(prefix / 'share/transit/notices', stage / 'notices')
        shutil.copy2(ROOT / 'transit.yaml.example', stage / 'transit.yaml.example')
        (stage / 'build-info.json').write_text(json.dumps(manifest, indent=2) + '\n')
        name = f'transit-{version}-linux-{architecture}'
        archive(stage, output / f'{name}.tar.gz', name, epoch)
        # Helm's ordinary archive carries checkout mtimes. Normalize its tar/gzip
        # metadata so retries can compare bytes before touching registry tags.
        subprocess.run(['helm', 'package', str(ROOT / 'charts/transit'), '--version', version, '--app-version', version, '--destination', temporary], check=True)
        chart = Path(temporary) / f'transit-{version}.tgz'
        with tarfile.open(chart) as source:
            source.extractall(Path(temporary) / 'chart', filter='data')
        archive(Path(temporary) / 'chart/transit', output / chart.name, 'transit', epoch)
    shutil.copy2(ROOT / 'install.sh', output / 'install.sh')
    manifest['assets'] = {path.name: sha256(path) for path in sorted(output.iterdir())}
    (output / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (output / 'SHA256SUMS').write_text(''.join(f'{sha256(path)}  {path.name}\n'
                                            for path in sorted(output.iterdir())))
    print(f'Packaged Transit {version} from {revision}: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    package(args.prefix.resolve(), args.output.resolve())
