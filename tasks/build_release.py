#!/usr/bin/env python3
"""Build the committed runtime with an explicit distribution version and source SHA."""
import argparse
import json
from pathlib import Path
import subprocess

from release_identity import ROOT, current

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out-link', required=True, type=Path)
    parser.add_argument('--cores', type=int, default=2)
    args = parser.parse_args()
    identity = current(clean=True)
    system = subprocess.check_output(['nix', 'eval', '--impure', '--raw', '--expr', 'builtins.currentSystem'], text=True).strip()
    source = 'git+' + ROOT.as_uri() + '?rev=' + identity['source_revision']
    expression = ('let f = builtins.getFlake ' + json.dumps(source) + '; in f.packages.' + system
                  + '.transit-release.override { releaseVersion = ' + json.dumps(identity['release'])
                  + '; sourceRevision = ' + json.dumps(identity['source_revision']) + '; }')
    subprocess.run(['nix', 'build', '--expr', expression, '--out-link', str(args.out_link),
                    '--cores', str(args.cores), '-L'], check=True)
