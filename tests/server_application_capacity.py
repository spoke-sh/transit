"""Accepted application work across actual ENOSPC in the owned ext4 fixture."""
import ctypes
import errno
import json
import os
from pathlib import Path
import signal
import subprocess
import time
from harness.processes import children, command
from server_applications import Applications, provision_authority
from server_application_faults import wait_file


def inside(mount, cli, node, host, worker, operator):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Applications(cli, node, host, parent=mount)
    reserve, filler = Path(mount) / 'reserve', Path(mount) / 'filler'
    with reserve.open('xb') as file:
        os.posix_fallocate(file.fileno(), 0, 512 * 1024**2)
        os.fsync(file.fileno())
    caller = None
    started = time.monotonic()
    recovery = Path('/proof/put.json')
    writer, inspector = Path('/proof/writer.json'), Path('/proof/inspector.json')
    administrator = Path('/proof/operator.json')
    try:
        fixture.start()
        fixture.ready()
        manifest = fixture.root / 'application.json'
        manifest.write_bytes(subprocess.check_output([operator, 'manifest', worker]))
        fixture.app('install', '--file', manifest, '--operation', 'install')
        ready = fixture.active()
        connections = dict(operator=administrator, writer=writer, inspector=inspector)
        for name, destination in connections.items():
            fixture.app('connect', '--application', 'work-items', '--caller', name, '--output', destination)
        binding = provision_authority(fixture, operator, connections)
        for mode, saved, arguments in [
                ('initialize-catalog', 'catalog-initialize.json', [binding]),
                ('prepare-table', 'table-initialize.json', ['1'])]:
            # Each retry preserves the original saved native request and its
            # direct dispatch reference; provisioning precedes disk pressure.
            deadline = time.monotonic() + 120
            while True:
                initialized = subprocess.run([operator, str(administrator), mode,
                    str(fixture.root / saved), *map(str, arguments)],
                    capture_output=True, text=True, timeout=max(1, deadline-time.monotonic()))
                if initialized.returncode == 0:
                    break
                assert initialized.stderr.strip() in ('error: AuthorityUnavailable',
                    'error: AuthorityTimeout', 'error: HttpConnectionClosing',
                    'error: ConnectionRefused', 'error: StaleStateResource'), initialized
                assert time.monotonic() < deadline, initialized
                time.sleep(.1)
        deadline = time.monotonic() + 10
        while True:
            initialized = subprocess.run([operator, str(inspector), 'inspect'], capture_output=True, text=True, timeout=5)
            if initialized.returncode == 0:
                break
            assert time.monotonic() < deadline, initialized
            time.sleep(.05)
        process = next(pid for pid in children(fixture.process.pid) if '/applications/work-items/data.bootstrap.json' in command(pid))
        # Leave an accepted input unresolved before exhausting provider space.
        os.kill(process, signal.SIGSTOP)
        caller = subprocess.Popen([operator, str(writer), 'put', str(recovery), '1', '0'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        deadline = time.monotonic() + 10
        while not recovery.exists():
            assert caller.poll() is None, caller.communicate()
            assert time.monotonic() < deadline, recovery
            time.sleep(.05)
        deadline = time.monotonic() + 10
        while json.loads(recovery.read_text())['receipt'] is None:
            assert time.monotonic() < deadline
            time.sleep(.05)
        accepted = json.loads(recovery.read_text())['receipt']
        available = os.statvfs(mount).f_bavail * os.statvfs(mount).f_frsize
        with filler.open('xb') as file:
            os.posix_fallocate(file.fileno(), 0, available - 4 * 1024**2)
            os.fsync(file.fileno())
        probe = Path(mount) / 'enospc-probe'
        with probe.open('xb') as file:
            try:
                os.posix_fallocate(file.fileno(), 0, 32 * 1024**2)
            except OSError as error:
                assert error.errno == errno.ENOSPC
            else:
                raise AssertionError('Expected actual ext4 ENOSPC')
        probe.unlink()
        os.kill(process, signal.SIGCONT)
        time.sleep(3)
        caller.terminate()
        caller.communicate(timeout=10)
        caller = None
        assert json.loads(recovery.read_text())['receipt'] == accepted
        fixture.stop()
        filler.unlink()
        reserve.unlink()
        fixture.start()
        fixture.ready()
        resumed = fixture.active()
        assert resumed['roles'][0]['pid'] == ready['roles'][0]['pid']
        assert resumed['resources'] == ready['resources']
        frozen = recovery.read_bytes()
        deadline = time.monotonic() + 40
        while True:
            # Readiness can precede the next successful authority observation.
            # Retry only the saved accepted request, checking its complete bytes.
            assert recovery.read_bytes() == frozen
            result = subprocess.run([operator, str(writer), 'put', str(recovery), '1', '0'],
                capture_output=True, text=True, timeout=max(1, deadline-time.monotonic()))
            assert recovery.read_bytes() == frozen
            if result.returncode == 0:
                break
            assert result.stderr.strip() in ('error: AuthorityUnavailable',
                'error: AuthorityTimeout', 'error: HttpConnectionClosing',
                'error: ConnectionRefused'), result
            assert time.monotonic() < deadline, result
            time.sleep(.1)
        assert result.returncode == 0, result
        assert json.loads(result.stdout)['accepted'] == accepted
        state = json.loads(subprocess.check_output([operator, str(inspector), 'inspect'], timeout=10))
        assert state['rows'] == 1
        fixture.stop()
        print(f'Application physical capacity: accepted input, real ENOSPC, joined shutdown and same receipt/PID/resource recovered in {time.monotonic() - started:.2f}s', flush=True)
    finally:
        if caller is not None:
            caller.kill()
            caller.communicate(timeout=10)
        filler.unlink(missing_ok=True)
        reserve.unlink(missing_ok=True)
        fixture.cleanup()
