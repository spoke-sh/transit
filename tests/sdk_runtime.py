"""Build and exercise the actual Nix runtime closure with no SDK source tree."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
source = Path(subprocess.check_output(['nix', 'eval', '--raw', '.#transit.src'], cwd=ROOT, text=True).strip())
assert not (source / 'sdks').exists(), 'runtime derivation includes SDK sources'
assert not (source / 'examples/station-sdk').exists(), 'runtime derivation includes SDK consumers'
result = subprocess.check_output(['nix', 'build', '--no-link', '--print-out-paths', '.#transit', '.#transit-sql-gateway'], cwd=ROOT, text=True)
packages = [Path(line) for line in result.splitlines()]
runtime = next(package for package in packages if (package / 'bin/transit').is_file())
gateway = next(package for package in packages if (package / 'bin/transit-sql-gateway').is_file())
for name in ('transit', 'transit-node', 'transit-query-host', 'transit-board'):
    assert (runtime / 'bin' / name).is_file(), name
# The node/query host take a configuration filename, not a --help switch.
for executable in (runtime / 'bin/transit', gateway / 'bin/transit-sql-gateway'):
    subprocess.run([str(executable), '--help'], cwd=source, check=True, stdout=subprocess.DEVNULL)
print('SDK boundary: packaged Transit and SQL gateway build and run without SDK sources')
