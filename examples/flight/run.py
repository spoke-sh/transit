"""Pinned Flight/ADBC consumers against owned Compose or reference services."""
import argparse
from contextlib import ExitStack
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import traceback
import urllib.request
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from cold_storage import ColdStore
from flight_adbc import verify
from serving_tls import TLSProxy
from storage import wait_ready
from placement import Compose, Reference


def run(profile, node, host, gateway, proof):
    node, host, gateway, proof = [str(Path(p).resolve()) for p in (node, host, gateway, proof)]
    started = time.monotonic()
    env = {k: v for k, v in os.environ.items() if not k.startswith(('URSULA_', 'OTEL_'))} | {'LOG_LEVEL': 'warn'}
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with tempfile.TemporaryDirectory(prefix='transit-flight-') as directory, ExitStack() as owned:
        work = Path(directory)
        for name in ('operator', 'ingress', 'application', 'courier', 'gateway-0'):
            (work / name).mkdir(mode=0o700)
            (work / (name + '-data')).mkdir(mode=0o700)
        (work / 'wal').mkdir()
        placement, cold, network = None, None, None
        local, logs, workers = [], [], {}

        def write(path, value):
            path.write_text(json.dumps(value)); path.chmod(0o600)

        def admin(operation):
            return subprocess.check_output([proof, url, operation, str(work / 'cli.json')], timeout=60)

        def activate(name, recovery=False):
            config = json.loads((work / (name + '.json')).read_text())
            role = 'application' if name == 'source' else 'ingress'
            config.update(url=placement.authority, activation_directory='/runtime-data', request_timeout_ms=10000)
            if profile == 'reference':
                config.pop('seed_file')
                config['generation'] += 1
                handle, registration = placement.register_host(config)
                assert all(registration[k] == config[k] for k in ('realm', 'principal', 'pid', 'generation'))
                public = bytes(registration['public_key']).hex()
                result = json.loads(admin('activate-' + name + ':' + public))
                assert result['generation'] == config['generation']
            else:
                if recovery:
                    admin('fence' if name == 'source' else 'fence-requester')
                    config['generation'] += 1
                shutil.copyfile(work / (name + '.seed'), work / role / 'seed.key')
                config['seed_file'] = '/' + role + '/seed.key'
                write(work / role / 'config.json', config)
                handle = placement.start(role)
            # Only the generation is local placement state. Authority is always
            # the signed grant/own above, never these configuration files.
            original = json.loads((work / (name + '.json')).read_text())
            original['generation'] = config['generation']
            write(work / (name + '.json'), original)
            workers[name] = handle

        def courier():
            config = json.loads((work / 'courier.json').read_text())
            if profile == 'compose':
                config.update(url=placement.authority, seed_file='/courier/seed.key')
                shutil.copyfile(work / 'courier.seed', work / 'courier/seed.key')
                write(work / 'courier/config.json', config)
                return placement.start('courier')
            config['url'] = url
            write(work / 'courier/config.json', config)
            log = (work / 'courier.log').open('w+'); logs.append(log)
            process = subprocess.Popen([host, str(work / 'courier/config.json')], env=env, stdout=log, stderr=subprocess.STDOUT)
            local.append(process)
            return process

        def start_gateway():
            return placement.start_gateway() if profile == 'reference' else placement.start('gateway-0')

        try:
            placement = (Compose if profile == 'compose' else Reference)(work)
            cold = owned.enter_context(ColdStore())
            if profile == 'reference':
                subprocess.run(['docker', 'network', 'connect', 'kind', cold.name], check=True, capture_output=True)
                network = 'kind'
                record = json.loads(subprocess.check_output(['docker', 'inspect', cold.name]))[0]
                placement.cold_address = record['NetworkSettings']['Networks']['kind']['IPAddress']
                endpoint = 'http://' + placement.cold_address + ':9000'
            else: endpoint = 'http://flight-cold:9000'
            wal = '/data/wal' if profile == 'reference' else '/wal'
            (work / 'ursula.toml').write_text('[server]\nlisten = "0.0.0.0:8080"\nadmin_listen = "127.0.0.1:0"\n[runtime]\ncore_count = 2\n[raft]\nnode_id = 1\ngroup_count = 1\n[raft.wal]\nbackend = "disk"\npath = "' + wal + '"\n' + cold.config().replace(cold.url, endpoint))
            (work / 'ursula.toml').chmod(0o600)
            public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
            write(work / 'operator/node.json', dict(profile='native_v1', genesis=dict(realm=45, root_key=public, max_clock_error_ms=10000), ursula_url='http://ursula:8080', bucket='flight', journal='authority', port=8080, listen='0.0.0.0', resident_pages=8, request_timeout_ms=10000))
            if profile == 'compose':
                placement.call('create', 'ursula')
                network = placement.project + '_storage'
                subprocess.run(['docker', 'network', 'connect', '--alias', 'flight-cold', network, cold.name], check=True, capture_output=True)
            storage = placement.start('ursula'); wait_ready(http, storage, placement.url('ursula') + '/__ursula/ready')
            placement.initialize()
            authority = placement.start('node'); url = placement.url('node'); wait_ready(http, authority, url + '/health')
            subprocess.run([proof, url, 'provision-flight', str(work)], check=True, capture_output=True, timeout=180)
            activate('source'); activate('requester'); delivery = courier()
            token = 'a' * 64
            (work / 'credential').write_text(token)
            mount = '/gateway' if profile == 'reference' else '/gateway-0'
            for name in ('inspector.seed', 'caller.seed', 'credential'):
                shutil.copyfile(work / name, work / 'gateway-0' / name)
            (work / 'gateway-0/ticket.seed').write_text('2a' * 32)
            connection = json.loads((work / 'cli.json').read_text())['connection']
            write(work / 'gateway-0/config.json', dict(url=placement.authority, inspector=55, inspector_seed_file=mount+'/inspector.seed', ticket_seed_file=mount+'/ticket.seed', listen='0.0.0.0', port=8080, ticket_ttl_ms=120000, native_timeout_ms=10000,
                callers=[dict(credential_file=mount+'/credential', seed_file=mount+'/caller.seed', connection=connection, service=1, binding_revision=1, columns=['id','value'])]))
            serving = start_gateway()
            target = urlsplit(placement.url('gateway-0'))
            edge = owned.enter_context(TLSProxy(work / 'tls', target.port, target.hostname, grpc=True, read_timeout=185))
            uri = f'grpc+tls://127.0.0.1:{edge.port}'
            certificate = (edge.root / 'certificate.pem').read_bytes()
            import pyarrow as pa
            import pyarrow.flight as flight
            from google.protobuf.any_pb2 import Any
            proto = ROOT / 'packages/zig/transit-flight/proto'
            subprocess.run(['protoc', '-I', str(proto), '--python_out='+str(work), str(proto/'FlightSql.proto')], check=True)
            sys.path.insert(0, str(work))
            import FlightSql_pb2 as sql
            packed = Any(); packed.Pack(sql.CommandStatementQuery(query='SELECT id, value FROM items'))
            statement = flight.FlightDescriptor.for_command(packed.SerializeToString())
            options = flight.FlightCallOptions(timeout=180, headers=[(b'authorization', ('Bearer '+token).encode()), (b'x-transit-request-sequence', b'2')])
            expected = [dict(id=i, value=None if i % 5 == 0 else 9007199254740993+i) for i in range(41)]
            schema = pa.schema([pa.field('id', pa.int64(), False), pa.field('value', pa.int64())])
            client = flight.connect(uri, tls_root_certs=certificate)

            def ready():
                # A ready pod does not establish that its replacement forward
                # and the TLS edge are ready. Schema discovery is read-only;
                # it never replaces an admission or the retained result ticket.
                deadline = time.monotonic()+30
                while True:
                    try:
                        assert client.get_schema(statement, options).schema == schema
                        return
                    except (flight.FlightUnavailableError, OSError) as error:
                        # Pinned PyArrow GetSchema exposes gRPC UNAVAILABLE as
                        # OSError with status detail; DoGet uses the typed error.
                        if not isinstance(error, flight.FlightUnavailableError) and 'Detail: Unavailable' not in str(error): raise
                        if time.monotonic() >= deadline: raise
                        time.sleep(.1)

            try:
                ready()
                info = client.get_flight_info(statement, options)
                assert client.do_get(info.endpoints[0].ticket, options).read_all().to_pylist() == expected
                print(f'Flight {profile}: TLS schema and exact 41-row snapshot passed; replacing physical services.', flush=True)
                for name, handle in workers.items():
                    if profile == 'reference': placement.stop_host(handle)
                    else: placement.stop_for_recovery('', handle)
                delivery.kill(); delivery.wait(timeout=10)
                placement.stop_for_recovery('gateway-0', serving)
                placement.stop_for_recovery('node', authority)
                placement.stop_for_recovery('ursula', storage)
                storage = placement.start('ursula'); wait_ready(http, storage, placement.url('ursula')+'/__ursula/ready')
                authority = placement.start('node'); url = placement.url('node'); wait_ready(http, authority, url+'/health')
                activate('source', True); activate('requester', True); delivery = courier()
                serving = start_gateway()
                recovered = urlsplit(placement.url('gateway-0'))
                assert recovered.port == target.port and recovered.hostname == target.hostname
                ready()
                assert client.do_get(info.endpoints[0].ticket, options).read_all().to_pylist() == expected
                retry = client.get_flight_info(statement, options)
                assert client.do_get(retry.endpoints[0].ticket, options).read_all().to_pylist() == expected
                print(f'Flight {profile}: original ticket and exact admission retry passed after physical recovery.', flush=True)
            finally: client.close()
            verify(uri, edge.root/'certificate.pem', work, token, schema, expected, lambda: json.loads(admin('next-sequence')))
            if profile == 'reference': placement.check_hosts(workers.values())
            print(f'Flight {profile}: TLS PyArrow/ADBC C/Python, physical gateway/worker/node/store recovery and exact retry passed in {time.monotonic()-started:.2f}s; {cold.data_objects()} cold objects / {cold.file_bytes()} bytes.', flush=True)
        except BaseException:
            traceback.print_exc()
            if placement:
                print(placement.call('logs')[-16000:], file=sys.stderr)
                if profile == 'reference':
                    for handle in placement.actors: print(placement.actor_logs(handle)[-2000:], file=sys.stderr)
            raise
        finally:
            for process in local:
                if process.poll() is None: process.kill()
                process.wait(timeout=10)
            for log in logs: log.close()
            if cold and network: subprocess.run(['docker','network','disconnect',network,cold.name], capture_output=True, timeout=15)
            if placement: placement.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', choices=('compose', 'reference'))
    for name in ('node', 'host', 'gateway', 'proof'): parser.add_argument(name)
    run(**vars(parser.parse_args()))
