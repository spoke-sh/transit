"""Flight-specific authority/retry/recovery against the real native gateway."""
import hashlib
import json
import struct
import subprocess
import time
import grpc
import pyarrow as pa
import pyarrow.flight as flight
from google.protobuf.any_pb2 import Any
from serving import Key
from storage import wait_ready


def qualify(env):
    import Flight_pb2 as wire
    client, info, table, boundary, fixture = (env[name] for name in ('client', 'info', 'table', 'boundary', 'fixture'))
    options, statement = env['call_options'], env['statement']
    auth = [('authorization', 'Bearer ' + env['token'])]
    channel = grpc.secure_channel(f'127.0.0.1:{env["edge"].port}', grpc.ssl_channel_credentials(env['certificate']))
    prefix = '/arrow.flight.protocol.FlightService/'

    def rpc(method, value, headers=auth, stream=False):
        call = channel.unary_stream(prefix + method) if stream else channel.unary_unary(prefix + method)
        result = call(value.SerializeToString() if not isinstance(value, bytes) else value, metadata=headers, timeout=60)
        return list(result) if stream else result

    def rejected(code, method, value, headers=auth, stream=False):
        try: rpc(method, value, headers, stream)
        except grpc.RpcError as error: assert error.code() == code, (method, error.code(), code)
        else: raise AssertionError((method, 'unexpected successful response'))

    def admin(operation):
        subprocess.run([env['proof'], env['url'], operation, str(fixture.root / 'cli.json')], check=True, capture_output=True, timeout=30)

    try:
        descriptor = wire.FlightDescriptor(type=wire.FlightDescriptor.CMD, cmd=statement.command)
        # One pooled authenticated connection cannot retain prior-call identity.
        assert rpc('GetSchema', descriptor)
        rejected(grpc.StatusCode.UNAUTHENTICATED, 'GetSchema', descriptor, [])
        rejected(grpc.StatusCode.UNAUTHENTICATED, 'GetSchema', descriptor, [('authorization', 'Bearer ' + 'c' * 64)])
        other_auth = [('authorization', 'Bearer ' + 'b' * 64)]
        assert rpc('GetSchema', descriptor, other_auth)
        rejected(grpc.StatusCode.INVALID_ARGUMENT, 'GetSchema', descriptor, auth + [('x-transit-resource', '1')])
        # nginx rejects duplicate Authorization before gRPC dispatch (HTTP 400).
        rejected(grpc.StatusCode.INTERNAL, 'GetSchema', descriptor, auth + auth)
        assert rpc('GetSchema', descriptor)
        rejected(grpc.StatusCode.INVALID_ARGUMENT, 'GetSchema', b'\x00')
        rejected(grpc.StatusCode.INVALID_ARGUMENT, 'GetFlightInfo', descriptor)
        rejected(grpc.StatusCode.INVALID_ARGUMENT, 'GetFlightInfo', descriptor, auth + [('x-transit-request-sequence', '02')])
        rejected(grpc.StatusCode.ABORTED, 'GetFlightInfo', descriptor, auth + [('x-transit-request-sequence', '999')])
        other = env['descriptor'](env['sql'].CommandStatementQuery(query='SELECT count(*) FROM items'))
        rejected(grpc.StatusCode.ABORTED, 'GetFlightInfo', wire.FlightDescriptor(type=2, cmd=other.command), auth + [('x-transit-request-sequence', '2')])
        rejected(grpc.StatusCode.UNIMPLEMENTED, 'DoAction', wire.Action(type='CreatePreparedStatement'), stream=True)
        rejected(grpc.StatusCode.UNIMPLEMENTED, 'ListFlights', wire.Criteria(), stream=True)
        bad_sql = env['descriptor'](env['sql'].CommandStatementQuery(query='DELETE FROM items'))
        rejected(grpc.StatusCode.UNIMPLEMENTED, 'GetSchema', wire.FlightDescriptor(type=2, cmd=bad_sql.command))

        wrapped = Any.FromString(info.endpoints[0].ticket.ticket)
        handle = env['sql'].TicketStatementQuery.FromString(wrapped.value).statement_handle
        rejected(grpc.StatusCode.PERMISSION_DENIED, 'DoGet', wire.Ticket(ticket=handle), other_auth, stream=True)
        damaged = bytearray(handle); damaged[100] ^= 1
        rejected(grpc.StatusCode.PERMISSION_DENIED, 'DoGet', wire.Ticket(ticket=bytes(damaged)), stream=True)
        # A correctly signed foreign scope still grants no authority.
        signer = Key(fixture.root, 'ticket-fixture', 42)
        foreign = bytearray(handle[:-64]); struct.pack_into('<Q', foreign, 12, 999)
        foreign += bytes(signer.sign(hashlib.sha256(b'transit.flight.ticket.v1\0' + foreign).digest()))
        rejected(grpc.StatusCode.PERMISSION_DENIED, 'DoGet', wire.Ticket(ticket=bytes(foreign)), stream=True)
        expired = bytearray(handle[:-64]); struct.pack_into('<Q', expired, 76, 1)
        expired += bytes(signer.sign(hashlib.sha256(b'transit.flight.ticket.v1\0' + expired).digest()))
        rejected(grpc.StatusCode.FAILED_PRECONDITION, 'DoGet', wire.Ticket(ticket=bytes(expired)), stream=True)
        assert client.do_get(info.endpoints[0].ticket, options()).read_all().equals(table)

        reader = client.do_get(info.endpoints[0].ticket, options())
        first = reader.read_chunk().data
        assert 0 < first.num_rows < table.num_rows
        boundary.pause = True
        assert boundary.reached.wait(timeout=5), 'no bounded native read followed the returned prefix'
        admin('revoke-read')  # Keep metadata inspection; remove only entry reads.
        boundary.pause = False; boundary.release.set()
        try: reader.read_all()
        except flight.FlightUnauthorizedError: pass
        else: raise AssertionError('revoked prefix was reported complete')
        rejected(grpc.StatusCode.PERMISSION_DENIED, 'GetSchema', descriptor)
        rejected(grpc.StatusCode.PERMISSION_DENIED, 'DoGet', wire.Ticket(ticket=handle), stream=True)
        admin('restore')
        assert client.do_get(info.endpoints[0].ticket, options()).read_all().equals(table)
        cancelled = client.do_get(info.endpoints[0].ticket, options())
        assert cancelled.read_chunk().data.num_rows > 0
        cancelled.cancel()
        assert client.do_get(info.endpoints[0].ticket, options()).read_all().equals(table)
        admin('released-pins')
        from flight_load import qualify as load
        load_info = client.get_flight_info(statement, options(2))
        load_handle = env['sql'].TicketStatementQuery.FromString(Any.FromString(load_info.endpoints[0].ticket.ticket).value).statement_handle
        load(env | dict(info=load_info), channel, auth, descriptor, load_handle)
        other_options = flight.FlightCallOptions(timeout=180, headers=[(b'authorization', ('Bearer ' + 'b' * 64).encode()), (b'x-transit-request-sequence', b'2')])
        other_info = client.get_flight_info(statement, other_options)
        other_reader = client.do_get(other_info.endpoints[0].ticket, other_options)
        assert 0 < other_reader.read_chunk().data.num_rows < table.num_rows
        boundary.reached.clear(); boundary.release.clear(); boundary.pause = True
        assert boundary.reached.wait(timeout=5)
        subprocess.run([env['proof'], env['url'], 'retire-requester', str(fixture.root / 'second/cli.json')], check=True, capture_output=True, timeout=30)
        boundary.pause = False; boundary.release.set()
        try: other_reader.read_all()
        except pa.ArrowInvalid: pass
        else: raise AssertionError('retired request prefix was reported complete')
        rejected(grpc.StatusCode.FAILED_PRECONDITION, 'DoGet', wire.Ticket(ticket=other_info.endpoints[0].ticket.ticket), other_auth, stream=True)
        print('Flight: pooled authentication, malformed/unsupported requests, sequence conflicts, foreign/tampered tickets, read-only revocation after a real batch and interrupted duplicate fetch passed.', flush=True)

        # Accepted evidence survives complete physical loss; no query reexecution.
        fresh = client.get_flight_info(statement, options(2))
        client.close(); channel.close()
        for name in ('source', 'requester', 'courier', 'node', 'gateway-replacement'):
            child = env['hosts'][name]
            child.kill(); child.wait(timeout=5)
        fixture.stop(); fixture.start()
        authority = env['start']('node-restarted', [env['node'], str(env['config'])])
        wait_ready(fixture.http, authority, env['url'] + '/health')
        for name, action in (('source', 'fence'), ('requester', 'fence-requester')):
            admin(action)
            path = fixture.root / (name + '.json')
            value = json.loads(path.read_text()); value['generation'] += 1
            path.write_text(json.dumps(value))
        for name in ('source', 'requester', 'courier'):
            env['start'](name + '-restarted', [env['host'], str(fixture.root / (name + '.json'))])
        env['start']('gateway-restarted', [env['gateway'], str(env['gateway_config'])])
        client = flight.connect(env['uri'], tls_root_certs=env['certificate'])
        assert client.do_get(fresh.endpoints[0].ticket, options()).read_all().equals(table)
        same = client.get_flight_info(statement, options(2))
        assert client.do_get(same.endpoints[0].ticket, options()).read_all().equals(table)
        channel = grpc.secure_channel(f'127.0.0.1:{env["edge"].port}', grpc.ssl_channel_credentials(env['certificate']))
        admin('retire-source')
        rejected(grpc.StatusCode.FAILED_PRECONDITION, 'DoGet', wire.Ticket(ticket=same.endpoints[0].ticket.ticket), stream=True)
        env['observation'].check(env['caller']['connection']['resource'], 'capture', unavailable=True)
        print('Flight: same retained result after gateway/worker/node/store restart, exact retry and permanent source retirement passed.', flush=True)
    finally:
        boundary.pause = False; boundary.release.set()
        client.close(); channel.close()
