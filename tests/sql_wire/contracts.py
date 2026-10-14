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
