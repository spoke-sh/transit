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

from cold_storage import minio_binary


def inside(mount, node, proof):
    from relational_exchange_native import run as exchanges
    mount = Path(mount)
    tempfile.tempdir = str(mount)
    reserve, filler = mount / 'reserve', mount / 'filler'
    observations = []

    def pressure(lifetime, call, restart, direct):
        before = call('captured-status' if lifetime == 'captured' else 'exchange-status')
        query = call('captured-status' if lifetime == 'captured' else 'maintained-status')
        with reserve.open('xb') as file:
            os.posix_fallocate(file.fileno(), 0, 512 * 1024**2)
            os.fsync(file.fileno())
        available = os.statvfs(mount).f_bavail * os.statvfs(mount).f_frsize
        with filler.open('xb') as file:
            os.posix_fallocate(file.fileno(), 0, available - 4 * 1024**2)
            os.fsync(file.fileno())
        probe = mount / 'enospc-probe'
        with probe.open('xb') as file:
            try:
                os.posix_fallocate(file.fileno(), 0, 32 * 1024**2)
            except OSError as error:
                assert error.errno == errno.ENOSPC, error
            else:
                raise AssertionError('Expected actual ext4 ENOSPC')
        probe.unlink()
        attempt = time.monotonic()
        if lifetime == 'captured':
            call('captured-pump', 1, fail=True, expected_error='AuthorityUnavailable')
        else:
            call('exchange-pump', 'r', 1, fail=True, expected_error='AuthorityUnavailable')
        refused_seconds = time.monotonic() - attempt
        assert refused_seconds < 30, refused_seconds
        attempt = time.monotonic()
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        try:
            with http.open(direct + '/health', timeout=5) as response:
                health = response.status
        except urllib.error.HTTPError as error:
            health = error.code
        assert health in (200, 503), health
        health_seconds = time.monotonic() - attempt
        assert health_seconds < 7
        # The filler stays allocated. Only the explicit recovery reserve is
        # released before restarting the same authority and physical WAL.
        recovery_started = time.monotonic()
        reserve.unlink()
        restart()
        recovered = call('captured-status' if lifetime == 'captured' else 'exchange-status')
        assert recovered == before, (lifetime, before, recovered)
        assert call('captured-status' if lifetime == 'captured' else 'maintained-status') == query
        if lifetime == 'captured':
            call('captured-pump', 1)
        else:
            call('exchange-pump', 'r', 1)
        observations.append(dict(lifetime=lifetime, physical_enospc=True,
            reserve_bytes=512 * 1024**2, refused_seconds=round(refused_seconds, 3),
            health_status=health, health_seconds=round(health_seconds, 3),
            recovery_seconds=round(time.monotonic() - recovery_started, 3),
            exact_head_and_query_preserved=True, control_with_filler_retained=True))
        filler.unlink()
        print(json.dumps(dict(profile='relational-physical-pressure', **observations[-1])), flush=True)

    try:
        exchanges(node, proof, pressure=pressure)
        assert len(observations) == 2
        print(json.dumps(dict(profile='relational-physical-capacity', observations=observations)), flush=True)
    finally:
        filler.unlink(missing_ok=True)
        reserve.unlink(missing_ok=True)


def run(node, proof):
    assert sys.platform == 'linux'
    repo = Path(__file__).resolve().parents[1]
    image = json.loads((repo / 'deploy/reference/versions.json').read_text())['ursula']
    selected = {name: str(Path(shutil.which(name) or 'missing').resolve(strict=True))
                for name in ('bash', 'mount', 'umount', 'setpriv', 'mkfs.ext4', 'ursula')}
    python, minio = str(Path(sys.executable).resolve(strict=True)), str(minio_binary())
    assert all(path.startswith('/nix/store/') for path in [*selected.values(), python, minio])
    root = Path(tempfile.mkdtemp(prefix='transit-relational-capacity-', dir='/var/tmp'))
    name = 'transit-relational-capacity-' + uuid.uuid4().hex[:12]
    with (root / 'disk.img').open('xb') as file:
        file.truncate(2 * 1024**3)
    (root / 'mount').mkdir()
    subprocess.run([selected['mkfs.ext4'], '-q', '-F', '-m', '0', str(root / 'disk.img')], check=True, timeout=30)
    command = [python, '-B', str(repo / 'tests/relational_capacity.py'), '--inside', '/proof/mount',
               *[str(Path(path).resolve()) for path in (node, proof)]]
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
            '--env', 'PATH=' + os.pathsep.join(str(Path(binary).parent) for binary in (selected['ursula'], minio)),
            '--mount', f'type=bind,src={root},dst=/proof',
            '--mount', f'type=bind,src={repo},dst={repo},readonly',
            '--mount', 'type=bind,src=/nix/store,dst=/nix/store,readonly',
            '--workdir', str(repo), '--entrypoint', selected['bash'], image, '/proof/start.sh'], timeout=600)
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
