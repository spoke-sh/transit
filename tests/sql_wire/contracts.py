"""Independent Python framing/authentication oracle for the database adapters."""
import argparse
import base64
import hashlib
import hmac
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def authentication():
    password = 'pencil'
    salt = bytes(range(16))
    random = bytes(range(18))
    rounds = 4096
    b64 = lambda value: base64.b64encode(value).decode()
    salted = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, rounds)
    client_key = hmac.digest(salted, b'Client Key', 'sha256')
    stored_key = hashlib.sha256(client_key).digest()
    server_key = hmac.digest(salted, b'Server Key', 'sha256')
    nonce = 'rOprNGfwEbeRWgbNEkqO' + b64(random)
    bare = 'n=,r=rOprNGfwEbeRWgbNEkqO'
    challenge = f'r={nonce},s={b64(salt)},i={rounds}'
    without_proof = f'c=biws,r={nonce}'
    message = f'{bare},{challenge},{without_proof}'.encode()
    signature = hmac.digest(stored_key, message, 'sha256')
    proof = bytes(a ^ b for a, b in zip(client_key, signature))
    return dict(password=password, salt=list(salt), iterations=rounds, stored_key=list(stored_key),
        server_key=list(server_key), random=list(random), first='n,,'+bare, challenge=challenge,
        final=without_proof+',p='+b64(proof), server_final='v='+b64(hmac.digest(server_key, message, 'sha256')))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    fixtures = {'transit-sql-gateway/src/fixtures/auth.json': authentication()}
    fixtures['transit-sql-gateway/src/fixtures/records.json'] = records()
    fixtures['transit-sql-gateway/src/fixtures/controls.json'] = controls()
    for protocol in ('postgres', 'mysql'):
        fixtures[f'transit-{protocol}/src/fixtures/scalars.json'] = scalars(protocol)
    for name, fixture in fixtures.items():
        path = ROOT / 'packages/zig' / name
        content = json.dumps(fixture, indent=2, ensure_ascii=False) + '\n'
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        else:
            assert path.read_text() == content, f'{name}: fixture drift; review before --write'
    print('SQL wire: independent SCRAM derivation and PostgreSQL/MySQL scalar bytes checked.')


def length(n):
    if n < 251:
        return bytes([n])
    if n < 65536:
        return b'\xfc' + struct.pack('<H', n)
    if n < 16777216:
        return b'\xfd' + n.to_bytes(3, 'little')
    return b'\xfe' + struct.pack('<Q', n)


def records():
    definition = hashlib.sha256(b'transit.native.v1.sql-wire-parameters.2026-10-13').digest()
    def record(magic, value, fields):
        encoded = magic.encode() + definition
        for name, layout in fields:
            item = value[name]
            if isinstance(layout, dict):
                encoded += bytes([layout[item]])
            elif layout == 'bytes':
                encoded += bytes(item)
            else:
                encoded += struct.pack('<' + layout, item)
        return dict(value=value, bytes=encoded.hex())
    head = dict(configuration=[7]*32, operations=42, unsettled=0, used_bytes=2**64-2,
                reserved_bytes=0, operation_quota=2**64-1, byte_quota=2**64-1,
                pending_quota=16, active=0, sequence=1)
    operation = dict(id=7, nonce=list(range(16)), resource=9, catalog=2**64-1, owner=11,
                     phase='reserved', intent_length=0, intent_digest=[0]*32, records=0,
                     staging=0, pending=0, published=0, pending_sequence=0, input=0,
                     stored_bytes=0, reservation=1024, cancel=0, reconcile=0, blocked=0,
                     summary='none', matched=0, changed=0)
    terminal = dict(kind='dml', identity=[13]*32, resource=9, principal=11, operation=7,
                    object=99, admitted_input=32, completed_input=33, state='applied',
                    reason=0, matched=2**64-1, changed=2**64-2, actual_object=0, route=2)
    return dict(
        head=record('GSH1', head, [(k, 'bytes' if k == 'configuration' else 'I' if k == 'pending_quota' else 'Q') for k in head]),
        operation=record('GSO1', operation, [(k, {'reserved':1} if k == 'phase' else {'none':0} if k == 'summary' else 'bytes' if k in ('nonce','intent_digest') else 'I' if k == 'intent_length' else 'B' if k in ('cancel','reconcile','blocked') else 'Q') for k in operation]),
        terminal=record('GST1', terminal, [(k, {'dml':2} if k == 'kind' else {'applied':1} if k == 'state' else 'bytes' if k == 'identity' else 'B' if k in ('reason','route') else 'Q') for k in terminal]),
    )


def controls():
    prefix = b'GSQ1' + hashlib.sha256(b'transit.native.v1.sql-wire-parameters.2026-10-13').digest()
    terminal = records()['terminal']
    cases = [
        (dict(begin=dict(nonce=list(range(16)), binding=dict(resource=9, catalog=2**64-1, owner=11))),
         b'\x02' + bytes(range(16)) + struct.pack('<QQQ', 9, 2**64-1, 11)),
        (dict(step_part=dict(target=dict(operation=99, generation=2, record=3),
                             part=dict(offset=128, length=3, bytes=[1, 2, 3]+[0]*125))),
         b'\x09' + struct.pack('<QQQIB', 99, 2, 3, 128, 3) + bytes([1, 2, 3])+bytes(125)),
        (dict(complete=dict(target=dict(operation=7, generation=2), outcome=terminal['value'])),
         b'\x14' + struct.pack('<QQ', 7, 2) + bytes.fromhex(terminal['bytes'])[36:]),
    ]
    return [dict(value=value, bytes=(prefix+encoded).hex()) for value, encoded in cases]


def scalars(protocol):
    cases = []
    for kind, values in (
        ('int64', [-2**63, -32769, -1, 0, 1, 32768, 2**63-1]),
        ('uint64', [0, 1, 10000, 2**63-1, 2**63, 2**64-1]),
        ('float64', [-0.0, 0.0, -1.25, 5e-324, 2.2250738585072014e-308, 1.7976931348623157e308]),
        ('boolean', [False, True]),
        ('utf8', [b'', 'snow ☃ and 列'.encode()] + ([b'a\0b'] if protocol == 'mysql' else [])),
        ('binary', [b'', bytes(range(256))]),
    ):
        for value in values:
            order = '>' if protocol == 'postgres' else '<'
            if kind in ('utf8', 'binary'):
                encoded_value = value.hex()
                binary = value if protocol == 'postgres' else length(len(value)) + value
                text = b'\\x' + value.hex().encode() if kind == 'binary' and protocol == 'postgres' else value
            else:
                encoded_value = str(value).lower()
                text = encoded_value.encode()
                if kind == 'boolean':
                    text = (b't' if value else b'f') if protocol == 'postgres' else (b'1' if value else b'0')
                if kind == 'uint64' and protocol == 'postgres':
                    digits, n = [], value
                    while n:
                        digits.insert(0, n % 10000)
                        n //= 10000
                    binary = struct.pack('>hhHH' + 'H'*len(digits), len(digits), max(len(digits)-1, 0), 0, 0, *digits)
                else:
                    binary = struct.pack(order + {'int64': 'q', 'uint64': 'Q', 'float64': 'd', 'boolean': '?'}[kind], value)
            if protocol == 'mysql':
                text = length(len(text)) + text
            cases.append(dict(kind=kind, value=encoded_value, binary=binary.hex(), text=text.hex()))
    return cases


if __name__ == '__main__':
    main()
