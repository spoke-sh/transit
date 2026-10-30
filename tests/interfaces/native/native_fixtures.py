"""Refresh independent native canonical/signing vectors for the current definition.

Cases retain their explicitly authored field order and defaults. Python supplies
canonical JSON and SHA-256; OpenSSL supplies Ed25519 using public test seeds.
This generator never decodes or converts a user's saved operations or state.
"""
from runner.paths import ROOT
import argparse
import hashlib
import hmac
import json
from pathlib import Path
import tempfile
import struct

from interfaces.http.serving import Key, subject_proof

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
        transaction_path = FIXTURES / 'transaction-v1.json'
        transaction = json.loads(transaction_path.read_text())

        def transaction_definition(value):
            if isinstance(value, dict):
                for name, child in value.items():
                    if name == 'definition':
                        value[name] = definition
                    else:
                        transaction_definition(child)
            elif isinstance(value, list):
                for child in value:
                    transaction_definition(child)

        transaction_definition(transaction)
        results[transaction_path] = transaction
        lifecycle['transaction'] = transaction
        # Independent neutral Stream/Queue attribution fixture. Logical offsets,
        # physical WAL positions and original operations deliberately differ.
        log_scope = dict(realm=1, resource=7, catalog=2**64-1)
        log_target = dict(definition=definition, interpretation=dict(
            object=dict(scope=log_scope, branch=1, object=43), revision=2,
            digest=[29]*32), partition=0)
        append = dict(target=log_target,
                      operation=dict(scope=log_scope, principal=17, operation=2**64-4),
                      kind='stream', producer=dict(id=[13]*16, epoch=5, sequence=2**64-1),
                      rows=4, payload=dict(bytes=1024, sha256=[31]*32))
        coverage = dict(cut=dict(target=log_target, accepted=dict(partition=91, next_lsn=12),
                                retained_from=2**64-9, next=2**64-1),
                        **{'from': 2**64-5}, until=2**64-1, through=2**64-1,
                        rows=2, complete=True)
        lease = dict(target=log_target,
                     claim=dict(scope=log_scope, principal=17, operation=2**64-3),
                     offset=2**64-4, epoch=9, attempt=2, expires_ms=1000)
        stream_queue = dict(
            declaration=dict(definition=definition, interpretation=log_target['interpretation'],
                             schema=dict(bytes=128, sha256=[37]*32),
                             configuration=dict(
                                 partitioning=dict(count=4, key_column=9, hash='sha256_64'),
                                 retention=dict(max_age_ms=None),
                                 policy=dict(stream=dict(compact_key_column=None, timestamp_column=None))),
                             limits=dict(append_rows=4096, append_bytes=1048576,
                                         claim_rows=64, read_rows=4096, read_bytes=1048576,
                                         active_leases=1024, waiters=64, timer_steps=256)),
            append=dict(append=append, first=2**64-5, next=2**64-1,
                        accepted=dict(partition=91, next_lsn=12), observed_ms=500),
            producer=dict(target=log_target, principal=17, producer=append['producer'],
                          discarded_through=2**64-7),
            claim=dict(claim=dict(target=log_target, operation=lease['claim'],
                                  maximum=16, lease_ms=500),
                       accepted=dict(partition=91, next_lsn=12),
                       observed_ms=500, expires_ms=1000, rows=2,
                       leases=dict(bytes=512, sha256=[41]*32)),
            clock=dict(floor_ms=500),
            offset_commit=dict(operation=dict(scope=log_scope, principal=17, operation=102),
                               group=dict(id=42, generation=7, principal=17),
                               coverage=coverage, expected_next=2**64-5, next=2**64-1),
            settlement=dict(settlement=dict(
                operation=dict(scope=log_scope, principal=17, operation=2**64-2),
                lease=lease, action=dict(ack={})), accepted=dict(partition=91, next_lsn=13)))
        stream_queue['group_progress'] = dict(target=log_target,
                                              group=stream_queue['offset_commit']['group'],
                                              next=stream_queue['offset_commit']['expected_next'])
        stream_queue['group_assignment'] = dict(
            assignment=dict(operation=dict(scope=log_scope, principal=0, operation=2**64-8),
                            cut=coverage['cut'], expected=stream_queue['group_progress'],
                            group=dict(id=42, generation=8, principal=19),
                            next=stream_queue['group_progress']['next']),
            accepted=dict(partition=91, next_lsn=13))
        stream_queue['offset_receipt'] = dict(commit=stream_queue['offset_commit'], accepted=dict(partition=91, next_lsn=13))
        read_operation = dict(scope=log_scope, principal=17, operation=2**64-12)
        read_source = dict(bytes=1024, sha256=[43]*32)
        stream_queue['read'] = dict(
            request=dict(target=log_target, operation=read_operation,
                         group=stream_queue['offset_commit']['group'],
                         **{'from': coverage['from']}, until=None, timestamp=None),
            cut=coverage['cut'], until=coverage['until'], source=read_source,
            accepted=dict(partition=91, next_lsn=13))
        read_handle = dict(owner=read_operation, source=read_source)
        coverage_body = b'transit.stream.read.coverage.v1\0' + bytes.fromhex(definition) + compact(dict(read=read_handle, coverage=coverage))
        stream_queue['read_cursor'] = dict(read=read_handle, coverage=coverage,
                                         authentication=list(hmac.digest(bytes([7]*32), coverage_body, 'sha256')))
        results[ROOT / 'packages/zig/transit-storage/src/stream_read_fixture.json'] = stream_queue['read_cursor']
        stream_queue['read_release'] = dict(
            release=dict(target=log_target, operation=dict(scope=log_scope, principal=17, operation=2**64-13),
                         read=read_handle), accepted=dict(partition=91, next_lsn=14))
        stream_queue['queue_cursor'] = dict(receipt=stream_queue['claim'], next=0)
        stream_queue['queue_read_release'] = dict(
            release=dict(operation=dict(scope=log_scope, principal=17, operation=2**64-14),
                         claim=stream_queue['claim']), accepted=dict(partition=91, next_lsn=14))
        stream_queue['queue_observation_basis'] = dict(
            cut=dict(target=log_target, accepted=dict(partition=91, next_lsn=13),
                     retained_from=0, next=2**64-1),
            time=dict(earliest_ms=600, latest_ms=700))
        stream_queue['queue_lease_observation'] = dict(
            original=lease, state='acquired', epoch=9, attempt=2,
            expires_ms=1000, blocked=dict(none={}), liveness='live')
        results[FIXTURES / 'stream-queue-v1.json'] = stream_queue
        lifecycle['stream_queue'] = stream_queue
        doc_partition = dict(
            definition=definition,
            interpretation=dict(
                object=dict(scope=log_scope, branch=1, object=2**64-2),
                revision=1, digest=[47]*32),
            partition=0)
        doc_target = dict(partition=doc_partition, document=list(range(33, 49)))
        doc_replica = dict(id=list(range(49, 65)), epoch=3,
                           sequence=2**64-1, preceding_sequence=2**64-2)
        doc_mutation = dict(
            target=doc_target,
            operation=dict(scope=log_scope, principal=17, operation=2**64-1),
            lineage=dict(profile='causal_crdt', merge_epoch=3,
                         base_revision=2**64-5, parent_revision=None,
                         replica=doc_replica,
                         raw_span=dict(part_id=1, byte_start=0, byte_end=256)),
            operations=4,
            payload=dict(bytes=256, sha256=[53]*32))
        doc_cut = dict(
            target=doc_target, merge_epoch=3,
            retained_from=2**64-6, accepted_revision=2**64-2,
            state=dict(bytes=1024, sha256=[59]*32),
            accepted=dict(partition=93, next_lsn=15))
        doc_read_op = dict(scope=log_scope, principal=17, operation=2**64-14)
        doc_read_source = dict(bytes=1024, sha256=[61]*32)
        doc_read_handle = dict(owner=doc_read_op, source=doc_read_source)
        doc_coverage = dict(
            cut=doc_cut, from_revision=2**64-5, through_revision=2**64-2,
            next_revision=2**64-1, steps=12, bytes=512, complete=True)
        doc_coverage_body = b'transit.document.read.coverage.v1\0' + bytes.fromhex(definition) + compact(dict(read=doc_read_handle, coverage=doc_coverage))
        document = dict(
            declaration=dict(
                definition=definition,
                interpretation=doc_partition['interpretation'],
                schema=dict(bytes=256, sha256=[51]*32),
                configuration=dict(
                    partitioning=dict(count=4, key_column=1, hash='sha256_64'),
                    profile='causal_crdt',
                    shredding=dict(frequent_path_threshold=64,
                                   max_shredded_columns=32,
                                   default_collation='utf8_binary'),
                    retention=dict(max_age_ms=86400000,
                                   merge_window_revisions=1024)),
                limits=dict(change_bytes=65536, operations_per_change=64,
                            path_depth=32, read_steps=4096,
                            read_bytes=262144, unresolved_conflicts=16)),
            mutation=dict(
                mutation=doc_mutation,
                accepted_revision=2**64-2,
                state=doc_cut['state'],
                unresolved_conflicts=1,
                accepted=dict(partition=93, next_lsn=15)),
            replica=dict(
                target=doc_target, principal=17,
                replica=doc_replica, discarded_through=2**64-7),
            checkpoint=dict(
                checkpoint=dict(
                    target=doc_target,
                    operation=dict(scope=log_scope, principal=17, operation=2**64-9),
                    previous_epoch=2, next_epoch=3,
                    retained_from=2**64-6, checkpoint_revision=2**64-2,
                    checkpoint=doc_cut['state']),
                cut=doc_cut),
            read=dict(
                request=dict(target=doc_target, operation=doc_read_op,
                             from_revision=2**64-5, through_revision=None,
                             max_steps=4096, max_bytes=262144),
                cut=doc_cut, through_revision=2**64-2, source=doc_read_source,
                accepted=dict(partition=93, next_lsn=16)),
            read_cursor=dict(
                read=doc_read_handle, coverage=doc_coverage,
                authentication=list(hmac.digest(bytes([7]*32), doc_coverage_body, 'sha256'))),
            read_release=dict(
                release=dict(
                    target=doc_target,
                    operation=dict(scope=log_scope, principal=17, operation=2**64-15),
                    read=doc_read_handle),
                accepted=dict(partition=93, next_lsn=17)))
        results[FIXTURES / 'document-v1.json'] = document
        lifecycle['document'] = document
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
