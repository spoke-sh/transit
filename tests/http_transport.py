"""Bounded real HTTP/TLS bytes, framing, omission, timeout and no-retry proof."""
import hashlib
import json
import os
from pathlib import Path
import socketserver
import ssl
import subprocess
import sys
import tempfile
import threading
import time


def run(binary):
    requests = []
    failures = []
    names = []
    payload = bytes((i * 17 + 3) % 256 for i in range(16387))

    class Peer(socketserver.BaseRequestHandler):
        def handle(self):
            try:
                data = b""
                while b"\r\n\r\n" not in data:
                    part = self.request.recv(4096)
                    if not part:
                        return
                    data += part
                head, body = data.split(b"\r\n\r\n", 1)
                while len(body) < 12:
                    body += self.request.recv(4096)
                assert body == b"request-body", body
                assert b"X-Order: first\r\nX-Order: second" in head
                path = head.split(b" ")[1].decode()
                host = b"http-pin.invalid" if path == "/pinned-name" else b"localhost"
                assert b"Host: " + host + b":" in head
                requests.append(path)
                if path == "/timeout":
                    time.sleep(1.3)
                    return
                if path == "/dropped":
                    return
                if path == "/smuggling":
                    self.request.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n")
                elif path == "/truncated":
                    self.request.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 40\r\n\r\nshort")
                elif path == "/redirect":
                    self.request.sendall(b"HTTP/1.1 307 Temporary Redirect\r\nLocation: http://169.254.169.254/private\r\nContent-Length: 0\r\n\r\n")
                elif path == "/close":
                    self.request.sendall(b"HTTP/1.1 200 OK\r\n\r\n" + payload)
                elif path == "/no-body":
                    self.request.sendall(b"HTTP/1.1 204 No Content\r\n\r\n")
                else:
                    self.request.sendall(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nSet-Cookie: fixture-secret\r\nContent-Type: application/octet-stream\r\n\r\n")
                    for offset in range(0, len(payload), 257):
                        piece = payload[offset:offset + 257]
                        self.request.sendall(f"{len(piece):x}\r\n".encode() + piece + b"\r\n")
                    self.request.sendall(b"0\r\nX-Private: fixture-secret\r\n\r\n")
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                pass  # Expected when validation/capture rejects the response.
            except BaseException as error:
                failures.append(repr(error))

    class Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True

    with tempfile.TemporaryDirectory(prefix="transit-http-") as directory:
        root = Path(directory)
        key, cert = root / "key.pem", root / "cert.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key), "-out", str(cert), "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,DNS:http-pin.invalid"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        other_cert = root / "other.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(root / "other-key.pem"), "-out", str(other_cert), "-days", "1", "-subj", "/CN=other"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for tls in (False, True):
            with Server(("127.0.0.1", 0), Peer) as server:
                if tls:
                    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                    context.load_cert_chain(cert, key)
                    context.set_servername_callback(lambda connection, name, context: names.append(name))
                    server.socket = context.wrap_socket(server.socket, server_side=True)
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    def invoke(path, trust=cert):
                        before = requests.count(path)
                        env = dict(os.environ, **{key: "http://127.0.0.1:1" for key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")})
                        result = json.loads(subprocess.check_output([binary, str(server.server_address[1]), path, "tls" if tls else "plain", str(trust)], timeout=10, env=env))
                        if path not in ("/wrong-host", "/dns-address", "/wrong-ca"):
                            assert requests.count(path) == before + 1, (path, requests)
                        else:
                            assert requests.count(path) == before
                        return result

                    result = invoke("/chunked")
                    assert result == {"status": 200, "bytes": len(payload), "omitted": 2, "sha256": hashlib.sha256(payload).hexdigest()}, result
                    assert invoke("/pinned-name") == result  # Reserved name has no DNS record.
                    assert "error" in invoke("/dns-address")  # A name cannot replace the pinned numeric address.
                    assert invoke("/no-body")["bytes"] == 0
                    assert invoke("/redirect")["status"] == 307
                    assert invoke("/smuggling")["error"] == "InvalidHttpFraming"
                    assert "error" in invoke("/truncated")
                    assert invoke("/small")["error"] == "HttpResponseTooLarge"
                    assert invoke("/capture-failure")["error"] == "CaptureUnavailable"
                    assert "error" in invoke("/dropped")
                    assert invoke("/timeout")["error"] == "HttpOutcomeUnknown"
                    close = invoke("/close")
                    assert close.get("error") == "UnframedTlsResponse" if tls else close["bytes"] == len(payload)
                    if tls:
                        assert invoke("/wrong-host")["error"] == "TlsInitializationFailed"
                        assert invoke("/wrong-ca", other_cert)["error"] == "TlsInitializationFailed"
                        assert "http-pin.invalid" in names and "localhost" in names
                finally:
                    server.shutdown()
                    thread.join(timeout=5)
        assert not failures, failures
        print(f"HTTP transport: {len(requests)} single-send requests; TLS identity, framing, binary chunks, omissions, failures and deadline passed.")


if __name__ == "__main__":
    run(str(Path(sys.argv[1]).resolve()))
