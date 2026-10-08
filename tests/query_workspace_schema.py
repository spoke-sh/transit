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
    assert json.dumps(actual['$defs'][native]).replace(f'#/$defs/{native}/', '#/owner/') == json.dumps(board[transport]).replace(f'#/components/schemas/{transport}/', '#/owner/'), f'{native}: Board diverged from the query owner'
validator = jsonschema.Draft202012Validator({**actual, '$ref': '#/$defs/Request'})
# Optional bindings preserve existing ordinary compile requests. They remain
# exact neutral scalars, never JavaScript-width numeric values or extra fields.
for request in ({'compile': {'sql': 'SELECT value FROM items'}},
                {'compile': {'sql': 'SELECT value FROM items', 'parameters': None}},
                {'compile': {'sql': 'SELECT value FROM items LIMIT $1', 'parameters': [{'unsigned': '18446744073709551615'}]}}):
    validator.validate(request)
for parameters in ([{'unsigned': 18446744073709551615}], [{'signed': '1', 'utf8': '1'}], [None], '1'):
    assert list(validator.iter_errors({'compile': {'sql': 'SELECT value FROM items', 'parameters': parameters}}))
print('Query workspace: owning reflection, schema validity and Board transport agreement passed.')

# Every recursive reference resolves inside its complete enclosing document.
def check_refs(value, document):
    if isinstance(value, dict):
        if '$ref' in value:
            pointer = value['$ref']
            assert pointer.startswith('#/'), pointer
            target = document
            for segment in pointer[2:].split('/'):
                target = target[segment.replace('~1', '/').replace('~0', '~')]
            assert isinstance(target, dict)
        for child in value.values(): check_refs(child, document)
    elif isinstance(value, list):
        for child in value: check_refs(child, document)
check_refs(actual, actual)
whole_board = {'components': {'schemas': board}}
check_refs(whole_board, whole_board)
print('Recursive query and Board references resolve at their own document locations.')
