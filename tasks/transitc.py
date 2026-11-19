#!/usr/bin/env python3
"""Import/verify the exact upstream compiler package used by Transit adapters."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / 'third_party/transitc'
PATHS = ['build.zig', 'build.zig.zon', 'LICENSE', 'NOTICE.md', 'README.md', 'apps', 'packages', 'contracts', 'tests', 'examples']


def identities():
    generated = {'.cache', '.zig-cache', 'zig-out', 'zig-pkg', '__pycache__', 'node_modules'}
    return {str(p.relative_to(DESTINATION)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(DESTINATION.rglob('*')) if p.is_file()
            and p != DESTINATION / 'upstream.json'
            and not (set(p.relative_to(DESTINATION).parts) & generated)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, help='explicit Git checkout to import; never a build dependency')
    parser.add_argument('--revision', help='full reviewed upstream commit')
    args = parser.parse_args()
    if args.source:
        if not args.revision or not re.fullmatch('[0-9a-f]{40}', args.revision):
            parser.error('--source requires a full --revision')
        data = subprocess.check_output(['git', 'archive', '--format=tar', args.revision, *PATHS], cwd=args.source)
        # A Git tree is the input, never the source checkout's mutable files.
        if DESTINATION.exists():
            shutil.rmtree(DESTINATION)
        DESTINATION.mkdir(parents=True)
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            archive.extractall(DESTINATION, filter='data')
        (DESTINATION / 'upstream.json').write_text(json.dumps({
            'repository': 'https://github.com/spoke-sh/transitc',
            'revision': args.revision,
            'paths': PATHS,
            'files': identities(),
        }, indent=2) + '\n')
    record = json.loads((DESTINATION / 'upstream.json').read_text())
    assert re.fullmatch('[0-9a-f]{40}', record['revision']) and record['paths'] == PATHS
    assert identities() == record['files'], 'Vendored compiler drift: change transitc and import a reviewed commit'
    print(f"transitc {record['revision']}: {len(record['files'])} exact upstream files verified")


if __name__ == '__main__': main()
