"""Run the same generated application/browser through owned physical placements."""
import argparse
from contextlib import ExitStack
import base64
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from urllib.parse import urlsplit
from placement import Compose, Reference

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests'))
from cold_storage import ColdStore
from storage import free_port
from serving_tls import TLSProxy


def run(profile):
    started = time.monotonic()
    env = {k:v for k,v in os.environ.items() if not k.startswith(('URSULA_', 'OTEL_'))} | {'LOG_LEVEL':'warn'}
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    proof = ROOT/'zig-out/bin/transit-work-items-browser-proof'
    host = ROOT/'zig-out/bin/transit-query-host'
    with tempfile.TemporaryDirectory(prefix='transit-work-items-') as directory, ExitStack() as resources:
        work = Path(directory)
        for role in ('operator','node','data','requester','publication','courier','gateway-0'):
            (work/role).mkdir(mode=0o700)
            (work/(role+'-data')).mkdir(mode=0o700)
        (work/'wal').mkdir()
        owned, cold, network, tls, backend = None, None, None, None, None
        children, logs = [], []
        url = ''
        def write(name,value):
            path=work/name;path.write_text(json.dumps(value));path.chmod(0o600);return path
        def invoke(phase,*args):
            result=subprocess.run([proof,url,phase,str(work),*map(str,args)],capture_output=True,env=env,timeout=600)
            if result.returncode: raise RuntimeError((phase,result.stderr.decode()[-3000:]))
            return json.loads(result.stdout) if result.stdout.strip() else None
        def ready(process,endpoint):
            deadline=time.monotonic()+90
            while process.poll() is None and time.monotonic()<deadline:
                try:
                    with http.open(endpoint,timeout=1) as response:
                        if response.status==200:return
                except (urllib.error.URLError,TimeoutError,ConnectionError):pass
                time.sleep(.1)
            raise RuntimeError('Physical application readiness failed: '+endpoint)
        def local(name,args):
            log=(work/(name+'.log')).open('w+');logs.append(log)
            process=subprocess.Popen(args,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            children.append(process);return process
        def activate(role,recovering=False):
            config=json.loads((work/(role+'.json')).read_text())
            config.update(url=owned.authority,activation_directory='/runtime-data',request_timeout_ms=10000)
            if profile=='reference':
                config.pop('seed_file')
                config['generation']=invoke('host-generation',role)['generation']+1
                handle,registration=owned.register_host(config)
                assert registration['pid']==config['pid'] and registration['generation']==config['generation']
                invoke('activate-host',role,write(role+'/registration.json',registration))
                return handle
            if recovering:
                invoke('fence-host',role)
                replacement=json.loads((work/(role+'.json')).read_text())
                config['generation']=replacement['generation']
            config['seed_file']='/'+role+'/seed.key'
            key=work/role/'seed.key';key.write_bytes((work/(role+'.seed')).read_bytes());key.chmod(0o600)
            write(role+'/config.json',config)
            return owned.start(role)
        def delivery():
            config=json.loads((work/'courier.json').read_text())
            if profile=='reference':
                config['url']=url
                return local('courier',[host,write('courier-local.json',config)])
            config.update(url=owned.authority,seed_file='/courier/seed.key')
            key=work/'courier/seed.key';key.write_bytes((work/'courier.seed').read_bytes());key.chmod(0o600)
            write('courier/config.json',config);return owned.start('courier')
        def start_gateway():
            nonlocal tls, backend, http
            config=json.loads((work/'gateway-base.json').read_text())
            config.update(url=owned.authority,listen='0.0.0.0',port=8080,public_origin=origin,development_allow_insecure_http=False)
            for role in ('inspection','query'):
                key=work/'gateway-0'/(role+'.seed');key.write_bytes((work/(role+'.seed')).read_bytes());key.chmod(0o600)
                config[role]['seed_file']='/gateway/'+role+'.seed'
            write('gateway-0/config.json',config)
            gateway=owned.start_gateway() if profile=='reference' else owned.start('gateway-0')
            endpoint = owned.gateway_url(private_port) if profile=='reference' else owned.url('gateway-0')
            if backend is not None: assert endpoint == backend, 'Private gateway endpoint changed during recovery'
            backend = endpoint
            if tls is None:
                target = urlsplit(endpoint)
                tls = TLSProxy(work/'gateway-tls', target.port, target.hostname, web_port).__enter__()
                http = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=tls.context))
            ready(gateway,origin+'/health');return gateway
        try:
            owned=Reference(work) if profile=='reference' else Compose(work)
            built=time.monotonic()-started
            web_port=free_port();private_port=free_port();origin=f'https://127.0.0.1:{web_port}'
            if profile=='compose':
                (work/'ursula.toml').touch()
                owned.call('create','ursula')
                network=owned.project+'_storage'
            else:
                network='kind'
            addresses=json.loads(subprocess.check_output(['docker','network','inspect',network]))[0]['IPAM']['Config']
            bridge=next((item['Gateway'] for item in addresses if 'Gateway' in item and ipaddress.ip_address(item['Gateway']).version==4),None)
            if bridge is None: raise RuntimeError('Physical application fixture requires a private IPv4 bridge gateway')
            cold=resources.enter_context(ColdStore(bind_address=bridge))
            owned.cold_address=bridge
            owned.cold_port=cold.port
            config='[server]\nlisten = "0.0.0.0:8080"\nadmin_listen = "127.0.0.1:0"\n[runtime]\ncore_count = 2\n[raft]\nnode_id = 1\ngroup_count = 1\n[raft.wal]\nbackend = "disk"\npath = "'+('/data/wal' if profile=='reference' else '/wal')+'"\n'+cold.config()
            (work/'ursula.toml').write_text(config);(work/'ursula.toml').chmod(0o600)
            public=json.loads(subprocess.check_output([proof,'public']))
            node_config = dict(profile='native_v1',genesis=dict(realm=51,root_key=public,max_clock_error_ms=10000),local_directory='/authority',listen='0.0.0.0',port=8080,resident_pages=16,request_timeout_ms=10000)
            write('operator/node.json', node_config)
            storage=owned.start('ursula');ready(storage,owned.url('ursula')+'/__ursula/ready')
            owned.initialize()
            authority=owned.start('node');url=owned.url('node');ready(authority,url+'/health')
            denied=[owned.address('ursula','storage')+':8080',owned.cold_address+':'+str(owned.cold_port),'1.1.1.1:443']
            assert owned.invoke('caller-probe','probe',owned.authority,*denied)==dict(authority='reachable',denied=3)
            invoke('setup')
            owned.stop_for_recovery('node', authority)
            table = json.loads((work/'data-catalog.json').read_text())
            table['registrar']['seed_file'] = '/operator/registrar.seed'
            registrar = work/'operator/registrar.seed'
            registrar.write_bytes((work/'registrar.seed').read_bytes()); registrar.chmod(0o600)
            node_config['table'] = table
            write('operator/node.json', node_config)
            authority=owned.start('node');url=owned.url('node');ready(authority,url+'/health')
            invoke('initialize-data')
            workers={role:activate(role) for role in ('requester','data','publication')}
            courier=delivery();invoke('seed')
            gateway=start_gateway()
            marker=work/'browser'
            public = subprocess.check_output(['openssl','x509','-in',str(tls.root/'certificate.pem'),'-pubkey','-noout'])
            der = subprocess.check_output(['openssl','pkey','-pubin','-outform','DER'],input=public)
            pin = base64.b64encode(hashlib.sha256(der).digest()).decode()
            env['NODE_EXTRA_CA_CERTS'] = str(tls.root/'certificate.pem')
            browser=local('browser',['node',ROOT/'examples/work-items/web/browser/proof.mjs',origin,marker,pin,
                '600000' if profile == 'reference' else '180000'])
            def phase(expected):
                deadline=time.monotonic()+360
                while not marker.exists() or marker.read_text()!=expected:
                    assert browser.poll() is None, 'Browser exited before '+expected
                    assert time.monotonic()<deadline, 'Browser timed out before '+expected
                    if profile=='reference':owned.check_hosts(workers.values())
                    time.sleep(.2)
            phase('migrate')
            # Stop all actual owners before storage recovery. Fresh registrations
            # preserve native role membership and foreign-resource grants while
            # advancing the same principal's key and ownership generation.
            for worker in workers.values():
                if profile=='reference':owned.stop_host(worker)
                else:worker.kill();worker.wait(timeout=10)
            courier.kill();courier.wait(timeout=10)
            owned.stop_for_recovery('gateway-0',gateway)
            owned.stop_for_recovery('node',authority)
            owned.stop_for_recovery('ursula',storage)
            storage=owned.start('ursula');ready(storage,owned.url('ursula')+'/__ursula/ready')
            authority=owned.start('node');url=owned.url('node');ready(authority,url+'/health')
            workers={role:activate(role,True) for role in workers}
            courier=delivery();invoke('migrate')
            gateway=start_gateway();marker.write_text('migrated')
            phase('deny');invoke('deny');marker.write_text('denied')
            assert browser.wait(timeout=180)==0
            print(f'Generated work items {profile}: actual owners/browser, private ingress, native/direct Table disk recovery across worker/node/gateway replacement, original query recovery, schema publication and current denial passed in {time.monotonic()-started:.2f}s including {built:.2f}s image work.',flush=True)
        except BaseException:
            if owned:
                print(owned.call('ps'),file=sys.stderr)
                print(owned.call('logs'),file=sys.stderr)
                if profile=='reference':
                    for handle in owned.actors:print(owned.actor_logs(handle)[-3000:],file=sys.stderr)
            for log in logs:
                log.flush();log.seek(0);print(log.read()[-5000:],file=sys.stderr)
            raise
        finally:
            for child in reversed(children):
                if child.poll() is None:os.killpg(child.pid,signal.SIGKILL)
                child.wait(timeout=10)
            for log in logs:log.close()
            if tls:tls.__exit__(None,None,None)
            if owned:owned.close()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile',choices=('compose','reference'))
    run(parser.parse_args().profile)
