#!/usr/bin/env python3
"""Install the actual release formula using the exact candidate in Homebrew's cache."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys

from package_release import ROOT, sha256


def run(args):
    return subprocess.check_output(args, text=True).strip()


def verify(directory):
    manifest = json.loads((directory / 'release-manifest.json').read_text())
    name = f'transit-{manifest["release"]}-linux-{platform.machine()}.tar.gz'
    for asset in (name, 'transit.rb'):
        if sha256(directory / asset) != manifest['assets'][asset]:
            raise ValueError(f'Homebrew input checksum mismatch: {asset}')
    tap = 'transit/release-check'
    formula = tap + '/transit'
    if subprocess.run(['brew', 'list', '--versions', 'transit'], capture_output=True).returncode == 0:
        raise ValueError('Homebrew release proof requires a fresh installation')
    subprocess.run(['brew', 'tap-new', '--no-git', tap], check=True)
    with ExitStack() as cleanup:
        cleanup.callback(subprocess.run, ['brew', 'untap', tap], check=True)
        repository = Path(run(['brew', '--repository', tap]))
        shutil.copy2(directory / 'transit.rb', repository / 'Formula/transit.rb')
        # Homebrew requires explicit trust before loading a local formula. The
        # candidate was checksum-verified above; trust only this formula and
        # preserve any trust entry that already belongs to the caller.
        trusted = json.loads(run(['brew', 'trust', '--formula', '--json=v1']))
        if formula not in trusted:
            subprocess.run(['brew', 'trust', '--formula', formula], check=True)
            cleanup.callback(subprocess.run, ['brew', 'untrust', '--formula', formula], check=True)
        # Preserve the formula's public URL. Homebrew still verifies its checksum;
        # this permits qualification before those immutable bytes are published.
        cached = Path(run(['brew', '--cache', '--formula', formula]))
        cached.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(directory / name, cached)
        subprocess.run(['brew', 'install', '--formula', formula], check=True)
        cleanup.callback(subprocess.run, ['brew', 'uninstall', formula], check=True)
        subprocess.run(['brew', 'test', formula], check=True)
        prefix = run(['brew', '--prefix', formula])
        subprocess.run([sys.executable, '-B', str(ROOT / 'tests/runner/launch.py'),
                        str(ROOT / 'tests/interfaces/installation/release.py'), prefix], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    verify(args.directory.resolve())
