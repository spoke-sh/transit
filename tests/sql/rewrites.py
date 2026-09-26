"""Check complete Lean proofs; omissions and sorry axioms fail qualification."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'contracts/sql/FuzeRewrite.lean'
result = subprocess.run(['lean', str(source)], text=True, capture_output=True)
assert result.returncode == 0, result.stdout + result.stderr
assert not result.stderr and 'sorryAx' not in result.stdout and 'warning:' not in result.stdout, result.stdout + result.stderr
names = re.findall(r'^#print axioms (\w+)$', source.read_text(), re.M)
assert names and all(name in result.stdout for name in names), result.stdout
print(result.stdout, end='')
print(f'Lean: {len(names)} named theorems checked, no sorry axioms or warnings.')
