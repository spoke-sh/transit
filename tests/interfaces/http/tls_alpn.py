"""TLS 1.2/1.3 ALPN must select h2 before any application bytes are written."""
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
from pathlib import Path


with tempfile.TemporaryDirectory(prefix="transit-alpn-") as work:
    root = Path(work)
    key, cert = root / "key.pem", root / "cert.pem"
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                    "-keyout", str(key), "-out", str(cert), "-days", "1",
                    "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"],
                   check=True, capture_output=True, timeout=20)
    for version in (ssl.TLSVersion.TLSv1_2, ssl.TLSVersion.TLSv1_3):
        for offered in (["h2"], [], ["http/1.1"]):
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = context.maximum_version = version
            context.load_cert_chain(cert, key)
            context.set_alpn_protocols(offered)
            captured, selected, failures = [], [], []
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(10)
                def peer():
                    try:
                        sock, _ = listener.accept()
                        with sock:
                            sock.settimeout(5)
                            try:
                                with context.wrap_socket(sock, server_side=True) as connection:
                                    selected.append(connection.selected_alpn_protocol())
                                    captured.append(connection.recv(128))
                            except (ssl.SSLError, ConnectionResetError):
                                pass
                    except Exception as error:
                        failures.append(error)
                thread = threading.Thread(target=peer); thread.start()
                result = subprocess.run([sys.argv[1], str(listener.getsockname()[1]), str(cert)], capture_output=True, timeout=10)
                thread.join(timeout=10)
                assert not thread.is_alive() and not failures, failures
                if offered == ["h2"]:
                    assert result.returncode == 0 and selected == ["h2"] and captured == [b"negotiated-h2"], (version, result.stderr, captured)
                else:
                    assert result.returncode != 0 and not any(captured), (version, offered, captured)
    print("TLS ALPN: h2 negotiated under TLS 1.2/1.3; absent and incompatible selections send no application data.")
