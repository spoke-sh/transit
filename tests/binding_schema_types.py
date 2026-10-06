#!/usr/bin/env python3
"""Qualify recursive host declarations with the pinned TypeScript compiler."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bindings'))
from schema_types import declarations


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
    source = declarations('Tree', schema) + '\n' + declarations('Other', second) + '''
const leaf: Tree = {value: {integer: "18446744073709551615"}, children: []};
const root: Tree = {value: {flag: true}, children: [leaf], parent: null};
const other: Other = "yes";
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
        subprocess.run(['vp', 'exec', 'tsc', '--project', str(path / 'tsconfig.json')], cwd=ROOT, check=True)
    print('Recursive host declarations preserve nested shapes and root-local references.')


if __name__ == '__main__':
    run()
