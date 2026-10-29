"""Public types come from the query workspace owner's reflected schema, never UI copies."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = ROOT / 'packages/zig/transit-query/api/workspace.schema.json'


sys.path.insert(0, str(ROOT / "bindings"))
from schema_types import declarations_at


def clean(value):
    if isinstance(value, list):
        return [clean(item) for item in value]
    if isinstance(value, dict):
        return {key: clean(item) for key, item in value.items() if not key.startswith('x-transit-')}
    return value


schema = json.loads(SCHEMA.read_text())
outputs = {
    'types.ts': '// Generated from owning Zig query workspace types; do not edit.\n'
                + declarations_at({f'#/$defs/{name}': (name, value) for name, value in schema['$defs'].items()}),
    'schema.json': json.dumps(clean(schema), separators=(',', ':')) + '\n',
}
for name, content in outputs.items():
    target = Path(__file__).parent / 'src' / name
    if '--check' in sys.argv:
        assert target.read_text() == content, f'query workspace declaration drift: {target}'
    else:
        target.write_text(content)

read_schema = json.loads((ROOT / 'packages/zig/transit-sql-client/api/read.schema.json').read_text())
read_outputs = {
    'read-types.ts': '// Generated from transit-sql-client ReadWorkspace; do not edit.\n'
        + f'export const readDefinition = {json.dumps(read_schema["definition"])} as const;\n'
        + declarations_at({f'#/$defs/{name}': (name, value) for name, value in read_schema['$defs'].items()}),
    'read-schema.json': json.dumps(clean({key: value for key, value in read_schema.items() if key != 'definition'}), separators=(',', ':')) + '\n',
}
for name, content in read_outputs.items():
    target = Path(__file__).parent / 'src' / name
    if '--check' in sys.argv:
        assert target.read_text() == content, f'SQL read declaration drift: {target}'
    else:
        target.write_text(content)
