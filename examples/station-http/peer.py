"""Independent synthetic TLS peer and network probes for the HTTP example."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import ssl
import sys
import urllib.request


def probe(authority, denied):
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(authority + "/health", timeout=5) as response:
        assert response.status == 200
    for address in denied:
        host, port = address.rsplit(":", 1)
        try:
            connection = socket.create_connection((host, int(port)), timeout=1)
        except OSError:
            continue
        connection.close()
        raise RuntimeError("Unexpected network access: " + address)
    print(json.dumps({"authority": "reachable", "denied": len(denied)}))


def serve(path):
    config = json.loads(Path(path).read_text())
    payload = bytes.fromhex(config["payload"])
    requests = []

    class Peer(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        def log_message(self, *_): pass
        def do_POST(self):
            if self.path != "/example" or self.headers.get("Authorization") != "Bearer " + config["secret"] or self.rfile.read(int(self.headers["Content-Length"])) != b"hello":
                self.send_error(403)
                return
            requests.append(self.path)
            Path(config["requests"]).write_text(json.dumps(requests))
            self.send_response(200)
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Set-Cookie", "omitted")
            self.end_headers()
            self.wfile.write(payload)

    peer = ThreadingHTTPServer(("0.0.0.0", 8443), Peer)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(config["certificate"], config["private_key"])
    peer.socket = context.wrap_socket(peer.socket, server_side=True)
    peer.serve_forever()


if __name__ == "__main__":
    if sys.argv[1] == "probe": probe(sys.argv[2], sys.argv[3:])
    else: serve(sys.argv[1])
