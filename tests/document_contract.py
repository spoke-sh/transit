"""Independent SDC1/SDR1 encodings and Publication commitments for SDK fixtures."""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-station-document/src/fixtures/changes.json'
REMOTE = FIXTURE.with_name('remote.json')


def dot(value=None):
    value = value or {}
    return struct.pack('<QQ', int(value.get('counter', '0')), int(value.get('replica', '0')))


def string(value):
    return bytes([len(value)]) + value


def scalar(value):
    name, payload = next(iter(value.items()))
    tags = ['null_value', 'boolean', 'signed', 'unsigned', 'float_bits', 'string', 'binary', 'map', 'list', 'text', 'character']
    result = bytes([tags.index(name)])
    if name == 'boolean': result += bytes([payload])
    elif name in ('signed', 'unsigned'): result += struct.pack('<q' if name == 'signed' else '<Q', int(payload))
    elif name == 'float_bits': result += bytes.fromhex(payload)
    elif name in ('string', 'binary'): result += string(payload.encode() if name == 'string' else bytes.fromhex(payload))
    elif name == 'character': result += struct.pack('<I', ord(payload))
    return result


def encode(change):
    result = b'SDC1' + struct.pack('<QQIQQQB', int(change['document']), int(change['epoch']), change.get('type_revision', 1),
        int(change['replica']), int(change.get('previous', '0')), int(change['first']), len(change['operations']))
    for operation in change['operations']:
        name, fields = next(iter(operation.items()))
        result += bytes([['assign', 'remove', 'insert', 'set_element', 'delete_element'].index(name)]) + dot(fields.get('object'))
        if 'field' in fields: result += string(fields['field'].encode())
        if 'element' in fields: result += dot(fields['element'])
        if name == 'insert': result += dot(fields.get('after'))
        if name in ('assign', 'remove', 'set_element'):
            observed = fields.get('observed', [])
            result += bytes([len(observed)]) + b''.join(dot(d) for d in observed)
        if 'value' in fields: result += scalar(fields['value'])
    return result


def commitment(data):
    chain = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x53444301, len(data))).digest()
    for index, offset in enumerate(range(0, len(data), 256)):
        chunk = data[offset:offset+256]
        chain = hashlib.sha256(b'\1' + chain + struct.pack('<IH', index, len(chunk)) + chunk).digest()
    return {'format': 0x53444301, 'length': len(data), 'digest': list(chain)}


def generate():
    def assignment(field, value, **kwargs): return {'assign': {'field': field, 'value': value, **kwargs}}
    def identity(counter, replica='1'): return {'counter': str(counter), 'replica': str(replica)}
    common = {'document': str(2**64-1), 'epoch': '1', 'type_revision': 1, 'replica': '1', 'previous': '0', 'first': '1'}
    variants = [
        ('scalars', {**common, 'operations': [assignment('null', {'null_value': {}}), assignment('boolean', {'boolean': True}),
            assignment('minimum', {'signed': str(-(2**63))}), assignment('maximum', {'unsigned': str(2**64-1)}),
            assignment('negative-zero', {'float_bits': '0000000000000080'}), assignment('utf8', {'string': 'café é 🙂'}),
            assignment('binary', {'binary': '00ff80'}), assignment('empty', {'string': ''})]}),
        ('nested', {**common, 'operations': [assignment('map', {'map': {}}), assignment('inner', {'null_value': {}}, object=identity(1)),
            assignment('list', {'list': {}}), {'insert': {'object': identity(3), 'value': {'binary': ''}}},
            assignment('text', {'text': {}}), {'insert': {'object': identity(5), 'value': {'character': '🙂'}}},
            {'insert': {'object': identity(5), 'after': identity(6), 'value': {'character': 'e'}}},
            {'insert': {'object': identity(5), 'after': identity(7), 'value': {'character': '́'}}}]}),
        ('resolve-delete', {**common, 'replica': str(2**64-1), 'first': '10', 'operations': [
            assignment('title', {'string': 'resolved'}, observed=[identity(1), identity(1, 2)]),
            {'remove': {'field': 'map', 'observed': [identity(1)]}},
            {'set_element': {'object': identity(3), 'element': identity(4), 'observed': [identity(4)], 'value': {'unsigned': '0'}}},
            {'delete_element': {'object': identity(5), 'element': identity(6)}}]}),
    ]
    fixtures = []
    for name, change in variants:
        wire = encode(change)
        fixtures.append({'name': name, 'change': change, 'wire_hex': wire.hex(), 'spec': commitment(wire)})
    reference = {'resource': 2**53-1, 'document': str(2**64-1), 'epoch': '3', 'type_revision': 2**32-1, 'revision': str(2**64-1)}
    wire = b'SDR1' + struct.pack('<QQQIQ', reference['resource'], int(reference['document']), int(reference['epoch']), reference['type_revision'], int(reference['revision']))
    return json.dumps({'changes': fixtures, 'reference': reference, 'reference_hex': wire.hex()}, ensure_ascii=False, indent=2) + '\n'


def remote():
    change = json.loads(generate())['changes'][0]
    spec = change['spec']
    request = b'SDQ1' + struct.pack('<QQQQIQQII', 2**53-1, 2**64-1, 2**64-1, 1, 1, 1,
        2**64-1, spec['format'], spec['length']) + bytes(spec['digest'])
    basis = b'SDR1' + struct.pack('<QQQIQ', 7, 2**64-1, 1, 1, 42)
    reply = b'SDO1' + struct.pack('<BBQ', 1, 0, 2**63+17) + basis
    route = b'SDT1' + struct.pack('<QQQQ', 2, 3, 17, 2**64-1) + request
    call = b'SDW1' + struct.pack('<QQQ', 2, 7, 2**64-1) + request
    assert (len(request), len(reply), len(route), len(call)) == (96, 54, 132, 124)
    return json.dumps({'change_hex': change['wire_hex'], 'request_hex': request.hex(),
        'reply_hex': reply.hex(), 'route_hex': route.hex(), 'call_hex': call.hex()}, indent=2) + '\n'


if __name__ == '__main__':
    if sys.argv[1:] == ['--write']:
        FIXTURE.write_text(generate())
        REMOTE.write_text(remote())
    elif sys.argv[1:] or FIXTURE.read_text() != generate() or REMOTE.read_text() != remote():
        raise SystemExit('Document fixtures differ; review and regenerate explicitly')
    print('Document fixtures: independent changes, reads, submission/reply routes and commitments passed.')
