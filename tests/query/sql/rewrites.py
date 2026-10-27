"""Check complete Lean proofs; omissions and sorry axioms fail qualification."""
from runner.paths import ROOT
from pathlib import Path
import re
import subprocess

source = ROOT / 'contracts/sql/FuzeRewrite.lean'
result = subprocess.run(['lean', str(source)], text=True, capture_output=True)
assert result.returncode == 0, result.stdout + result.stderr
assert not result.stderr and 'sorryAx' not in result.stdout and 'warning:' not in result.stdout, result.stdout + result.stderr
names = re.findall(r'^#print axioms (\w+)$', source.read_text(), re.M)
required = {'filter_reorder_preserves_selection', 'projection_pruning_preserves_rows',
            'predicate_pushdown_through_projection', 'pushdown_preserves_downstream_errors'}
assert set(names) == required and all(name in result.stdout for name in names), result.stdout
for axioms in re.findall(r'depends on axioms: \[(.*?)\]', result.stdout):
    assert set(axioms.split(', ')) <= {'propext'}, result.stdout
print(result.stdout, end='')
print(f'Lean: {len(names)} named theorems checked, no sorry axioms or warnings.')
