"""Inspect real captured HTTP evidence through Board's public read boundary."""
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
from urllib.parse import urlencode
from storage import free_port, wait_ready


def inspect_capture(fixture, admin, authority, saved, board, provision, state, browser):
    admin('board-grant')
    seed = fixture.root / 'board.seed'
    seed.write_text('4a' * 32)
    port = free_port()
    origin = f'http://127.0.0.1:{port}'
    config = fixture.root / 'board.json'
    config.write_text(json.dumps(dict(upstream=authority, realm=47, principal=55,
        profile='growing_v3', seed_file=str(seed), public_origin=origin, port=port,
        request_timeout_ms=5000, upstream_timeout_ms=1500)))
    log = (fixture.root / 'board.log').open('w+')
    serving = subprocess.Popen([board, str(config)], stdout=log, stderr=subprocess.STDOUT)
    path = f'/api/v1/resources/{saved["resource"]}/records'
    def request(target=path, status=200):
        time.sleep(0.15)
        try: response = fixture.http.open(origin + target, timeout=10)
        except urllib.error.HTTPError as error: response = error
        with response:
            data = response.read()
            assert response.status == status, (response.status, data[:200])
            assert response.headers['Cache-Control'] == 'no-store'
            assert b'fixture-request-secret' not in data
            return json.loads(data)
    try:
        wait_ready(fixture.http, serving, origin + '/health')
        caps = request('/api/v1/capabilities')
        assert caps['http_connector'] and caps['read_only'] and not caps['query_enabled']
        position = admin('position')
        pages, details = [], []
        cursor = ''
        for _ in range(64):
            page = request(path + cursor)
            pages.append(page)
            assert all(entry is None or set(entry) == {'key', 'revision'} for entry in page['page']['entries'])
            assert page['resource']['id'] == saved['resource']
            assert page['resource']['writer'] == saved['pid']
            for index, lens in enumerate(page['exchanges']):
                if lens is None: continue
                source = lens['source']
                entry = page['page']['entries'][index]
                assert source == dict(realm=47, pid=saved['pid'], resource=saved['resource'],
                    key=entry['key'], entry_revision=entry['revision'],
                    resource_revision=page['resource']['revision'], position=page['position'])
                details.append(lens['declaration'])
            if page['page']['next'] is None: break
            cursor = '?' + urlencode(dict(revision=page['resource']['revision'], after=page['page']['next']))
        else: raise AssertionError('Board paging exceeded bounded proof workload')
        metadata_path = f'/api/v1/resources/{saved["resource"]}/http/1'
        metadata = request(metadata_path)
        assert metadata['exchange'] == '1' and metadata['phase'] == 'complete'
        assert metadata['policy']['endpoint_revision'] == '1'
        assert metadata['policy']['tls'] and metadata['policy']['retry'] == dict(id='77', revision='1')
        assert int(metadata['terminal']['timing']['started_ms']) > 0
        assert int(metadata['terminal']['timing']['elapsed_ns']) > 0
        assert metadata['terminal']['omission']['request_secrets'] == 1
        assert metadata['terminal']['omission']['response_headers'] > 0
        assert metadata['terminal']['completion']['response_bytes'] == '1027'
        assert metadata['source']['resource_revision'] == pages[0]['resource']['revision']
        serialized = json.dumps(metadata)
        for forbidden in ('fixture', '/public', '/status', 'Authorization', 'localhost', '127.0.0.1'):
            assert forbidden not in serialized, forbidden
        assert admin('position') == position, 'Inspection mutated durable authority'
        capture = next(item['capture'] for item in details if 'capture' in item)
        assert capture['exchange'] == '1' and capture['phase'] == 'complete'
        assert capture['effect'] > 0 and capture['attempt'] > 0 and int(capture['bytes']) > 1027
        assert next(item['obligations'] for item in details if 'obligations' in item)['disposition'] == 'observed'
        assert next(item['attempts'] for item in details if 'attempts' in item)['used'] == 1
        subprocess.run(['node', 'tests/board_records_client.mjs'], input=json.dumps(dict(pages=pages, metadata=metadata)).encode(), check=True, timeout=20)
        request(path + '?revision=0&after=00', status=409)
        for suffix in ('?after=00', '?revision=1&after=ff0', '?revision=1&after=', '?view=1'):
            request(path + suffix, status=400)
        admin('board-revoke')
        assert request(status=403)['err'] == 'Forbidden'
        request(metadata_path, status=403)
        # Knowing a previous key/revision cannot bypass the current read grant.
        request(path + '?revision=' + str(pages[0]['resource']['revision']) + '&after=00', status=403)
        admin('board-restore')
        request()
        if browser:
            environment = os.environ | dict(BOARD_TEST_URL=origin, BOARD_HTTP_PROOF=provision,
                BOARD_HTTP_AUTHORITY=authority, BOARD_HTTP_STATE=str(state), BOARD_HTTP_RESOURCE=str(saved['resource']))
            subprocess.run(['vp', 'exec', '--filter', '@rey/transit-board-web', 'playwright', 'test', 'http.spec.ts'], env=environment, check=True, timeout=120)
        print('Board HTTP: real capture, source-bound pages, immutable inspection, generated validation and revoked continuation passed' + (' with browser clearing.' if browser else '.'))
    except BaseException:
        log.flush(); log.seek(0)
        print(log.read()[-3000:])
        raise
    finally:
        serving.kill(); serving.wait(timeout=10); log.close()
