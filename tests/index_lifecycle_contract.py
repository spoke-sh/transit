"""Independent index declaration commitments and reflected schema checks."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys

import jsonschema

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / 'contracts/index-lifecycle-v1.schema.json'
FIXTURE = ROOT / 'packages/zig/transit-protocol/src/fixtures/index-lifecycle-v1.json'


def commitment(declaration):
    data = bytearray(b'transit.index.declaration.v1\0')
    data.extend(bytes.fromhex(declaration['definition']))

    def number(value):
        data.extend(struct.pack('>Q', value))

    def identity(value):
        scope = value['scope']
        for value in (scope['realm'], scope['resource'], scope['catalog'], value['branch'], value['object']):
            number(value)

    def definition(value):
        identity(value['object'])
        number(value['revision'])
        data.extend(value['digest'])

    identity(declaration['interpretation']['object'])
    number(declaration['interpretation']['revision'])
    definition(declaration['source'])
    number(len(declaration['keys']))
    for key in declaration['keys']:
        number(key['column'])
        data.extend(({'ascending': 1, 'descending': 2}[key['direction']],
                     {'first': 1, 'last': 2}[key['nulls']],
                     {'declared_column': 1}[key['comparison']]))
    number(len(declaration['included']))
    for column in declaration['included']:
        number(column)
    purpose = declaration['purpose']
    if 'acceleration' in purpose:
        data.append(0)
    else:
        data.append(1)
        constraint = purpose['constraint']
        definition(constraint['interpretation'])
        data.extend(({'primary_key': 1, 'unique': 2}[constraint['kind']],
                     {'forbidden': 1, 'distinct': 2, 'equal': 3}[constraint['nulls']]))
    return list(hashlib.sha256(data).digest())


def fixture():
    current = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    scope = dict(realm=1, resource=7, catalog=2**64-1)
    source = dict(object=dict(scope=scope, branch=1, object=42), revision=3, digest=[23]*32)
    index = dict(object=dict(scope=scope, branch=1, object=2**64-2), revision=1, digest=[0]*32)
    declaration = dict(definition=current, interpretation=index, source=source,
                       keys=[dict(column=11, direction='ascending', nulls='last', comparison='declared_column'),
                             dict(column=19, direction='descending', nulls='first', comparison='declared_column')],
                       included=[23], purpose=dict(acceleration={}))
    index['digest'] = commitment(declaration)
    constrained = copy.deepcopy(declaration)
    constrained['interpretation']['revision'] = 2
    constrained['purpose'] = dict(constraint=dict(
        interpretation=dict(object=dict(scope=scope, branch=1, object=2**64-3), revision=1, digest=[41]*32),
        kind='unique', nulls='distinct'))
    constrained['interpretation']['digest'] = commitment(constrained)
    base = dict(interpretation=source, manifest=None, checkpoint_lsn=0,
                accepted=dict(partition=8, next_lsn=11))
    build = dict(definition=current, declaration=index, generation=2**64-1,
                 operation=dict(scope=scope, principal=0, operation=101), base=base)
    covered = copy.deepcopy(base)
    covered['accepted']['next_lsn'] = 13
    coverage = dict(build=build, source=covered, root=dict(bytes=8192, sha256=[15]*32))
    return dict(declaration=declaration, constraint_declaration=constrained,
                progress=dict(build=build, phase='complete', through=dict(partition=8, next_lsn=13)),
                coverage=coverage,
                publication=dict(definition=current, operation=dict(scope=scope, principal=0, operation=102),
                                 coverage=coverage, expected=dict(bytes=256, sha256=[21]*32)))


def main():
    assert sys.argv[1:] in ([], ['--write']), 'unsupported arguments'
    actual = sys.stdin.buffer.read()
    schema = json.loads(actual)
    jsonschema.Draft202012Validator.check_schema(schema)
    expected_fixture = fixture()
    validator = jsonschema.Draft202012Validator(schema)
    validator.validate(expected_fixture)
    if sys.argv[1:] == ['--write']:
        SCHEMA.write_bytes(actual)
        FIXTURE.write_text(json.dumps(expected_fixture, indent=2) + '\n')
    assert actual == SCHEMA.read_bytes(), 'Index lifecycle schema drift: run just contract::generate'
    assert json.loads(FIXTURE.read_text()) == expected_fixture, 'Index fixture drift: run just contract::generate'
    for path in (('declaration',), ('constraint_declaration',), ('progress', 'build'),
                 ('coverage', 'build'), ('publication',), ('publication', 'coverage', 'build')):
        for value in (None, '0'*64):
            changed = copy.deepcopy(expected_fixture)
            item = changed
            for name in path:
                item = item[name]
            if value is None:
                del item['definition']
            else:
                item['definition'] = value
            assert not validator.is_valid(changed), f'incompatible definition accepted at {path}'
    # Nonempty/unique keys and the combined column bound are domain checks in
    # the Zig owner; the generic reflected schema supplies per-sequence maxima.
    for replacement in ([expected_fixture['declaration']['keys'][0]] * 129,):
        changed = copy.deepcopy(expected_fixture)
        changed['declaration']['keys'] = replacement
        assert not validator.is_valid(changed), 'unbounded key definition accepted'
    for field, value in (('comparison', 'physical_bytes'), ('direction', 'sideways'), ('nulls', 'drop')):
        changed = copy.deepcopy(expected_fixture)
        changed['declaration']['keys'][0][field] = value
        assert not validator.is_valid(changed), f'unsupported key semantics accepted: {field}'
    for field in ('predicate', 'collation_override', 'physical_encoding'):
        changed = copy.deepcopy(expected_fixture)
        changed['declaration'][field] = 'unsupported'
        assert not validator.is_valid(changed), f'undeclared index extension accepted: {field}'
    print('Index lifecycle: reflected schema, independent commitments, exact definitions and bounded keys passed.')


if __name__ == '__main__':
    main()
