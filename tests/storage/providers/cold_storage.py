"""Owned MinIO fixture; loopback by default, explicit private bridge for placements."""
from datetime import datetime, timezone
import hashlib
import hmac
import ipaddress
import os
from pathlib import Path
import secrets
import ssl
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from harness.services import free_port
from harness.phases import phase


def minio_binary():
    """The pinned shell and local bundle share nix/minio.nix's source build."""
    path = shutil.which('minio')
    if path is None:
        raise RuntimeError('Pinned MinIO is required; enter the Linux x86_64 or ARM64 Nix development shell')
    return Path(path).resolve()


class ColdStore:
    def __init__(self, *, bind_address='127.0.0.1', tls=None):
        address = ipaddress.IPv4Address(bind_address)
        if not address.is_private or address.is_unspecified or address.is_multicast:
            raise ValueError('Cold-store fixture needs a selected private interface')
        self.bind_address = str(address)
        # Failure evidence must survive Nix's disposable TMPDIR as well as an
        # unjoined child. Only successful joined runs remove their own state.
        self.directory = tempfile.TemporaryDirectory(prefix="transit-cold-proof-", dir='/var/tmp', delete=False)
        self.root = Path(self.directory.name) / 'data'
        self.root.mkdir(mode=0o700)
        self.access = "transit-proof"
        self.secret = secrets.token_hex(24)
        self.bucket = "transit-proof"
        self.port = free_port()
        self.tls = (not address.is_loopback) if tls is None else tls
        self.url = f"{'https' if self.tls else 'http'}://{self.bind_address}:{self.port}"
        self.ca_file = None
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.pid = None
        self.process = None
        self.log = None
        self.identity = None

    @phase("provision", "minio")
    def __enter__(self):
        try:
            self.log = (Path(self.directory.name) / 'minio.log').open('w+b')
            binary = minio_binary()
            with binary.open('rb') as artifact:
                digest = hashlib.file_digest(artifact, 'sha256').hexdigest()
            self.identity = {'kind': 'native', 'binary': str(binary), 'sha256': digest}
            # A fresh native process owns only this disk directory and selected
            # listener. No ambient MinIO/cloud configuration is inherited.
            env = {key: value for key, value in os.environ.items()
                   if not key.startswith(('MINIO_', 'AWS_'))}
            env.update(MINIO_ROOT_USER=self.access, MINIO_ROOT_PASSWORD=self.secret, MINIO_BROWSER='off')
            tls_args = []
            if self.tls:
                certificates = Path(self.directory.name) / 'certs'
                certificates.mkdir(mode=0o700)
                self.ca_file = certificates / 'public.crt'
                subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                    '-keyout', str(certificates / 'private.key'), '-out', str(self.ca_file),
                    '-days', '2', '-subj', '/CN=transit-minio-proof',
                    '-addext', f'subjectAltName=IP:{self.bind_address}',
                    '-addext', 'basicConstraints=critical,CA:TRUE'],
                    check=True, capture_output=True, timeout=30)
                (certificates / 'private.key').chmod(0o600)
                self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                    urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=str(self.ca_file))))
                tls_args = ['--certs-dir', str(certificates)]
            self.process = subprocess.Popen([
                binary, 'server', str(self.root), '--address', f'{self.bind_address}:{self.port}',
                '--console-address', '127.0.0.1:0', *tls_args,
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
        # or SDK chain are consulted. Transit itself exercises the S3 data path.
        now = datetime.now(timezone.utc)
        date, timestamp = now.strftime("%Y%m%d"), now.strftime("%Y%m%dT%H%M%SZ")
        payload = hashlib.sha256(b"").hexdigest()
        host = f"{self.bind_address}:{self.port}"
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

    def native_config(self):
        """Explicit native tier configuration with an owned credential reference."""
        import json
        credentials = Path(self.directory.name) / 'native-credentials.json'
        credentials.write_text(json.dumps(dict(access_key_id=self.access, secret_access_key=self.secret)))
        credentials.chmod(0o600)
        return dict(endpoint=self.url, region='us-east-1', bucket=self.bucket,
                    prefix='native-' + secrets.token_hex(16), credentials_file=str(credentials),
                    allow_loopback_http=not self.tls, ca_file=str(self.ca_file) if self.ca_file else None, cache_bytes=32 * 1024 * 1024)

    def placement_config(self, work):
        """Mount only into the authority; callers never receive provider files."""
        options = self.native_config()
        operator = Path(work) / 'operator'
        for member, name in (('credentials_file', 'object-credentials.json'), ('ca_file', 'object-ca.pem')):
            source = options[member]
            if source is not None:
                target = operator / name
                target.write_bytes(Path(source).read_bytes())
                target.chmod(0o600)
                options[member] = '/operator/' + name
        return options

    def native_data_objects(self):
        # MinIO's actual per-generation object metadata; exclude owner markers.
        return sum(1 for path in (self.root / self.bucket).glob('native-*/objects/*/*/xl.meta') if path.is_file())

    def file_bytes(self):
        total = 0
        for path in self.root.rglob("*"):
            try:
                if path.is_file():
                    total += path.stat().st_size
            except FileNotFoundError:
                pass  # Concurrent object-store temporary-file reclamation.
        return total

    @phase("teardown", "minio")
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
                if exc_type:
                    print(f'Failed MinIO state and private credentials retained at {self.directory.name}', file=sys.stderr)
                else:
                    self.directory.cleanup()
