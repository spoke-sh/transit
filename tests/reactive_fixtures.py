"""Independent REACTIVE_V1 golden bytes; OpenSSL supplies Ed25519, not Zig."""
import hashlib
import json
from pathlib import Path
import struct
import tempfile

from serving import Key, subject_proof

DEFINITION = json.loads((Path(__file__).resolve().parents[1] / "contracts/transit-v1.schema.json").read_text())["x-transit"]["definition"]


def generate():
    maximum = (1 << 53) - 1
    identity = dict(session=7, generation=10)
    cases = []

    def case(name, body, wire):
        cases.append(dict(command={'reactive': {name: body}}, hex=(b'SV1c\x05' + wire).hex()))

    full = (1 << 64) - 1
    source = dict(revision=1, audience=88, resource=8, realm=49, catalog=str(full), branch=1, namespace=7, object=str(full-1), interpretation_revision=str(full-2), interpretation_digest=[5] * 32, published=True)
    case('publish', dict(expected=0, source=source), b'\0' + struct.pack('<6Q', 0, 1, 88, 8, 49, full) + b'\1' + struct.pack('<3Q', 7, full-1, full-2) + bytes([5]) * 32 + b'\1')
    case('observe_clock', 1000, b'\1' + struct.pack('<Q', 1000))
    case('open', dict(session=7, source_revision=1, lease_before_ms=5000), b'\2' + struct.pack('<QQQ', 7, 1, 5000))
    case('attach', dict(identity=identity, expected=2, nonce=[8] * 16), b'\3' + struct.pack('<QQQ', 7, 10, 2) + bytes([8]) * 16)
    case('subscribe', dict(identity=identity, expected=0, subscription=3, operation=maximum), b'\4' + struct.pack('<QQQQQ', 7, 10, 0, 3, maximum))
    case('renew', dict(identity=identity, expected=5000, lease_before_ms=6000), b'\5' + struct.pack('<QQQQ', 7, 10, 5000, 6000))
    case('unsubscribe', dict(identity=identity, subscription=3, generation=12), b'\6' + struct.pack('<QQQQ', 7, 10, 3, 12))
    case('close', identity, b'\7' + struct.pack('<QQ', 7, 10))
    case('expire', dict(principal=65536, identity=identity, observed_ms=6000), b'\10' + struct.pack('<QQQQ', 65536, 7, 10, 6000))
    with tempfile.TemporaryDirectory() as directory:
        key = Key(Path(directory), 'fixture', 17)
        scope = dict(realm=49, principal=maximum, service=1, ingress=9, session=7, generation=10, subscription=3, subscription_generation=12)
        position = dict(version=1, scope=scope, watch_revision=2, resource=11, schema=[3] * 32, data_revision=str(full), outcome_position=12)
        scope_bytes = struct.pack('<8Q', *scope.values())
        position_bytes = b'SV1E\1' + scope_bytes + struct.pack('<QQ', 2, 11) + bytes([3]) * 32 + struct.pack('<QQ', full, 12)
        cursor = dict(position=position, signature=key.sign(hashlib.sha256(b'transit.reactive.cursor.v1\0' + bytes.fromhex(DEFINITION) + position_bytes).digest()))
        cursor_bytes = b'SV1K' + position_bytes[4:] + bytes(cursor['signature'])
        read = dict(scope=scope, kind='events', attachment=3, nonce=[8] * 16, cursor=cursor)
        read_bytes = b'SV1U' + scope_bytes + b'\3' + struct.pack('<Q', 3) + bytes([8]) * 16 + b'\1' + cursor_bytes
        signed = dict(read=read, proof=subject_proof(key, maximum, scope['ingress'], hashlib.sha256(b'transit.reactive.read.v1\0' + read_bytes).digest(), credential_epoch=1))
        return dict(version=1, commands=cases, public_key=key.public, cursor=cursor, cursor_hex=cursor_bytes.hex(), read=signed)


if __name__ == '__main__':
    target = Path(__file__).resolve().parents[1] / 'packages/zig/transit-serving/src/fixtures/reactive-v1.json'
    target.write_text(json.dumps(generate(), indent=2) + '\n')
