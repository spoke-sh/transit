"""Real ENOSPC for durable relational work in one newly allocated ext4 image."""
import errno
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

from harness.services import free_port, wait_ready


def inside(mount, node, proof):
    mount = Path(mount)
    tempfile.tempdir = str(mount)
    root = Path(tempfile.mkdtemp(prefix='direct-relational-'))
    reserve, filler = mount / 'reserve', mount / 'filler'
    observations = []
    profile, config = root / 'profile.json', root / 'node.json'
    seed = root / 'registrar.seed'
    seed.write_text('11' * 32)
    seed.chmod(0o600)
    port = free_port()
    url = f'http://127.0.0.1:{port}'
    settings = dict(genesis=dict(realm=42, root_key=json.loads(subprocess.check_output([proof, 'public'], timeout=15)), max_clock_error_ms=10000),
                    local_directory=str(root / 'native'), port=port, resident_pages=1, request_timeout_ms=60000)
    config.write_text(json.dumps(settings))
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    log = (root / 'node.log').open('w+')
    authority = None

    def restart():
        nonlocal authority
        if authority is not None:
            authority.kill()
            authority.wait(timeout=15)
        authority = subprocess.Popen([node, str(config), '--bootstrap'], stdout=log, stderr=subprocess.STDOUT)
        wait_ready(http, authority, url + '/health')

    def call(command, *, status=False, fail=False):
        result = subprocess.run([proof, url, command, str(profile)], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=35 if fail else 900)
        if fail:
            assert result.returncode != 0 and 'error: AuthorityUnavailable' in result.stderr, (command, result.returncode, result.stderr)
        else:
            assert result.returncode == 0, (command, result.returncode, result.stderr)
        return json.loads(result.stdout) if status else None

    def pressure(lifetime, status, attempt_command, recover):
        before = call(status, status=True)
        with reserve.open('xb') as file:
            os.posix_fallocate(file.fileno(), 0, 512 * 1024**2)
            os.fsync(file.fileno())
        probe = mount / 'enospc-probe'
        with probe.open('x+b') as checking, filler.open('x+b') as file:
            stat = os.statvfs(mount)
            available = stat.f_bavail * stat.f_frsize
            # Leave room for extent metadata during the large allocation, then
            # consume the tail with bounded allocations down to one block.
            # A statvfs byte count alone does not include that metadata cost.
            offset = available - 4 * 1024**2
            os.posix_fallocate(file.fileno(), 0, offset)
            for size in (1024**2, stat.f_frsize):
                for _ in range(2048):
                    try:
                        os.posix_fallocate(file.fileno(), offset, size)
                    except OSError as error:
                        assert error.errno == errno.ENOSPC, error
                        break
                    offset += size
                else:
                    raise AssertionError('Filesystem tail did not reach ENOSPC')
            os.fsync(file.fileno())
            try:
                os.posix_fallocate(checking.fileno(), 0, 32 * 1024**2)
            except OSError as error:
                assert error.errno == errno.ENOSPC, error
            else:
                raise AssertionError('Expected actual ext4 ENOSPC')
        probe.unlink()
        attempt = time.monotonic()
        call(attempt_command, fail=True)
        refused_seconds = time.monotonic() - attempt
        assert refused_seconds < 30, refused_seconds
        attempt = time.monotonic()
        try:
            with http.open(url + '/health', timeout=5) as response:
                health = response.status
        except urllib.error.HTTPError as error:
            health = error.code
        assert health in (200, 503), health
        health_seconds = time.monotonic() - attempt
        assert health_seconds < 7
        # Release only the explicit recovery reserve. Restart the same physical
        # authority and compare every retained computation entry, including its
        # original source vector, query progress and exchange credit/coverage.
        recovery_started = time.monotonic()
        reserve.unlink()
        restart()
        recovered = call(status, status=True)
        assert recovered == before, (lifetime, before, recovered)
        call(recover)
        observations.append(dict(lifetime=lifetime, physical_enospc=True,
            reserve_bytes=512 * 1024**2, refused_seconds=round(refused_seconds, 3),
            health_status=health, health_seconds=round(health_seconds, 3),
            recovery_seconds=round(time.monotonic() - recovery_started, 3),
            exact_computation_state_preserved=True, completed_with_filler_retained=True))
        filler.unlink()
        print(json.dumps(dict(profile='relational-physical-pressure', **observations[-1])), flush=True)

    try:
        restart()
        call('provision')
        settings['table'] = dict(catalog=json.loads(profile.read_text())['catalog'], registrar=dict(principal=0, seed_file=str(seed)))
        config.write_text(json.dumps(settings))
        restart()
        call('maintained-initialize')
        call('capacity-captured-prepare')
        pressure('captured', 'capacity-captured-status', 'capacity-captured-pressure', 'capacity-captured-recover')
        checkpoint = root / 'direct-exchange-recovery.json'
        executor = subprocess.Popen([proof, url, 'capture-exchanges-prepare', str(profile)])
        try:
            until = time.monotonic() + 600
            while not checkpoint.exists():
                assert executor.poll() is None, 'exchange exited before its partial checkpoint'
                assert time.monotonic() < until, 'exchange checkpoint deadline'
                time.sleep(.05)
            original = checkpoint.read_bytes()
            executor.kill()
            assert executor.wait(timeout=15) == -9
        finally:
            if executor.poll() is None:
                executor.kill()
                executor.wait(timeout=15)
        pressure('exchange', 'capacity-exchange-status', 'capture-exchanges-pressure', 'capture-exchanges-resume')
        assert checkpoint.read_bytes() == original, 'recovery replaced the original exchange selection'
        assert len(observations) == 2
        print(json.dumps(dict(profile='relational-physical-capacity', observations=observations)), flush=True)
    finally:
        filler.unlink(missing_ok=True)
        reserve.unlink(missing_ok=True)
        if authority is not None:
            authority.kill()
            authority.wait(timeout=15)
        log.close()


def run(node, proof):
    assert sys.platform == 'linux'
    repo = Path(__file__).resolve().parents[1]
    image = json.loads((repo / 'deploy/reference/versions.json').read_text())['ursula']
    selected = {name: str(Path(shutil.which(name) or 'missing').resolve(strict=True))
                for name in ('bash', 'mount', 'umount', 'setpriv', 'mkfs.ext4', 'patchelf')}
    python = str(Path(sys.executable).resolve(strict=True))
    assert all(path.startswith('/nix/store/') for path in [*selected.values(), python])
    root = Path(tempfile.mkdtemp(prefix='transit-relational-capacity-', dir='/var/tmp'))
    name = 'transit-relational-capacity-' + uuid.uuid4().hex[:12]
    interpreter = subprocess.check_output([selected['patchelf'], '--print-interpreter', python], text=True).strip()
    assert interpreter.startswith('/nix/store/') and Path(interpreter).is_file()
    (root / 'bin').mkdir()
    for source in (Path(node).resolve(), Path(proof).resolve()):
        destination = root / 'bin' / source.name
        shutil.copy2(source, destination)
        subprocess.run([selected['patchelf'], '--set-interpreter', interpreter, str(destination)], check=True)
    with (root / 'disk.img').open('xb') as file:
        file.truncate(2 * 1024**3)
    (root / 'mount').mkdir()
    subprocess.run([selected['mkfs.ext4'], '-q', '-F', '-m', '0', str(root / 'disk.img')], check=True, timeout=30)
    command = [python, '-B', str(repo / 'tests/relational_capacity.py'), '--inside', '/proof/mount',
               *['/proof/bin/' + Path(path).name for path in (node, proof)]]
    q = shlex.quote
    script = f'''set -euo pipefail
{q(selected['mount'])} -o loop /proof/disk.img /proof/mount
trap '{q(selected['umount'])} /proof/mount' EXIT
{q(python)} -c 'import os; os.chown("/proof/mount", {os.getuid()}, {os.getgid()})'
{q(selected['setpriv'])} --reuid={os.getuid()} --regid={os.getgid()} --clear-groups {shlex.join(command)}
'''
    (root / 'start.sh').write_text(script)
    success = False
    try:
        result = subprocess.run(['docker', 'run', '--rm', '--name', name, '--privileged', '--user', '0:0',
            '--env', 'PATH=/unavailable',
            '--mount', f'type=bind,src={root},dst=/proof',
            '--mount', f'type=bind,src={repo},dst={repo},readonly',
            '--mount', 'type=bind,src=/nix/store,dst=/nix/store,readonly',
            '--workdir', str(repo), '--entrypoint', selected['bash'], image, '/proof/start.sh'], timeout=1800)
        assert result.returncode == 0, result
        success = True
    finally:
        subprocess.run(['docker', 'rm', '--force', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        if success:
            shutil.rmtree(root)
        else:
            print(f'Failed physical relational fixture retained at {root}', flush=True)


if __name__ == '__main__':
    if sys.argv[1] == '--inside':
        inside(*sys.argv[2:])
    else:
        run(*sys.argv[1:])
