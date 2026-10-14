"""Independent Python framing/authentication oracle for the database adapters."""
import argparse
import base64
import hashlib
import hmac
import json
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
    path = ROOT / 'packages/zig/transit-sql-gateway/src/fixtures/auth.json'
    content = json.dumps(authentication(), indent=2) + '\n'
    if args.write:
        path.write_text(content)
    else:
        assert path.read_text() == content, 'Authentication fixture drift; review before --write'
    print('SQL wire: independent PBKDF2/HMAC/SHA-256 SCRAM proof and verifier checked.')


if __name__ == '__main__':
    main()
