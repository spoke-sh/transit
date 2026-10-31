"""Reflected contract drift and independent browser response validation."""
import copy
import json
import sys
import jsonschema
from runner.paths import ROOT

raw = sys.stdin.read()
schema = json.loads(raw)
jsonschema.Draft202012Validator.check_schema(schema)
path = ROOT / 'contracts/browser-v1.schema.json'
if '--write' in sys.argv:
    path.write_text(raw)
else:
    assert path.read_text() == raw, 'browser schema drift; regenerate from browser-contract'

def validate(name, value):
    jsonschema.validate(value, dict(schema, **{'$ref':'#/$defs/'+name}))

validate('Session', dict(authenticated=False, provider=None, identity=None, bound=False))
value = dict(type='snapshot', view='catalog', columns=[dict(name='id', type={'uint64':{}}, nullable=False)], rows=[['9007199254740993']], attribution=dict(resource_object='2001', publication_revision='1', source_object='7', source_revision='1', source_partition='9', source_next_lsn='12', watermark_lsn='11', row_count='1', retention='current_cut_unpinned', complete=True))
validate('Snapshot', value)
for field in ('source_next_lsn','row_count'):
    invalid=copy.deepcopy(value)
    invalid['attribution'][field]=12
    try:
        validate('Snapshot',invalid)
    except jsonschema.ValidationError:
        pass
    else:
        raise AssertionError('numeric attribution accepted: '+field)
print('Browser reflected schema and independent response controls passed')
