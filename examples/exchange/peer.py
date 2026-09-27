"""Independent synthetic TLS peers and network probes for finite exchanges."""
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import ssl
import sys
import threading
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


class RpcPeer:
    def __init__(self, config, host, port, record):
        import grpc
        self.executor = ThreadPoolExecutor(max_workers=2)
        self.server = grpc.server(self.executor, maximum_concurrent_rpcs=2)

        def exchange(messages, context):
            received = list(messages)
            metadata = list(context.invocation_metadata())
            if received != [bytes.fromhex(config["request"]), b""] or ("authorization", config["secret"]) not in metadata:
                context.abort(grpc.StatusCode.PERMISSION_DENIED, "Fixture request rejected")
            record("/transit.examples.Exchange/Exchange")
            context.send_initial_metadata((("x-tag", "one"), ("x-tag", "two"), ("x-data-bin", b"\x00\xff")))
            yield bytes.fromhex(config["payload"])
            yield b""
            context.set_trailing_metadata((("x-end", "complete"),))

        self.server.add_generic_rpc_handlers((grpc.method_handlers_generic_handler(
            "transit.examples.Exchange", {"Exchange": grpc.stream_stream_rpc_method_handler(
                exchange, request_deserializer=lambda value: value, response_serializer=lambda value: value)}),))
        credentials = grpc.ssl_server_credentials(((Path(config["private_key"]).read_bytes(), Path(config["certificate"]).read_bytes()),))
        self.server_port = self.server.add_secure_port(f"{host}:{port}", credentials)
        assert self.server_port
        self.server.start()

    def shutdown(self):
        self.server.stop(0).wait()
        self.executor.shutdown(wait=True)

    def server_close(self): pass


def start(config, host="127.0.0.1", port=0, requests=None):
    requests = requests if requests is not None else []

    def record(path):
        requests.append(path)
        if config.get("requests"):
            Path(config["requests"]).write_text(json.dumps(requests))

    if config.get("protocol") == "grpc":
        return RpcPeer(config, host, port, record)

    payload = bytes.fromhex(config["payload"])

    class Peer(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        def log_message(self, *_): pass
        def do_POST(self):
            if self.path != "/example" or self.headers.get("Authorization") != "Bearer " + config["secret"] or self.rfile.read(int(self.headers["Content-Length"])) != b"hello":
                self.send_error(403)
                return
            record(self.path)
            self.send_response(200)
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Set-Cookie", "omitted")
            self.end_headers()
            self.wfile.write(payload)

    peer = ThreadingHTTPServer((host, port), Peer)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(config["certificate"], config["private_key"])
    peer.socket = context.wrap_socket(peer.socket, server_side=True)
    threading.Thread(target=peer.serve_forever, daemon=True).start()
    return peer


if __name__ == "__main__":
    if sys.argv[1] == "probe": probe(sys.argv[2], sys.argv[3:])
    else:
        server = start(json.loads(Path(sys.argv[1]).read_text()), "0.0.0.0", 8443)
        try: threading.Event().wait()
        finally: server.shutdown(); server.server_close()
