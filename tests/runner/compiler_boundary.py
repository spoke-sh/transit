"""Transit supplies runtime/frontend APIs and must not import its compiler consumer."""
from pathlib import Path
import re
import subprocess
from runner.paths import ROOT

assert not (ROOT / 'third_party/transitc').exists(), 'Compiler sources belong in transitc'
assert not (ROOT / 'packages/zig/transit-compiler').exists(), 'Remove compiler adapters from Transit'
for name in subprocess.check_output(['git', 'ls-files', '-z', '--', 'apps', 'packages', 'build'], cwd=ROOT, text=True).split('\0'):
    if not name:
        continue
    path = ROOT / name
    if path.suffix in {'.zon', '.zig'}:
        text = path.read_text()
        assert not re.search(r'@import\("(?:transit_compiler|transit_workspace|transitc_[^" ]*)"\)|\.transitc?_(?:compiler|workspace)\s*=', text), path
for path in [ROOT / 'build.zig.zon', ROOT / 'flake.nix', ROOT / 'flake.lock']:
    assert 'third_party/transitc' not in path.read_text() and 'spoke-sh/transitc' not in path.read_text(), path
print('Compiler boundary: Transit has no vendored or build dependency on transitc')
