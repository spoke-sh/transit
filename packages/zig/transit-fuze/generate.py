"""Write/check logical JSON Schemas reflected from the owning Zig types."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parent / 'api'
schemas = json.load(sys.stdin)
for name, schema in schemas.items():
    assert name in ('type', 'value')
    schema = {'$schema': 'https://json-schema.org/draft/2020-12/schema', **schema}
    data = json.dumps(schema, indent=2) + '\n'
    path = root / f'logical-{name}.schema.json'
    if '--write' in sys.argv:
        root.mkdir(exist_ok=True)
        path.write_text(data)
    elif not path.exists() or path.read_text() != data:
        raise SystemExit('Logical schema drift: run just contract::logical-generate')
print('Logical JSON Schemas match their recursive Zig types.')
