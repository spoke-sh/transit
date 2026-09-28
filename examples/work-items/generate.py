"""Generate the example proposal with the actual compiler; artifacts grant no rights."""
from pathlib import Path
import subprocess
import sys

here = Path(__file__).resolve().parent
compiler = Path(sys.argv[1]).resolve()
generated = subprocess.check_output([str(compiler), 'module', str(here/'interface.sql')], text=True)
target = here/'web/src/proposal.generated.ts'
if '--check' in sys.argv:
    assert target.read_text() == generated, 'work-item generated proposal drift'
else:
    target.write_text(generated)
