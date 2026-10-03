"""Independent HTTP/2 peer for directional credit and malformed gRPC envelopes."""
import hashlib
import json
import socket
import ssl
import struct
import subprocess
import threading

import h2.config
import h2.connection
import h2.events
import h2.settings


def verify(binary, cert, key, payload):
    for mode in ("Flow", "Missing", "Truncated", "Compressed", "EarlyStatus", "DuplicateStatus", "DroppedTls"):
        failures, requests = [], []
        fragments = [0]
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0)); listener.listen(1); listener.settimeout(15)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert, key); context.set_alpn_protocols(["h2"])
            def peer():
                try:
                    raw, _ = listener.accept()
                    with raw:
                        raw.settimeout(10); raw.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                        with context.wrap_socket(raw, server_side=True) as sock:
                            assert sock.selected_alpn_protocol() == "h2"
                            connection = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=False, header_encoding=None))
                            connection.initiate_connection()
                            connection.update_settings({h2.settings.SettingCodes.INITIAL_WINDOW_SIZE: 64})
                            sock.sendall(connection.data_to_send())
                            stream, body, response, offset, pending, ended = None, bytearray(), b"", 0, [], False
                            while True:
                                incoming = sock.recv(65536)
                                if not incoming: return
                                events = connection.receive_data(incoming)
                                for event in events:
                                    if isinstance(event, h2.events.RequestReceived):
                                        stream = event.stream_id
                                        if mode == "DroppedTls": return
                                        fields = [(b":status", b"200"), (b"content-type", b"application/grpc+proto")]
                                        if mode == "EarlyStatus": fields.append((b"grpc-status", b"0"))
                                        connection.send_headers(stream, fields)
                                        response = (b"\0" + struct.pack(">I", len(payload)) + payload) * 3 if mode == "Flow" else b""
                                        if mode == "Truncated": response = b"\0\0\0\0\x04abc"
                                        if mode == "Compressed": response = b"\1\0\0\0\x01x"
                                    elif isinstance(event, h2.events.DataReceived):
                                        body.extend(event.data); fragments[0] += 1
                                        if mode == "Flow" and offset < len(response): pending.append((event.flow_controlled_length, event.stream_id))
                                        else: connection.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                                    elif isinstance(event, h2.events.StreamEnded):
                                        ended = True
                                    elif isinstance(event, (h2.events.ConnectionTerminated, h2.events.StreamReset)):
                                        return
                                if stream is not None:
                                    while offset < len(response):
                                        credit = min(connection.local_flow_control_window(stream), connection.max_outbound_frame_size, len(response)-offset)
                                        if credit <= 0: break
                                        connection.send_data(stream, response[offset:offset+credit]); offset += credit
                                    if offset == len(response):
                                        for count, sid in pending: connection.acknowledge_received_data(count, sid)
                                        pending.clear()
                                    if mode != "Flow" or ended:
                                        if mode == "Missing": connection.send_data(stream, b"", end_stream=True)
                                        else:
                                            trailers = [(b"grpc-status", b"0")]
                                            if mode == "DuplicateStatus": trailers.append((b"grpc-status", b"7"))
                                            connection.send_headers(stream, trailers, end_stream=True)
                                        sock.sendall(connection.data_to_send())
                                        if mode == "Flow": requests.append(bytes(body))
                                        return
                                pending_wire = connection.data_to_send()
                                if pending_wire: sock.sendall(pending_wire)
                except (ssl.SSLError, ConnectionResetError, BrokenPipeError):
                    if mode == "Flow": failures.append("flow peer lost its connection")
                except Exception as error:
                    failures.append(repr(error))
            thread = threading.Thread(target=peer); thread.start()
            result = json.loads(subprocess.check_output([binary, str(listener.getsockname()[1]), "/test.Peer/" + mode, "4", str(cert)], timeout=15))
            thread.join(timeout=15)
            assert not thread.is_alive() and not failures, (mode, failures, result)
            if mode == "Flow":
                frame = b"\0" + struct.pack(">I", len(payload)) + payload
                assert requests == [frame*4] and fragments[0] > 100, (len(requests), fragments)
                assert result["capture_complete"] and result["status"] == 0 and result["sent"] == 4 and result["received"] == 3 and result["half_closed"], result
                assert result["sha256"] == hashlib.sha256(payload*3).hexdigest(), result
            else:
                expected = {"Missing": "MissingStatus", "Truncated": "Internal", "Compressed": "Internal", "EarlyStatus": "MalformedResponse", "DuplicateStatus": "MalformedResponse", "DroppedTls": "TlsConnectionTruncated"}[mode]
                assert result.get("error") == expected, (mode, result)
    print("gRPC HTTP/2 peer: 64-byte send credit and 16-KiB receive credit progress together; missing, truncated, compressed and forged terminal envelopes reject.")
