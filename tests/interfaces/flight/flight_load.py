"""Actual Flight concurrency, delayed native reads and slow HTTP/2 credit."""
import socket
import struct
import time
from pathlib import Path
import grpc
import h2.config
import h2.connection
import h2.events
import h2.settings


def qualify(env, channel, auth, descriptor, handle):
    import Flight_pb2 as wire
    prefix = '/arrow.flight.protocol.FlightService/'
    boundary = env['boundary']
    boundary.release.clear(); boundary.saturated.clear(); boundary.hold_count = 2
    channels = [grpc.secure_channel(f'127.0.0.1:{env["edge"].port}', grpc.ssl_channel_credentials(env['certificate']), options=(('grpc.use_local_subchannel_pool', 1),)) for _ in range(2)]
    streams = [peer.unary_stream(prefix+'DoGet')(wire.Ticket(ticket=handle).SerializeToString(), metadata=auth, timeout=60) for peer in channels]
    try:
        assert boundary.saturated.wait(timeout=5), 'two fetches did not reach the native reader'
        started = time.monotonic()
        # Per-caller data capacity is full; the authenticated control reserve
        # still reads current schema and does not inherit a frozen native task.
        assert channel.unary_unary(prefix+'GetSchema')(descriptor.SerializeToString(), metadata=auth, timeout=5)
        try:
            list(channel.unary_stream(prefix+'DoGet')(wire.Ticket(ticket=handle).SerializeToString(), metadata=auth, timeout=5))
        except grpc.RpcError as error: assert error.code() == grpc.StatusCode.RESOURCE_EXHAUSTED
        else: raise AssertionError('per-caller data limit was not enforced')
        status = Path('/proc') / str(env['hosts']['gateway-replacement'].pid) / 'status'
        rss = int(next(line.split()[1] for line in status.read_text().splitlines() if line.startswith('VmRSS:'))) * 1024
        assert rss < 192 * 1024 * 1024, rss
        # Deliberately exceed the usual 5-second native page budget; this
        # deployment explicitly selects 15 seconds, without changing tickets.
        remaining = 6 - (time.monotonic()-started)
        if remaining > 0: time.sleep(remaining)
        boundary.release.set()
        for stream in streams:
            messages = [wire.FlightData.FromString(value) for value in stream]
            assert len(messages) == 7 and messages[0].data_header and not messages[0].data_body
        print(f'Flight: two concurrent delayed fetches, data admission rejection, current-schema control progress and joined completion; observed gateway RSS {rss} bytes.', flush=True)
    finally:
        boundary.release.set()
        for stream in streams: stream.cancel()
        for peer in channels: peer.close()

    # The private HTTP/2 adapter must release a blocked writer even when no
    # extra TLS-edge buffering is involved. Authentication is still required.
    raw = socket.create_connection(('127.0.0.1', env['flight_port']), timeout=10)
    raw.settimeout(10)
    h = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True))
    h.initiate_connection(); h.update_settings({h2.settings.SettingCodes.INITIAL_WINDOW_SIZE: 1})
    raw.sendall(h.data_to_send())
    h.receive_data(raw.recv(32768))
    h.send_headers(1, [(':method','POST'),(':scheme','http'),(':authority','localhost'),(':path',prefix+'DoGet'),('content-type','application/grpc'),('te','trailers'), *auth])
    value = wire.Ticket(ticket=handle).SerializeToString()
    h.send_data(1, b'\0'+struct.pack('>I',len(value))+value, end_stream=True)
    raw.sendall(h.data_to_send())
    saw_prefix = False
    try:
        deadline = time.monotonic()+12
        while time.monotonic() < deadline:
            data = raw.recv(32768)
            if not data: break
            events = h.receive_data(data)
            if any(isinstance(event,h2.events.DataReceived) for event in events):
                saw_prefix = True
                assert channel.unary_unary(prefix+'GetSchema')(descriptor.SerializeToString(), metadata=auth, timeout=5)
            # SETTINGS acknowledgement does not grant additional data credit.
            outgoing = h.data_to_send()
            if outgoing: raw.sendall(outgoing)
        else: raise AssertionError('slow Flight writer was not closed within budget')
        assert saw_prefix, 'slow peer never received an actual Flight prefix'
    finally: raw.close()
    assert env['client'].do_get(env['info'].endpoints[0].ticket, env['call_options']()).read_all().equals(env['table'])
    print('Flight: one-byte HTTP/2 credit stall closed within the write budget; current control and subsequent same-result fetch passed.', flush=True)
    for frame, expected in ((b'\1\0\0\0\0', b'12'), (b'\0\xff\xff\xff\xff', b'8'), (b'\0\0\0\0\4x', b'3')):
        with socket.create_connection(('127.0.0.1', env['flight_port']), timeout=5) as peer:
            peer.settimeout(5)
            h = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True))
            h.initiate_connection(); peer.sendall(h.data_to_send()); h.receive_data(peer.recv(32768))
            h.send_headers(1, [(':method','POST'),(':scheme','http'),(':authority','localhost'),(':path',prefix+'DoGet'),('content-type','application/grpc'),('te','trailers'), *auth])
            h.send_data(1, frame, end_stream=True); peer.sendall(h.data_to_send())
            status = None
            while status is None:
                data = peer.recv(32768)
                assert data, 'malformed Flight frame closed without status'
                for event in h.receive_data(data):
                    if isinstance(event, (h2.events.TrailersReceived,h2.events.ResponseReceived)):
                        status = dict(event.headers).get(b'grpc-status',status)
                outgoing = h.data_to_send()
                if outgoing: peer.sendall(outgoing)
            assert status == expected, (status, expected)
    print('Flight: compressed, oversized and truncated request frames rejected before dispatch.', flush=True)
