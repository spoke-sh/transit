"""Render reflected host schemas as TypeScript, including recursive references."""
import json
import re


def ts(schema, references=None):
    if '$ref' in schema:
        reference = schema['$ref']
        if references is None or reference not in references:
            raise ValueError(f'Unresolved host schema reference {reference}')
        return references[reference]
    if 'const' in schema:
        return json.dumps(schema['const'])
    if 'anyOf' in schema or 'oneOf' in schema:
        return '(' + ' | '.join(ts(item, references) for item in schema.get('anyOf', schema.get('oneOf'))) + ')'
    if 'enum' in schema:
        return ' | '.join(json.dumps(item) for item in schema['enum'])
    kind = schema['type']
    if kind in ('integer', 'number'):
        return 'number'
    if kind in ('null', 'boolean', 'string'):
        return kind
    if kind == 'array':
        return f"Array<{ts(schema['items'], references)}>"
    if kind == 'object':
        return '{ ' + '; '.join(f"{json.dumps(k)}{'' if k in schema.get('required', []) else '?'}: {ts(v, references)}" for k, v in schema.get('properties', {}).items()) + ' }'
    raise ValueError(f'Unsupported host schema type {kind}')


def declarations(name, schema):
    """Each independently validated root owns its local JSON Pointer namespace."""
    definitions = schema.get('$defs', {})
    for identifier in (name, *definitions):
        if re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', identifier) is None:
            raise ValueError(f'Invalid reflected type name {identifier}')
    references = {f'#/$defs/{key}': f'{name}_{key}' for key in definitions}
    lines = [f'type {name}_{key} = {ts(value, references)};' for key, value in definitions.items()]
    lines.append(f'export type {name} = {ts(schema, references)};')
    return '\n'.join(lines)
