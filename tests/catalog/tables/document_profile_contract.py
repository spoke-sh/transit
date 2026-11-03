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
CONTAINER_FIXTURE = FIXTURE.with_name('document-profile-container-v1.json')


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


def container_commitment(profile, root, parts, relationships):
    """Independent wire commitment; no production encoder is used."""
    out = bytearray(b'transit.document.container.v1\0')
    definition = bytes.fromhex(parts[0]['definition'])
    out.extend(definition)
    out.extend(profile)
    def number(value):
        out.extend(struct.pack('>Q', value))
    def content(value):
        number(value['bytes'])
        out.extend(value['sha256'])
    def optional_content(value):
        out.append(int(value is not None))
        if value is not None:
            content(value)
    def span(value):
        number(value['part_id'])
        out.append({'raw': 1, 'decoded': 2, 'derived': 3}[value['space']])
        number(value['byte_start'])
        number(value['byte_end'])
    def part(value):
        out.extend(bytes.fromhex(value['definition']))
        out.extend(value['profile'])
        number(value['id'])
        number(value['bytes'])
        out.extend(value['sha256'])
        out.append({'prefix': 1, 'complete': 2, 'redacted': 3}[value['coverage']])
        source = value['source']
        out.append(0 if source is None else 1 if 'exact' in source else 2)
        if source is not None:
            if 'exact' in source:
                span(source['exact'])
            else:
                span(source['derived']['source'])
                content(source['derived']['transform'])
    number(root)
    for value in parts:
        out.append(1)
        part(value)
    for edge in relationships:
        out.extend((2, {'contains': 1, 'references': 2, 'derived_from': 3,
                        'response_to': 4, 'attachment': 5}[edge['kind']]))
        number(edge['from'])
        if 'local' in edge['to']:
            out.append(1)
            number(edge['to']['local'])
        else:
            out.append(2)
            reference = edge['to']['external']
            revision = reference['revision']
            target = revision['target']
            partition = target['partition']
            interpretation = partition['interpretation']
            obj = interpretation['object']
            out.extend(bytes.fromhex(partition['definition']))
            for value in (obj['scope']['realm'], obj['scope']['resource'], obj['scope']['catalog'],
                          obj['branch'], obj['object'], interpretation['revision']):
                number(value)
            out.extend(interpretation['digest'])
            number(partition['partition'])
            out.extend(target['document'])
            number(revision['revision'])
            out.extend(revision['manifest'])
            number(reference['ordinal'])
            part(reference['part'])
        optional_content(edge['label'])
    out.append(3)
    for value in (len(parts), len(relationships), sum(v['bytes'] for v in parts),
                  sum(v['coverage'] == 'complete' for v in parts),
                  sum(v['coverage'] == 'redacted' for v in parts),
                  sum(v['coverage'] == 'prefix' for v in parts)):
        number(value)
    return list(hashlib.sha256(out).digest())


def candidate_commitment(value):
    out = bytearray(b'transit.document.candidate.v1\0')
    out.extend(bytes.fromhex(value['definition']))

    def number(item):
        out.extend(struct.pack('>Q', item))

    def target(item):
        partition = item['partition']
        interpretation = partition['interpretation']
        obj = interpretation['object']
        out.extend(bytes.fromhex(partition['definition']))
        for field in (obj['scope']['realm'], obj['scope']['resource'], obj['scope']['catalog'],
                      obj['branch'], obj['object'], interpretation['revision']):
            number(field)
        out.extend(interpretation['digest'])
        number(partition['partition'])
        out.extend(item['document'])

    target(value['target'])
    operation = value['operation']
    for item in (operation['scope']['realm'], operation['scope']['resource'],
                 operation['scope']['catalog'], operation['principal'], operation['operation']):
        number(item)
    base = value['base']
    out.append(int(base is not None))
    if base is not None:
        target(base['target'])
        number(base['revision'])
        out.extend(base['manifest'])
    out.extend(value['interpretation']['digest'])
    source = value['source']
    out.extend(bytes.fromhex(source['definition']))
    out.extend(source['profile'])
    for field in ('root', 'parts', 'relationships', 'retained_bytes',
                  'complete_parts', 'redacted_parts', 'prefix_parts'):
        number(source[field])
    out.extend(source['digest'])
    return list(hashlib.sha256(out).digest())


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
    result = dict(descriptor=descriptor,
                part=dict(definition=current, profile=descriptor['digest'], id=2**64-1,
                          bytes=3, sha256=list(hashlib.sha256(b'123').digest()),
                          coverage='redacted', source=source),
                span=span, provenance=dict(derived=dict(source=span, transform=descriptor['grammar'])),
                capture='unknown', validation=dict(revision=7, validator=descriptor['grammar'],
                                                    status='invalid', diagnostics=2))
    reference = dict(revision=dict(
        target=dict(partition=dict(definition=current, partition=2**32-1,
            interpretation=dict(object=dict(scope=dict(realm=7, resource=9, catalog=2**64-1),
                                            branch=1, object=2**64-2),
                                revision=2**64-1, digest=list(hashlib.sha256(b'interpretation').digest()))),
                    document=list(range(1, 17))),
        revision=2**64-1, manifest=list(hashlib.sha256(b'external manifest').digest())),
        ordinal=2**64-1, part=copy.deepcopy(result['part']))
    relationships = [dict(kind='references', **{'from': 0}, to=dict(local=0), label=None),
                     dict(kind='attachment', **{'from': 0}, to=dict(external=reference), label=descriptor['grammar'])]
    parts = []
    for identity, data, coverage, source in (
        (1, b'', 'complete', None),
        (2**32, b'123', 'prefix', result['provenance']),
        (2**64-1, b'123', 'redacted', result['part']['source'])):
        parts.append(dict(definition=current, profile=descriptor['digest'], id=identity,
                          bytes=len(data), sha256=list(hashlib.sha256(data).digest()),
                          coverage=coverage, source=source))
    result.update(reference=reference, relationships=relationships, container_parts=parts,
                  container=dict(definition=current, profile=descriptor['digest'], root=0,
                                 parts=3, relationships=2, retained_bytes=6, complete_parts=1,
                                 redacted_parts=1, prefix_parts=1,
                                 digest=container_commitment(descriptor['digest'], 0, parts, relationships)))
    result['capabilities'] = dict(descriptor=copy.deepcopy(descriptor), operations=dict(
        parse=True, construct=True, validate_schema=False, edit=False, persist=False,
        query=False, search=False, branch=False, live_transport=False))
    result['candidate'] = dict(definition=current, target=copy.deepcopy(reference['revision']['target']),
        operation=dict(scope=copy.deepcopy(reference['revision']['target']['partition']['interpretation']['object']['scope']),
                       principal=11, operation=2**64-1), base=copy.deepcopy(reference['revision']),
        interpretation=copy.deepcopy(descriptor), source=copy.deepcopy(result['container']), digest=[0]*32)
    result['candidate']['digest'] = candidate_commitment(result['candidate'])
    return result


def main():
    assert sys.argv[1:] in ([], ['--write'], ['--fixture-only'])
    corpus = fixture()
    container = dict(manifest=corpus['container'], parts=corpus.pop('container_parts'),
                     relationships=corpus.pop('relationships'))
    expected = dict(corpus, relationship=container['relationships'][1])
    if sys.argv[1:] == ['--fixture-only']:
        FIXTURE.write_text(json.dumps(expected, indent=2) + '\n')
        CONTAINER_FIXTURE.write_text(json.dumps(container, indent=2) + '\n')
        return
    actual = sys.stdin.buffer.read()
    schema = json.loads(actual)
    jsonschema.Draft202012Validator.check_schema(schema)
    validator = jsonschema.Draft202012Validator(schema)
    validator.validate(expected)
    if sys.argv[1:] == ['--write']:
        SCHEMA.write_bytes(actual)
        FIXTURE.write_text(json.dumps(expected, indent=2) + '\n')
        CONTAINER_FIXTURE.write_text(json.dumps(container, indent=2) + '\n')
    assert actual == SCHEMA.read_bytes(), 'Document profile schema drift: run just contract::generate'
    assert json.loads(FIXTURE.read_text()) == expected, 'Document profile fixture drift'
    assert json.loads(CONTAINER_FIXTURE.read_text()) == container, 'Document container fixture drift'
    for owner in ('descriptor', 'part', 'container', 'candidate'):
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
