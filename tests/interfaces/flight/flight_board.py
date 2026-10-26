"""Board reads the same durable query evidence with only its inspection grant."""
import json
from pathlib import Path
import time
import urllib.error
from harness.services import free_port, wait_ready


class Observer:
    def __init__(self, env, binary):
        self.fixture = env['fixture']
        self.origin = f'http://127.0.0.1:{free_port()}'
        config = self.fixture.root / 'board.json'
        config.write_text(json.dumps(dict(upstream=env['url'], realm=45, principal=55, profile='native_v1', seed_file=str(self.fixture.root / 'inspector.seed'), public_origin=self.origin, port=int(self.origin.rsplit(':',1)[1]), request_timeout_ms=5000, upstream_timeout_ms=3500)))
        process = env['start']('board', [str(Path(binary).resolve()), str(config)])
        wait_ready(self.fixture.http, process, self.origin+'/health')
        with self.fixture.http.open(self.origin+'/api/v1/capabilities') as response:
            capabilities = json.load(response)
        assert capabilities['read_only'] and not capabilities['query_enabled']

    def check(self, resource, kind, unavailable=False):
        cursor = ''
        deadline = time.monotonic()+40
        while time.monotonic() < deadline:
            time.sleep(.12)
            try:
                response = self.fixture.http.open(self.origin+f'/api/v1/resources/{resource}/records'+cursor, timeout=15)
            except urllib.error.HTTPError as error:
                if unavailable:
                    assert error.code == 410, error.code
                    error.close()
                    print('Board: retired query evidence fails closed without empty-result substitution.', flush=True)
                    return
                if error.code in (409,429,503):
                    cursor = ''; error.close(); continue
                raise
            with response:
                assert not unavailable, 'retired query resource disclosed records'
                assert response.headers['Cache-Control'] == 'no-store'
                value = json.load(response)
            for lens in value['queries']:
                if lens and kind in lens['declaration']:
                    assert lens['source']['resource'] == resource and lens['source']['position'] == value['position']
                    assert lens['source']['resource_revision'] == value['resource']['revision']
                    assert 'value' not in lens['declaration']
                    print(f'Board: bounded {kind} metadata retains exact source key/revisions without SQL, rows or tickets.', flush=True)
                    return
            after = value['page']['next']
            assert after is not None, ('query metadata missing', kind)
            cursor = f'?revision={value["resource"]["revision"]}&after={after}'
        raise AssertionError('Board query evidence did not settle')
