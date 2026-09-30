"""Independent canonical JSON, SHA-256 and Ed25519 check of the public fixture."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
actual = sys.stdin.buffer.read()
expected = (root / 'contracts/application-installation-v1.fixture.json').read_bytes()
assert actual == expected, 'Application signing fixture drift: run just contract::generate'
fixture = json.loads(actual)
inspection = fixture['inspection']
canonical_inspection = dict(version=1, application='items', roles=[dict(name='data', contract='items-v1', artifact=dict(path='/worker', sha256=[1] * 32), configuration='{}', accesses=[], depends_on=[])], resources=[dict(name='data', writer='data')], callers=[], initialize=[], inspection=[dict(resource='data', permissions=3)])
assert inspection == canonical_inspection
assert fixture['inspection_digest'] == list(hashlib.sha256(b'transit.application.v1\0' + json.dumps(canonical_inspection, separators=(',', ':')).encode()).digest())
signed = fixture['signed']
# Field/default order is part of v1; object insertion order from the exporter
# alone would not detect an accidental change to the public field ordering.
request = signed['request']
canonical = {
    'version': request['version'], 'installation': request['installation'],
    'realm': request['realm'], 'principal': request['principal'],
    'operation': request['operation'], 'command': {'status': {
        'application': request['command']['status']['application'],
        'after': request['command']['status']['after']}},
}
message = hashlib.sha256(b'transit.application.v1\0' + json.dumps(canonical, separators=(',', ':'), ensure_ascii=False).encode()).digest()
assert list(message) == fixture['digest']
with tempfile.TemporaryDirectory(prefix='transit-application-signing-') as directory:
    directory = Path(directory)
    # RFC 8410 SubjectPublicKeyInfo prefix for an Ed25519 key.
    (directory / 'key.der').write_bytes(bytes.fromhex('302a300506032b6570032100') + bytes(signed['public_key']))
    (directory / 'message').write_bytes(message)
    (directory / 'signature').write_bytes(bytes(signed['signature']))
    result = subprocess.run(['openssl', 'pkeyutl', '-verify', '-pubin', '-inkey', str(directory / 'key.der'),
        '-keyform', 'DER', '-rawin', '-in', str(directory / 'message'), '-sigfile', str(directory / 'signature')], capture_output=True)
    assert result.returncode == 0, result.stderr.decode()
print('Application canonical request, digest and signature match the independent fixture.')
