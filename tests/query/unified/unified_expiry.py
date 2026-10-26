"""Finite request lifetime on the real synchronized authority; no test clock."""
import json
from pathlib import Path
import subprocess
import time

from cold_storage import ColdStore
from harness.ursula import Fixture
from harness.services import free_port, wait_ready
from query.unified.unified_abi import Native, Failure, upload


def run(node, host, proof, library, kinds):
    for kind in kinds:
        started = time.monotonic()
        with ColdStore() as cold, Fixture(cold.config()) as fixture:
            root = fixture.root
            fixture.env.update(LOG_FORMAT='json', LOG_LEVEL='warn')
            processes, logs = [], []
            client = None
            public = json.loads(subprocess.check_output([proof, 'public']))
            port = free_port()
            url = f'http://127.0.0.1:{port}'
            config = root/'node.json'
            config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000),
                ursula_url=fixture.url, bucket='unified-expiry', journal='authority', port=port,
                resident_pages=64 if kind == 'document' else 8, request_timeout_ms=10000)))

            if kind == 'table':
                settings = json.loads(config.read_text())
                for field in ('ursula_url', 'bucket', 'journal'): settings.pop(field)
                settings['local_directory'] = str(root/'authority')
                config.write_text(json.dumps(settings))

            def start(name, command):
                log = (root/(name+'.log')).open('w+')
                logs.append(log)
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
                processes.append(process)
                return process

            def invoke(mode, *args, timeout=60):
                result = subprocess.run([proof, url, mode, str(root), *args], capture_output=True, text=True, timeout=timeout, env=fixture.env)
                assert result.returncode == 0, (mode, result.stderr)
                return json.loads(result.stdout) if result.stdout.strip() else None

            try:
                subprocess.run([node, str(config), '--initialize'], check=True, env=fixture.env)
                authority = start('node', [node, str(config)])
                wait_ready(fixture.http, authority, url+'/health')
                if kind == 'table':
                    invoke('catalog-bootstrap', timeout=300)
                    authority.terminate(); authority.wait(timeout=10)
                    settings = json.loads(config.read_text())
                    settings['table'] = json.loads((root/'catalog-node.json').read_text())
                    config.write_text(json.dumps(settings))
                    authority = start('node-catalog', [node, str(config)])
                    wait_ready(fixture.http, authority, url+'/health')
                connection = invoke('provision-expiring', kind, timeout=1800)
                expires = json.loads((root/'client.json').read_text())['expiry_at_ms']
                for role in ('source', 'requester', 'courier'): start(role, [host, str(root/(role+'.json'))])
                client = Native(library, url, connection, tables=json.loads((root/'client.json').read_text()).get('tables'))
                upload(client, root)
                # The same source has a complete readable publication before the
                # configured request deadline. The source remains unlimited.
                while client.call({'status': '1'})['status']['phase'] != 'complete':
                    assert time.time()*1000 < expires-10000, 'query did not complete before finite lifetime'
                    time.sleep(.1)
                first = client.call({'page': {'namespace': '1'}})['page']
                assert first['rows'] > 0 and first['next']
                if kind == 'table': invoke('released-pins')
                versions = invoke('versions')
                assert all(v['released_at'] is not None for v in versions['entries'] if v)
                print(f'Unified {kind} expiry: complete result read before opted-in request deadline; waiting for real time.', flush=True)
                # Account for the admitted trusted clock uncertainty, not just
                # the host wall clock. No quota or timeout may authorize expiry.
                while time.time()*1000 <= expires+11000: time.sleep(min(1, (expires+11001-time.time()*1000)/1000))
                resource = invoke('expire-request')
                assert resource['phase'] == 'retired' and resource['deadline_ms'] == expires, resource
                for operation in ({'status': '1'}, {'page': {'namespace': '1', 'cursor': first['next']}}):
                    try:
                        client.call(operation)
                        raise AssertionError('expired request disclosed a result')
                    except Failure as error:
                        assert error.detail['err'] in ('QuerySourceUnavailable', 'Rejected', 'AccessDenied'), error
                # Current lifetime still denies after the actual authority/store
                # processes restart from the same durable journal.
                for process in processes[1:]:
                    if process.poll() is None: process.kill(); process.wait(timeout=10)
                authority.kill(); authority.wait(timeout=10)
                fixture.stop(); fixture.start()
                authority = start('node-recovered', [node, str(config)])
                wait_ready(fixture.http, authority, url+'/health')
                try:
                    client.call({'page': {'namespace': '1'}})
                    raise AssertionError('restart revived expired query')
                except Failure as error:
                    assert error.detail['err'] in ('QuerySourceUnavailable', 'Rejected', 'AccessDenied'), error
                print(f'Unified {kind} expiry: prefix/complete reads denied, source pin released, node/store restart preserves expiry; '
                      f'{time.monotonic()-started:.2f}s / backend={"local_directory" if kind == "table" else "ursula"} / {cold.data_objects()} cold objects / {cold.file_bytes()} cold bytes.', flush=True)
            except BaseException:
                for log in logs:
                    log.flush(); log.seek(0)
                    print(log.name, log.read()[-3000:])
                raise
            finally:
                if client: client.close()
                for process in processes:
                    if process.poll() is None: process.kill()
                    process.wait(timeout=10)
                for log in logs: log.close()
