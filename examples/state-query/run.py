"""Fresh owned non-trading source/query demonstration and recovery schedule."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--profile', choices=('local', 'compose', 'reference'), default='local')
parser.add_argument('--source', choices=('kv', 'table', 'document'), default='table')
args = parser.parse_args()
if args.profile == 'local':
    subprocess.run(['zig', 'build', 'test-unified-query', '-Doptimize=ReleaseSafe',
                    '-Dunified-example=true', '-Dunified-source='+args.source], cwd=ROOT, check=True)
else:
    from placed import run
    run(args.profile, args.source)
