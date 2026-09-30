"""Install public raw-client wheels outside the checkout and exercise real I/O."""
import asyncio
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def consumer(mode, config_file):
    import transit_client
    from transit_client import Client, AsyncClient, ClientConfig, Credential, ProcessRef
    from transit_client.errors import Busy, Closed, UncertainOperation, UnsupportedCapability, IncompatibleNative
    config = json.loads(Path(config_file).read_text())
    assert Path(transit_client.__file__).is_relative_to(Path(sys.prefix))
    assert 'transit_station' not in sys.modules
    peer = ProcessRef(72, config['pid'])
    options = ClientConfig(config['url'], 'native_v1', timeout_ms=3000)
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
        Client.open(ClientConfig(config['url'], 'native_v1', native_directory=Path('/missing-transit')))
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
            deadline = time.monotonic() + 15
            while not Path(config['accepted']).exists():
                assert not task.done() and time.monotonic() < deadline
                await asyncio.sleep(0.01)
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
    from sdk_raw_client import run as schedule
    wheels = Path(wheels).resolve()
    def install(target):
        environment = {key: value for key, value in os.environ.items() if key not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
        venv = target / 'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', str(venv)], check=True, env=environment)
        python = venv / 'bin/python'
        subprocess.run([sys.executable, '-m', 'pip', '--python', str(python), 'install', '--no-index', '--find-links', str(wheels), 'transit-client==0.2.0'], check=True, env=environment, stdout=subprocess.DEVNULL)
        installed = subprocess.check_output([python, '-c', 'import importlib.metadata as m; print(sorted(d.metadata["Name"] for d in m.distributions()))'], env=environment, text=True)
        assert 'transit-station' not in installed and 'transit-native-station' not in installed
        script = target / 'consumer.py'
        shutil.copyfile(__file__, script)
        def invoke(mode, config):
            return subprocess.check_output([python, '-B', script, '--consumer', mode, config], cwd=target, env=environment, timeout=30)
        return invoke
    schedule(node, cli, raw_library, install, 'Python')


if __name__ == '__main__':
    if sys.argv[1] == '--consumer':
        consumer(*sys.argv[2:])
    else:
        run(*sys.argv[1:])
