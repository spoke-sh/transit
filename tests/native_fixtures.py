"""Refresh independent native canonical/signing vectors for the current definition.

Cases retain their explicitly authored field order and defaults. Python supplies
canonical JSON and SHA-256; OpenSSL supplies Ed25519 using public test seeds.
This generator never decodes or converts a user's saved operations or state.
"""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import struct

from serving import Key, subject_proof

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'packages/zig/transit-protocol/src/fixtures'


def compact(value):
    return json.dumps(value, separators=(',', ':'), ensure_ascii=False).encode()


def generated():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    results = {}
    with tempfile.TemporaryDirectory(prefix='transit-native-fixtures-') as directory:
        key = Key(Path(directory), 'public-test-seed', 7)

        def vector(body, domain):
            digest = hashlib.sha256(domain + compact(body)).digest()
            return dict(canonical=compact(body).decode(), sha256=digest.hex(), signature=key.sign(digest))

        def current(body):
            body['definition'] = definition
            def byte_arrays(value):
                if isinstance(value, dict):
                    for name, child in value.items():
                        if name in ('public_key', 'signature', 'digest', 'context', 'epoch', 'nonce', 'instance', 'workload', 'incarnation', 'worker_incarnation') and isinstance(child, str):
                            value[name] = list(child.encode())
                        else:
                            byte_arrays(child)
                elif isinstance(value, list):
                    for child in value:
                        byte_arrays(child)
            byte_arrays(body)
            command = body.get('command', {})
            if 'send' in command:
                command['send']['role'] = None
            for turn in [command.get('turn'), command.get('turn_with_versions', {}).get('turn')]:
                if turn is not None:
                    turn['authorization'] = None
                    fields = dict(turn)
                    turn.clear()
                    for name, value in fields.items():
                        if name == 'blocks':
                            continue
                        turn[name] = value
                        if name == 'mutations':
                            turn['blocks'] = fields.get('blocks', [None]*16)
            snapshot = body.get('kind', {}).get('snapshot_read')
            if snapshot is not None:
                fields = dict(snapshot)
                snapshot.clear()
                for name, value in fields.items():
                    if name == 'blocks':
                        continue
                    snapshot[name] = value
                    if name == 'points':
                        snapshot['blocks'] = fields.get('blocks', [None]*8)

        requests = json.loads((FIXTURES / 'requests-v1.json').read_text())
        assert requests['public_key'] == key.public
        assert requests['seed_hex'] == '07' * 32
        for case in requests['cases']:
            body = json.loads(case['canonical'])
            current(body)
            case.update(vector(body, b'transit.request.v1\0'))
        results[FIXTURES / 'requests-v1.json'] = requests

        sdk_path = ROOT / 'tests/sdk/sdk-operations-v1.json'
        sdk = json.loads(sdk_path.read_text())
        assert sdk['seed_hex'] == '07' * 32
        for case in sdk['cases']:
            body = json.loads(case['canonical'])
            current(body)
            generated_case = vector(body, case['domain'].encode())
            case.update(generated_case)
        results[sdk_path] = sdk

        inspection = json.loads((FIXTURES / 'inspection-v1.json').read_text())
        assert inspection['public_key'] == key.public
        body = json.loads(inspection['canonical'])
        body['definition'] = definition
        inspection.update(vector(body, b'transit.query.v1\0'))
        results[FIXTURES / 'inspection-v1.json'] = inspection

        for filename in ('leased-snapshots.json', 'snapshot-read.json'):
            cases = json.loads((FIXTURES / filename).read_text())
            for case in cases:
                current(case['query'])
                case['digest'] = hashlib.sha256(b'transit.query.v1\0' + compact(case['query'])).hexdigest()
            results[FIXTURES / filename] = cases

        request = dict(version=1, definition=definition, realm=42, principal=0, sequence=7,
                       command=dict(authorization=dict(begin=dict(expected_revision=5, role=None,
                                    action=dict(create_role=dict(name=b'analyst'.hex(), login=True, create_role=False))))))
        query = dict(version=1, definition=definition, realm=42, principal=11,
                     kind=dict(authorization=dict(role=None, kind=dict(decision=dict(object=dict(kind='domain', id=17), privileges=1)))))
        selector = dict(role=3, kind=dict(grants=dict(object=dict(kind='domain', id=17), grantee=3, cursor=None)))
        scope_body = dict(definition=definition, realm=42, principal=11, query=selector)
        scope = hashlib.sha256(b'transit.authorization.cursor.v1\0' + compact(scope_body)).hexdigest()
        turn = dict(version=1, definition=definition, realm=42, principal=0, sequence=1,
                    command=dict(turn=dict(pid=2, generation=3, input=4, expected_revision=0,
                        permit=None, views=[None]*4, current_views=[None]*4, write_view=None,
                        mutations=[None]*4, blocks=[None]*16, outputs=[None]*4, effect=None, failed=False, authorization=None)))
        entries = dict(version=1, definition=definition, realm=42, principal=0,
                       kind=dict(entries=dict(view=5, resource=None, revision=None, key=None, after=None)))
        results[FIXTURES / 'authorization-v1.json'] = dict(version=1, public_key=key.public,
            request=vector(request, b'transit.request.v1\0'), query=vector(query, b'transit.query.v1\0'),
            turn=vector(turn, b'transit.request.v1\0'), entries=vector(entries, b'transit.query.v1\0'),
            cursor=dict(realm=42, principal=11, role=3, query=selector, scope=scope))
        claim = dict(definition=definition, realm=42, principal=11, credential_epoch=9,
                     role=3, audience=17, context=list(hashlib.sha256(b'complete immutable service request').digest()))
        results[FIXTURES / 'authorization-subject-v1.json'] = dict(
            public_key=key.public, subject=vector(claim, b'transit.authorization.subject.v1\0'),
            utf8_subject=vector(dict(claim, context=[0] * 32), b'transit.authorization.subject.v1\0'),
            input=dict(value=b'original native input'.hex(),
                       digest=hashlib.sha256(b'transit.authorization.input.v1\0original native input').hexdigest()))

        diagnostic = json.loads((FIXTURES / 'diagnostic-v1.json').read_text())
        diagnostic['definition'] = definition
        results[FIXTURES / 'diagnostic-v1.json'] = diagnostic

        lifecycle_path = FIXTURES / 'data-lifecycle-v1.json'
        lifecycle = json.loads(lifecycle_path.read_text())
        for item in (lifecycle['binding'], lifecycle['commit']['binding'],
                     lifecycle['snapshot'], lifecycle['resource_initialization']):
            item['definition'] = definition
        results[lifecycle_path] = lifecycle

        serving_path = ROOT / 'packages/zig/transit-serving/src/fixtures/serving-v1.json'
        serving = json.loads(serving_path.read_text())
        serving_key = key
        assert serving['public_key'] == serving_key.public
        read = serving['read']['read']
        encoded = b'SV1r' + struct.pack('<QQQQBQ', read['realm'], read['principal'], read['service'], read['ingress'], {'discovery': 1, 'status': 2, 'result': 3, 'disposition': 4}[read['kind']], read['operation'])
        serving['read'] = dict(read=read, proof=subject_proof(serving_key, read['principal'], read['ingress'], hashlib.sha256(b'transit.serving.read.v1\0' + encoded).digest(), credential_epoch=1, realm=read['realm']))
        results[serving_path] = serving
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    for path, value in generated().items():
        text = json.dumps(value, indent=2, ensure_ascii=False) + '\n'
        if args.write:
            path.write_text(text)
        else:
            assert path.read_text() == text, f'{path.name}: native fixture drift; review before --write'
    print('Native fixtures: independent canonical bytes, signatures and authorization cursor scope agree.')


if __name__ == '__main__':
    main()
