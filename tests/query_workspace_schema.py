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
validator = jsonschema.Draft202012Validator(actual['$defs']['Request'])
# Optional bindings preserve existing ordinary compile requests. They remain
# exact neutral scalars, never JavaScript-width numeric values or extra fields.
for request in ({'compile': {'sql': 'SELECT value FROM items'}},
                {'compile': {'sql': 'SELECT value FROM items', 'parameters': None}},
                {'compile': {'sql': 'SELECT value FROM items LIMIT $1', 'parameters': [{'uint64': '18446744073709551615'}]}}):
    validator.validate(request)
for parameters in ([{'uint64': 18446744073709551615}], [{'int64': '1', 'utf8': '1'}], [None], '1'):
    assert list(validator.iter_errors({'compile': {'sql': 'SELECT value FROM items', 'parameters': parameters}}))
print('Query workspace: owning reflection, schema validity and Board transport agreement passed.')
