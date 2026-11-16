"""Owned ext4 disk, actual ENOSPC and reserved native control progress.

Only a new regular image is formatted. Loop devices and mounts stay inside one
owned privileged container. The measured binary is the supplied native Transit
proof; the pinned registry image supplies only a container filesystem.
"""
from runner.paths import ROOT
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


def run(binary):
    assert sys.platform == 'linux', 'Physical capacity proof requires Linux'
    image = json.loads((ROOT / 'deploy/reference/versions.json').read_text())['registry']
    tools = {name: str(Path(shutil.which(name) or 'missing').resolve(strict=True))
             for name in ('bash', 'mount', 'umount', 'setpriv', 'mkfs.ext4')}
    python = str(Path(sys.executable).resolve(strict=True))
    assert all(path.startswith('/nix/store/') for path in [python, *tools.values()])
    name = 'transit-capacity-' + uuid.uuid4().hex[:12]
    root = Path(tempfile.mkdtemp(prefix='transit-capacity-', dir='/var/tmp'))
    container = None
    passed = False
    try:
        root.chmod(0o755)
        shutil.copy2(binary, root / 'proof')
        with (root / 'disk.img').open('xb') as file:
            file.truncate(2 * 1024**3)
        subprocess.run([tools['mkfs.ext4'], '-q', '-F', '-m', '0', str(root / 'disk.img')], check=True, timeout=30)
        (root / 'mount').mkdir()
        initialize = '''import os
from pathlib import Path
p = Path('/proof/mount')
(p/'native').mkdir()
os.chown(p/'native', 65532, 65532)
fd = os.open(p/'reserve', os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
os.posix_fallocate(fd, 0, 1024**3)
os.fsync(fd)
assert os.fstat(fd).st_blocks * 512 >= 1024**3
os.close(fd)
os.sync()
'''
        script = f'''set -euo pipefail
{shlex.quote(tools['mount'])} -o loop /proof/disk.img /proof/mount
cleanup() {{
  trap - EXIT TERM INT
  {shlex.quote(tools['umount'])} /proof/mount
}}
trap cleanup EXIT
trap 'exit 0' TERM INT
{shlex.quote(python)} -c {shlex.quote(initialize)}
{shlex.quote(python)} -c 'from pathlib import Path; Path("/proof/ready").touch(); import time; time.sleep(3600)' &
wait $!
'''
        (root / 'start.sh').write_text(script)
        container = subprocess.check_output(['docker', 'create', '--name', name, '--privileged', '--user', '0:0',
            '--mount', f'type=bind,src={root},dst=/proof',
            '--mount', 'type=bind,src=/nix/store,dst=/nix/store,readonly',
            '--entrypoint', tools['bash'], image, '/proof/start.sh'], text=True, timeout=60).strip()
        subprocess.run(['docker', 'start', container], check=True, stdout=subprocess.DEVNULL, timeout=20)
        until = time.monotonic() + 30
        while not (root / 'ready').exists():
            assert time.monotonic() < until, 'Owned capacity filesystem was not mounted'
            time.sleep(.05)

        def inside(source, timeout=60):
            return subprocess.check_output(['docker', 'exec', container, python, '-c', source], text=True, timeout=timeout).strip()

        def stats():
            return json.loads(inside('''import json, os
from pathlib import Path
p = Path('/proof/mount')
s = os.statvfs(p)
files = [f for f in (p/'native/wal').rglob('*') if f.is_file()]
print(json.dumps(dict(available=s.f_bavail*s.f_frsize,
  wal_bytes=sum(f.stat().st_size for f in files),
  wal_allocated=sum(f.stat().st_blocks*512 for f in files))))
'''))

        phases = []

        def proof(phase):
            # A child inside the mount owns its real disk and is killed after
            # flushing its result, before graceful storage teardown can run.
            command = [tools['setpriv'], '--reuid=65532', '--regid=65532', '--clear-groups',
                       '/proof/proof', '/proof/mount/native', phase]
            source = f'''import json, subprocess, time
from pathlib import Path
with Path('/proof/{phase}.json').open('w+') as out, Path('/proof/{phase}.log').open('w+') as err:
    child = subprocess.Popen({command!r}, stdout=out, stderr=err)
    try:
        until = time.monotonic() + 180
        while child.poll() is None:
            out.seek(0)
            if out.read().endswith('\\n'):
                child.kill()
                break
            assert time.monotonic() < until, 'Capacity phase timed out'
            time.sleep(.02)
        child.wait(timeout=10)
        err.seek(0)
        assert child.returncode == -9, err.read()[-12000:]
        out.seek(0)
        print(out.read())
    finally:
        if child.poll() is None: child.kill()
        child.wait(timeout=10)
'''
            started = time.monotonic()
            value = json.loads(inside(source, timeout=200))
            value['seconds'] = round(time.monotonic() - started, 3)
            phases.append(value)
            print('Native capacity: ' + json.dumps(value), flush=True)

        proof('write')
        before = stats()
        inside('''import errno, os
p = '/proof/mount'
fd = os.open(p+'/filler', os.O_CREAT | os.O_EXCL | os.O_RDWR, 0o600)
try:
    offset = 0
    for size in (1024**2, 4096):
        while True:
            try: os.posix_fallocate(fd, offset, size)
            except OSError as error:
                assert error.errno == errno.ENOSPC
                break
            offset += size
    os.fsync(fd)
finally: os.close(fd)
os.sync()
assert os.statvfs(p).f_bavail == 0
''')
        pressured = stats()
        assert pressured['available'] == 0
        proof('pressure')
        # Only the reserve is released. Durable ordinary admission stays closed.
        inside("import os; os.unlink('/proof/mount/reserve'); os.sync()")
        released = stats()
        assert released['available'] - pressured['available'] >= 1024**3
        proof('control')
        after_control = stats()
        assert after_control['wal_allocated'] - before['wal_allocated'] < 128*1024**2
        proof('recover')
        after_recovery = stats()
        assert after_recovery['wal_bytes'] == after_control['wal_bytes'], 'Completed recovery appended authority'
        evidence = dict(version=1, status='passed', container_filesystem=image, profile='native_v1',
            revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
            binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
            admission_ceiling=96, control_record_bound=96, reserve_bytes=1024**3,
            before_pressure=before, pressured=pressured, released=released,
            after_control=after_control, after_recovery=after_recovery, phases=phases)
        output = ROOT / '.cache/growing-capacity-evidence.json'
        output.parent.mkdir(exist_ok=True)
        output.write_text(json.dumps(evidence, indent=2) + '\n')
        passed = True
        print('Physical native ENOSPC, reserved control progress, checkpoint/trim and SIGKILL recovery passed.')
    except BaseException:
        if container:
            subprocess.run(['docker', 'logs', '--tail', '80', container], check=False)
        print(f'Retained capacity proof: {root}', file=sys.stderr)
        raise
    finally:
        if container:
            subprocess.run(['docker', 'stop', '--time', '10', container], check=False, stdout=subprocess.DEVNULL, timeout=20)
            subprocess.run(['docker', 'rm', '--force', container], check=True, stdout=subprocess.DEVNULL, timeout=20)
        if passed:
            shutil.rmtree(root)


if __name__ == '__main__':
    assert len(sys.argv) == 2, 'Expected binary'
    run(Path(sys.argv[1]).resolve(strict=True))
