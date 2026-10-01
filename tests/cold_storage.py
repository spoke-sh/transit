"""Owned, loopback-only MinIO fixture for Ursula cold-tier qualification."""
from datetime import datetime, timezone
import hashlib
import hmac
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from storage import free_port


def minio_binary():
    """The pinned shell and local bundle share nix/minio.nix's source build."""
    path = shutil.which('minio')
    if path is None:
        raise RuntimeError('Pinned MinIO is required; enter the Linux x86_64 Nix development shell')
    return Path(path).resolve()


class ColdStore:
    def __init__(self):
        # Cleanup is explicit so an unjoined child retains its owned disk state.
        self.directory = tempfile.TemporaryDirectory(prefix="transit-cold-proof-", delete=False)
        self.root = Path(self.directory.name) / 'data'
        self.root.mkdir(mode=0o700)
        self.access = "transit-proof"
        self.secret = secrets.token_hex(24)
        self.bucket = "transit-proof"
        self.port = free_port()
        self.url = f"http://127.0.0.1:{self.port}"
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.pid = None
        self.process = None
        self.log = None
        self.identity = None

    def __enter__(self):
        try:
            self.log = (Path(self.directory.name) / 'minio.log').open('w+b')
            binary = minio_binary()
            with binary.open('rb') as artifact:
                digest = hashlib.file_digest(artifact, 'sha256').hexdigest()
            self.identity = {'kind': 'native', 'binary': str(binary), 'sha256': digest}
            # A fresh native process owns only this disk directory and loopback
            # listener. No ambient MinIO/cloud configuration is inherited.
            env = {key: value for key, value in os.environ.items()
                   if not key.startswith(('MINIO_', 'AWS_'))}
            env.update(MINIO_ROOT_USER=self.access, MINIO_ROOT_PASSWORD=self.secret, MINIO_BROWSER='off')
            self.process = subprocess.Popen([
                binary, 'server', str(self.root), '--address', f'127.0.0.1:{self.port}',
                '--console-address', '127.0.0.1:0',
            ], env=env, cwd=self.root, stdout=self.log, stderr=subprocess.STDOUT)
            self.pid = self.process.pid
            deadline = time.monotonic() + 30
            while True:
                if self.process.poll() is not None:
                    raise RuntimeError(f'Owned cold store exited before readiness: {self.process.returncode}')
                try:
                    with self.http.open(self.url + "/minio/health/ready", timeout=0.5) as response:
                        if response.status == 200:
                            break
                except (urllib.error.URLError, TimeoutError, ConnectionError):
                    pass
                if time.monotonic() >= deadline:
                    raise TimeoutError("Owned cold-store readiness deadline")
                time.sleep(0.05)
            self.create_bucket(deadline)
            return self
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise

    def create_bucket(self, deadline):
        # Minimal SigV4 for this one empty PutBucket request; no cloud credentials
        # or SDK chain are consulted. Ursula itself exercises the S3 data path.
        now = datetime.now(timezone.utc)
        date, timestamp = now.strftime("%Y%m%d"), now.strftime("%Y%m%dT%H%M%SZ")
        payload = hashlib.sha256(b"").hexdigest()
        host = f"127.0.0.1:{self.port}"
        signed_headers = "host;x-amz-content-sha256;x-amz-date"
        canonical = (f"PUT\n/{self.bucket}\n\nhost:{host}\nx-amz-content-sha256:{payload}\n"
                     f"x-amz-date:{timestamp}\n\n{signed_headers}\n{payload}")
        scope = f"{date}/us-east-1/s3/aws4_request"
        to_sign = f"AWS4-HMAC-SHA256\n{timestamp}\n{scope}\n{hashlib.sha256(canonical.encode()).hexdigest()}"
        key = ("AWS4" + self.secret).encode()
        for value in (date, "us-east-1", "s3", "aws4_request"):
            key = hmac.digest(key, value.encode(), "sha256")
        signature = hmac.new(key, to_sign.encode(), "sha256").hexdigest()
        authorization = f"AWS4-HMAC-SHA256 Credential={self.access}/{scope}, SignedHeaders={signed_headers}, Signature={signature}"
        request = urllib.request.Request(self.url + "/" + self.bucket, data=b"", method="PUT",
            headers={"Authorization": authorization, "x-amz-date": timestamp, "x-amz-content-sha256": payload})
        retries = 0
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Owned cold-store bucket readiness deadline")
            try:
                with self.http.open(request, timeout=min(5, remaining)) as response:
                    assert response.status == 200
                if retries:
                    print(f"Cold-store bucket readiness: {retries} temporary HTTP 503 responses before creation.", flush=True)
                return
            except urllib.error.HTTPError as error:
                if error.code == 409:
                    # A prior PUT can have succeeded before its reply was lost.
                    # Only the explicit owned-bucket result is idempotent.
                    body = error.read(4096)
                    error.close()
                    try:
                        owned = ET.fromstring(body).findtext('Code') == 'BucketAlreadyOwnedByYou'
                    except ET.ParseError:
                        owned = False
                    if not owned:
                        raise
                    return
                # The health route can become ready before bucket operations.
                # Repeat this same private fixture request only for temporary
                # unavailability, within the original startup deadline.
                if error.code != 503:
                    raise
                error.close()
                retries += 1
            time.sleep(min(0.05, max(0, deadline-time.monotonic())))

    def config(self):
        return f'''[storage.cold]
backend = "s3"
root = "pages"
flush_interval = "100ms"
flush_size = "256KiB"
flush_pressure_hot_size = "256KiB"
max_hot_size_per_group = "8MiB"
[storage.cold.cache]
max_size = "8MiB"
block_size = "256KiB"
readahead_blocks = 0
[storage.cold.s3]
bucket = "{self.bucket}"
region = "us-east-1"
endpoint = "{self.url}"
access_key_id = "{self.access}"
secret_access_key = "{self.secret}"
server_side_encryption = "none"
[storage.snapshot]
backend = "s3"
drive_interval = "1s"
[governance.cold_health]
hot_size_high = "6MiB"
hot_size_low = "4MiB"
'''

    def file_bytes(self):
        total = 0
        for path in self.root.rglob("*"):
            try:
                if path.is_file():
                    total += path.stat().st_size
            except FileNotFoundError:
                pass  # Concurrent object-store temporary-file reclamation.
        return total

    def data_objects(self):
        # This pinned MinIO layout stores one xl.meta per object. Require actual
        # Ursula chunk objects, not merely MinIO's bucket/startup metadata.
        return sum(1 for _ in (self.root / self.bucket).glob("**/chunks/*/xl.meta"))

    def stop(self):
        """Join the owned native process without removing its disk evidence."""
        if self.process is not None:
            if self.process.poll() is None:
                self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=10)
            if self.process.poll() is None:
                raise RuntimeError(f'Cold-store stop did not join PID {self.pid}')

    def __exit__(self, exc_type, *_):
        try:
            self.stop()
        finally:
            try:
                if self.log is not None:
                    if exc_type:
                        self.log.flush()
                        self.log.seek(0, os.SEEK_END)
                        self.log.seek(max(0, self.log.tell() - 8192))
                        tail = self.log.read(8192).decode(errors='replace').replace(self.secret, '<redacted>')
                        sys.stderr.write(tail[-4000:])
                    self.log.close()
            finally:
                if self.process is not None and self.process.poll() is None:
                    raise RuntimeError(f'Cold-store cleanup did not join PID {self.pid}; retained {self.directory.name}')
                self.directory.cleanup()
