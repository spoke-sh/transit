"""Real pinned nginx termination, independent verified TLS peers, owned fixtures."""
import json
from pathlib import Path
import socket
import ssl
import subprocess
import time

from storage import free_port


class TLSProxy:
    def __init__(self, directory, backend):
        self.root = directory
        self.root.mkdir()
        self.port = free_port()
        self.backend = backend
        self.process = None
        self.log = None

    def __enter__(self):
        try:
            certificate, private = self.root / 'certificate.pem', self.root / 'private.pem'
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(private), '-out', str(certificate), '-days', '1', '-subj', '/CN=serving.example.test', '-addext', 'subjectAltName=DNS:serving.example.test,IP:127.0.0.1'], check=True, capture_output=True)
            private.chmod(0o600)
            template = (Path(__file__).resolve().parents[1] / 'examples/serving/nginx.conf.in').read_text()
            values = dict(PORT=self.port, BACKEND=self.backend, PID=self.root / 'nginx.pid', ERROR_LOG=self.root / 'nginx.log', BODY_TEMP=self.root / 'body', PROXY_TEMP=self.root / 'proxy', CERTIFICATE=certificate, PRIVATE_KEY=private)
            for key, value in values.items():
                template = template.replace('@' + key + '@', str(value) if isinstance(value, int) else json.dumps(str(value)))
            configuration = self.root / 'nginx.conf'
            configuration.write_text(template)
            self.log = (self.root / 'process.log').open('w+')
            self.process = subprocess.Popen(['nginx', '-p', str(self.root) + '/', '-c', str(configuration)], stdout=self.log, stderr=subprocess.STDOUT)
            self.context = ssl.create_default_context(cafile=str(certificate))
            until = time.monotonic() + 10
            while True:
                assert self.process.poll() is None, 'nginx exited before readiness'
                try:
                    with socket.create_connection(('127.0.0.1', self.port), timeout=1) as raw:
                        with self.context.wrap_socket(raw, server_hostname='serving.example.test') as peer:
                            assert peer.version() in ('TLSv1.2', 'TLSv1.3')
                    break
                except ConnectionRefusedError:
                    assert time.monotonic() < until
                    time.sleep(.03)
            for context, name in ((ssl.create_default_context(), 'serving.example.test'), (self.context, 'foreign.example.test')):
                try:
                    with socket.create_connection(('127.0.0.1', self.port), timeout=1) as raw:
                        context.wrap_socket(raw, server_hostname=name).close()
                except ssl.SSLCertVerificationError:
                    continue
                raise AssertionError('untrusted certificate or wrong hostname accepted')
            return self
        except BaseException:
            self.__exit__(True)
            raise

    def __exit__(self, *exc):
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        if self.log:
            if exc and exc[0]:
                self.log.seek(0)
                print(self.log.read()[-4000:])
            self.log.close()
