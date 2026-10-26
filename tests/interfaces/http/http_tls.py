"""Independent TLS path-validation peers; every key is generated for this run."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import ssl
import subprocess
import threading


def verify_paths(binary, root):
    def openssl(*args):
        subprocess.run(["openssl", *map(str, args)], cwd=root, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)

    def signed(name, issuer, extensions):
        openssl("req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", name + ".key",
                "-out", name + ".csr", "-subj", "/CN=" + name)
        (root / (name + ".ext")).write_text(extensions)
        openssl("x509", "-req", "-in", name + ".csr", "-CA", issuer + ".pem",
                "-CAkey", issuer + ".key", "-CAcreateserial", "-out", name + ".pem",
                "-days", "1", "-extfile", name + ".ext")

    openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", "anchor.key",
            "-out", "anchor.pem", "-days", "1", "-subj", "/CN=anchor",
            "-addext", "basicConstraints=critical,CA:TRUE")
    ca = "basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n"
    leaf = "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nsubjectAltName=DNS:localhost\n"
    cases = {
        "valid": (ca, leaf + "extendedKeyUsage=serverAuth\n"),
        "nonca": (ca.replace("CA:TRUE,pathlen:0", "CA:FALSE"), leaf),
        "usage": (ca.replace("keyCertSign,cRLSign", "digitalSignature"), leaf),
        "purpose": (ca, leaf + "extendedKeyUsage=clientAuth\n"),
        "names": (ca + "nameConstraints=critical,permitted;DNS:.allowed.invalid\n", leaf),
        "pathlen": (ca, leaf),
    }
    for name, (constraints, purpose) in cases.items():
        issuer = name + "-issuer"
        signed(issuer, "anchor", constraints)
        chain = (root / (issuer + ".pem")).read_bytes()
        if name == "pathlen":
            child = name + "-child"
            signed(child, issuer, ca)
            issuer = child
            chain = (root / (child + ".pem")).read_bytes() + chain
        signed(name, issuer, purpose)
        chain_file = root / (name + "-chain.pem")
        chain_file.write_bytes((root / (name + ".pem")).read_bytes() + chain)
        for version in (ssl.TLSVersion.TLSv1_2, ssl.TLSVersion.TLSv1_3):
            requests = []

            class Peer(BaseHTTPRequestHandler):
                protocol_version = "HTTP/1.1"
                def log_message(self, *_): pass
                def do_POST(self):
                    requests.append(self.path)
                    self.rfile.read(int(self.headers["Content-Length"]))
                    self.send_response(200)
                    self.send_header("Content-Length", "0")
                    self.end_headers()

            server = ThreadingHTTPServer(("127.0.0.1", 0), Peer)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = context.maximum_version = version
            context.load_cert_chain(chain_file, root / (name + ".key"))
            server.socket = context.wrap_socket(server.socket, server_side=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                result = json.loads(subprocess.check_output([binary, str(server.server_port), "/path", "tls", str(root / "anchor.pem")], timeout=10))
                if name == "valid":
                    assert result.get("status") == 200 and requests == ["/path"], (name, version, result)
                else:
                    expected = {"nonca": "NotACertificateAuthority", "usage": "KeyUsageForbidsCertSigning",
                                "purpose": "ExtendedKeyUsageMismatch", "names": "NameConstraintViolated",
                                "pathlen": "PathLenConstraintExceeded"}[name]
                    assert result["error"] == expected and requests == [], (name, version, result)
            finally:
                server.shutdown(); server.server_close(); thread.join(timeout=5)
    print("TLS path validation: TLS 1.2/1.3 valid chains accepted; non-CA, signing usage, path length, server purpose and name constraints rejected before HTTP bytes.")
