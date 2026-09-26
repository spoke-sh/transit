"""Pure Station codecs need no authority endpoint, handle or signing credential."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def run(host):
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
        for invalid in ({}, {'local_codec': True, 'url': 'http://127.0.0.1:1'},
                        {'local_codec': True, 'seed_file': '/missing-never-read.key'}):
            config.write_text(json.dumps(invalid))
            rejected = subprocess.run([host, config], input='', text=True, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, timeout=10)
            assert rejected.returncode != 0 and rejected.stdout == ''
    print('Station local codecs: shared framing, no authority configuration or credentials, incompatible mode rejection passed.')


if __name__ == '__main__': run(*sys.argv[1:])
