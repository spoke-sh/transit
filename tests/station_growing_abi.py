"""Growing foreign turns: explicit dispatch, scoped pages and exact recovery."""
import ctypes as c
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import select
import subprocess
import sys
import threading
import time

from client_abi_growing import GrowingSystem
from storage import wait_ready
from station import frame
from station_abi import ROOT, rejects
from transit_station import Client, TransitError, _Library, _json, _seed


class Native:
    def __init__(self, libraries, url, seed, config):
        self.api = _Library(libraries, 'station')
        self.pointer = c.c_void_p()
        data, endpoint, key = _json(config), url.encode(), _seed(seed)
        try:
            status = self.api.lib.station_growing_create(1, endpoint, len(endpoint), key,
                data, len(data), c.byref(self.pointer))
            if status:
                raise TransitError(status)
        finally:
            c.memset(key, 0, 32)

    def close(self):
        self.api.lib.station_growing_destroy(self.pointer)
        self.pointer = c.c_void_p()

    def prepare(self):
        return self.api.call('station_growing_prepare', self.pointer, time.time_ns() // 1_000_000 + 30000)

    def dispatch(self):
        return self.api.call('station_growing_dispatch', self.pointer)

    def apply(self, scope, action):
        data = _json(action)
        return self.api.call('station_growing_apply', self.pointer, scope, data, len(data))

    def finish(self, scope, failed=False):
        return self.api.call('station_growing_finish_result', self.pointer, scope, int(failed))

    def discard(self, scope):
        status = self.api.lib.station_growing_discard(self.pointer, scope)
        if status:
            raise TransitError(status)

    def pending(self):
        pointer = c.c_void_p()
        status = self.api.lib.station_growing_pending(self.pointer, c.byref(pointer))
        try:
            if status:
                raise TransitError(status)
            return c.string_at(self.api.data(pointer), self.api.size(pointer))
        finally:
            self.api.destroy(pointer)


class Port:
    def __init__(self, host, config):
        self.child = subprocess.Popen([host, config], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)

    def call(self, request):
        self.child.stdin.write(_json(request) + b'\n')
        assert select.select([self.child.stdout], [], [], 15)[0], 'Native port timed out'
        line = self.child.stdout.readline(540672)
        assert line.endswith(b'\n'), 'Incomplete native port response'
        result = json.loads(line)
        if result['status']:
            raise TransitError(result['status'], result['value'])
        return result['value']

    def close(self):
        self.child.stdin.close()
        try:
            assert self.child.wait(timeout=10) == 0
        finally:
            if self.child.poll() is None:
                self.child.kill()
                self.child.wait(timeout=5)
            self.child.stdout.close()


def run(node, cli, library, raw_library, host):
    with GrowingSystem(node, cli) as system:
        libraries = system.root / 'libraries'
        libraries.mkdir()
        for name, source in (('station', library), ('client', raw_library)):
            (libraries / f'libtransit_{name}.so').symlink_to(Path(source).resolve())
        root_client = Client(libraries, system.url)
        sequence = 0

        def command(body):
            nonlocal sequence
            sequence += 1
            return root_client.call(root_client.prepare(6, system.seed, {
                'version': 3, 'realm': 72, 'principal': 0, 'sequence': sequence,
                'command': body}))['position']

        def query(kind):
            return root_client.call(root_client.prepare(7, system.seed, {
                'version': 3, 'realm': 72, 'principal': 0, 'kind': kind}))['body']

        def provision(principal, spawn=None):
            pid = command({'spawn': spawn or {}})
            seed, public = system.key(f'growing-{principal}')
            command({'grant': {'subject': principal, 'public_key': public, 'permissions': 88, 'pid': pid}})
            resource = command({'create_resource': {'writer': pid}})
            for subject in (0, principal):
                command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': 7}})
            command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
            command({'own': {'pid': pid, 'worker': principal, 'expected_generation': 1}})
            return pid, resource, seed

        fault = {'commands': [], 'drop': False, 'bad_read': False}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', system.port, timeout=10)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v3/command':
                        fault['commands'].append(body)
                        if fault['drop'] and response.status == 200:
                            fault['drop'] = False
                            self.close_connection = True
                            return
                    elif self.path == '/v3/query' and fault['bad_read'] and response.status == 200:
                        fault['bad_read'] = False
                        result = json.loads(data)
                        result['realm'] += 1
                        data = _json(result)
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        server = None
        port = None
        saved = system.root / 'pending.json'
        observed_kinds = set()

        def dispatch(server):
            frozen = server.pending()
            count = len(fault['commands'])
            for _ in range(2):
                event = server.prepare()
                assert event['event'] == 'pending'
                observed_kinds.add(event['pending_kind'])
                assert event['pending_input'] > 0
                assert server.pending() == frozen
            assert len(fault['commands']) == count, 'Preparation submitted before persistence'
            saved.write_bytes(frozen)
            saved.chmod(0o600)
            result = server.dispatch()
            assert result['confirmation']['receipt']['position'] > 0
            assert result['confirmation']['input'] == event['pending_input']
            for _ in range(2):
                observed = server.api.call('station_growing_confirmation', server.pointer)
                assert observed['confirmation'] == result['confirmation']
            assert len(fault['commands']) == count + 1
            return result

        def ready(server):
            for _ in range(12):
                event = server.prepare()
                if event['event'] == 'ready':
                    return event
                assert event['event'] in ('pending', 'progress'), event
                if event['event'] == 'pending':
                    dispatch(server)
            raise AssertionError('No scoped turn')

        def finish(server, scope):
            server.finish(scope)
            rejects(13, server.apply, scope, {'get': b'local'.hex()})
            result = dispatch(server)
            assert result['event'] == 'committed'
            return result

        try:
            pid, resource, seed = provision(65536)
            config = {'profile': 'growing_v3', 'realm': 72, 'principal': 65536,
                'pid': pid, 'generation': 2, 'failure_policy': 'stop'}
            for invalid in ({**config, 'profile': 'legacy_v2'}, {**config, 'principal': 2**53},
                            {key: value for key, value in config.items() if key != 'profile'}):
                rejects(1, Native, libraries, url, seed, invalid)
            command({'send': {'pid': pid, 'value': frame(b'init')}})
            server = Native(libraries, url, seed, config)
            caps = server.api.call('station_growing_capabilities')
            assert caps['gated_dispatch'] and caps['paged_state'] and caps['query_results']
            initial = ready(server)
            assert initial['initializing'] and initial['scope'] > 0
            scope = initial['scope']
            assert server.apply(scope, {'budgets': {}})['budgets']['mutations'] == 3
            server.apply(scope, {'put': {'key': b'local'.hex(), 'value': b'private'.hex()}})
            assert server.apply(scope, {'budgets': {}})['budgets']['mutations'] == 2
            assert rejects(1, server.finish, scope, True)['err'] == 'ForeignHandlerFailure'
            assert query({'process': pid})['process']['process']['failure'] is None
            event = ready(server)
            assert event['scope'] != scope and event['initializing']
            rejects(13, server.apply, scope, {'get': b'local'.hex()})
            scope = event['scope']
            assert server.apply(scope, {'get': b'local'.hex()}) == {'value': None}
            server.apply(scope, {'table_create': {'id': 1, 'key_name': 'id', 'value_name': 'value', 'value_type': 'int64'}})
            server.apply(scope, {'table_write': {'id': 1, 'mode': 'insert',
                'row': {'key': str(-(2**63)), 'value': {'int64': str(2**63-1)}}}})
            server.finish(scope)
            frozen = server.pending()
            saved.write_bytes(frozen)
            saved.chmod(0o600)
            fault['drop'] = True
            rejects(6, server.dispatch)
            assert server.pending() == frozen and not fault['drop']
            sent = fault['commands'][-1]
            server.close()
            server = None
            system.authority.kill()
            system.authority.wait(timeout=10)
            system.store.stop()
            system.store.start()
            system.authority = system.start(node, system.config)
            wait_ready(system.store.http, system.authority, system.url + '/health')
            receipt = json.loads(subprocess.check_output([sys.executable, '-B',
                str(ROOT / 'tests/client_abi.py'), '--retry', str(Path(raw_library).resolve()), url, str(saved)], timeout=15))
            assert receipt['position'] > 0 and sent == fault['commands'][-1]
            assert query({'process': pid})['process']['process']['consumed'] == 1
            command({'own': {'pid': pid, 'worker': 65536, 'expected_generation': 2}})
            config['generation'] = 3
            server = Native(libraries, url, seed, config)
            for batch in range(10):
                command({'send': {'pid': pid, 'value': frame(b'batch')}})
                event = ready(server)
                assert not event['initializing']
                for index in range(batch * 4, batch * 4 + 4):
                    server.apply(event['scope'], {'table_write': {'id': 1, 'mode': 'insert',
                        'row': {'key': str(index), 'value': {'int64': '9007199254740993'}}}})
                finish(server, event['scope'])
            command({'send': {'pid': pid, 'value': frame(b'pages')}})
            event = ready(server)
            cursor, rows, pages = None, [], 0
            while True:
                result = server.apply(event['scope'], {'table_page': {'id': 1, 'cursor': cursor}})['rows']
                rows.extend(row for row in result['rows'] if row is not None)
                pages += 1
                cursor = result['next']
                if pages == 1:
                    first_cursor = cursor
                    rejects(1, server.apply, event['scope'], {'table_page': {'id': 1, 'cursor': ' ' + cursor}})
                if cursor is None:
                    break
            assert len(rows) == 41 and pages == 6
            assert rows[0] == {'key': str(-(2**63)), 'value': {'int64': str(2**63-1)}}
            assert rows[-1]['value'] == {'int64': '9007199254740993'}
            version = server.apply(event['scope'], {'retain': {}})['version']
            finish(server, event['scope'])
            command({'send': {'pid': pid, 'value': frame(b'old-cursor')}})
            event = ready(server)
            rejects(1, server.apply, event['scope'], {'table_page': {'id': 1, 'cursor': first_cursor}})
            server.apply(event['scope'], {'table_write': {'id': 1, 'mode': 'insert',
                'row': {'key': str(2**63-1), 'value': {'int64': '-9007199254740993'}}}})
            rejects(1, server.apply, event['scope'], {'table_page': {'id': 1}})
            retained = server.apply(event['scope'], {'table_page': {'id': 1, 'version': version}})['rows']
            assert len([row for row in retained['rows'] if row is not None]) == 8
            schema = server.apply(event['scope'], {'table_schema': {'id': 1, 'version': version}})['schema']
            assert (schema['id'], schema['key_name'], schema['value_name'], schema['value_type']) == (1, 'id', 'value', 'int64')
            assert schema['basis'] == retained['basis']
            point = server.apply(event['scope'], {'version_table_get': {'version': version, 'id': 1, 'key': str(-(2**63))}})
            assert point == {'row': rows[0]}
            assert server.apply(event['scope'], {'version_table_get': {'version': version, 'id': 1, 'key': str(2**63-1)}}) == {'row': None}
            finish(server, event['scope'])
            command({'send': {'pid': pid, 'value': frame(b'poison')}})
            event = ready(server)
            fault['bad_read'] = True
            rejects(8, server.apply, event['scope'], {'get': b'remote'.hex()})
            rejects(8, server.apply, event['scope'], {'put': {'key': b'local'.hex(), 'value': '01'}})
            assert rejects(8, server.finish, event['scope'])['err'] == 'InvalidAuthorityResponse'
            assert query({'process': pid})['process']['process']['failure'] is None
            server.close()
            server = None
            command({'own': {'pid': pid, 'worker': 65536, 'expected_generation': 3}})
            config['generation'] = 4
            port_config = system.root / 'host.json'
            port_config.write_text(json.dumps({'url': url, 'seed_file': str(seed), 'growing_server': config}))
            port = Port(host, port_config)
            assert port.call({'hello': {}}) == {'host_version': 1, 'station_version': 1, 'transit_version': 1}
            assert port.call({'growing_capabilities': {}}) == caps
            for _ in range(10):
                result = port.call({'growing_prepare': time.time_ns() // 1_000_000 + 30000})
                if result['event'] == 'ready':
                    break
                if result['event'] == 'pending':
                    pending = port.call({'growing_pending': {}})
                    assert json.loads(pending)['operation']['growing_command']['request']['principal'] == 65536
                    port.call({'growing_dispatch': {}})
            else:
                raise AssertionError('Port did not expose a growing turn')
            scope = result['scope']
            assert port.call({'growing_apply': {'scope': scope, 'action': {'get': b'local'.hex()}}}) == {'value': None}
            correlation = port.call({'growing_apply': {'scope': scope, 'action': {'call': {'pid': pid, 'value': ''}}}})['correlation']
            assert port.call({'growing_apply': {'scope': scope, 'action': {'cancel': correlation}}}) == {'cancelled': True}
            assert port.call({'growing_apply': {'scope': scope, 'action': {'cancel': correlation}}}) == {'cancelled': False}
            port.call({'growing_discard': scope})
            rejects(13, port.call, {'growing_apply': {'scope': scope, 'action': {'get': b'local'.hex()}}})
            port.close()
            port = None
            server = Native(libraries, url, seed, {**config, 'generation': 3})
            rejects(11, server.prepare)
            server.close()
            server = None
            command({'revoke': 65536})
            server = Native(libraries, url, seed, config)
            rejects(4, server.prepare)
            with Client(libraries, url) as raw:
                rejects(4, raw.call, frozen.decode())
            server.close()
            server = None
            now = time.time_ns() // 1_000_000
            finite, _, finite_seed = provision(65537, {'work_before_ms': now + 120000, 'settle_before_ms': now + 150000})
            command({'send': {'pid': finite, 'value': frame(b'permit')}})
            server = Native(libraries, url, finite_seed, {**config, 'principal': 65537, 'pid': finite, 'generation': 2})
            ready(server)
            assert observed_kinds == {'open', 'commit', 'permit'}
            server.close()
            server = None

            # Native publication and HTTP call composition use the same growing
            # turn gate. The host never implements digests or admission framing.
            caller, resource, caller_seed = provision(65538)
            destination = command({'spawn': {}})
            server = Native(libraries, url, caller_seed, {**config, 'principal': 65538, 'pid': caller, 'generation': 2})
            assert caps['publications'] and caps['http_requests'] and caps['http_release'] and caps['http_followup'] and caps['publication_chunk_bytes'] == 256
            document = _json({'prepare': {'resource': resource, 'namespace': str(2**64-1),
                'request': {'method': 'POST', 'target': [{'literal': '/write'}]}, 'body': '00ff01',
                'endpoint_revision': '7', 'reconcile_before_ms': now + 120000}})
            prepared = server.api.call('station_http_codec', document, len(document))['prepared']
            namespace = str(2**64-1)
            def operation(action):
                command({'send': {'pid': caller, 'value': frame(b'publication-step')}})
                scope = ready(server)['scope']
                result = server.apply(scope, action)
                finish(server, scope)
                return result
            operation({'publication_create': {'namespace': namespace, 'record_bytes': 8192, 'staging_bytes': '16384', 'staging_records': 2}})
            for identity, data, spec in (('1', bytes.fromhex(prepared['metadata']), prepared['metadata_spec']), ('2', b'\x00\xff\x01', prepared['body_spec'])):
                operation({'publication_begin': {'namespace': namespace, 'id': identity, 'spec': spec}})
                for offset in range(0, len(data), 256):
                    chunk = {'publication_append': {'namespace': namespace, 'id': identity, 'index': offset // 256, 'bytes': data[offset:offset+256].hex()}}
                    assert operation(chunk) == {'publication': 'changed'}
                    assert operation(chunk) == {'publication': 'duplicate'}
                command({'send': {'pid': caller, 'value': frame(b'incomplete')}})
                scope = ready(server)['scope']
                assert rejects(1, server.apply, scope, {'http_call': {'pid': destination, 'reference': prepared['reference']}})['err'] == 'PublicationNotPublished'
                assert rejects(1, server.apply, scope, {'http_followup': {'pid': destination, 'resource': 7, 'parent': str(2**64-1), 'reason': 'retry', 'reference': prepared['reference']}})['err'] == 'PublicationNotPublished'
                finish(server, scope)
                operation({'publication_publish': {'namespace': namespace, 'id': identity}})
            command({'send': {'pid': caller, 'value': frame(b'http-call')}})
            scope = ready(server)['scope']
            before = server.apply(scope, {'budgets': {}})
            changed = bytearray.fromhex(prepared['reference']); changed[24] ^= 1
            assert rejects(1, server.apply, scope, {'http_call': {'pid': destination, 'reference': changed.hex()}})['err'] == 'InvalidHttpRequestReference'
            assert server.apply(scope, {'budgets': {}}) == before
            correlation = server.apply(scope, {'http_call': {'pid': destination, 'reference': prepared['reference']}})['correlation']
            assert int(correlation) > 0
            finish(server, scope)
            outgoing = next(item for item in query({'outputs': {}})['outputs']['entries'] if item and item['source'] == caller)
            assert outgoing['destination'] == destination
            assert bytes.fromhex(outgoing['value'])[13:] == bytes.fromhex(prepared['reference'])
            # Disposal is an ordinary durable call even without transcript read
            # access. The service, not the caller's foreign-resource read scope,
            # authenticates the recorded holder and current admission policy.
            command({'send': {'pid': caller, 'value': frame(b'http-release')}})
            scope = ready(server)['scope']
            before = server.apply(scope, {'budgets': {}})
            assert rejects(1, server.apply, scope, {'http_release': {'pid': destination,
                'resource': 7, 'exchange': '0'}})['err'] == 'InvalidHttpRelease'
            assert server.apply(scope, {'budgets': {}}) == before
            released = server.apply(scope, {'http_release': {'pid': destination,
                'resource': 7, 'exchange': str(2**64-1)}})['correlation']
            assert int(released) > int(correlation)
            finish(server, scope)
            position = root_client.call(root_client.prepare(7, system.seed, {
                'version': 3, 'realm': 72, 'principal': 0, 'kind': {'capabilities': {}}}))['position']
            disposal = next(item for item in query({'outputs': {'after': outgoing['id'], 'position': position}})['outputs']['entries'] if item and item['source'] == caller)
            release_fixture = json.loads((Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-http/src/release-fixtures.json').read_text())
            assert disposal['destination'] == destination
            assert bytes.fromhex(disposal['value'])[13:] == bytes.fromhex(release_fixture['request'])
            command({'send': {'pid': caller, 'value': frame(b'http-followup')}})
            scope = ready(server)['scope']
            followup = {'pid': destination, 'resource': 7, 'parent': str(2**64-1), 'reason': 'retry', 'reference': prepared['reference']}
            before = server.apply(scope, {'budgets': {}})
            assert rejects(1, server.apply, scope, {'http_followup': {**followup, 'reference': changed.hex()}})['err'] == 'InvalidHttpRequestReference'
            assert rejects(1, server.apply, scope, {'http_followup': {**followup, 'parent': '0'}})['err'] == 'InvalidHttpFollowup'
            assert server.apply(scope, {'budgets': {}}) == before
            linked = server.apply(scope, {'http_followup': followup})['correlation']
            assert int(linked) > int(released)
            finish(server, scope)
            document = _json({'followup': {k: v for k, v in followup.items() if k != 'pid'}})
            encoded = server.api.call('station_http_codec', document, len(document))['followup']
            position = root_client.call(root_client.prepare(7, system.seed, {
                'version': 3, 'realm': 72, 'principal': 0, 'kind': {'capabilities': {}}}))['position']
            linked_output = next(item for item in query({'outputs': {'after': disposal['id'], 'position': position}})['outputs']['entries'] if item and item['source'] == caller)
            assert linked_output['destination'] == destination
            assert bytes.fromhex(linked_output['value'])[13:] == bytes.fromhex(encoded)
            assert bytes.fromhex(encoded)[:21] == b'HTU1' + (7).to_bytes(8, 'little') + (2**64-1).to_bytes(8, 'little') + b'\x01'
            assert bytes.fromhex(encoded)[21:] == bytes.fromhex(prepared['reference'])
            operation({'publication_retire': {'namespace': namespace, 'id': '1'}})
            assert operation({'publication_collect': {'namespace': namespace, 'id': '1'}}) == {'collected': True}

            # The shared bounded uploader owns its namespace and resumes after
            # loss of the host and a fresh owner. Changed identity cannot use
            # partially staged bytes, including after logical retirement.
            source = bytes((index * 17 + 3) % 256 for index in range(513))
            request = {'resource': resource, 'namespace': str(2**64-2),
                'request': {'method': 'POST', 'target': [{'literal': '/write'}]},
                'body': source.hex(), 'endpoint_revision': '7',
                'reconcile_before_ms': now + 120000}
            document = _json({'prepare': request})
            prepared = server.api.call('station_http_codec', document, len(document))['prepared']
            stage = {'http_stage': {'reference': prepared['reference'],
                'metadata': prepared['metadata'], 'body': source.hex()}}
            assert operation(stage) == {'staged': False}
            assert operation(stage) == {'staged': False}
            assert operation(stage) == {'staged': False}
            server.close()
            server = None
            command({'own': {'pid': caller, 'worker': 65538, 'expected_generation': 2}})
            server = Native(libraries, url, caller_seed, {**config, 'principal': 65538, 'pid': caller, 'generation': 3})
            document = _json({'prepare': {**request, 'endpoint_revision': '8'}})
            changed = server.api.call('station_http_codec', document, len(document))['prepared']
            command({'send': {'pid': caller, 'value': frame(b'changed-upload')}})
            scope = ready(server)['scope']
            before = server.apply(scope, {'budgets': {}})
            assert rejects(1, server.apply, scope, {'http_stage': {
                **stage['http_stage'], 'reference': changed['reference']}})['err'] == 'HttpRequestIdentityConflict'
            assert server.apply(scope, {'budgets': {}}) == before
            finish(server, scope)
            for _ in range(16):
                if operation(stage)['staged']:
                    break
            else:
                raise AssertionError('HTTP upload did not complete within its bounded steps')
            command({'send': {'pid': caller, 'value': frame(b'resumed-call')}})
            scope = ready(server)['scope']
            assert server.apply(scope, stage) == {'staged': True}
            resumed = server.apply(scope, {'http_call': {'pid': destination,
                'reference': prepared['reference']}})['correlation']
            assert int(resumed) > int(correlation)
            finish(server, scope)
            operation({'publication_retire': {'namespace': request['namespace'], 'id': '1'}})
            command({'send': {'pid': caller, 'value': frame(b'retired-upload')}})
            scope = ready(server)['scope']
            assert rejects(1, server.apply, scope, stage)['err'] == 'PublicationNotPublished'
            finish(server, scope)
        finally:
            if port is not None:
                port.close()
            if server is not None:
                server.close()
            root_client.close()
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
    print('Growing Station ABI: gated controls, scoped pages, exact host/disk recovery, poison/stop, wide values, publication and validated HTTP calls passed')


if __name__ == '__main__':
    run(*sys.argv[1:])
