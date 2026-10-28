"""Independent Python/OpenSSL clients exercise the actual Zig TLS server API."""
import socket
import json
import ssl
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from interfaces.sql_wire.reference import exact, port, run


def connect(child, listen):
    deadline = time.monotonic() + 10
    while True:
        assert child.poll() is None, 'TLS probe exited before accepting'
        try:
            return socket.create_connection(('127.0.0.1', listen), timeout=5)
        except ConnectionRefusedError:
            assert time.monotonic() < deadline
            time.sleep(.02)


def main(binary):
    with tempfile.TemporaryDirectory(prefix='transit-server-tls-') as directory:
        root = Path(directory)
        cert, key = root / 'certificate.pem', root / 'key.pem'
        run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
             '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost',
             '-keyout', str(key), '-out', str(cert)])
        key.chmod(0o600)
        for protocol in ('postgres', 'mysql'):
            for case in ('1.2', '1.3', 'wrong-host', 'untrusted', 'plaintext', 'timeout'):
                listen = port()
                child = subprocess.Popen([binary, str(cert), str(key), str(listen), protocol],
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    with connect(child, listen) as sock:
                        # Deliberately fragment the upgrade frame.
                        request = struct.pack('!II', 8, 80877103) if protocol == 'postgres' else b'\x20\0\0\x01' + struct.pack('<IIB', 0xA00, 65536, 46) + bytes(23)
                        for byte in request:
                            sock.sendall(bytes([byte]))
                        if protocol == 'postgres':
                            assert exact(sock, 1) == b'S'
                        if case == 'timeout':
                            assert child.wait(timeout=6) != 0
                            continue
                        if case == 'plaintext':
                            sock.sendall(b'this is not TLS\n')
                            assert child.wait(timeout=6) != 0
                            continue
                        context = ssl.create_default_context(cafile=None if case == 'untrusted' else cert)
                        if case in ('1.2', '1.3'):
                            version = ssl.TLSVersion.TLSv1_2 if case == '1.2' else ssl.TLSVersion.TLSv1_3
                            context.minimum_version = context.maximum_version = version
                        try:
                            with context.wrap_socket(sock, server_hostname='wrong.invalid' if case == 'wrong-host' else 'localhost') as secure:
                                assert case in ('1.2', '1.3')
                                assert secure.version() == 'TLSv' + case
                                payload = b'independent-peer'
                                secure.sendall(payload[:3])
                                secure.sendall(payload[3:])
                                assert exact(secure, len(payload)) == payload
                                assert secure.recv(1) == b''
                        except ssl.SSLCertVerificationError:
                            assert case in ('wrong-host', 'untrusted')
                        code = child.wait(timeout=6)
                        assert (code == 0) == (case in ('1.2', '1.3')), (protocol, case, child.stderr.read().decode())
                finally:
                    if child.poll() is None:
                        child.kill()
                    child.communicate(timeout=10)
        print('Zig/OpenSSL server: both upgrade frames, TLS 1.2/1.3, fragmented input, identity/trust denial, plaintext refusal and deadline pass.')
        for protocol in ('postgres', 'mysql'):
            listen = port()
            child = subprocess.Popen([binary, str(cert), str(key), str(listen), protocol, '100'],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                for iteration in range(100):
                    with connect(child, listen) as sock:
                        request = struct.pack('!II', 8, 80877103) if protocol == 'postgres' else b'\x20\0\0\x01' + struct.pack('<IIB', 0xA00, 65536, 46) + bytes(23)
                        sock.sendall(request)
                        if protocol == 'postgres':
                            assert exact(sock, 1) == b'S'
                        context = ssl.create_default_context(cafile=cert)
                        version = ssl.TLSVersion.TLSv1_2 if iteration % 2 == 0 else ssl.TLSVersion.TLSv1_3
                        context.minimum_version = context.maximum_version = version
                        with context.wrap_socket(sock, server_hostname='localhost') as secure:
                            payload = bytes([iteration]) * 16
                            secure.sendall(payload)
                            assert exact(secure, 16) == payload
                            assert secure.recv(1) == b''
                stdout, stderr = child.communicate(timeout=10)
                assert child.returncode == 0, stderr.decode()
                report = json.loads(stdout)
                assert report['connections'] == 100
                assert all(report['backing'][field] == 0 for field in ('alloc_attempts', 'growing_resize_attempts', 'remap_attempts'))
                assert 0 < report['peak_occupied_bytes'] < 16 * 1024 * 1024
                print(f'{protocol}: 100 alternating TLS 1.2/1.3 connections in one fixed OpenSSL reserve; peak={report["peak_occupied_bytes"]}')
            finally:
                if child.poll() is None:
                    child.kill()
                child.communicate(timeout=10)


if __name__ == '__main__':
    main(str(Path(sys.argv[1]).resolve()))
