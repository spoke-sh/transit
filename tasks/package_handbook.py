#!/usr/bin/env python3
"""Package the checked, source-pinned handbook and its generated specification downloads."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from package_release import ROOT, archive, sha256


def package(site, output):
    version = (ROOT / 'VERSION').read_text().strip()
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT):
        raise ValueError('the release handbook requires a clean source revision')
    if not (site / 'index.html').is_file() or not (site / 'specs').is_dir():
        raise ValueError('missing generated handbook/specifications')
    # Fail if an ordinary latest-source site was passed instead of the pinned build.
    html = (site / 'reference/distribution.html').read_text()
    if f'/blob/{revision}/' not in html or '/blob/main/' in html:
        raise ValueError('handbook source links must identify the release commit')
    epoch = int(subprocess.check_output(['git', 'show', '-s', '--format=%ct', 'HEAD'], cwd=ROOT))
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError('handbook archive output must be empty')
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    manifest = dict(version=1, release=version, source_revision=revision, definition=definition)
    with tempfile.TemporaryDirectory(prefix='transit-handbook-') as temporary:
        stage = Path(temporary)
        shutil.copytree(site, stage / 'site')
        (stage / 'build-info.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (stage / 'README.txt').write_text(
            f'Transit {version} handbook and specifications, source {revision}.\n\n'
            'Serve this directory locally with:\n'
            '  python3 -m http.server --bind 127.0.0.1 --directory site 8000\n'
            'Open http://127.0.0.1:8000/ in a browser.\n'
            'Pages, search and specifications are local; source-code links use the pinned GitHub commit.\n')
        name = f'transit-handbook-{version}'
        archive(stage, output / f'{name}.tar.gz', name, epoch)
    manifest['assets'] = {path.name: sha256(path) for path in output.iterdir()}
    (output / 'handbook-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('site', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    package(args.site.resolve(), args.output.resolve())
