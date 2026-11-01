"""Independent Document interpretation commitments and reflected schema checks."""
from runner.paths import ROOT
import copy
import hashlib
import json
import struct
import sys

import jsonschema

SCHEMA = ROOT / 'contracts/document-profile-v1.schema.json'
FIXTURE = ROOT / 'packages/zig/transit-protocol/src/fixtures/document-profile-v1.json'


def commitment(value):
    # Deliberately independent byte encoding, including field order and tags.
    result = bytearray(b'transit.document.profile.v1\0')
    result.extend(bytes.fromhex(value['definition']))
    result.append(1)  # JSON
    result.extend(struct.pack('>Q', value['revision']))

    def content(item):
        result.extend(struct.pack('>Q', item['bytes']))
        result.extend(item['sha256'])

    content(value['grammar'])
    for field in ('schema', 'segmenter'):
        result.append(int(value[field] is not None))
        if value[field] is not None:
            content(value[field])
    result.extend((1, 1, 1, 1))  # UTF-8, single frame, binary key/value ordering
    for field in ('input_bytes', 'expanded_bytes', 'expansion_ratio', 'parts',
                  'nodes', 'depth', 'token_bytes', 'attributes', 'diagnostics', 'work'):
        result.extend(struct.pack('>Q', value['limits'][field]))
    return list(hashlib.sha256(result).digest())


def fixture():
    current = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    grammar = b'JSON scalar/event corpus: UTF-8; ordered duplicate keys; exact number lexemes'
    descriptor = dict(definition=current, format='json', revision=2**64-1,
                      grammar=dict(bytes=len(grammar), sha256=list(hashlib.sha256(grammar).digest())),
                      schema=None, segmenter=None, encoding='utf8', framing='single',
                      key_collation='utf8_binary', value_collation='utf8_binary',
                      limits=dict(input_bytes=100*1024*1024, expanded_bytes=100*1024*1024,
                                  expansion_ratio=16, parts=1024, nodes=2**32+1,
                                  depth=128, token_bytes=65536, attributes=256,
                                  diagnostics=1024, work=2**40), digest=[0]*32)
    descriptor['digest'] = commitment(descriptor)
    span = dict(part_id=2**64-1, space='raw', byte_start=2**32, byte_end=2**32+3)
    source = dict(exact=span)
    return dict(descriptor=descriptor,
                part=dict(definition=current, profile=descriptor['digest'], id=2**64-1,
                          bytes=3, sha256=list(hashlib.sha256(b'123').digest()),
                          coverage='redacted', source=source),
                span=span, provenance=dict(derived=dict(source=span, transform=descriptor['grammar'])),
                capture='unknown', validation=dict(revision=7, validator=descriptor['grammar'],
                                                    status='invalid', diagnostics=2))


def main():
    assert sys.argv[1:] in ([], ['--write'], ['--fixture-only'])
    expected = fixture()
    if sys.argv[1:] == ['--fixture-only']:
        FIXTURE.write_text(json.dumps(expected, indent=2) + '\n')
        return
    actual = sys.stdin.buffer.read()
    schema = json.loads(actual)
    jsonschema.Draft202012Validator.check_schema(schema)
    validator = jsonschema.Draft202012Validator(schema)
    validator.validate(expected)
    if sys.argv[1:] == ['--write']:
        SCHEMA.write_bytes(actual)
        FIXTURE.write_text(json.dumps(expected, indent=2) + '\n')
    assert actual == SCHEMA.read_bytes(), 'Document profile schema drift: run just contract::generate'
    assert json.loads(FIXTURE.read_text()) == expected, 'Document profile fixture drift'
    for owner in ('descriptor', 'part'):
        for definition in (None, '0'*64, '0'):
            changed = copy.deepcopy(expected)
            if definition is None:
                del changed[owner]['definition']
            else:
                changed[owner]['definition'] = definition
            assert not validator.is_valid(changed), (owner, definition)
    for owner, field, value in (('descriptor', 'format', 'unspecified'),
                                ('part', 'coverage', 'success'),
                                ('span', 'space', 'wire_or_text'),
                                ('validation', 'status', 'acknowledged')):
        changed = copy.deepcopy(expected)
        changed[owner][field] = value
        assert not validator.is_valid(changed), (owner, field)
    changed = copy.deepcopy(expected)
    changed['descriptor']['effect_permit'] = True
    assert not validator.is_valid(changed)
    print('Document profiles: reflected schema, independent commitment, full-width spans and definition rejection passed.')


if __name__ == '__main__':
    main()
