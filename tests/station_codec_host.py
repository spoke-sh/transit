"""Pure Station codecs need no authority endpoint, handle or signing credential."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile


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
        assert responses[2] == {'status': 0, 'value': {'rejected': 'denied'}}
        assert responses[3] == {'status': 0, 'value': {'release': release['request']}}
        assert responses[4] == {'status': 0, 'value': {'released': {'resource': 7, 'exchange': str(2**64-1)}}}
        assert responses[5] == responses[4]
        assert responses[6] == {'status': 0, 'value': {'followup': followup['request']}}
        assert all(r['status'] == 1 for r in responses[7:])
        if library:
            # The generated ABI declares the exact same implementation as the port.
            from transit_station import _Library, TransitError
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
        seed = Path(temporary) / 'test.key'
        seed.write_text('00' * 32)
        activation = {'realm': 72, 'principal': 1, 'pid': 1, 'generation': 1, 'association': 'data'}
        for profile in ({'local_codec': True},
                        {'url': 'http://127.0.0.1:1'},
                        {'url': 'http://127.0.0.1:1', 'seed_file': str(seed), 'server': activation},
                        {'url': 'http://127.0.0.1:1', 'seed_file': str(seed), 'growing_server': dict(activation,
                            profile='growing_v3', failure_policy='stop', query_results=True)}):
            config.write_text(json.dumps(profile))
            with subprocess.Popen([host, config], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL) as child:
                child.stdin.write(b'{"shutdown":{}}\n'); child.stdin.flush()
                assert child.wait(timeout=5) == 0
                assert json.loads(child.stdout.readline()) == {'status': 0, 'value': {'closed': True}}
                assert child.stdout.read() == b''
        for invalid in ({}, {'local_codec': True, 'url': 'http://127.0.0.1:1'},
                        {'local_codec': True, 'seed_file': '/missing-never-read.key'}):
            config.write_text(json.dumps(invalid))
            rejected = subprocess.run([host, config], input='', text=True, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, timeout=10)
            assert rejected.returncode != 0 and rejected.stdout == ''
    print('Station local codecs: shared framing and HTTP admission fixtures, full-width IDs, malformed rejection, no authority/credentials, native/port parity and shutdown passed.')


if __name__ == '__main__': run(*sys.argv[1:])
