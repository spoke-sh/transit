"""Owned ext4 disk, real ENOSPC, and a preallocated control reserve. Linux/Docker.

Only a new regular image file is formatted. Mounts and loop-device allocation
live inside one owned privileged container; no host mount or block device is
selected. Ursula runs as nobody against that filesystem using its official image.
"""
import json
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import uuid


def run(binary, growing=False):
    assert sys.platform == "linux", "Physical capacity proof requires Linux"
    repo = Path(__file__).resolve().parents[1]
    image = json.loads((repo / "deploy/reference/versions.json").read_text())["ursula"]
    tools = {}
    for tool in ("bash", "mount", "umount", "setpriv", "mkfs.ext4"):
        tools[tool] = str(Path(shutil.which(tool) or "missing").resolve(strict=True))
        assert tools[tool].startswith("/nix/store/"), "Run via just test::capacity for pinned mount tools"
    python = str(Path(sys.executable).resolve(strict=True))
    assert python.startswith("/nix/store/")
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    name = "rey-capacity-" + uuid.uuid4().hex[:12]
    with tempfile.TemporaryDirectory(prefix="rey-capacity-") as directory:
        root = Path(directory)
        disk = root / "disk.img"
        with disk.open("xb") as file:
            file.truncate(2 * 1024**3)
        subprocess.run([tools["mkfs.ext4"], "-q", "-F", "-m", "0", str(disk)], check=True, timeout=30)
        (root / "mount").mkdir()
        (root / "ursula.toml").write_text('''[server]
listen = "0.0.0.0:8080"
admin_listen = "127.0.0.1:8081"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "/proof/mount/wal"
min_available_size = "16MiB"
resume_available_size = "32MiB"
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
''')
        initialize = '''import os
from pathlib import Path
p = Path('/proof/mount')
(p/'wal').mkdir()
os.chown(p/'wal', 65532, 65532)
fd = os.open(p/'reserve', os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
os.posix_fallocate(fd, 0, 1024**3)
os.fsync(fd)
assert os.fstat(fd).st_blocks * 512 >= 1024**3
os.close(fd)
os.sync()
'''
        script = f'''set -euo pipefail
{shlex.quote(tools['mount'])} -o loop /proof/disk.img /proof/mount
pid=
cleanup() {{
  trap - EXIT TERM INT
  if test -n "$pid"; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  {shlex.quote(tools['umount'])} /proof/mount
}}
trap cleanup EXIT
trap 'exit 0' TERM INT
{shlex.quote(python)} -c {shlex.quote(initialize)}
while true; do
  {shlex.quote(tools['setpriv'])} --reuid=65532 --regid=65532 --clear-groups /usr/local/bin/ursula server --config /proof/ursula.toml &
  pid=$!
  printf '%s' "$pid" > /proof/server.pid
  wait "$pid" || true
done
'''
        (root / "start.sh").write_text(script)
        root.chmod(0o755)  # The unprivileged server reads only its public config.
        container = subprocess.check_output(["docker", "create", "--name", name, "--privileged", "--user", "0:0",
            "--publish", "127.0.0.1::8080", "--mount", f"type=bind,src={root},dst=/proof",
            "--mount", "type=bind,src=/nix/store,dst=/nix/store,readonly",
            "--env", "RUST_LOG=warn", "--env", "TOKIO_WORKER_THREADS=2", "--entrypoint", tools["bash"],
            image, "/proof/start.sh"], text=True, timeout=60).strip()
        requests = []
        phases = []

        class ObserveAdapter(BaseHTTPRequestHandler):
            def forward(self):
                size = int(self.headers.get("Content-Length", "0"))
                assert size <= 2*1024**2
                body = self.rfile.read(size) if size else None
                requests.append(self.command)
                connection = HTTPConnection(address, timeout=10)
                try:
                    connection.request(self.command, self.path, body, dict(self.headers))
                    response = connection.getresponse()
                    body = response.read(2*1024**2 + 1)
                    assert len(body) <= 2*1024**2
                    self.send_response(response.status)
                    for name, value in response.getheaders():
                        if name.lower() not in ("connection", "transfer-encoding", "content-length"):
                            self.send_header(name, value)
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    if self.command != "HEAD":
                        self.wfile.write(body)
                finally:
                    connection.close()

            do_GET = do_HEAD = do_PUT = do_POST = do_DELETE = forward

            def log_message(self, *_):
                pass

        proxy = ThreadingHTTPServer(("127.0.0.1", 0), ObserveAdapter)
        proxy_thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        proxy_thread.start()

        def inside(source):
            return subprocess.check_output(["docker", "exec", container, python, "-c", source], text=True, timeout=60).strip()

        def stats():
            return json.loads(inside('''import json, os
from pathlib import Path
p = Path('/proof/mount')
s = os.statvfs(p)
files = [f for f in (p/'wal').rglob('*') if f.is_file()]
print(json.dumps({'available': s.f_bavail*s.f_frsize, 'wal_bytes': sum(f.stat().st_size for f in files),
  'wal_allocated': sum(f.stat().st_blocks*512 for f in files)}))
'''))

        def await_status(status):
            limit = time.monotonic() + 40
            while True:
                try:
                    with http.open(url + "/__ursula/ready", timeout=1) as response:
                        if response.status == status:
                            return
                except urllib.error.HTTPError as error:
                    if error.code == status:
                        return
                except (urllib.error.URLError, TimeoutError, ConnectionError):
                    pass
                assert time.monotonic() < limit, "Ursula disk gate did not reach expected state"
                time.sleep(0.1)

        def proof(phase):
            started = time.monotonic()
            result = subprocess.run([str(binary), f"http://127.0.0.1:{proxy.server_port}", phase],
                check=not growing, timeout=120, capture_output=growing, text=True)
            if growing:
                if result.returncode:
                    raise RuntimeError(f"Growing capacity {phase}: {result.stderr[-12000:]}")
                value = json.loads(result.stdout)
                value["seconds"] = round(time.monotonic() - started, 3)
                phases.append(value)
                print(f"Growing capacity: {json.dumps(value)}", flush=True)

        try:
            subprocess.run(["docker", "start", container], check=True, stdout=subprocess.DEVNULL, timeout=20)
            address = subprocess.check_output(["docker", "port", container, "8080/tcp"], text=True).strip()
            url = "http://" + address
            await_status(200)
            proof("write")
            before_pressure = stats()
            # Fill only this bounded filesystem. Confirm actual allocation fails
            # with ENOSPC rather than treating a mock quota error as disk pressure.
            inside('''import errno, os
p = '/proof/mount'
s = os.statvfs(p)
available = s.f_bavail*s.f_frsize
fd = os.open(p+'/filler', os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
os.posix_fallocate(fd, 0, available - 4*1024**2)
os.fsync(fd)
os.close(fd)
fd = os.open(p+'/enospc-probe', os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
try:
    os.posix_fallocate(fd, 0, 32*1024**2)
except OSError as error:
    assert error.errno == errno.ENOSPC
else:
    raise AssertionError('Expected physical ENOSPC')
finally:
    os.close(fd)
    os.unlink(p+'/enospc-probe')
os.sync()
''')
            await_status(503)
            pressured = stats()
            assert pressured["available"] < 16*1024**2
            request = urllib.request.Request(url + "/transit-capacity/pressure-probe", b"{}",
                {"Content-Type": "application/json"}, method="POST")
            try:
                http.open(request, timeout=5)
            except urllib.error.HTTPError as error:
                assert error.code == 503 and b"WalDiskPressure" in error.read()
            else:
                raise AssertionError("Storage accepted a write under disk pressure")
            if growing:
                proof("pressure")
            # Admissions are already durably closed. Releasing only the reserve
            # cannot reopen them; the filler stays allocated throughout recovery.
            inside("import os; os.unlink('/proof/mount/reserve'); os.sync()")
            await_status(200)
            released = stats()
            assert released["available"] - pressured["available"] >= 1024**3
            proof("control")
            after_control = stats()
            assert after_control["available"] > 32*1024**2
            assert after_control["wal_allocated"] - before_pressure["wal_allocated"] < 128*1024**2
            # Actual SIGKILL of Ursula, while the owned mount and filler persist.
            old_pid = inside("from pathlib import Path; print(Path('/proof/server.pid').read_text())")
            inside("import os, signal; from pathlib import Path; os.kill(int(Path('/proof/server.pid').read_text()), signal.SIGKILL)")
            limit = time.monotonic() + 10
            while inside("from pathlib import Path; print(Path('/proof/server.pid').read_text())") == old_pid:
                assert time.monotonic() < limit
                time.sleep(0.05)
            await_status(200)
            before_reconcile = stats()
            requests.clear()
            proof("recover")
            after_reconcile = stats()
            assert requests and set(requests) <= {"GET", "HEAD"}, "Completed maintenance issued a mutation"
            evidence = {"version": 1, "status": "passed", "image": image, "profile": "growing_v3" if growing else "v2",
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=repo)),
                "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
                "admission_ceiling": 96 if growing else 256, "control_record_bound": 96 if growing else 4385,
                "reserve_bytes": 1024**3, "before_pressure": before_pressure, "pressured": pressured,
                "released": released, "after_control": after_control, "before_recovery": before_reconcile,
                "after_recovery": after_reconcile, "recovery_methods": sorted(set(requests)), "phases": phases}
            output = repo / (".cache/growing-capacity-evidence.json" if growing else ".cache/capacity-evidence.json")
            output.parent.mkdir(exist_ok=True)
            output.write_text(json.dumps(evidence, indent=2) + "\n")
            print("Physical ENOSPC, reserved control progress, checkpoint/trim and disk restart passed.")
        except BaseException:
            subprocess.run(["docker", "logs", "--tail", "80", container], check=False)
            raise
        finally:
            proxy.shutdown()
            proxy.server_close()
            proxy_thread.join(timeout=5)
            subprocess.run(["docker", "stop", "--time", "10", container], check=False, stdout=subprocess.DEVNULL, timeout=20)
            subprocess.run(["docker", "rm", "--force", container], check=True, stdout=subprocess.DEVNULL, timeout=20)


if __name__ == "__main__":
    assert sys.argv[2:] in ([], ["--growing"]), "Expected binary [--growing]"
    run(Path(sys.argv[1]).resolve(strict=True), growing=bool(sys.argv[2:]))
