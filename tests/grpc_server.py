"""Independent grpcio/h2 clients against the actual bounded Zig server."""
import socket
import struct
import subprocess
import sys
import time

import grpc
import h2.config
import h2.connection
import h2.events


def port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


listen = port()
process = subprocess.Popen([sys.argv[1], str(listen)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
address = f'127.0.0.1:{listen}'


def channel():
    result = grpc.insecure_channel(address, options=(('grpc.enable_retries', 0), ('grpc.use_local_subchannel_pool', 1)))
    grpc.channel_ready_future(result).result(timeout=5)
    return result


def active(peer):
    return struct.unpack('<I', peer.unary_unary('/test.Peer/Health')(b'', timeout=2))[0]


def eventually(predicate):
    until = time.monotonic() + 4
    while not predicate():
        assert time.monotonic() < until, 'bounded server did not release work'
        time.sleep(.02)


class Raw:
    def __init__(self, credit=65535):
        self.socket = socket.create_connection(('127.0.0.1', listen), timeout=2)
        self.socket.settimeout(2)
        self.h2 = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True))
        self.h2.initiate_connection()
        self.h2.update_settings({h2.settings.SettingCodes.INITIAL_WINDOW_SIZE: credit})
        self.socket.sendall(self.h2.data_to_send())
        # Server settings constrain new streams before a request is emitted.
        self.receive()

    def receive(self):
        data = self.socket.recv(32768)
        if not data:
            return None
        events = self.h2.receive_data(data)
        outgoing = self.h2.data_to_send()
        if outgoing:
            self.socket.sendall(outgoing)
        return events

    def request(self, method, body=b'\0\0\0\0\0', headers=()):
        self.h2.send_headers(1, [(':method', 'POST'), (':scheme', 'http'), (':authority', address), (':path', method), ('content-type', 'application/grpc'), ('te', 'trailers'), *headers])
        self.h2.send_data(1, body, end_stream=True)
        self.socket.sendall(self.h2.data_to_send())

    def close(self):
        self.socket.close()


started = time.monotonic()
try:
    with channel() as peer:
        echo = peer.unary_unary('/test.Peer/Echo')
        # Reused pooled connection, empty/binary/Unicode and full-width wire data.
        payload = b'\0\xff' + 'café 🌐'.encode() + struct.pack('<Q', 2**64 - 1)
        for value in (b'', payload, b'x' * 16384, payload):
            assert echo(value, timeout=3) == value
        chunks = list(peer.unary_stream('/test.Peer/Stream')(b'', timeout=3))
        assert len(chunks) == 24 and all(chunk == b'*' * 8192 for chunk in chunks)
        for method, headers, status in (
            ('/test.Peer/Unknown', (), grpc.StatusCode.UNIMPLEMENTED),
            ('/test.Peer/Echo', (('authorization', 'a'), ('authorization', 'b')), grpc.StatusCode.INVALID_ARGUMENT),
        ):
            try:
                peer.unary_unary(method)(b'', metadata=headers, timeout=2)
                raise AssertionError('invalid request succeeded')
            except grpc.RpcError as error:
                assert error.code() == status, error

    # Two distinct client connections saturate the data budget; a third still
    # performs control calls. Reset each in-flight request and observe cleanup.
    with channel() as first, channel() as second, channel() as control:
        waits = [first.unary_unary('/test.Peer/Wait').future(b'', timeout=4), second.unary_unary('/test.Peer/Wait').future(b'', timeout=4)]
        eventually(lambda: active(control) == 2)
        try:
            control.unary_unary('/test.Peer/Echo')(b'blocked', timeout=2)
            raise AssertionError('capacity did not reject')
        except grpc.RpcError as error:
            assert error.code() == grpc.StatusCode.RESOURCE_EXHAUSTED, error
        for waiting in waits:
            waiting.cancel()
        eventually(lambda: active(control) == 0)
        # Client deadline cancels the task even while the handler is waiting.
        with channel() as deadline_peer:
            try:
                deadline_peer.unary_unary('/test.Peer/Wait')(b'', timeout=.1)
                raise AssertionError('deadline did not terminate')
            except grpc.RpcError as error:
                assert error.code() == grpc.StatusCode.DEADLINE_EXCEEDED
        eventually(lambda: active(control) == 0)

    # A peer that withholds HTTP/2 credit cannot monopolize application work.
    with channel() as control:
        slow = Raw(credit=1)
        try:
            slow.request('/test.Peer/Stream')
            eventually(lambda: active(control) == 1)
            assert active(control) == 1
            eventually(lambda: active(control) == 0)
        finally:
            slow.close()
        for frame, expected in ((b'\1\0\0\0\0', b'12'), (b'\0\xff\xff\xff\xff', b'8'), (b'\0\0\0\0\4x', b'3'), (b'\0\0\0\0\0\0\0\0\0\0', b'3')):
            malformed = Raw()
            try:
                malformed.request('/test.Peer/Echo', frame)
                # A recognizable gRPC request receives a specific framing error.
                status = None
                until = time.monotonic() + 3
                while time.monotonic() < until:
                    events = malformed.receive()
                    if events is None:
                        break
                    for event in events:
                        if isinstance(event, (h2.events.TrailersReceived, h2.events.ResponseReceived)):
                            status = dict(event.headers).get(b'grpc-status', status)
                    if status is not None:
                        break
                assert status == expected, (status, expected)
            finally:
                malformed.close()
        assert active(control) == 0
    assert process.poll() is None
    print(f'Inbound gRPC: reused connections, unary/streaming, 16 KiB payload, 192 KiB flow control, separate control admission, cancellation/deadline joins, malformed/compressed/oversize rejection; {time.monotonic() - started:.2f}s', flush=True)
finally:
    process.terminate()
    try:
        out, errors = process.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        out, errors = process.communicate(timeout=5)
    if errors:
        print(errors.decode(), file=sys.stderr)
