"""Build the archived public Zig SDK and qualify an installed application's lifecycle."""
import argparse
import platform
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

from interfaces.installation.server_applications import run


def qualify(archive, runtime):
    runtime = runtime.resolve()
    with tempfile.TemporaryDirectory(prefix='transit-release-zig-') as temporary:
        root = Path(temporary)
        with tarfile.open(archive) as bundle:
            bundle.extractall(root, filter='data')
        source, = root.iterdir()
        application = source / 'examples/work-items'
        subprocess.run(['zig', 'build', '-Dtarget=' + platform.machine() + '-linux-musl',
                        '-Dcpu=baseline', '-Doptimize=ReleaseSafe', '-j2'], cwd=application, check=True)
        installed = root / 'installed'
        shutil.copytree(application / 'zig-out/bin', installed)
        # Runtime and application both execute outside their source tree, with
        # no developer PATH. The private test driver calls public library APIs.
        run(runtime / 'bin/transit', runtime / 'bin/transit-node',
            runtime / 'bin/transit-query-host', installed / 'transit-work-items',
            installed / 'work-items', embedded=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('runtime', type=Path)
    args = parser.parse_args()
    qualify(args.archive, args.runtime)
