"""Reflect the Table service independently of CLI, SDK and Board adapters."""
import json
from pathlib import Path
import sys
import jsonschema

root = Path(__file__).resolve().parents[1]
raw = sys.stdin.buffer.read()
schema = json.loads(raw)
jsonschema.Draft202012Validator.check_schema(schema)
path = root / 'contracts/table-service-v1.schema.json'
if '--write' in sys.argv:
    path.write_bytes(raw)
else:
    assert path.read_bytes() == raw, 'Table service schema drift: just contract::table-service-generate'

def refs(value):
    if isinstance(value, dict):
        if '$ref' in value:
            target = schema
            assert value['$ref'].startswith('#/')
            for segment in value['$ref'][2:].split('/'):
                target = target[segment.replace('~1', '/').replace('~0', '~')]
            assert isinstance(target, dict)
        for child in value.values():
            refs(child)
    elif isinstance(value, list):
        for child in value:
            refs(child)

refs(schema)
for name in ('Request', 'Response', 'Limits'):
    jsonschema.Draft202012Validator({**schema, '$ref': '#/$defs/' + name})
request = schema['$defs']['Request']
while '$ref' in request:
    pointer = request['$ref']
    request = schema
    for segment in pointer[2:].split('/'):
        request = request[segment.replace('~1', '/').replace('~0', '~')]
assert 'definition' in request['required']
assert 'proof' in request['required']
assert request['additionalProperties'] is False
print('Table service: owning reflection, mandatory identity/proof and local schema references passed.')
