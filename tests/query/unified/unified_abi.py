"""Query-only native/port owners for the real signed v1 authority schedule."""
import ctypes as c
import json
from pathlib import Path
import select
import subprocess
import time


class Failure(Exception):
    def __init__(self, status, detail):
        super().__init__(status, detail)
        self.status, self.detail = status, detail


def bounded_read(function):
    """Retry reads or pure preparation after capacity/stale-cut refusal; never send."""
    def call(self, action):
        operation = next(iter(action))
        for attempt in range(12):
            try:
                return function(self, action)
            except Failure as failure:
                if (operation not in {'describe', 'inspect', 'compile', 'status', 'page', 'observe', 'next', 'prepare', 'authorize'}
                        or not isinstance(failure.detail, dict)
                        or failure.detail.get('protocol_error') not in {'HttpCapacity', 'QueryExpired', 'StaleStateResource'}
                        or attempt == 11):
                    raise
                time.sleep(.05)
        raise AssertionError('read retry budget exhausted')
    return call


class Native:
    def __init__(self, library, url, connection=None, *, relational=None, tables=None, seed_byte=10):
        self.api = api = c.CDLL(str(Path(library).resolve()))
        api.station_unified_query_create.argtypes = [c.c_uint32, c.c_char_p, c.c_size_t, c.c_void_p, c.c_char_p, c.c_size_t, c.POINTER(c.c_void_p)]
        api.station_unified_query_create.restype = c.c_uint32
        api.station_unified_query_destroy.argtypes = [c.c_void_p]
        api.station_unified_query_destroy.restype = None
        api.station_unified_query_call.argtypes = [c.c_void_p, c.c_char_p, c.c_size_t, c.POINTER(c.c_void_p)]
        api.station_unified_query_call.restype = c.c_uint32
        api.station_buffer_data.argtypes = [c.c_void_p]
        api.station_buffer_data.restype = c.c_void_p
        api.station_buffer_size.argtypes = [c.c_void_p]
        api.station_buffer_size.restype = c.c_size_t
        api.station_buffer_destroy.argtypes = [c.c_void_p]
        api.station_buffer_destroy.restype = None
        self.pointer = c.c_void_p()
        endpoint = url.encode()
        config = json.dumps(dict(connection=connection, relational=relational, tables=tables, timeout_ms=10000)).encode()
        seed = c.create_string_buffer(bytes([seed_byte])*32, 32)
        status = api.station_unified_query_create(1, endpoint, len(endpoint), seed, config, len(config), c.byref(self.pointer))
        assert status == 0
        if connection is not None:
            assert self.call({'capabilities': {}})['capabilities']['version'] == 1
        else:
            assert self.call({'relational': {'capabilities': {}}})['relational']['capabilities']['interactive']

    @bounded_read
    def call(self, action):
        request = json.dumps(action).encode()
        output = c.c_void_p()
        status = self.api.station_unified_query_call(self.pointer, request, len(request), c.byref(output))
        try:
            value = json.loads(c.string_at(self.api.station_buffer_data(output), self.api.station_buffer_size(output))) if output.value else None
        finally:
            self.api.station_buffer_destroy(output)
        if status: raise Failure(status, value)
        return value

    def close(self):
        if self.pointer.value:
            self.api.station_unified_query_destroy(self.pointer)
            self.pointer = c.c_void_p()


class Port:
    def __init__(self, host, root, url, connection=None, *, relational=None, tables=None):
        config = root / 'query-client-port.json'
        config.write_text(json.dumps(dict(url=url, seed_file=str(root / 'caller.seed'),
            query_client=dict(connection=connection, relational=relational, tables=tables, timeout_ms=10000))))
        self.child = subprocess.Popen([host, str(config)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        if connection is not None:
            assert self.call({'capabilities': {}})['capabilities']['version'] == 1
        else:
            assert self.call({'relational': {'capabilities': {}}})['relational']['capabilities']['interactive']

    @bounded_read
    def call(self, action):
        self.child.stdin.write(json.dumps({'unified_query': action})+'\n')
        self.child.stdin.flush()
        assert select.select([self.child.stdout], [], [], 90)[0], 'query port response timed out'
        value = json.loads(self.child.stdout.readline())
        if value['status']: raise Failure(value['status'], value['value'])
        return value['value']

    def close(self):
        try:
            if self.child.poll() is None:
                self.child.stdin.write('{"shutdown":{}}\n')
                self.child.stdin.flush()
                assert self.child.wait(timeout=10) == 0
        finally:
            if self.child.poll() is None:
                self.child.kill()
                self.child.wait(timeout=10)
            self.child.stdin.close()
            self.child.stdout.close()


def authorize_capture(client, root, operation, description=None):
    """Authorize new work once; callers retain these bytes throughout upload."""
    if description is None:
        description = (root / 'bundle-description.bin').read_bytes().hex()
    capture = json.loads((root / 'client.json').read_text()).get('capture')
    if capture is not None:
        capture = dict(capture, operation=str(operation), selection='current')
    return client.call({'authorize': dict(bundle=description, capture=capture)})['authorized']


def upload(client, root):
    bundle = (root / 'bundle.bin').read_bytes().hex()
    for _ in range(1000):
        prepared = client.call({'next': dict(namespace='1', bundle=bundle)})['prepared']
        if prepared is None: return client.call({'status': '1'})['status']
        # This opaque canonical string also parses as native Prepared for an
        # independently restarted Zig caller. Persist before every dispatch.
        (root / 'pending.json').write_text(prepared)
        receipt = client.call({'submit': prepared})['receipt']
        until = time.monotonic()+60
        while True:
            observed = client.call({'observe': receipt['position']})['observation']
            if 'committed' in observed: break
            assert 'pending' in observed, observed
            assert time.monotonic() < until
            time.sleep(0.02)
    raise AssertionError('finite native upload exceeded its command budget')


def verify(native, port, root, pages):
    cursor = None
    for ordinal in range(pages):
        owner = native if ordinal % 2 == 0 else port
        result = owner.call({'page': dict(namespace='1', cursor=cursor)})['page']
        assert result['ordinal'] == str(ordinal)
        assert bytes.fromhex(result['ipc']) == (root / f'result-{ordinal}.arrow').read_bytes()
        assert result['manifest']['segments'] == str(pages)
        cursor = result['next']
        assert (cursor is None) == (ordinal+1 == pages)
