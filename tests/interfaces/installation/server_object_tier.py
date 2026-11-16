"""Installed SQL and settings use the native immutable tier through MinIO TLS."""
import json
from pathlib import Path
import sys
import time

from interfaces.installation.server import Fixture
from interfaces.installation.server_direct_tables import storage
from interfaces.installation.server_application_faults import ExistingKey, native, post
from interfaces.cli.table_console import records
from storage.providers.cold_storage import ColdStore


def run(cli):
    with ColdStore(tls=True) as cold:
        fixture = Fixture(cli)
        try:
            options = cold.native_config()
            fixture.config['storage'] = dict(object_storage=options,
                maintenance=dict(flush=dict(enabled=True, rows=1, work_rows=2)))
            fixture.path.write_text(json.dumps(fixture.config))
            fixture.start()
            fixture.ready()
            record = fixture.record()
            identity = {name: record[name] for name in ('installation', 'root_public', 'identity', 'default_table', 'provision')}
            key = ExistingKey(fixture.root, fixture.installation / 'root.seed')

            def tier():
                return post(fixture.config['ports']['node'], '/v1/query',
                    native(key, record['realm'], 0, dict(storage={})))['body']['storage']['object_tier']

            def drained():
                until = time.monotonic() + 300
                while True:
                    observed = tier()
                    table = storage(fixture, record)
                    assert observed is not None and not observed['recovery_required'], observed
                    if observed['pending_objects'] == 0 and table['pending']['complete'] and table['pending']['rows'] == 0:
                        assert observed['pending_upload_bytes'] == 0
                        return observed
                    assert time.monotonic() < until, (observed, table['pending'])
                    time.sleep(.1)

            fixture.console('INSERT INTO items VALUES (1, 11), (2, 22);\n')
            expected = [dict(id='1', value='11'), dict(id='2', value='22')]
            assert sorted(records(fixture.console('SELECT id, value FROM items;\n')[-1]), key=lambda r: r['id']) == expected
            first = drained()
            assert first['uploads_completed'] > 0 and cold.native_data_objects() > 0
            # Reload records the mutable cache budget as pending; the active
            # owner keeps its old limit until restart.
            fixture.config['storage']['object_storage']['cache_bytes'] = 64 * 1024 * 1024
            fixture.path.write_text(json.dumps(fixture.config))
            fixture.console('SELECT transit_reload_conf();\n')
            assert tier()['cache_limit_bytes'] == 32 * 1024 * 1024
            fixture.stop(kill=True)
            fixture.start()
            fixture.ready()
            assert {name: fixture.record()[name] for name in identity} == identity
            assert tier()['cache_limit_bytes'] == 64 * 1024 * 1024
            assert sorted(records(fixture.console('SELECT id, value FROM items;\n')[-1]), key=lambda r: r['id']) == expected
            assert tier()['cache_misses'] > 0, 'Cold restart did not fetch original provider objects'
            fixture.console('UPDATE items SET value = 33 WHERE id = 2;\n')
            expected[1]['value'] = '33'
            drained()
            fixture.stop(kill=True)
            fixture.start()
            fixture.ready()
            assert sorted(records(fixture.console('SELECT id, value FROM items;\n')[-1]), key=lambda r: r['id']) == expected
            encoded = json.dumps(tier())
            assert cold.url not in encoded and cold.secret not in encoded and 'credentials_file' not in encoded
        except BaseException:
            fixture.stop(kill=True)
            print(f'Failed installed tier state retained privately at {fixture.root}', file=sys.stderr)
            raise
        else:
            fixture.cleanup()
    print('Installed native MinIO: SQL writes/flush, verified remote coverage, mutable cache settings, original installation identity and cold restart reads passed.', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])
