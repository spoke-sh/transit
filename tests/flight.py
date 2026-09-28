"""Independent Flight/ADBC consumers over the real native finite requester."""
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

import pyarrow as pa
import pyarrow.flight as flight
from google.protobuf.any_pb2 import Any
from serving_tls import TLSProxy
from flight_faults import NativeBoundary
from storage import Fixture, free_port, wait_ready


def run(node, host, gateway, proof, mode=None, board=None):
    faults = mode == 'faults'
    node, host, gateway, proof = [str(Path(p).resolve()) for p in (node, host, gateway, proof)]
    with Fixture() as fixture, ExitStack() as owned:
        proto = Path(__file__).resolve().parents[1] / 'packages/zig/transit-flight/proto'
        subprocess.run(['protoc', '-I', str(proto), '--python_out=' + str(fixture.root), str(proto / 'FlightSql.proto'), str(proto / 'Flight.proto')], check=True)
        sys.path.insert(0, str(fixture.root))
        import FlightSql_pb2 as sql
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        port, flight_port = free_port(), free_port()
        url = f'http://127.0.0.1:{port}'
        config = fixture.root / 'node.json'
        config.write_text(json.dumps(dict(profile='growing_v3', genesis=dict(realm=45, root_key=public, max_clock_error_ms=10000), ursula_url=fixture.url, bucket='flight', journal='authority', port=port, resident_pages=8, request_timeout_ms=10000)))
        processes, logs, hosts = [], [], {}
        def start(name, command):
            log = (fixture.root / f'{name}.log').open('w+')
            logs.append(log)
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
            processes.append(child)
            hosts[name] = child
            return child
        try:
            subprocess.run([node, str(config), '--initialize'], check=True, capture_output=True, timeout=30)
            authority = start('node', [node, str(config)])
            wait_ready(fixture.http, authority, url + '/health')
            subprocess.run([proof, url, 'provision-flight', str(fixture.root)], check=True, capture_output=True, timeout=60)
            for name in ('source', 'requester', 'courier'):
                start(name, [host, str(fixture.root / f'{name}.json')])
            caller = json.loads((fixture.root / 'cli.json').read_text())
            token = 'a' * 64
            (fixture.root / 'credential').write_text(token)
            (fixture.root / 'ticket.seed').write_text('2a' * 32)
            boundary = owned.enter_context(NativeBoundary(url)) if faults else None
            options = dict(url=boundary.url if boundary else url, inspector=55, inspector_seed_file=str(fixture.root / 'inspector.seed'), ticket_seed_file=str(fixture.root / 'ticket.seed'), port=flight_port, ticket_ttl_ms=120000,
                callers=[dict(credential_file=str(fixture.root / 'credential'), seed_file=str(fixture.root / 'caller.seed'), connection=caller['connection'], service=1, binding_revision=1, columns=['id','value'])])
            if faults:
                options['native_timeout_ms'] = 15000
                second = fixture.root / 'second'; second.mkdir(mode=0o700)
                subprocess.run([proof, url, 'provision-flight-second', str(second)], check=True, capture_output=True, timeout=60)
                (second / 'credential').write_text('b' * 64)
                other = json.loads((second / 'cli.json').read_text())
                options['callers'].append(dict(credential_file=str(second / 'credential'), seed_file=str(second / 'caller.seed'), connection=other['connection'], service=1, binding_revision=1, columns=['id', 'value']))
                for name in ('source', 'requester', 'courier'):
                    start('second-' + name, [host, str(second / f'{name}.json')])
            gateway_config = fixture.root / 'gateway.json'
            gateway_config.write_text(json.dumps(options))
            process = start('gateway', [gateway, str(gateway_config)])
            edge = owned.enter_context(TLSProxy(fixture.root / 'tls', flight_port, grpc=True, read_timeout=185))
            uri = f'grpc+tls://127.0.0.1:{edge.port}'
            certificate = (edge.root / 'certificate.pem').read_bytes()
            client = flight.connect(uri, tls_root_certs=certificate)
            auth = (b'authorization', ('Bearer ' + token).encode())
            def call_options(sequence=None):
                headers = [auth]
                if sequence is not None: headers.append((b'x-transit-request-sequence', str(sequence).encode()))
                return flight.FlightCallOptions(timeout=180, headers=headers)
            def descriptor(command):
                packed = Any(); packed.Pack(command)
                return flight.FlightDescriptor.for_command(packed.SerializeToString())
            deadline = time.monotonic() + 20
            while True:
                try:
                    assert list(client.list_actions(call_options())) == []
                    break
                except flight.FlightUnavailableError:
                    assert process.poll() is None and time.monotonic() < deadline
                    time.sleep(.1)
            catalogs = client.get_flight_info(descriptor(sql.CommandGetCatalogs()), call_options())
            assert client.do_get(catalogs.endpoints[0].ticket, call_options()).read_all().to_pylist() == [{'catalog_name':'transit'}]
            statement = descriptor(sql.CommandStatementQuery(query='SELECT id, value FROM items'))
            schema = client.get_schema(statement, call_options()).schema
            assert schema == pa.schema([pa.field('id',pa.int64(),False),pa.field('value',pa.int64())])
            started = time.monotonic()
            if boundary:
                boundary.drop = True
                try:
                    client.get_flight_info(statement, call_options(2))
                except flight.FlightUnavailableError: pass
                else: raise AssertionError('lost native acceptance reported success')
                assert boundary.original and boundary.receipt
                process.kill(); process.wait(timeout=5)
                process = start('gateway-replacement', [gateway, str(gateway_config)])
                client.close()
                client = flight.connect(uri, tls_root_certs=certificate)
            info = client.get_flight_info(statement, call_options(2))
            assert info.total_records == 41 and len(info.endpoints) == 1
            table = client.do_get(info.endpoints[0].ticket, call_options()).read_all()
            expected = [dict(id=i, value=None if i % 5 == 0 else 9007199254740993+i) for i in range(41)]
            assert table.to_pylist() == expected
            assert client.do_get(info.endpoints[0].ticket, call_options()).read_all().equals(table)
            retry = client.get_flight_info(statement, call_options(2))
            assert client.do_get(retry.endpoints[0].ticket, call_options()).read_all().equals(table)
            print(f'Flight actual finite statement, full-width/null rows, schema, metadata and exact retry passed in {time.monotonic()-started:.2f}s', flush=True)
            if faults:
                assert boundary.retries >= 2
                from flight_board import Observer
                observation = Observer(locals(), board)
                observation.check(caller['connection']['resource'], 'capture')
                observation.check(caller['connection']['requests'], 'manifest')
                from flight_lifecycle import qualify
                qualify(locals())
                return
            client.close()
            from flight_adbc import verify
            verify(uri, edge.root / 'certificate.pem', fixture.root, token, schema, expected)

        except BaseException:
            for log in logs:
                log.flush(); log.seek(0)
                print(log.read()[-16000:], file=sys.stderr)
            raise
        finally:
            for child in reversed(processes):
                if child.poll() is None: child.terminate()
            for child in processes:
                try: child.wait(timeout=5)
                except subprocess.TimeoutExpired: child.kill(); child.wait(timeout=5)
            for log in logs: log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])
