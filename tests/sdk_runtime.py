"""Build and exercise the actual Nix runtime closure with no SDK source tree."""
from pathlib import Path
import json
import subprocess
import yaml

ROOT = Path(__file__).resolve().parents[1]
sources = json.loads(subprocess.check_output([
    'nix', 'eval', '--json', '.#transit', '--apply',
    'p: { runtime = toString p.src; board = toString p.boardAssets.src; dependencies = toString p.frontendDeps.src; }',
], cwd=ROOT, text=True))
source, board_source, dependency_source = (Path(sources[key]) for key in ('runtime', 'board', 'dependencies'))
assert not (source / 'sdks').exists(), 'runtime derivation includes SDK sources'
assert not (source / 'examples/station-sdk').exists(), 'runtime derivation includes SDK consumers'
assert not (source / 'tests/verification/results').exists(), 'runtime includes retained proof records'
assert (source / 'tests/runner/suite.json').is_file(), 'executable verification inventory was removed'
for name in ('packages/zig', 'third_party', 'tests', 'sdks'):
    assert not (board_source / name).exists(), f'Board asset source includes {name}'
assert (board_source / 'tasks/embed_web.py').is_file()
assert (board_source / 'contracts/transit-board-v1.openapi.json').is_file()
manifests = {Path('package.json')}
for pattern in yaml.safe_load((source / 'pnpm-workspace.yaml').read_text())['packages']:
    assert isinstance(pattern, str) and not pattern.startswith('!'), 'review changed workspace selection'
    manifests.update((path / 'package.json').relative_to(source)
                     for path in source.glob(pattern) if (path / 'package.json').is_file())
dependency_files = {path.relative_to(dependency_source) for path in dependency_source.rglob('*') if path.is_file()}
assert dependency_files == manifests | {Path('pnpm-lock.yaml'), Path('pnpm-workspace.yaml')}, (
    'frontend dependency source must preserve every runtime workspace manifest and only package-manager inputs',
    dependency_files ^ (manifests | {Path('pnpm-lock.yaml'), Path('pnpm-workspace.yaml')}),
)
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
