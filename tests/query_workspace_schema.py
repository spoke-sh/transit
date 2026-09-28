"""Query owner and Board's transport reflect the same host contract."""
import json
from pathlib import Path
import subprocess
import sys
import jsonschema

root = Path(__file__).resolve().parents[1]
actual = json.loads(subprocess.check_output([sys.argv[1]], text=True))
expected = json.loads((root/'packages/zig/transit-query/api/workspace.schema.json').read_text())
assert actual == expected, 'query workspace schema drift'
jsonschema.Draft202012Validator.check_schema(actual)
board = json.loads((root/'contracts/transit-board-v1.openapi.json').read_text())['components']['schemas']
for native, transport in [('Request', 'UnifiedQueryRequest'), ('Response', 'UnifiedQueryResponse')]:
    assert actual['$defs'][native] == board[transport], f'{native}: Board diverged from the query owner'
print('Query workspace: owning reflection, schema validity and Board transport agreement passed.')
