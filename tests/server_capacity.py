#!/usr/bin/env python3
"""Real ENOSPC in one owned ext4 image; no host mount or existing block device."""
import ctypes
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
import uuid

def inside(mount, cli, node, host):
    from table_console import atom
    from server_faults import response
    from server_direct_boundary import FaultFixture
    from server_direct_faults import pending, terminal
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = FaultFixture(cli, node, host, parent=mount)
    reserve, filler = Path(mount) / "reserve", Path(mount) / "filler"
    with reserve.open("xb") as file:
        os.posix_fallocate(file.fileno(), 0, 512 * 1024**2)
        os.fsync(file.fileno())
    started = time.monotonic()
    try:
        fixture.start()
        fixture.ready()
        original = fixture.record()
        identity, binding = pending(fixture, fixture.boundary, 1)
        # Freeze after durable SQL dispatch and direct admission. The independent
        # caller is gone; the server owns the complete original intent/reference.
        stat = os.statvfs(mount)
        available = stat.f_bavail * stat.f_frsize
        with filler.open("xb") as file:
            try:
                os.posix_fallocate(file.fileno(), 0, available - stat.f_frsize)
            except OSError as error:
                # Concurrent owned background writes can consume the last block
                # between statvfs and fallocate. That is the intended real fault.
                assert error.errno == errno.ENOSPC, error
            os.fsync(file.fileno())
        probe = Path(mount) / "enospc-probe"
        try:
            with probe.open("xb") as file:
                os.posix_fallocate(file.fileno(), 0, 32 * 1024**2)
        except OSError as error:
            assert error.errno == errno.ENOSPC, error
        else:
            raise AssertionError("Expected actual ext4 ENOSPC")
        probe.unlink(missing_ok=True)
        fixture.boundary.resume()
        time.sleep(3)
        # Pressure may prevent control writes too. Observation must stay finite;
        # neither an unavailable response nor shutdown is a terminal write result.
        attempt = time.monotonic()
        try:
            status, _ = response(fixture, "/health")
            assert status in (200, 503)
        except (OSError, ConnectionError):
            pass
        assert time.monotonic() - attempt < 7
        fixture.stop(kill=True)
        filler.unlink()
        reserve.unlink()
        fixture.start()
        fixture.ready()
        assert fixture.record()["provision"] == original["provision"]
        outcome = terminal(fixture, identity)
        assert outcome['outcome'] == 'applied' and outcome['matched'] == outcome['changed'] == 1, outcome
        assert int(identity['id']) == binding['identity']['operation']
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '1'
        row = fixture.console('SELECT id, value FROM items;\n')[-1]['rows'][0]
        assert [cell['value']['atom']['signed'] for cell in row] == ['1', '100'], row
        fixture.stop()
        print(f"Transit server physical capacity: admitted direct write, real ENOSPC, finite observation/shutdown and exact identity/count recovery passed in {time.monotonic()-started:.2f}s", flush=True)
    finally:
        filler.unlink(missing_ok=True)
        reserve.unlink(missing_ok=True)
        fixture.boundary.resume()
        fixture.cleanup()


def run(cli, node, host, *application):
    assert sys.platform == "linux"
    repo = Path(__file__).resolve().parents[1]
    image = json.loads((repo / "deploy/reference/versions.json").read_text())["ursula"]
    tools = {name: str(Path(shutil.which(name) or "missing").resolve(strict=True))
             for name in ("bash", "mount", "umount", "setpriv", "mkfs.ext4", "patchelf")}
    python = str(Path(sys.executable).resolve(strict=True))
    assert all(path.startswith("/nix/store/") for path in [*tools.values(), python])
    root = Path(tempfile.mkdtemp(prefix="transit-server-capacity-", dir="/var/tmp"))
    name = "transit-server-capacity-" + uuid.uuid4().hex[:12]
    # Source-built ELFs name the host's /lib loader while their dependencies
    # come from the pinned Nix environment. Patch only private executable copies
    # so this container does not combine its older libc with those dependencies.
    interpreter = subprocess.check_output([tools['patchelf'], '--print-interpreter', python], text=True).strip()
    assert interpreter.startswith('/nix/store/') and Path(interpreter).is_file()
    binaries = root / 'bin'
    binaries.mkdir()
    sources = [Path(path).resolve() for path in (cli, node, host, *application)]
    sources += [Path(cli).resolve().parent / name for name in ('transit-board', 'transit-sql-gateway')]
    for source in sources:
        destination = binaries / source.name
        assert not destination.exists(), destination
        shutil.copy2(source, destination)
        subprocess.run([tools['patchelf'], '--set-interpreter', interpreter, str(destination)], check=True)
    with (root / "disk.img").open("xb") as file:
        file.truncate(2 * 1024**3)
    (root / "mount").mkdir()
    subprocess.run([tools["mkfs.ext4"], "-q", "-F", "-m", "0", str(root / "disk.img")], check=True, timeout=30)
    q = shlex.quote
    command = [python, "-B", str(repo / "tests/server_capacity.py"), "--inside-application" if application else "--inside", "/proof/mount",
               *['/proof/bin/' + Path(path).name for path in (cli, node, host, *application)]]
    script = f'''set -euo pipefail
{q(tools['mount'])} -o loop /proof/disk.img /proof/mount
trap '{q(tools['umount'])} /proof/mount' EXIT
{q(python)} -c 'import os; os.chown("/proof/mount", {os.getuid()}, {os.getgid()})'
{q(tools['setpriv'])} --reuid={os.getuid()} --regid={os.getgid()} --clear-groups {shlex.join(command)}
'''
    (root / "start.sh").write_text(script)
    success = False
    try:
        result = subprocess.run(["docker", "run", "--rm", "--name", name, "--privileged", "--user", "0:0",
            "--env", "PATH=/unavailable",
            "--mount", f"type=bind,src={root},dst=/proof",
            "--mount", f"type=bind,src={repo},dst={repo},readonly",
            "--mount", "type=bind,src=/nix/store,dst=/nix/store,readonly",
            "--workdir", str(repo), "--entrypoint", tools["bash"], image, "/proof/start.sh"], timeout=300)
        assert result.returncode == 0, result
        success = True
    finally:
        subprocess.run(["docker", "rm", "--force", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        if success:
            shutil.rmtree(root)
        else:
            print(f"Failed physical server evidence retained at {root}", flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "--inside-application":
        from server_application_capacity import inside as inside_application
        inside_application(*sys.argv[2:])
    elif sys.argv[1] == "--inside":
        inside(*sys.argv[2:])
    else:
        run(*sys.argv[1:])
