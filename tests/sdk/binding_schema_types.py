#!/usr/bin/env python3
"""Qualify recursive host declarations with the pinned TypeScript compiler."""
from runner.paths import ROOT
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(ROOT / 'bindings'))
from schema_types import declarations, declarations_at


def run():
    schema = {
        '$ref': '#/$defs/T0',
        '$defs': {
            'T0': {'type': 'object', 'required': ['value', 'children'], 'properties': {
                'value': {'$ref': '#/$defs/T1'},
                'children': {'type': 'array', 'items': {'$ref': '#/$defs/T0'}},
                'parent': {'anyOf': [{'$ref': '#/$defs/T0'}, {'type': 'null'}]}}},
            'T1': {'oneOf': [
                {'type': 'object', 'required': ['integer'], 'properties': {'integer': {'type': 'string'}}},
                {'type': 'object', 'required': ['flag'], 'properties': {'flag': {'type': 'boolean'}}}]}}}
    second = {'$ref': '#/$defs/T0', '$defs': {'T0': {'enum': ['yes', 'no']}}}
    for name, invalid in [
        ('Invalid', {'$ref': '#/$defs/Unknown'}),
        ('Invalid', {'$ref': 'https://example.invalid/unknown'}),
        ('Bad; injected', {'type': 'string'}),
        ('Invalid', {'$defs': {'bad-name': {'type': 'string'}}, '$ref': '#/$defs/bad-name'}),
    ]:
        try:
            declarations(name, invalid)
        except ValueError:
            pass
        else:
            raise AssertionError(f'Accepted invalid reference or identifier: {invalid}')
    embedded = json.loads(json.dumps(schema).replace('#/$defs/', '#/components/schemas/Tree/$defs/'))
    embedded_second = json.loads(json.dumps(second).replace('#/$defs/', '#/components/schemas/Other/$defs/'))
    embedded_types = declarations_at({'#/components/schemas/Tree': ('EmbeddedTree', embedded),
                                      '#/components/schemas/Other': ('EmbeddedOther', embedded_second)})
    for invalid in [{'$ref': '#/$defs/T0'}, {'$ref': '#/components/schemas/Other/$defs/T0'}]:
        try:
            declarations_at({'#/components/schemas/Tree': ('EmbeddedTree', invalid)})
        except ValueError:
            pass
        else:
            raise AssertionError('Accepted a reference outside the selected enclosing document')
    source = embedded_types + declarations('Tree', schema) + '\n' + declarations('Other', second) + '''
const leaf: Tree = {value: {integer: "18446744073709551615"}, children: []};
const root: Tree = {value: {flag: true}, children: [leaf], parent: null};
const other: Other = "yes";
const embedded: EmbeddedTree = root;
const embeddedOther: EmbeddedOther = other;
// @ts-expect-error Embedded reference graphs must retain distinct root types.
const invalidEmbedded: EmbeddedOther = embedded;
void [embeddedOther, invalidEmbedded];
// @ts-expect-error Wide integers retain their string wire representation.
const invalidInteger: Tree = {value: {integer: 2}, children: []};
// @ts-expect-error A child must satisfy the same recursive shape.
const invalidChild: Tree = {value: {flag: false}, children: [{value: {flag: true}}]};
// @ts-expect-error Definition names cannot collide between roots.
const invalidRoot: Other = root;
void [leaf, root, other, invalidInteger, invalidChild, invalidRoot];
'''
    with tempfile.TemporaryDirectory(prefix='transit-binding-types-') as temporary:
        path = Path(temporary)
        (path / 'fixture.ts').write_text(source)
        (path / 'tsconfig.json').write_text(json.dumps({
            'compilerOptions': {'strict': True, 'noEmit': True, 'types': [],
                                'target': 'ES2022', 'skipLibCheck': True},
            'files': ['fixture.ts'],
        }))
        # The client package declares the pinned compiler. The workspace root
        # does not; invoking there can accidentally use stale installed tools.
        subprocess.run(['vp', 'exec', '--filter', '@transit/client', 'tsc', '--project',
                        str(path / 'tsconfig.json')], cwd=ROOT, check=True)
    print('Recursive host declarations preserve nested shapes and root-local references.')


if __name__ == '__main__':
    run()
