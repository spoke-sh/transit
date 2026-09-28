"""Check the committed application schema against the actual public Zig exporter."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
actual = json.loads(subprocess.check_output([sys.argv[1], 'schema']))
expected = json.loads((ROOT / 'packages/zig/transit-station-app/api/application.schema.json').read_text())
assert actual == expected, 'application public schema drift'
print('Application schema matches the owning Zig types.')
