#!/usr/bin/env python3
"""Real ENOSPC in one owned ext4 image; no host mount or existing block device."""
import ctypes
import errno
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

from server import Fixture, minio_binary


def inside(mount, cli, node, host):
    from console import Console
    from server_faults import response
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Fixture(cli, node, host, parent=mount)
    reserve = Path(mount) / "reserve"
    filler = Path(mount) / "filler"
    with reserve.open("xb") as file:
        os.posix_fallocate(file.fileno(), 0, 512 * 1024**2)
        os.fsync(file.fileno())
    shell = None
    started = time.monotonic()
    try:
        fixture.start(initialize=True)
        fixture.ready()
        original = fixture.record()
        config = fixture.console_config()
        config["seed_file"] = str(fixture.installation / "caller.seed")
        # Client intent persistence is independent of the provider volume being
        # filled. Both remain explicitly configured private paths.
        config["recovery_file"] = "/proof/client-recovery.json"
        console_path = Path("/proof/console.json")
        console_path.write_text(json.dumps(config))
        shell = Console(fixture.cli, console_path)
        shell.process.stdin.write(b"SELECT COUNT(*) FROM items;\n"); shell.process.stdin.flush()
        deadline = time.monotonic() + 30
        while True:
            record_path = Path(config["recovery_file"])
            if record_path.exists():
                accepted = json.loads(record_path.read_text())
                if accepted["input"] is not None or accepted["complete"]:
                    break
            assert time.monotonic() < deadline, "query receipt was not persisted"
            time.sleep(.005)
        os.kill(shell.process.pid, signal.SIGSTOP)
        available = os.statvfs(mount).f_bavail * os.statvfs(mount).f_frsize
        # Match the physical-capacity foundation: retain 4 MiB for bounded
        # control metadata, then prove a real 32 MiB allocation gets ENOSPC.
        with filler.open("xb") as file:
            os.posix_fallocate(file.fileno(), 0, available - 4 * 1024**2)
            os.fsync(file.fileno())
        probe = Path(mount) / "enospc-probe"
        with probe.open("xb") as file:
            try:
                os.posix_fallocate(file.fileno(), 0, 32 * 1024**2)
            except OSError as error:
                assert error.errno == errno.ENOSPC, error
            else:
                raise AssertionError("Expected actual ext4 ENOSPC")
        probe.unlink()
        # Read/control attempts stay finite even while provider writes refuse.
        attempt = time.monotonic()
        try:
            status, _ = response(fixture, "/health")
            assert status in (200, 503)
        except (OSError, ConnectionError):
            pass  # A stopped installation is visibly unavailable, not ready.
        assert time.monotonic() - attempt < 7
        shell.process.send_signal(signal.SIGCONT)
        shell.process.send_signal(signal.SIGTERM)
        shell.process.wait(timeout=10)
        for stream in (shell.process.stdin, shell.process.stdout, shell.process.stderr):
            stream.close()
        shell = None
        recovery = json.loads(Path(config["recovery_file"]).read_text())
        assert recovery["namespace"] == accepted["namespace"] and recovery["bundle"]
        fixture.stop()
        filler.unlink()
        reserve.unlink()
        fixture.start()
        fixture.ready()
        assert fixture.record()["provision"] == original["provision"]
        shell = Console(fixture.cli, console_path)
        page = shell.call(".resume")
        assert page["complete_coverage"] and page["cells"][0][0]["value"]["uint64"] == "0", page
        shell.close()
        shell = None
        fixture.stop()
        print(f"Transit server physical capacity: accepted query, real ENOSPC, finite control/shutdown and exact recovery passed in {time.monotonic()-started:.2f}s", flush=True)
    finally:
        if shell is not None:
            if shell.process.poll() is None:
                shell.process.kill()
            shell.process.wait(timeout=10)
        # Make space available for fixture diagnostics/cleanup on failure too.
        filler.unlink(missing_ok=True)
        reserve.unlink(missing_ok=True)
        fixture.cleanup()


def run(cli, node, host, *application):
    assert sys.platform == "linux"
    repo = Path(__file__).resolve().parents[1]
    minio_binary()  # Native binary exists before entering the isolated container.
    image = json.loads((repo / "deploy/reference/versions.json").read_text())["ursula"]
    tools = {name: str(Path(shutil.which(name) or "missing").resolve(strict=True))
             for name in ("bash", "mount", "umount", "setpriv", "mkfs.ext4")}
    python = str(Path(sys.executable).resolve(strict=True))
    ursula = str(Path(shutil.which("ursula") or "missing").resolve(strict=True))
    assert all(path.startswith("/nix/store/") for path in [*tools.values(), python])
    root = Path(tempfile.mkdtemp(prefix="transit-server-capacity-", dir="/var/tmp"))
    name = "transit-server-capacity-" + uuid.uuid4().hex[:12]
    with (root / "disk.img").open("xb") as file:
        file.truncate(2 * 1024**3)
    (root / "mount").mkdir()
    subprocess.run([tools["mkfs.ext4"], "-q", "-F", "-m", "0", str(root / "disk.img")], check=True, timeout=30)
    q = shlex.quote
    command = [python, "-B", str(repo / "tests/server_capacity.py"), "--inside-application" if application else "--inside", "/proof/mount",
               *[str(Path(path).resolve()) for path in (cli, node, host, *application)]]
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
            "--env", "PATH=" + str(Path(ursula).parent),
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
