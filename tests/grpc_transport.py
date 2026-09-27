"""Independent grpcio peer; runtime implementation is the actual Zig transport."""
from concurrent.futures import ThreadPoolExecutor
import grpc
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory
from grpc_h2 import verify

with tempfile.TemporaryDirectory(prefix="transit-grpc-") as work:
    root = Path(work)
    key, cert = root / "key.pem", root / "cert.pem"
    fixture = Path(__file__).parent / "fixtures" / "grpc"
    subprocess.run(["protoc", "--proto_path=" + str(fixture), "--include_imports", "--descriptor_set_out=" + str(root / "peer.pb"), str(fixture / "peer.proto")], check=True, timeout=10)
    assert (root / "peer.pb").read_bytes() == (fixture / "peer.pb").read_bytes()
    descriptor = descriptor_pb2.FileDescriptorSet.FromString((fixture / "peer.pb").read_bytes())
    descriptors = descriptor_pool.DescriptorPool()
    for file in descriptor.file: descriptors.Add(file)
    Payload = message_factory.GetMessageClass(descriptors.FindMessageTypeByName("test.Payload"))
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key), "-out", str(cert), "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"], check=True, capture_output=True, timeout=20)
    applications = []
    def begin(context, name):
        applications.append(name)
        metadata = list(context.invocation_metadata())
        assert [(k, v) for k, v in metadata if k == "x-repeat"] == [("x-repeat", "first"), ("x-repeat", "second")]
        assert ("x-blob-bin", b"\x00\xff") in metadata
        context.send_initial_metadata((("x-repeat", "first"), ("x-repeat", "second"), ("x-blob-bin", b"\x00\xff")))
        context.set_trailing_metadata((("x-trailer", "done"), ("x-blob-bin", b"\x00\xff")))
    def unary(request, context):
        begin(context, "unary"); return request
    def server_stream(request, context):
        begin(context, "server")
        for _ in range(8): yield request
    def client_stream(requests, context):
        begin(context, "client")
        items = list(requests)
        assert len(items) == 4
        return items[0]
    def bidi(requests, context):
        begin(context, "bidi")
        for request in requests:
            yield request
    def failed(request, context):
        begin(context, "failed"); context.abort(grpc.StatusCode.PERMISSION_DENIED, "fixture refusal")
    def stall(request, context):
        begin(context, "stall")
        while context.is_active(): time.sleep(.02)
        return b""
    def oversized(request, context):
        begin(context, "oversized"); return b"x" * 16385
    pool = ThreadPoolExecutor(max_workers=4)
    server = grpc.server(pool, options=(("grpc.so_reuseport", 0),))
    server.add_generic_rpc_handlers((grpc.method_handlers_generic_handler("test.Peer", {
        "Unary": grpc.unary_unary_rpc_method_handler(unary),
        "Server": grpc.unary_stream_rpc_method_handler(server_stream),
        "Client": grpc.stream_unary_rpc_method_handler(client_stream),
        "Bidi": grpc.stream_stream_rpc_method_handler(bidi),
        "Failed": grpc.unary_unary_rpc_method_handler(failed),
        "Stall": grpc.unary_unary_rpc_method_handler(stall),
        "Oversized": grpc.unary_unary_rpc_method_handler(oversized),
        "Limited": grpc.unary_stream_rpc_method_handler(server_stream),
    }),))
    port = server.add_secure_port("127.0.0.1:0", grpc.ssl_server_credentials(((key.read_bytes(), cert.read_bytes()),)))
    server.start()
    try:
        blob = b"\x00\xff\xc3\xa9\xf0\x9f\x8c\x90" + b"Z" * (8192 - 8)
        payload = Payload(text="café 🌐", blob=blob, sequence=2**64-1).SerializeToString(deterministic=True)
        for method, shape, count, sent in (("Unary", 1, 1, 1), ("Server", 2, 8, 1), ("Client", 3, 1, 4), ("Bidi", 4, 4, 4)):
            result = json.loads(subprocess.check_output([sys.argv[1], str(port), "/test.Peer/" + method, str(shape), str(cert)], timeout=10))
            assert "error" not in result, (method, result)
            assert result == dict(status=0, sent=sent, received=count, bytes=count*len(payload), sha256=hashlib.sha256(payload*count).hexdigest(), half_closed=True, initial=1, trailers=1, duplicates=2, binary=2), (method, result)
        for method, shape, error in (("Failed", 1, None), ("Stall", 1, "GrpcOutcomeUnknown"), ("Oversized", 1, "ResourceExhausted"), ("Limited", 2, "GrpcBudgetExceeded")):
            result = json.loads(subprocess.check_output([sys.argv[1], str(port), "/test.Peer/" + method, str(shape), str(cert)], timeout=10))
            if error is None: assert result["status"] == 7 and result["received"] == 0, result
            else: assert result.get("error") == error, (method, result)
        assert applications == ["unary", "server", "client", "bidi", "failed", "stall", "oversized", "server"], applications
        verify(sys.argv[1], cert, key, payload)
        print("gRPC transport: all four shapes, duplex binary messages, duplicate/binary metadata, trailers, non-OK status, deadlines and finite budgets passed; eight calls, no redial/retry.")
    finally:
        server.stop(0).wait(timeout=5); pool.shutdown(wait=True)
