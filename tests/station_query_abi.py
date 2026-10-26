"""Growing ABI query capture, owned IPC and completion after worker/store loss."""
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sys
import threading
import time

from cold_storage import ColdStore
from client_abi_growing import GrowingSystem
from station import frame
from abi_support import rejects
from station_growing_abi import Native, Port
from harness.services import wait_ready
from sdk_scenarios import check
from abi_support import Client, TransitError


def run(node, cli, library, raw_library, host):
    with ColdStore() as cold:
        _run(node, cli, library, raw_library, host, cold)


def _run(node, cli, library, raw_library, host, cold):
    fixture = GrowingSystem(node, cli, storage_config=cold.config())
    fixture.resident_pages = 64  # Match the bounded native query qualification.
    with fixture as system:
        libraries = system.root / 'libraries'
        libraries.mkdir()
        for name, source in (('station', library), ('client', raw_library)):
            (libraries / f'libtransit_{name}.so').symlink_to(Path(source).resolve())
        admin = Client(libraries, system.url)
        sequence = 0

        def command(body):
            nonlocal sequence
            sequence += 1
            return admin.call(admin.prepare(6, system.seed, {
                'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body}))['position']

        def query(kind):
            return read(kind)['body']

        def read(kind):
            return admin.call(admin.prepare(7, system.seed, {
                'realm': 72, 'principal': 0, 'kind': kind}))

        def provision(principal):
            pid = command({'spawn': {}})
            key, public = system.key(f'query-{principal}')
            command({'grant': {'subject': principal, 'public_key': public, 'permissions': 88, 'pid': pid}})
            resource = command({'create_resource': {'writer': pid}})
            for subject in (0, principal):
                command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': 7}})
            command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
            command({'own': {'pid': pid, 'worker': principal, 'expected_generation': 1}})
            return {'profile': 'native_v1', 'realm': 72, 'principal': principal, 'pid': pid,
                    'generation': 2, 'failure_policy': 'stop', 'query_results': True}, key, resource

        service_config, service_key, resource = provision(65536)
        requester_config, requester_key, requests = provision(65537)
        service_pid, requester_pid = service_config['pid'], requester_config['pid']
        fault = {'dropped': None, 'retried': False, 'sealed': False, 'commands': 0}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', system.port, timeout=15)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v1/command':
                        fault['commands'] += 1
                        envelope = json.loads(body)['request']['command']
                        turn = envelope.get('turn', envelope.get('turn_with_versions', {}).get('turn', {}))
                        keys = [bytes.fromhex(m['key']) for m in turn.get('mutations', []) if m]
                        if response.status == 200 and any(key.startswith(b'\x00Qm') for key in keys):
                            fault['sealed'] = True
                        if response.status == 200 and any(key.startswith(b'\x00Qs') for key in keys) and fault['dropped'] is None:
                            fault['dropped'] = body
                            self.close_connection = True
                            return
                        if body == fault['dropped']:
                            assert response.status == 200
                            fault['retried'] = True
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        endpoint = f'http://127.0.0.1:{proxy.server_port}'
        service = requester = port = None
        scopes, initialized = set(), {service_pid: 0, requester_pid: 0}
        correlation = manifest = None
        segments = []
        creation = mutation = table_status = None
        input_counts = {service_pid: 0, requester_pid: 0}

        def dispatch(server):
            frozen = server.pending()
            path = system.root / 'pending.json'
            path.write_bytes(frozen)
            path.chmod(0o600)
            try:
                event = server.dispatch()
            except TransitError as error:
                assert error.status == 6
                assert server.pending() == frozen
                event = server.dispatch()
            assert event['confirmation']['receipt']['position'] > 0
            return event

        def handle(server, event):
            nonlocal correlation, manifest, segments, table_status
            scope, message = event['scope'], event['input']
            input_counts[event['pid']] += 1
            if event['initializing']:
                initialized[event['pid']] += 1
                if event['pid'] == service_pid:
                    server.apply(scope, {'query_policy': {'peer': requester_pid, 'table': '1', 'expected_revision': '0', 'allow': True}})
            payload = bytes.fromhex(message['payload'])
            if event['pid'] == service_pid:
                if message['kind'] == 'call':
                    start = server.apply(scope, {'query_start': {'id': '1', 'plan': {'projection': [0, 1, 2], 'limit': str(2**64 - 1)}}})['query']
                    assert start['correlation'] == str(correlation)
                    assert start['source']['input'] == start['result']
                elif payload == b'create':
                    table_status = server.apply(scope, {'table': creation})['table']['created']
                elif payload == b'mutate':
                    table_status = server.apply(scope, {'table': mutation})['table']['mutation']
                else:
                    assert payload == b'init'
            elif message['kind'] == 'result_complete':
                manifest = server.apply(scope, {'query_completed': str(correlation)})['manifest']
                assert (manifest['source'], manifest['destination'], manifest['basis']['resource']) == (service_pid, requester_pid, resource)
                assert manifest['rows'] == '41' and manifest['segments'] == '6'
                rejects(1, server.apply, scope, {'query_segment': {'correlation': str(correlation), 'ordinal': '6'}})
                for ordinal in range(int(manifest['segments'])):
                    segment = server.apply(scope, {'query_segment': {'correlation': str(correlation), 'ordinal': str(ordinal)}})['segment']
                    assert segment['ordinal'] == str(ordinal) and segment['bytes'] <= 65535
                    ipc = bytes.fromhex(segment['ipc'])
                    assert list(hashlib.sha256(ipc).digest()) == segment['digest']
                    assert len(ipc) == segment['bytes'] and segment['result'] == manifest['result']
                    segments.append(ipc)
                server.apply(scope, {'put': {'key': b'completed'.hex(), 'value': b'yes'.hex()}})
                scopes.add(scope)
            elif payload == b'start':
                correlation = int(server.apply(scope, {'call': {'pid': service_pid, 'value': b'all'.hex()}})['correlation'])
                server.apply(scope, {'put': {'key': b'correlation'.hex(), 'value': correlation.to_bytes(8, 'little').hex()}})
                rejects(1, server.apply, scope, {'query_completed': str(correlation)})
            else:
                raise AssertionError(message)
            server.finish(scope)

        def step(server):
            for _ in range(12):
                before = fault['commands']
                event = server.prepare()
                assert fault['commands'] == before
                if event['event'] == 'idle':
                    return False
                if event['event'] == 'pending':
                    result = dispatch(server)
                    if result['event'] == 'committed':
                        return True
                    assert result['event'] != 'blocked', result
                elif event['event'] == 'ready':
                    handle(server, event)
                else:
                    assert event['event'] == 'progress', event
            raise AssertionError('Unbounded preparation')

        after = None
        def deliver():
            nonlocal after
            position = read({'capabilities': {}})['position']
            batch = query({'outputs': {'after': after, 'position': position}})['outputs']
            for output in batch['entries']:
                if output:
                    assert output['phase'] == 'pending'
                    command({'deliver': output['id']})
                    after = output['id']

        try:
            service = Native(libraries, endpoint, service_key, service_config)
            requester = Native(libraries, endpoint, requester_key, requester_config)
            # Query actions require explicit opt-in even when the library supports them.
            command({'send': {'pid': service_pid, 'value': frame(b'init')}})
            plain = Native(libraries, endpoint, service_key, dict(service_config, query_results=False))
            while (event := plain.prepare())['event'] != 'ready':
                assert event['event'] == 'pending'
                dispatch(plain)
            rejects(1, plain.apply, event['scope'], {'query_completed': '1'})
            plain.discard(event['scope'])
            plain.close()
            assert step(service)
            caps = service.api.call('station_growing_capabilities')
            signed = lambda value: {'value': {'atom': {'signed': str(value)}}}
            schema = dict(definition=caps['definition'], object='1', revision='1', next_column='4',
                columns=[dict(id=str(i), name=name, type={kind: {}}, nullable=i == 2,
                    default={'value': {'atom': {'utf8': 'query'}}} if i == 3 else None, max_characters=None, encoding='plain', collation='none')
                    for i, name, kind in ((1, 'id', 'int64'), (2, 'value', 'int64'), (3, 'label', 'utf8'))], primary_key=['1'])
            creation = {'create': dict(realm=72, resource=resource, schema=schema,
                limits=dict(record_bytes=65536, staging_bytes='8388608', staging_records=1024))}
            for _ in range(512):
                command({'send': {'pid': service_pid, 'value': frame(b'create')}})
                assert step(service)
                if table_status['state'] != 'building':
                    assert table_status['state'] == 'applied', table_status
                    break
            else: raise AssertionError('Table creation continuation budget exhausted')
            for first in range(0, 41, 4):
                rows = []
                for index in range(first, min(first + 4, 41)):
                    key = -(2**63) if index == 0 else index
                    value = {'null': {}} if index % 5 == 0 else signed(2**63 - 1 if index == 1 else 9007199254740993)
                    rows.append([dict(column='1', value={'cell': signed(key)}), dict(column='2', value={'cell': value})])
                operation = command({'send': {'pid': service_pid, 'value': frame(b'mutate')}})
                mutation = {'mutate': dict(realm=72, resource=resource, principal=0, operation=str(operation), schema=schema,
                    mutation=dict(action={'insert': rows}, predicate=None))}
                for part in range(512):
                    if part: command({'send': {'pid': service_pid, 'value': frame(b'mutate')}})
                    assert step(service)
                    if table_status['state'] != 'building':
                        assert table_status['state'] == 'applied' and table_status['counts'] == {'matched': str(len(rows)), 'changed': str(len(rows))}, table_status
                        break
                else: raise AssertionError('Table mutation continuation budget exhausted')
            setup_inputs = input_counts[service_pid]
            command({'send': {'pid': requester_pid, 'value': frame(b'start')}})
            assert step(requester)
            restarted = False
            for _ in range(400):
                deliver()
                step(service)
                step(requester)
                if fault['sealed'] and not restarted:
                    service.close()
                    requester.close()
                    service = requester = None
                    system.authority.kill()
                    system.authority.wait(timeout=10)
                    system.store.stop()
                    system.store.start()
                    system.authority = system.start(system.node, system.config)
                    wait_ready(system.store.http, system.authority, system.url + '/health')
                    for config in (service_config, requester_config):
                        command({'own': {'pid': config['pid'], 'worker': config['principal'], 'expected_generation': config['generation']}})
                        config['generation'] += 1
                    service = Native(libraries, endpoint, service_key, service_config)
                    requester = Native(libraries, endpoint, requester_key, requester_config)
                    restarted = True
                if manifest is not None:
                    deliver()
                    step(service)  # Commit the complete-result acknowledgement.
                    break
            assert restarted and fault['retried'] and manifest is not None
            assert initialized == {service_pid: 1, requester_pid: 1}
            assert input_counts == {service_pid: setup_inputs + 1, requester_pid: 2}, input_counts
            assert sum(map(len, segments)) == int(manifest['bytes'])
            requester.close()
            requester = None
            # IPC is an owned copy and remains valid after the native handle dies.
            from fuze_logical_arrow import arrow_cell, read_stream
            from fuze_file_query import descriptor, cell_bytes
            types = [{'int64': {}}, {'int64': {}}, {'utf8': {}}]
            fields = [dict(name=name, type=typ, nullable=index == 1, optional=False)
                      for index, (name, typ) in enumerate(zip(('id', 'value', 'label'), types))]
            rows = []
            for ipc in segments:
                physical, batches = read_stream(ipc)
                assert physical.metadata[b'transit.logical_schema'] == descriptor({'structure': fields}).hex().encode()
                for batch in batches:
                    for index in range(batch.num_rows):
                        ordinal = len(rows)
                        key = -(2**63) if ordinal == 0 else ordinal
                        value = {'null': {}} if ordinal % 5 == 0 else signed(2**63 - 1 if ordinal == 1 else 9007199254740993)
                        expected = (signed(key), value, {'value': {'atom': {'utf8': 'query'}}})
                        row = tuple(arrow_cell(batch.column(column), index, typ) for column, typ in enumerate(types))
                        assert row == tuple(cell_bytes(cell, typ) for cell, typ in zip(expected, types))
                        rows.append(row)
            assert len(rows) == 41
            api = service.api
            cell = api.call('station_growing_arrow_cell', segments[0], len(segments[0]), 1, 1)
            assert cell['value'] == signed(2**63 - 1) and cell['name'] == 'value'
            rejects(1, api.call, 'station_growing_arrow_cell', segments[0][:-8], len(segments[0]) - 8, 0, 0)
            rejects(1, api.call, 'station_growing_arrow_cell', bytes(65536), 65536, 0, 0)
            config = system.root / 'query-host.json'
            config.write_text(json.dumps({'url': endpoint, 'seed_file': str(requester_key), 'growing_server': requester_config}))
            port = Port(host, str(config))
            command({'send': {'pid': requester_pid, 'value': frame(b'inspect')}})
            while (event := port.call({'growing_prepare': time.time_ns() // 1_000_000 + 30000}))['event'] != 'ready':
                assert event['event'] == 'pending'
                port.call({'growing_dispatch': {}})
            scope = event['scope']
            assert port.call({'growing_apply': {'scope': scope, 'action': {'query_completed': str(correlation)}}})['manifest'] == manifest
            first = port.call({'growing_apply': {'scope': scope, 'action': {'query_segment': {'correlation': str(correlation), 'ordinal': '0'}}}})['segment']
            assert bytes.fromhex(first['ipc']) == segments[0]
            assert port.call({'growing_arrow_cell': {'ipc': first['ipc'], 'row': 1, 'column': 1}}) == cell
            port.call({'growing_discard': scope})
            rejects(13, port.call, {'growing_apply': {'scope': scope, 'action': {'query_completed': str(correlation)}}})
            command({'grant_resource': {'resource': requests, 'subject': 65537, 'permissions': 0}})
            rejects(4, port.call, {'growing_prepare': time.time_ns() // 1_000_000 + 30000})
            check('query-abi', {
                'rows': len(rows), 'segments': len(segments), 'exact_retry': fault['retried'],
                'restarted_after_seal': restarted, 'service_initializations': initialized[service_pid],
                'requester_initializations': initialized[requester_pid], 'owned_ipc_after_close': requester is None,
                'port_bytes_equal': bytes.fromhex(first['ipc']) == segments[0],
                'stale_scope_status': 13, 'revoked_result_status': 4,
            })
            assert cold.data_objects() > 0
            print(f'Growing query ABI storage: {cold.data_objects()} cold objects, 8 MiB hot memory, {fixture.resident_pages} authority pages, {setup_inputs} setup callbacks.')
            print('Growing query ABI: three typed columns, six bounded IPC segments, typed metadata, opt-in, exact retry, worker/store restart, stale scope, revocation and independent Arrow decoding passed.')
        finally:
            if port:
                port.close()
            if service:
                service.close()
            if requester:
                requester.close()
            admin.close()
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)


if __name__ == '__main__':
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdks/python/transit-station'))
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdks/python/transit-client'))
    run(*sys.argv[1:])
