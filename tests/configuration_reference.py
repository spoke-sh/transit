"""Keep the configuration reference and input schema tied to the typed registry."""
import json
from pathlib import Path
import sys
import jsonschema

raw = sys.stdin.buffer.read()
value = json.loads(raw)
jsonschema.Draft202012Validator.check_schema(value['schema'])
path = Path(__file__).resolve().parents[1] / 'contracts/configuration-settings-v1.json'
if '--write' in sys.argv:
    path.write_bytes(raw)
else:
    assert path.read_bytes() == raw, 'Settings registry drift: just contract::configuration-generate'
names = [entry['name'] for entry in value['settings']]
assert len(set(names)) == len(names)
assert any(entry['session_mutable'] for entry in value['settings'])
assert all(entry['owner'] and entry['description'] for entry in value['settings'])
print('Configuration registry: generated keys, types, bounds, defaults, and ownership agree.')
