"""A shared real-authority raw SDK schedule; language adapters install consumers."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import tempfile
import threading
import time

def run(node, cli, raw_library, install, label):
    from client_abi_growing import GrowingSystem
    from client_abi import Native
    from sdk_scenarios import check
    with tempfile.TemporaryDirectory(prefix='transit-client-consumer-') as temporary, GrowingSystem(node, cli) as system:
        consumer_root = Path(temporary)
        invoke_consumer = install(consumer_root)
        native = Native(raw_library)
        admin = native.client(system.url)
        root_seed = bytes.fromhex(system.seed.read_text().strip())
        sequence = 0
        def command(body):
            nonlocal sequence
            sequence += 1
            operation = native.prepare(6, root_seed, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body})
            try:
                return native.call(admin, operation)['position']
            finally:
                native.lib.transit_operation_destroy(operation)
        pid = command({'spawn': {}})
        key, public = system.key('python-sdk')
        original_seed = key.read_bytes()
        command({'grant': {'subject': 65536, 'public_key': public, 'permissions': 255}})
        unrelated = native.prepare(6, root_seed, {'realm': 72, 'principal': 0, 'sequence': 3, 'command': {'spawn': {}}})
        spawn = consumer_root / 'spawn.json'
        spawn.write_bytes(native.export(unrelated))
        native.lib.transit_operation_destroy(unrelated)
        accepted = consumer_root / 'accepted'
        fault = {'drop': True, 'delay': False, 'bodies': []}
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', system.port, timeout=10)
                try:
                    # Preserve the request target; self.path can normalize double slashes.
                    target = self.raw_requestline.split()[1].decode('ascii')
                    connection.request('POST', target, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v3/command':
                        fault['bodies'].append(body)
                    if self.path == '/v3/command' and fault['drop'] and response.status == 200:
                        fault['drop'] = False
                        self.close_connection = True
                        return
                    if fault['delay']:
                        if self.path == '/v3/command' and response.status == 200:
                            accepted.touch()
                        time.sleep(0.6)
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        config = consumer_root / 'config.json'
        config.write_text(json.dumps({'url': f'http://127.0.0.1:{proxy.server_port}', 'pid': pid,
                                      'seed': str(key), 'pending': str(consumer_root / 'pending.json'), 'spawn': str(spawn), 'accepted': str(accepted)}))
        def invoke(mode):
            return invoke_consumer(mode, config)
        try:
            invoke('first')
            key.unlink()
            receipt = json.loads(invoke('recover'))
            assert receipt['position'] > 0 and fault['bodies'][0] == fault['bodies'][1]
            key.write_bytes(original_seed)
            fault['delay'] = True
            ownership = json.loads(invoke('async'))
            if 'scenario' in ownership:
                check(ownership['scenario'], ownership['observations'])
            else:
                check('local-cancellation-disposal', ownership)
            fault['delay'] = False
            command({'revoke': 65536})
            invoke('denied')
            read = native.prepare(7, root_seed, {'realm': 72, 'principal': 0, 'kind': {'process': pid}})
            try:
                state = native.call(admin, read)['body']['process']
                assert state['process']['admitted'] == 2 and state['process']['consumed'] == 0
                assert bytes.fromhex(state['input']['value']) == b'wide'
            finally:
                native.lib.transit_operation_destroy(read)
            print(f'{label} public client: clean independent artifacts, typed bounds, owned bytes, lost receipt, seedless restart, native classification, owned I/O/disposal and revoked retry passed.')
        finally:
            native.lib.transit_client_destroy(admin)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
