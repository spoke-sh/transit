"""Pure Station codecs need no authority endpoint, handle or signing credential."""
import json
from pathlib import Path
import subprocess
import struct
import sys
import tempfile


def connector_diagnostics(host, config, native):
    """Independent wire constructors cover every status, terminal and rejection."""
    grpc_names = ('ok cancelled unknown invalid_argument deadline_exceeded not_found '
                  'already_exists permission_denied resource_exhausted failed_precondition '
                  'aborted out_of_range unimplemented internal unavailable data_loss unauthenticated').split()
    cases = []
    for protocol, magic, width, statuses in [('http', b'HTR1', 'H', range(200, 600)),
                                              ('grpc', b'GRR1', 'I', range(17))]:
        def wire(phase, status=0, attempt=20):
            return struct.pack('<4sB4Q' + width + '32s', magic, phase, 7, 2**64-1,
                               19, attempt, status, bytes([1 if phase == 1 else 0]) * 32).hex()
        for status in statuses:
            suffix = {2: 'response', 3: 'redirect', 4: 'client_error', 5: 'server_error'}[status // 100] if protocol == 'http' else grpc_names[status]
            cases.append((protocol, wire(1, status), 'outcome', protocol + '.' + suffix + '_observed', 'completed', status))
        cases += [(protocol, wire(2), 'outcome', protocol + '.remote_outcome_unknown', 'closed_unknown', None),
                  (protocol, wire(3, attempt=0), 'outcome', protocol + '.not_dispatched', 'not_dispatched', None)]
        for reason, suffix in [(1, 'request_denied'), (2, 'invalid_request'), (3, 'exchange_busy')]:
            cases.append((protocol, (magic[:2] + b'F1' + bytes([reason])).hex(), 'rejected', protocol + '.' + suffix, 'input_rejected', None))
    result = subprocess.run([host, config], input=''.join(json.dumps({protocol + '_codec': {'outcome': wire}}) + '\n' for protocol, wire, *_ in cases),
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=30, check=True)
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    for case, reply in zip(cases, replies, strict=True):
        protocol, wire, variant, code, outcome, status = case
        assert reply['status'] == 0, (case, reply)
        value = reply['value'][variant]
        detail = value['diagnostic']
        assert (detail['code'], detail['outcome'], detail['evidence']) == (code, outcome, 'domain_status'), (case, detail)
        assert detail['cause'] is None and detail['location'] is None
        assert [a['kind'] for a in detail['actions'] if a] == ['inspect_scope' if code.endswith('request_denied') else 'inspect_status']
        facts = {fact['field']: fact for fact in detail['facts'] if fact}
        if variant == 'outcome':
            assert detail['identity'] == {'domain': 'exchange', 'id': str(2**64-1), 'realm': None, 'resource': '7', 'sequence': None}
            assert value['status'] == status
            if status is not None:
                assert facts['protocol_status']['value'] == {'unsigned': str(status)}
                assert facts['completion']['value'] == {'boolean': True}
            else:
                assert value['reference'] is None and facts['completion']['availability'] == 'unrecorded'
        else:
            assert detail['identity'] is None and facts['field_path']['availability'] == 'unrecorded'
        if native:
            data = json.dumps({'outcome': wire}).encode()
            assert native.call('station_' + protocol + '_codec', data, len(data)) == reply['value']
    print(f'Connector diagnostics: {len(cases)} independent native/port status, terminal and rejection mappings passed.')


def run(host, library=None):
    with tempfile.TemporaryDirectory(prefix='station-local-codecs-') as temporary:
        config = Path(temporary) / 'host.json'
        config.write_text(json.dumps({'local_codec': True}))
        requests = [
            {'hello': {}}, {'growing_capabilities': {}},
            {'frame': {'kind': 1, 'correlation': '0', 'payload': b'TSC\x01\x02'.hex()}},
            {'prepare': {'kind': 6, 'seed_file': '/missing-never-read.key', 'document': '{}'}},
            {'call': '{}'}, {'growing_prepare': 1},
        ]
        result = subprocess.run([host, config], input=''.join(json.dumps(r)+'\n' for r in requests),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=15, check=True)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        assert len(responses) == len(requests)
        assert responses[0] == {'status': 0, 'value': {'host_version': 1, 'station_version': 1, 'transit_version': 1}}
        assert responses[1]['value']['gated_dispatch']
        assert responses[2] == {'status': 0, 'value': (b'STN1\x01' + bytes(8) + b'TSC\x01\x02').hex()}
        assert all(response == {'status': 13, 'value': None} for response in responses[3:])
        fixture = json.loads((Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-http/src/admission-fixtures.json').read_text())
        release = json.loads((Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-http/src/release-fixtures.json').read_text())
        followup = json.loads((Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-http/src/followup-fixtures.json').read_text())
        request = {key: value for key, value in fixture['request'].items() if key != 'body_bytes'}
        actions = [
            {'prepare': {'resource': 8, 'namespace': str(2**64-1), 'request': request,
                'body': fixture['body'], 'endpoint_revision': '7', 'reconcile_before_ms': 9000, 'max_attempts': 2}},
            {'outcome': fixture['outcome']}, {'outcome': fixture['rejection']},
            {'release': {'resource': 7, 'exchange': str(2**64-1)}},
            {'released': release['reply']},
            {'outcome': release['reply']},
            {'followup': {'resource': 7, 'parent': str(2**64-1), 'reason': 'retry', 'reference': fixture['reference']}},
            {'followup': {'resource': 7, 'parent': '0', 'reason': 'retry', 'reference': fixture['reference']}},
            {'followup': {'resource': 7, 'parent': str(2**64), 'reason': 'retry', 'reference': fixture['reference']}},
            {'followup': {'resource': 7, 'parent': '1', 'reason': 'retry', 'reference': fixture['reference'][:-2]}},
            {'outcome': fixture['outcome'][:-2]},
            {'released': release['reply'][:-2]},
            {'released': release['request']},
            {'release': {'resource': 7, 'exchange': '0'}},
            {'prepare': {'resource': 8, 'namespace': str(2**64), 'request': request,
                'body': '', 'endpoint_revision': '7', 'reconcile_before_ms': 9000}},
        ]
        result = subprocess.run([host, config], input=''.join(json.dumps({'http_codec': a})+'\n' for a in actions),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=15, check=True)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        prepared = responses[0]['value']['prepared']
        assert responses[0]['status'] == 0 and prepared['reference'] == fixture['reference']
        assert bytes.fromhex(prepared['metadata']).decode() == fixture['metadata']
        assert responses[1]['status'] == 0
        assert responses[1]['value']['outcome']['exchange'] == str(2**64-1)
        assert responses[1]['value']['outcome']['status'] == 200
        assert responses[2]['status'] == 0 and responses[2]['value']['rejected']['reason'] == 'denied'
        assert responses[3] == {'status': 0, 'value': {'release': release['request']}}
        assert responses[4] == {'status': 0, 'value': {'released': {'resource': 7, 'exchange': str(2**64-1)}}}
        assert responses[5] == responses[4]
        assert responses[6] == {'status': 0, 'value': {'followup': followup['request']}}
        assert all(r['status'] == 1 for r in responses[7:])
        if library:
            # The generated ABI declares the exact same implementation as the port.
            from abi_support import _Library, TransitError
            directory = Path(temporary) / 'lib'
            directory.mkdir()
            (directory / 'libtransit_station.so').symlink_to(Path(library).resolve())
            native = _Library(directory, 'station')
            for action, expected in zip(actions, responses, strict=True):
                data = json.dumps(action).encode()
                try:
                    actual = {'status': 0, 'value': native.call('station_http_codec', data, len(data))}
                except TransitError as error:
                    actual = {'status': error.status, 'value': error.detail}
                assert actual == expected, (actual, expected)
        # RPC uses independent binary fixtures through the same public native
        # and isolated port boundary, with no authority endpoint or credential.
        base = Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-grpc/src/fixtures'
        request_fixture = json.loads((base / 'request.json').read_text())
        service = json.loads((base / 'service.json').read_text())
        provenance = json.loads(request_fixture['metadata'])
        entries = []
        for item in provenance['metadata']:
            value = item['value']
            if 'literal_hex' in value:
                value = {'literal': value['literal_hex']}
            else:
                value = {'secret': {**value['secret'], 'version': str(value['secret']['version'])}}
            entries.append({'name': item['name'], 'value': value})
        request = {'method': {'path': provenance['method'], 'shape': provenance['shape'],
            'descriptor_digest': provenance['descriptor_digest']}, 'metadata': entries}
        reference = bytearray.fromhex(request_fixture['reference_hex'])
        # Deadlines are safe JSON counters at the foreign boundary. Other full
        # width identities use decimal strings. The wire fixture stays u64.
        reference[100:108] = (9000).to_bytes(8, 'little')
        actions = [
            {'prepare': {'resource': 2**53-1, 'namespace': str(2**64-1), 'request': request,
                'messages': request_fixture['messages_hex'], 'endpoint_revision': str(2**64-1),
                'reconcile_before_ms': 9000, 'max_attempts': 2**32-1}},
            {'outcome': service['outcome_ok_hex']},
            {'outcome': service['outcome_unknown_hex']},
            {'outcome': service['rejection_hex']},
            {'release': {'resource': 7, 'exchange': str(2**64-1)}},
            {'released': service['released_hex']},
            {'followup': {'resource': 7, 'parent': str(2**64-1), 'reference': request_fixture['reference_hex']}},
            {'followup': {'resource': 7, 'parent': '0', 'reference': request_fixture['reference_hex']}},
            {'outcome': service['outcome_ok_hex'][:-2]},
            {'released': service['release_hex']},
            {'prepare': {'resource': 8, 'namespace': '01', 'request': request,
                'messages': [], 'endpoint_revision': '7', 'reconcile_before_ms': 9000}},
            {'descriptor': {'bytes': '0affffffffff0f', 'method': provenance['method']}},
        ]
        result = subprocess.run([host, config], input=''.join(json.dumps({'grpc_codec': a})+'\n' for a in actions),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=15, check=True)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        prepared = responses[0]['value']['prepared']
        assert prepared['reference'] == reference.hex(), (prepared['reference'], reference.hex())
        assert bytes.fromhex(prepared['metadata']).decode() == request_fixture['metadata']
        assert prepared['batch'] == request_fixture['batch_hex']
        assert responses[1]['value']['outcome']['status'] == 0
        assert responses[1]['value']['outcome']['reference'] is not None
        assert responses[2]['value']['outcome']['status'] is None
        assert responses[2]['value']['outcome']['reference'] is None
        assert responses[2]['value']['outcome']['exchange'] == str(2**64-1)
        assert responses[3]['status'] == 0 and responses[3]['value']['rejected']['reason'] == 'denied'
        assert responses[4] == {'status': 0, 'value': {'release': service['release_hex']}}
        assert responses[5] == {'status': 0, 'value': {'released': {'resource': 7, 'exchange': str(2**64-1)}}}
        assert responses[6] == {'status': 0, 'value': {'followup': service['followup_hex']}}
        assert all(r['status'] == 1 for r in responses[7:]), responses[7:]
        if library:
            for action, expected in zip(actions, responses, strict=True):
                data = json.dumps(action).encode()
                try:
                    actual = {'status': 0, 'value': native.call('station_grpc_codec', data, len(data))}
                except TransitError as error:
                    actual = {'status': error.status, 'value': error.detail}
                assert actual == expected, (actual, expected)
        connector_diagnostics(host, config, native if library else None)
        # Document codecs use canonical shared fixtures and preserve binary/float
        # bits separately from host JSON number representation.
        fixture = json.loads((Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-document/src/fixtures/changes.json').read_text())
        actions = [{'prepare': row['change']} for row in fixture['changes']]
        actions += [{'decode': row['wire_hex']} for row in fixture['changes']]
        actions += [{'reference': fixture['reference']}, {'inspect_reference': fixture['reference_hex']}]
        valid_count = len(actions)
        actions += [{'decode': fixture['changes'][0]['wire_hex'][:-2]},
                    {'prepare': dict(fixture['changes'][0]['change'], replica='01')},
                    {'prepare': dict(fixture['changes'][1]['change'], first=str(2**64-1))},
                    {'inspect_reference': fixture['reference_hex'] + '00'}]
        result = subprocess.run([host, config], input=''.join(json.dumps({'document_codec': a})+'\n' for a in actions),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=15, check=True)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        for row, response in zip(fixture['changes'], responses[:3], strict=True):
            assert response == {'status': 0, 'value': {'prepared': {'bytes': row['wire_hex'], 'spec': row['spec']}}}, response
        assert all(row['status'] == 0 for row in responses[:valid_count]), responses
        assert responses[6] == {'status': 0, 'value': {'reference': fixture['reference_hex']}}
        assert responses[7] == {'status': 0, 'value': {'inspected_reference': fixture['reference']}}
        assert all(row['status'] == 1 for row in responses[valid_count:]), responses[valid_count:]
        if library:
            for action, expected in zip(actions, responses, strict=True):
                data = json.dumps(action).encode()
                try:
                    actual = {'status': 0, 'value': native.call('station_document_codec', data, len(data))}
                except TransitError as error:
                    actual = {'status': error.status, 'value': error.detail}
                assert actual == expected, (actual, expected)
        seed = Path(temporary) / 'test.key'
        seed.write_text('00' * 32)
        activation = {'realm': 72, 'principal': 1, 'pid': 1, 'generation': 1, 'association': 'data'}
        for profile in ({'local_codec': True},
                        {'url': 'http://127.0.0.1:1'},
                        {'url': 'http://127.0.0.1:1', 'seed_file': str(seed), 'growing_server': dict(activation,
                            profile='native_v1', failure_policy='stop', query_results=True)}):
            config.write_text(json.dumps(profile))
            with subprocess.Popen([host, config], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL) as child:
                child.stdin.write(b'{"shutdown":{}}\n'); child.stdin.flush()
                assert child.wait(timeout=5) == 0
                assert json.loads(child.stdout.readline()) == {'status': 0, 'value': {'closed': True}}
                assert child.stdout.read() == b''
        for invalid in ({}, {'url': 'http://127.0.0.1:1', 'seed_file': str(seed), 'server': activation},
                        {'local_codec': True, 'url': 'http://127.0.0.1:1'},
                        {'local_codec': True, 'seed_file': '/missing-never-read.key'}):
            config.write_text(json.dumps(invalid))
            rejected = subprocess.run([host, config], input='', text=True, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, timeout=10)
            assert rejected.returncode != 0 and rejected.stdout == ''
    print('Station local codecs: shared framing and HTTP/RPC/Document fixtures, full-width IDs, malformed rejection, no authority/credentials, native/port parity and shutdown passed.')


if __name__ == '__main__': run(*sys.argv[1:])
