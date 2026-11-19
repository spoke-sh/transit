"""Run the pinned upstream source checks against the Transit-composed probe."""
import os
import subprocess
import sys
from runner.paths import ROOT

if __name__ == '__main__':
    upstream = ROOT / 'third_party/transitc'
    environment = os.environ.copy()
    environment['TRANSIT_SQL_GRAMMAR_DIR'] = str(ROOT / 'contracts/sql')
    subprocess.run([sys.executable, '-B', str(upstream / 'tests/runner/launch.py'),
                    'tests/query/application_source/types.py', *sys.argv[1:]],
                   env=environment, check=True)
