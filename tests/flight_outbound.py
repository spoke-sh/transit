"""Independent PyArrow service through the actual recorded M16 RPC worker."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import pyarrow as pa
import pyarrow.flight as flight
from storage import Fixture, free_port, wait_ready


def run(node, provision, worker, adapter):
    node, provision, worker, adapter = [str(Path(p).resolve()) for p in (node, provision, worker, adapter)]
    with Fixture() as fixture:
        key, cert = fixture.root / 'peer.key', fixture.root / 'peer.pem'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(key), '-out', str(cert), '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost'], check=True, capture_output=True)
        calls = []
        class Authentication(flight.ServerMiddlewareFactory):
            def start_call(self, info, headers):
                if headers.get('authorization') != ['Bearer fixture-flight-secret']:
                    raise flight.FlightUnauthenticatedError('credential required')
        class Peer(flight.FlightServerBase):
            def do_get(self, context, ticket):
                assert ticket.ticket == b'finite-int64'
                calls.append(ticket.ticket)
                schema = pa.schema([pa.field('id', pa.int64(), False), pa.field('value', pa.int64())])
                table = pa.Table.from_pylist([dict(id=i, value=None if i % 5 == 0 else 9007199254740993+i) for i in range(41)], schema=schema)
                return flight.GeneratorStream(schema, iter(table.to_batches(max_chunksize=8)))
        peer = Peer('grpc+tls://127.0.0.1:0', tls_certificates=[(cert.read_bytes(), key.read_bytes())], middleware={'auth': Authentication()})
        port = free_port(); url = f'http://127.0.0.1:{port}'
        public = json.loads(subprocess.check_output([provision, 'public'], timeout=10))
        config = fixture.root / 'node.json'
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=47, root_key=public, max_clock_error_ms=10000), ursula_url=fixture.url, bucket='flight-outbound', journal='authority', port=port, resident_pages=8)))
        state, seed, secret = fixture.root / 'saved.json', fixture.root / 'worker.seed', fixture.root / 'secret'
        seed.write_text('48'*32); secret.write_text('Bearer fixture-flight-secret')
        proto = Path(__file__).resolve().parents[1] / 'packages/zig/transit-flight/proto'
        descriptor = fixture.root / 'flight.pb'
        subprocess.run(['protoc', '-I', str(proto), '--include_imports', '--descriptor_set_out=' + str(descriptor), str(proto / 'Flight.proto')], check=True)
        subprocess.run([adapter, 'prepare', str(descriptor), str(fixture.root)], check=True)
        log = (fixture.root / 'node.log').open('w+')
        authority = None
        def start():
            child = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
            wait_ready(fixture.http, child, url + '/health'); return child
        def admin(mode):
            return json.loads(subprocess.check_output([provision, url, mode, str(state)], timeout=60))
        def invoke(mode, saved):
            value = dict(url=url, realm=47, principal=65536, seed_file=str(seed), pid=saved['pid'], generation=saved['generation'], activation_directory=str(fixture.root), exchange=1, endpoint_revision=1,
                endpoint=dict(host='localhost', address='127.0.0.1', port=peer.port, tls=True, ca_file=str(cert), timeout_ms=60000), mode=mode,
                request_file=str(fixture.root/'request.json'), batch_file=str(fixture.root/'batch.bin'), reconcile_before_ms=deadline,
                credentials=[dict(binding='peer', version=1, metadata='authorization', file=str(secret))], response_metadata=[])
            path = fixture.root / 'worker.json'; path.write_text(json.dumps(value))
            result = subprocess.run([worker, str(path)], capture_output=True, timeout=180, env=fixture.env | {'LOG_LEVEL':'warn'})
            assert result.returncode == 0, result.stderr[-4000:]
            assert b'fixture-flight-secret' not in result.stdout + result.stderr
            return json.loads(result.stdout)
        try:
            deadline = int(time.time()*1000) + 600000
            subprocess.run([node, str(config), '--initialize'], check=True, stdout=log, stderr=subprocess.STDOUT, timeout=30)
            authority = start()
            assert invoke('prepare', admin('provision'))['phase'] == 'ready'
            assert calls == []
            assert invoke('execute', admin('own'))['outcome'] == 'observed'
            assert len(calls) == 1
            peer.shutdown(); secret.unlink()
            authority.kill(); authority.wait(timeout=5)
            fixture.stop(); fixture.start(); authority = start()
            replay = json.loads(subprocess.check_output([adapter, 'replay', url, str(state)], timeout=180))
            assert replay == dict(complete=True, rows=41, batches=6), replay
            assert len(calls) == 1
            print('Outbound Flight: authorized recorded TLS DoGet, six exact int64/null batches, complete outcome and network-free typed replay after node/store restart passed.', flush=True)
        finally:
            peer.shutdown()
            if authority and authority.poll() is None: authority.kill(); authority.wait(timeout=5)
            log.close()


if __name__ == '__main__': run(*sys.argv[1:])
