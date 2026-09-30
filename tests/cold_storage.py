"""Owned, loopback-only MinIO fixture for Ursula cold-tier qualification."""
from datetime import datetime, timezone
import hashlib
import hmac
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
import urllib.request
import urllib.error
import uuid
import xml.etree.ElementTree as ET
from storage import free_port


IMAGE = "quay.io/minio/minio@sha256:14cea493d9a34af32f524e538b8346cf79f3321eff8e708c1e2960462bd8936e"


class ColdStore:
    def __init__(self):
        self.directory = tempfile.TemporaryDirectory(prefix="transit-cold-proof-")
        self.root = Path(self.directory.name)
        self.name = "transit-cold-proof-" + uuid.uuid4().hex[:12]
        self.access = "transit-proof"
        self.secret = secrets.token_hex(24)
        self.bucket = "transit-proof"
        self.port = free_port()
        self.url = f"http://127.0.0.1:{self.port}"
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.pid = None

    def __enter__(self):
        try:
            subprocess.run([
                "docker", "run", "--detach", "--rm", "--name", self.name,
                "--user", f"{os.getuid()}:{os.getgid()}",
                "--publish", f"127.0.0.1:{self.port}:9000",
                "--mount", f"type=bind,source={self.root},target=/data",
                "--env", "MINIO_ROOT_USER",
                "--env", "MINIO_ROOT_PASSWORD",
                IMAGE, "server", "/data", "--address", ":9000", "--console-address", ":9001",
            ], env={**os.environ, "MINIO_ROOT_USER": self.access, "MINIO_ROOT_PASSWORD": self.secret},
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=120)
            deadline = time.monotonic() + 30
            while True:
                ready = False
                try:
                    with self.http.open(self.url + "/minio/health/ready", timeout=0.5) as response:
                        ready = response.status == 200
                except (urllib.error.URLError, TimeoutError, ConnectionError):
                    pass
                if ready:
                    try:
                        # The health route can answer before PutBucket is ready.
                        # This empty PUT names only this fixture's owned bucket.
                        self.create_bucket()
                    except urllib.error.HTTPError as error:
                        if error.code != 503:
                            raise
                        error.close()
                    else:
                        break
                if time.monotonic() >= deadline:
                    raise TimeoutError("Owned cold-store readiness deadline")
                time.sleep(0.05)
            self.pid = int(subprocess.check_output(
                ["docker", "inspect", "--format", "{{.State.Pid}}", self.name], text=True, timeout=10))
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def create_bucket(self):
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
        try:
            response = self.http.open(request, timeout=5)
        except urllib.error.HTTPError as error:
            if error.code != 409:
                raise
            # A previous PUT can have succeeded before a lost/503 response.
            # Never accept another owner's bucket or an unrelated conflict.
            body = error.read(4096)
            error.close()
            try:
                owned = ET.fromstring(body).findtext('Code') == 'BucketAlreadyOwnedByYou'
            except ET.ParseError:
                owned = False
            if not owned:
                raise
            return
        with response:
            assert response.status == 200

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

    def __exit__(self, *_):
        try:
            subprocess.run(["docker", "rm", "--force", self.name], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        finally:
            self.directory.cleanup()
