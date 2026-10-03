"""Public diagnostics come from the shared Zig diagnostic contract."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = ROOT / 'contracts/diagnostic-v1.schema.json'


def ts(schema):
    if '$ref' in schema:
        return schema['$ref'].rsplit('/', 1)[-1]
    if 'const' in schema:
        return json.dumps(schema['const'])
    if 'oneOf' in schema or 'anyOf' in schema:
        return '(' + ' | '.join(ts(item) for item in schema.get('oneOf', schema.get('anyOf'))) + ')'
    if 'enum' in schema:
        return ' | '.join(json.dumps(item) for item in schema['enum'])
    kind = schema['type']
    if kind in ('integer', 'number'):
        return 'number'
    if kind in ('null', 'boolean', 'string'):
        return kind
    if kind == 'array':
        return f"Array<{ts(schema['items'])}>"
    if kind == 'object':
        return '{ ' + '; '.join(f"{json.dumps(key)}{'' if key in schema.get('required', []) else '?'}: {ts(value)}"
                                for key, value in schema.get('properties', {}).items()) + ' }'
    raise ValueError(kind)


def clean(value):
    if isinstance(value, list):
        return [clean(item) for item in value]
    if isinstance(value, dict):
        return {key: clean(item) for key, item in value.items() if not key.startswith('x-transit-')}
    return value


schema = {'$schema': 'https://json-schema.org/draft/2020-12/schema', '$id': 'https://transit.invalid/diagnostic-v1', '$defs': {'Diagnostic': json.loads(SCHEMA.read_text())}}
outputs = {
    'types.ts': '// Generated from owning Zig diagnostic type; do not edit.\n'
                + '\n'.join(f'export type {name} = {ts(value)};' for name, value in schema['$defs'].items()) + '\n',
    'schema.json': json.dumps(clean(schema), separators=(',', ':')) + '\n',
}
for name, content in outputs.items():
    target = Path(__file__).parent / 'src' / name
    if '--check' in sys.argv:
        assert target.read_text() == content, f'diagnostic declaration drift: {target}'
    else:
        target.write_text(content)
