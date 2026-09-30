"""Real serving placement, exact retry and fresh activation over owned disk state."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from http.client import HTTPConnection, HTTPSConnection
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
import traceback
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from cold_storage import ColdStore
from serving import REALM, Key, compact, frame, native_command, native_query, policy, publication, signed_read, submit
from serving_tls import TLSProxy
from placement import Compose, Reference


def run(profile, reactive=False, views=False):
    reactive = reactive or views
    started = time.monotonic()
    env = {k: v for k, v in os.environ.items() if not k.startswith(('URSULA_', 'OTEL_'))} | {'LOG_LEVEL': 'warn'}
    with tempfile.TemporaryDirectory(prefix='transit-serving-') as directory, ExitStack() as owned:
        work = Path(directory)
        roles = ('operator', 'ingress', 'application', 'courier', 'gateway-0', 'gateway-1')
        for role in roles:
            (work / role).mkdir(mode=0o700)
            (work / (role + '-data')).mkdir(mode=0o700)
        (work / 'wal').mkdir()
        keys = {p: Key(work, f'key-{p}', seed) for p, seed in ((0, 7), (33, 8), (34, 9), (65536, 10), (65537, 11), (77, 12), (78, 13), (79, 14), (80, 15))}
        sequences = dict.fromkeys(keys, 0)
        placement, cold, cold_network = None, None, None
        local, logs, proxies = [], [], []
        url = None

        def write(name, value):
            path = work / name
            path.write_text(json.dumps(value)); path.chmod(0o600)
            return path

        def request(endpoint, path, value=None, expected=200, tls=None, headers=None):
            target = urlsplit(endpoint)
            connection = HTTPSConnection(target.hostname, target.port, context=tls, timeout=15) if tls else HTTPConnection(target.hostname, target.port, timeout=15)
            try:
                connection.request('POST' if value is not None else 'GET', path,
                    compact(value) if value is not None else None, {'Content-Type': 'application/json'} | (headers or {}))
                response = connection.getresponse()
                body = response.read()
                assert response.status == expected, (path, response.status, body[:500], expected)
                return json.loads(body)
            finally: connection.close()

        def ready(child, endpoint):
            until = time.monotonic() + 90
            while child.poll() is None and time.monotonic() < until:
                try:
                    request(endpoint, '/__ursula/ready' if child is storage else '/health')
                    return
                except (OSError, AssertionError, ValueError): time.sleep(.1)
            raise RuntimeError('Serving placement did not become ready')

        def send(command, principal=0):
            message = native_command(keys[principal], principal, sequences[principal] + 1, command)
            receipt = request(url, '/v1/command', message)
            sequences[principal] += 1
            return receipt['position']

        def query(kind):
            return request(url, '/v1/query', native_query(keys[0], 0, kind))['body']

        def grant(principal, permissions, pid=None, public=None):
            send({'grant': dict(subject=principal, public_key=public or keys[principal].public, permissions=permissions, pid=pid)})

        def resource_grant(resource, principal, permissions):
            send({'grant_resource': dict(resource=resource, subject=principal, permissions=permissions)})

        def cast(pid, payload, principal=33):
            return send({'send': dict(pid=pid, value=frame(payload))}, principal)

        def provision(principal):
            pid = send({'spawn': dict(code=1, work_before_ms=None, settle_before_ms=None)})
            grant(principal, 88, pid)
            resource = send({'create_resource': dict(writer=pid, owned=True, deadline_ms=None)})
            for subject in (0, principal): resource_grant(resource, subject, 7)
            send({'associate': dict(pid=pid, name=b'state'.hex(), expected_revision=0, resource=resource, required=True)})
            return pid, resource

        def drained(pid):
            until = time.monotonic() + 120
            while time.monotonic() < until:
                value = query({'process': pid})['process']
                assert value['process']['failure'] is None, value
                if value['input'] is None: return
                time.sleep(.05)
            raise AssertionError(('undrained', pid, value))

        def activate(name, principal, pid, resource, role):
            generation = query({'process': pid})['process']['process']['generation'] + 1
            config = dict(url=placement.authority, realm=REALM, principal=principal, pid=pid,
                generation=generation, activation_directory='/runtime-data', request_timeout_ms=10000, role=role)
            if profile == 'reference':
                handle, registration = placement.register_host(config)
                assert registration['realm'] == REALM and registration['pid'] == pid and registration['principal'] == principal and registration['generation'] == generation
                public = registration['public_key']
                assert public != keys[principal].public, 'bootstrap must use a fresh key'
                grant(principal, 88, pid, public)
                resource_grant(resource, principal, 7)
                if views:
                    resource_grant(application_resource if principal == 77 else ingress_resource, principal, 3)
                send({'own': dict(pid=pid, expected_generation=generation - 1, worker=principal)})
                return handle
            config['seed_file'] = '/' + name + '/seed.key'
            (work / name / 'seed.key').write_bytes(keys[principal].seed.read_bytes())
            (work / name / 'seed.key').chmod(0o600)
            write(name + '/config.json', config)
            send({'own': dict(pid=pid, expected_generation=generation - 1, worker=principal)})
            return placement.start(name)

        def courier():
            config = dict(url=placement.authority if profile == 'compose' else url,
                realm=REALM, principal=80, seed_file='/courier/seed.key' if profile == 'compose' else str(keys[80].seed),
                role={'courier': dict(destinations=[ingress, application])})
            path = write('courier/config.json', config)
            if profile == 'compose':
                (work / 'courier/seed.key').write_bytes(keys[80].seed.read_bytes())
                (work / 'courier/seed.key').chmod(0o600)
                return placement.start('courier')
            log = (work / 'courier.log').open('w+')
            logs.append(log)
            process = subprocess.Popen([ROOT / 'zig-out/bin/transit-query-host', path], env=env, stdout=log, stderr=subprocess.STDOUT)
            local.append(process)
            return process

        def gateways():
            for proxy in proxies: proxy.__exit__(None, None, None)
            proxies.clear()
            handles = []
            for index in range(2):
                name = 'gateway-' + str(index)
                mount = '/gateway' if profile == 'reference' else '/' + name
                config = dict(url=placement.authority, realm=REALM, principal=79, seed_file=mount + '/seed.key',
                    request_timeout_ms=3000, role={'gateway': dict(service=1, ingress=ingress, resource=ingress_resource,
                        listen='0.0.0.0', port=8080, host='serving.example.test', public_origin='https://serving.example.test',
                        callers=[dict(principal=65536, public_key=keys[65536].public)])})
                if reactive:
                    config['role']['gateway'].update(reactive=True, options=dict(requests=4, request_timeout_ms=30000))
                (work / name / 'seed.key').write_bytes(keys[79].seed.read_bytes())
                (work / name / 'seed.key').chmod(0o600)
                write(name + '/config.json', config)
                handle = placement.start_gateway(name) if profile == 'reference' else placement.start(name)
                endpoint = placement.url(name)
                target = urlsplit(endpoint)
                proxy = owned.enter_context(TLSProxy(work / (name + '-tls-' + str(time.monotonic_ns())), target.port, target.hostname, read_timeout=35 if reactive else 6))
                proxies.append(proxy)
                handles.append(handle)
                until = time.monotonic() + 30
                while True:
                    try:
                        request('https://127.0.0.1:' + str(proxy.port), '/health', tls=proxy.context, headers={'Host': 'serving.example.test'})
                        break
                    except (OSError, AssertionError):
                        assert time.monotonic() < until
                        time.sleep(.1)
            return handles

        def api(path, value, expected=200, gateway=0):
            proxy = proxies[gateway]
            return request('https://127.0.0.1:' + str(proxy.port), '/serving/v1/' + path, value, expected, proxy.context,
                {'Host': 'serving.example.test', 'Origin': 'https://serving.example.test'})

        def read(kind, operation=0, expected=200):
            return api('read', signed_read(keys[65536], 65536, ingress, kind, operation), expected)

        try:
            placement = Reference(work, views) if profile == 'reference' else Compose(work, views)
            cold = ColdStore().__enter__()
            if profile == 'reference':
                cold_network = 'kind'
                subprocess.run(['docker', 'network', 'connect', cold_network, cold.name], check=True, capture_output=True)
                record = json.loads(subprocess.check_output(['docker', 'inspect', cold.name]))[0]
                placement.cold_address = record['NetworkSettings']['Networks'][cold_network]['IPAddress']
                endpoint = 'http://' + placement.cold_address + ':9000'
            else: endpoint = 'http://serving-cold:9000'
            wal = '/data/wal' if profile == 'reference' else '/wal'
            (work / 'ursula.toml').write_text('[server]\nlisten = "0.0.0.0:8080"\nadmin_listen = "127.0.0.1:0"\n[runtime]\ncore_count = 2\n[raft]\nnode_id = 1\ngroup_count = 1\n[raft.wal]\nbackend = "disk"\npath = "' + wal + '"\n' + cold.config().replace(cold.url, endpoint))
            (work / 'ursula.toml').chmod(0o600)
            write('operator/node.json', dict(profile='native_v1', genesis=dict(realm=REALM, root_key=keys[0].public, max_clock_error_ms=10000, admission_ceiling=50000, control_reserve=2000),
                ursula_url='http://ursula:8080', bucket='serving', journal='authority', port=8080, listen='0.0.0.0', resident_pages=8, request_timeout_ms=10000))
            if profile == 'compose':
                placement.call('create', 'ursula')
                cold_network = placement.project + '_storage'
                subprocess.run(['docker', 'network', 'connect', '--alias', 'serving-cold', cold_network, cold.name], check=True, capture_output=True)
                record = json.loads(subprocess.check_output(['docker', 'inspect', cold.name]))[0]
                placement.cold_address = record['NetworkSettings']['Networks'][cold_network]['IPAddress']
            storage = placement.start('ursula'); ready(storage, placement.url('ursula'))
            placement.initialize()
            authority = placement.start('node'); url = placement.url('node'); ready(authority, url)
            denied = [placement.address('ursula', 'storage') + ':8080', placement.cold_address + ':9000', '1.1.1.1:443']
            assert placement.invoke('caller-probe', 'probe', placement.authority, *denied) == dict(authority='reachable', denied=3)
            ingress, ingress_resource = provision(77)
            application, application_resource = provision(78)
            if views:
                for pid, foreign in ((ingress, application_resource), (application, ingress_resource)):
                    send({'associate': dict(pid=pid, name=b'query-peer'.hex(), expected_revision=0, resource=foreign, required=False)})
                resource_grant(application_resource, 77, 3)
                resource_grant(ingress_resource, 78, 3)
            grant(33, 20); grant(34, 20); grant(80, 148)
            grant(79, 16, None if reactive else ingress); resource_grant(ingress_resource, 79, 3)
            if reactive: resource_grant(application_resource, 79, 3)
            ingress_role = {'live_ingress': dict(service=dict(service=1, administrator=33, observer=34), query_principal=65536, source=application)} if views else {'ingress': dict(service=1, administrator=33, observer=34)}
            application_role = {'application': dict(ingress=ingress, initializer=33, queries=views)}
            workers = [activate('ingress', 77, ingress, ingress_resource, ingress_role),
                       activate('application', 78, application, application_resource, application_role)]
            cast(ingress, b'SV1c\x00'); cast(application, b'')
            drained(ingress); drained(application)
            deadline = int(time.time() * 1000) + 900000
            cast(ingress, publication(1, application, deadline)); cast(ingress, policy(65536)); drained(ingress)
            grant(65536, 20, ingress)
            if views:
                for resource in (ingress_resource, application_resource): resource_grant(resource, 65536, 3)
                cast(ingress, policy(65537)); drained(ingress)
                grant(65537, 20, ingress)
                delivery = courier()

                def recover_views():
                    nonlocal workers, storage, authority, url, delivery
                    if profile == 'reference':
                        for handle in workers: placement.stop_host(handle)
                        delivery.kill(); delivery.wait(timeout=10)
                    else:
                        for child in workers: placement.stop_for_recovery('', child)
                        placement.stop_for_recovery('courier', delivery)
                    placement.stop_for_recovery('node', authority)
                    placement.stop_for_recovery('ursula', storage)
                    storage = placement.start('ursula'); ready(storage, placement.url('ursula'))
                    authority = placement.start('node'); url = placement.url('node'); ready(authority, url)
                    workers = [activate('ingress', 77, ingress, ingress_resource, ingress_role),
                               activate('application', 78, application, application_resource, application_role)]
                    delivery = courier()

                from views_placement import run as run_views
                run_views(locals())
                if profile == 'reference': placement.check_hosts(workers)
                print(f'Live views {profile}: owned workers/gateways/node/store recovered; {cold.data_objects()} cold objects / {cold.file_bytes()} bytes; total {time.monotonic()-started:.2f}s.', flush=True)
                return
            gateway_workers = gateways()
            assert read('discovery')['binding']['target'] == application
            reactive_state = None
            if reactive:
                from reactive_placement import PhysicalReactive
                reactive_state = PhysicalReactive(locals())
                reactive_state.begin()
            frozen = native_command(keys[65536], 65536, sequences[65536] + 1, {'send': dict(pid=ingress, value=frame(submit(1, deadline)))})
            sequences[65536] += 1
            if reactive_state: reactive_state.submit(frozen)
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(lambda index: api('command', frozen, 202, index), range(2)))
            assert results[0] == results[1]
            drained(ingress)
            assert read('status', 1)['stage'] == 'service_admitted'
            if reactive_state: reactive_state.before_loss()
            # No courier has delivered the admitted outbox. Replace the physical
            # workers/gateways and recover the same disk state before delivery.
            if profile == 'reference':
                placement.kill_caller_worker()
                for handle in workers: placement.stop_host(handle)
            else:
                for child in workers: child.kill(); child.wait(timeout=10)
            for index, child in enumerate(gateway_workers): placement.stop_for_recovery('gateway-' + str(index), child)
            placement.stop_for_recovery('node', authority)
            placement.stop_for_recovery('ursula', storage)
            storage = placement.start('ursula'); ready(storage, placement.url('ursula'))
            authority = placement.start('node'); url = placement.url('node'); ready(authority, url)
            workers = [activate('ingress', 77, ingress, ingress_resource, ingress_role),
                       activate('application', 78, application, application_resource, application_role)]
            gateway_workers = gateways()
            assert api('command', frozen, 202, 1) == results[0]
            delivery = courier()
            until = time.monotonic() + 180
            while read('status', 1)['stage'] != 'completed':
                assert time.monotonic() < until
                time.sleep(.1)
            result = read('result', 1)
            assert struct.unpack('<q', bytes.fromhex(result['operation']['result']))[0] == 1
            if reactive_state: reactive_state.restore()
            duplicate = native_command(keys[65536], 65536, sequences[65536] + 1, frozen['request']['command'])
            api('command', duplicate, 202); sequences[65536] += 1; drained(ingress)
            assert read('result', 1)['operation'] == result['operation']
            cast(ingress, publication(2, application, deadline, published=False)); drained(ingress)
            if reactive_state: reactive_state.retired()
            assert read('result', 1)['operation'] == result['operation']
            cast(ingress, policy(65536, revision=2, reads=False)); drained(ingress)
            read('result', 1, 403)
            if profile == 'reference': placement.check_hosts(workers)
            print(f'Serving {profile}: two TLS gateways, exact retry, physical worker/gateway/node/disk recovery, fresh activation, immutable outcome, retirement and current denial passed in {time.monotonic()-started:.2f}s; 8 resident authority pages, 8 MiB hot store, {cold.data_objects()} cold objects / {cold.file_bytes()} bytes.', flush=True)
        except BaseException:
            traceback.print_exc()
            if placement:
                print(placement.call('ps'), file=sys.stderr)
                print(placement.call('logs'), file=sys.stderr)
                if profile == 'reference':
                    for handle in placement.actors:
                        print(placement.actor_logs(handle)[-2000:], file=sys.stderr)
            for log in logs:
                log.flush(); log.seek(0); print(log.read()[-2000:], file=sys.stderr)
            raise
        finally:
            for process in local:
                if process.poll() is None: process.kill()
                process.wait(timeout=10)
            for log in logs: log.close()
            if cold and cold_network: subprocess.run(['docker', 'network', 'disconnect', cold_network, cold.name], capture_output=True, timeout=15)
            if placement: placement.close()
            if cold: cold.__exit__(None, None, None)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--profile', choices=('compose', 'reference'), required=True)
    parser.add_argument('--reactive', action='store_true')
    parser.add_argument('--views', action='store_true')
    run(**vars(parser.parse_args()))
