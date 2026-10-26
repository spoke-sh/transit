"""Owned placement/recovery of the real query hosts and finite Zig SQL caller."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests'))
from storage.providers.cold_storage import ColdStore
from placement import Compose, Reference


def run(profile, kind):
    started = time.monotonic()
    proof = ROOT/'zig-out/bin/transit-unified-query-proof'
    example = ROOT/'zig-out/bin/example-state-query'
    host = ROOT/'zig-out/bin/transit-query-host'
    env = {k: v for k, v in os.environ.items() if not k.startswith(('URSULA_', 'OTEL_'))} | {'LOG_LEVEL': 'warn'}
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with tempfile.TemporaryDirectory(prefix='transit-query-') as directory:
        work = Path(directory)
        for role in ('operator', 'source', 'requester', 'courier', 'client'):
            (work/role).mkdir(mode=0o700)
            (work/(role+'-data')).mkdir(mode=0o700)
        (work/'wal').mkdir()
        placement, cold, cold_network = None, None, None
        local, logs = [], []
        url = ''

        def write(path, value):
            path = work/path
            path.write_text(json.dumps(value)); path.chmod(0o600)
            return path

        def invoke(mode, *args, timeout=120):
            result = subprocess.run([proof, url, mode, str(work), *map(str, args)], capture_output=True, env=env, timeout=timeout)
            if result.returncode: raise RuntimeError((mode, result.stderr.decode()[-2000:]))
            return json.loads(result.stdout) if result.stdout.strip() else None

        def ready(child, endpoint):
            until = time.monotonic()+90
            while child.poll() is None and time.monotonic() < until:
                try:
                    with http.open(endpoint, timeout=.5) as result:
                        if result.status == 200: return
                except (urllib.error.URLError, TimeoutError, ConnectionError): pass
                time.sleep(.1)
            raise RuntimeError('Query placement service did not become ready')

        def start_local(name, command):
            log = (work/(name+'.log')).open('w+')
            logs.append(log)
            process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
            local.append(process)
            return process

        def activate(role, recovering=False):
            config = json.loads((work/(role+'.json')).read_text())
            if profile == 'reference':
                config.pop('seed_file')
                config.update(url=placement.authority, activation_directory='/runtime-data',
                              generation=invoke('host-generation', role)['generation']+1)
                handle, registration = placement.register_host(config)
                assert registration['pid'] == config['pid'] and registration['generation'] == config['generation']
                invoke('activate-host', role, write(role+'/registration.json', registration))
                return handle
            if recovering:
                config['generation'] = invoke('fence' if role == 'source' else 'fence-requester')['generation']
            config.update(url=placement.authority, seed_file='/'+role+'/seed.key', activation_directory='/runtime-data')
            (work/role/'seed.key').write_bytes((work/(role+'.seed')).read_bytes())
            (work/role/'seed.key').chmod(0o600)
            write(role+'/config.json', config)
            return placement.start(role)

        def courier():
            config = json.loads((work/'courier.json').read_text())
            if profile == 'reference':
                config['url'] = url
                return start_local('courier-operator', [host, write('courier-local.json', config)])
            config.update(url=placement.authority, seed_file='/courier/seed.key')
            (work/'courier/seed.key').write_bytes((work/'courier.seed').read_bytes())
            (work/'courier/seed.key').chmod(0o600)
            write('courier/config.json', config)
            return placement.start('courier')

        def caller(mode='upload'):
            config = json.loads((work/'shell.json').read_text())
            config.update(namespace=1, sql='SELECT * FROM items', mode=mode)
            if profile == 'compose':
                config.update(url=placement.authority, seed_file='/client/seed.key', recovery_file='/runtime-data/recovery.json')
                (work/'client/seed.key').write_bytes((work/'caller.seed').read_bytes())
                (work/'client/seed.key').chmod(0o600)
                write('client/config.json', config)
                return placement.call('run', '--rm', '--no-deps', '-T', 'client', timeout=300)
            config.update(url=url, recovery_file=str(work/'client-data/recovery.json'))
            result = subprocess.run([example, write('client/config.json', config)], env=env, capture_output=True, text=True, timeout=300)
            if result.returncode: raise RuntimeError(result.stderr[-3000:])
            return result.stdout

        try:
            placement = Reference(work) if profile == 'reference' else Compose(work)
            cold = ColdStore().__enter__()
            if profile == 'reference':
                cold_network = 'kind'
                subprocess.run(['docker', 'network', 'connect', cold_network, cold.name], check=True, capture_output=True)
                record = json.loads(subprocess.check_output(['docker', 'inspect', cold.name]))[0]
                placement.cold_address = record['NetworkSettings']['Networks'][cold_network]['IPAddress']
                endpoint = 'http://'+placement.cold_address+':9000'
            else: endpoint = 'http://query-cold:9000'
            config = '[server]\nlisten = "0.0.0.0:8080"\nadmin_listen = "127.0.0.1:0"\n[runtime]\ncore_count = 2\n[raft]\nnode_id = 1\ngroup_count = 1\n[raft.wal]\nbackend = "disk"\npath = "'+('/data/wal' if profile == 'reference' else '/wal')+'"\n'+cold.config().replace(cold.url, endpoint)
            (work/'ursula.toml').write_text(config); (work/'ursula.toml').chmod(0o600)
            public = json.loads(subprocess.check_output([proof, 'public']))
            write('operator/node.json', dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000),
                ursula_url='http://ursula:8080', bucket='query-example', journal='authority', port=8080, listen='0.0.0.0',
                resident_pages=64 if kind == 'document' else 8, request_timeout_ms=10000))
            if profile == 'compose':
                placement.call('create', 'ursula')
                cold_network = placement.project+'_storage'
                subprocess.run(['docker', 'network', 'connect', '--alias', 'query-cold', cold_network, cold.name], check=True, capture_output=True)
                record = json.loads(subprocess.check_output(['docker', 'inspect', cold.name]))[0]
                placement.cold_address = record['NetworkSettings']['Networks'][cold_network]['IPAddress']
            storage = placement.start('ursula'); ready(storage, placement.url('ursula')+'/__ursula/ready')
            placement.initialize()
            authority = placement.start('node'); url = placement.url('node'); ready(authority, url+'/health')
            denied = [placement.address('ursula', 'storage')+':8080', placement.cold_address+':9000', '1.1.1.1:443']
            assert placement.invoke('caller-probe', 'probe', placement.authority, *denied) == dict(authority='reachable', denied=3)
            invoke('provision', kind, timeout=1800)
            requester, source = activate('requester'), activate('source')
            delivery = courier()
            admission = json.loads(caller())['status']
            assert admission['phase'] == 'admitted', admission
            until = time.monotonic()+300
            while True:
                job = invoke('job', '1')
                checkpoint = job.get('checkpoint')
                if checkpoint and checkpoint['progress']['segments'] > 0:
                    assert job['job']['phase'] == 'capturing', job
                    break
                assert time.monotonic() < until, 'no intermediate capture boundary'
                time.sleep(.05)
            # Stop actual application hosts and physical infrastructure. The
            # operator records fresh ownership after the same disk WAL returns.
            if profile == 'reference':
                placement.kill_caller_worker()
                for handle in (source, requester): placement.stop_host(handle)
            else:
                for process in (source, requester): process.kill(); process.wait(timeout=10)
            delivery.kill(); delivery.wait(timeout=10)
            placement.stop_for_recovery('node', authority)
            placement.stop_for_recovery('ursula', storage)
            storage = placement.start('ursula'); ready(storage, placement.url('ursula')+'/__ursula/ready')
            authority = placement.start('node'); url = placement.url('node'); ready(authority, url+'/health')
            requester, source = activate('requester', True), activate('source', True)
            delivery = courier()
            recovered = json.loads(caller())['status']
            assert recovered['correlation'] == admission['correlation']
            until = time.monotonic()+600
            next_health = 0
            while True:
                status = invoke('status')
                if status['phase'] == 'complete': break
                assert status['phase'] == 'admitted' and time.monotonic() < until, status
                if profile == 'reference' and time.monotonic() >= next_health:
                    placement.check_hosts((source, requester))
                    next_health = time.monotonic()+5
                time.sleep(.2)
            pages = [json.loads(line) for line in caller('read').splitlines()]
            assert sum(len(page['cells']) for page in pages) == (12 if kind == 'document' else 41)
            assert all(page['manifest']['basis']['kind'] == kind for page in pages)
            assert all(page['complete_coverage'] == (i+1 == len(pages)) for i, page in enumerate(pages))
            versions = invoke('versions')
            assert all(v['released_at'] is not None for v in versions['entries'] if v)
            invoke('retire-source')
            try:
                caller('read')
                raise AssertionError('retired source disclosed results')
            except RuntimeError as error:
                assert any(name in str(error) for name in ('QuerySourceUnavailable', 'ResourceUnavailable', 'Rejected', 'AccessDenied')), str(error)
            print(f'Query {profile}/{kind}: same call/source identity, staged capture, physical worker/node/disk recovery, complete owned pages, released pin, retirement and network isolation passed in {time.monotonic()-started:.2f}s; 8 MiB hot store, {cold.data_objects()} cold objects / {cold.file_bytes()} bytes.', flush=True)
        except BaseException:
            if placement:
                print(placement.call('ps'), file=sys.stderr)
                print(placement.call('logs'), file=sys.stderr)
            for log in logs:
                log.flush(); log.seek(0); print(log.read()[-3000:], file=sys.stderr)
            raise
        finally:
            for process in local:
                if process.poll() is None: process.kill()
                process.wait(timeout=10)
            for log in logs: log.close()
            if cold and cold_network:
                subprocess.run(['docker', 'network', 'disconnect', cold_network, cold.name], capture_output=True, timeout=15)
            if placement: placement.close()
            if cold: cold.__exit__(None, None, None)
