"""Independent finite bidi peer used by installed foreign RPC callers."""
from concurrent.futures import ThreadPoolExecutor
from runner.paths import ROOT
import grpc


def payload(blob):
    from google.protobuf import descriptor_pb2, descriptor_pool, message_factory
    pool = descriptor_pool.DescriptorPool()
    data = (ROOT / 'tests/fixtures/grpc/peer.pb').read_bytes()
    for file in descriptor_pb2.FileDescriptorSet.FromString(data).file: pool.Add(file)
    Message = message_factory.GetMessageClass(pool.FindMessageTypeByName('test.Payload'))
    return Message(text='café 🌐', blob=blob, sequence=2**64-1).SerializeToString(deterministic=True)


class Peer:
    def __init__(self, key, cert, request, response, requests, failures):
        self.descriptor = (ROOT / 'tests/fixtures/grpc/peer.pb').read_bytes()
        self.pool = ThreadPoolExecutor(max_workers=2)
        self.server = grpc.server(self.pool)
        def bidi(messages, context):
            try:
                fields = list(context.invocation_metadata())
                assert ('authorization', 'fixture-secret') in fields
                assert [(k, v) for k, v in fields if k == 'x-tag'] == [('x-tag', 'one'), ('x-tag', 'two')]
                assert ('x-data-bin', b'\x00\xff') in fields
                requests.append('/test.Peer/Bidi')
                context.send_initial_metadata((('x-tag', 'one'), ('set-cookie', 'not-for-capture')))
                context.set_trailing_metadata((('x-data-bin', b'\x00\xff'),))
                # The fixture keeps original bytes opaque to the connector. Its
                # protobuf schema is pinned, but app decoding remains external.
                assert list(messages) == [request, b'']
                yield response
            except BaseException as error:
                failures.append(repr(error))
                context.abort(grpc.StatusCode.INTERNAL, 'fixture failed')
        self.server.add_generic_rpc_handlers((grpc.method_handlers_generic_handler('test.Peer', {
            'Bidi': grpc.stream_stream_rpc_method_handler(bidi),
        }),))
        self.server_port = self.server.add_secure_port('127.0.0.1:0', grpc.ssl_server_credentials(((key.read_bytes(), cert.read_bytes()),)))
        self.server.start()

    def shutdown(self): self.server.stop(0).wait(timeout=5)
    def server_close(self): self.pool.shutdown(wait=True)
