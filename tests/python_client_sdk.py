"""Install public raw-client wheels outside the checkout and exercise real I/O."""
import asyncio
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time


def consumer(mode, config_file):
    import transit_client
    from transit_client import Client, AsyncClient, ClientConfig, Credential, ProcessRef
    from transit_client.errors import Busy, Closed, UncertainOperation, UnsupportedCapability, IncompatibleNative
    config = json.loads(Path(config_file).read_text())
    assert Path(transit_client.__file__).is_relative_to(Path(sys.prefix))
    assert 'transit_station' not in sys.modules
    peer = ProcessRef(72, config['pid'])
    options = ClientConfig(config['url'], 'growing_v3', timeout_ms=3000)
    pending_file = Path(config['pending'])
    credential = Credential(72, 65536, Path(config['seed']))
    for invalid in [True, -1, 0, 2**53]:
        try:
            ProcessRef(72, invalid)
        except ValueError:
            pass
        else:
            raise AssertionError('Unvalidated ID')
    try:
        Client.open(ClientConfig(config['url'], 'growing_v3', native_directory=Path('/missing-transit')))
    except IncompatibleNative:
        pass
    else:
        raise AssertionError('Missing artifacts accepted')
    if mode == 'first':
        with Client.open(options) as client:
            caps = client.capabilities(credential)
            assert caps.realm == peer.realm and caps.principal_sequence == 0
            assert caps.page_size == 8 and caps.retained_versions
            mutable = bytearray(b'wide')
            with client.prepare_send(peer, mutable, credential=credential, sequence=1) as pending:
                frozen = pending.export()
                mutable[:] = b'evil'
                assert pending.export() == frozen
                assert pending.identity.sha256 == hashlib.sha256(frozen).hexdigest()
                assert 'wide' not in repr(pending) and str(credential.seed_file) not in repr(credential)
                pending_file.write_bytes(frozen)
                try:
                    client.dispatch(pending)
                except UncertainOperation as error:
                    assert error.recovery == frozen and error.status == 6
                else:
                    raise AssertionError('Dropped receipt was reported as confirmed')
            try:
                pending.export()
            except Closed:
                pass
            else:
                raise AssertionError('Closed pending operation escaped')
    elif mode == 'recover':
        assert not credential.seed_file.exists()
        with Client.open(options) as client:
            with client.recover_send(pending_file.read_bytes()) as pending:
                receipt = client.dispatch(pending)
                assert receipt.position > 0 and client.last_receipt == receipt
                print(json.dumps({'position': receipt.position}))
                original = client._api.call
                def fail_after_receipt(name, *args, **kwargs):
                    result = original(name, *args, **kwargs)
                    if name == 'transit_client_call':
                        raise MemoryError('injected host response allocation')
                    return result
                client._api.call = fail_after_receipt
                try:
                    client.dispatch(pending)
                except UncertainOperation as error:
                    assert error.recovery == pending.export() and client.last_receipt is None
                else:
                    raise AssertionError('Post-receipt host allocation lost uncertainty')
                finally:
                    client._api.call = original
            try:
                client.recover_send(Path(config['spawn']).read_bytes())
            except UnsupportedCapability:
                pass
            else:
                raise AssertionError('Recovered spawn presented as a send')
            try:
                client.recover_send(b' ' + pending_file.read_bytes())
            except transit_client.errors.TransitError:
                pass
            else:
                raise AssertionError('Noncanonical recovery accepted')
    elif mode == 'async':
        async def run():
            client = await AsyncClient.open(options)
            pending = await client.prepare_send(peer, b'async', credential=credential, sequence=2)
            task = asyncio.create_task(client.dispatch(pending))
            await asyncio.sleep(0.1)
            try:
                await client.dispatch(pending)
            except Busy:
                pass
            else:
                raise AssertionError('Concurrent call admitted')
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
            else:
                raise AssertionError('Await was not cancelled')
            close = asyncio.create_task(client.aclose())
            beats = 0
            while not close.done():
                beats += 1
                await asyncio.sleep(0.01)
            await close
            assert beats > 5 and client.last_receipt is not None
            try:
                await client.dispatch(pending)
            except Closed:
                pass
            else:
                raise AssertionError('Closed client accepted work')
            pending.close()
            print(json.dumps({'await_cancelled': task.cancelled(), 'overlap_rejected': True,
                              'responsive_during_join': beats > 5, 'disposed_handle_rejected': True}))
        asyncio.run(run())
    elif mode == 'denied':
        from transit_client.errors import AccessDenied
        with Client.open(options) as client:
            with client.recover_send(pending_file.read_bytes()) as pending:
                try:
                    client.dispatch(pending)
                except AccessDenied as error:
                    assert error.status == 4 and error.code is not None
                else:
                    raise AssertionError('Revoked historical retry accepted')
    else:
        raise AssertionError(mode)
    assert 'transit_station' not in sys.modules


def run(node, cli, raw_library, wheels):
    from client_abi_growing import GrowingSystem
    from client_abi import Native
    from sdk_scenarios import check
    root = Path(__file__).resolve().parents[1]
    wheels = Path(wheels).resolve()
    with tempfile.TemporaryDirectory(prefix='transit-python-consumer-') as temporary, GrowingSystem(node, cli) as system:
        consumer_root = Path(temporary)
        environment = {key: value for key, value in os.environ.items() if key not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
        venv = consumer_root / 'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', str(venv)], check=True, env=environment)
        python = venv / 'bin/python'
        subprocess.run([sys.executable, '-m', 'pip', '--python', str(python), 'install', '--no-index', '--find-links', str(wheels), 'transit-client==0.2.0'], check=True, env=environment, stdout=subprocess.DEVNULL)
        installed = subprocess.check_output([python, '-c', 'import importlib.metadata as m; print(sorted(d.metadata["Name"] for d in m.distributions()))'], env=environment, text=True)
        assert 'transit-station' not in installed and 'transit-native-station' not in installed
        script = consumer_root / 'consumer.py'
        shutil.copyfile(__file__, script)
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
        fault = {'drop': True, 'delay': False, 'bodies': []}
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', system.port, timeout=10)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v3/command':
                        fault['bodies'].append(body)
                    if self.path == '/v3/command' and fault['drop'] and response.status == 200:
                        fault['drop'] = False
                        self.close_connection = True
                        return
                    if fault['delay']:
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
                                      'seed': str(key), 'pending': str(consumer_root / 'pending.json'), 'spawn': str(spawn)}))
        def invoke(mode):
            return subprocess.check_output([python, '-B', script, '--consumer', mode, config], cwd=consumer_root, env=environment, timeout=20)
        try:
            invoke('first')
            key.unlink()
            receipt = json.loads(invoke('recover'))
            assert receipt['position'] > 0 and fault['bodies'][0] == fault['bodies'][1]
            key.write_bytes(original_seed)
            fault['delay'] = True
            check('local-cancellation-disposal', json.loads(invoke('async')))
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
            print('Python public client: clean independent wheels, typed bounds, owned bytes, lost receipt, seedless restart, native classification, async overlap/cancellation/join and revoked retry passed.')
        finally:
            native.lib.transit_client_destroy(admin)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)


if __name__ == '__main__':
    if sys.argv[1] == '--consumer':
        consumer(*sys.argv[2:])
    else:
        run(*sys.argv[1:])
