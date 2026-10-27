"""Verified database TLS, scoped placement and fenced disk recovery."""
from contextlib import ExitStack
import decimal
import ipaddress
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests'))
from storage.providers.cold_storage import ColdStore
from harness.services import wait_ready
from placement import Compose, Reference
import psycopg
import mysql.connector


def run(profile,node,catalog,ledger,gateway):
    node,catalog,ledger,gateway = [str(Path(p).resolve()) for p in (node,catalog,ledger,gateway)]
    started = time.monotonic()
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    env = {k:v for k,v in os.environ.items() if not k.startswith(('URSULA_','OTEL_'))} | {'LOG_LEVEL':'warn'}
    with tempfile.TemporaryDirectory(prefix='transit-sql-placement-') as temporary, ExitStack() as owned:
        work = Path(temporary)
        for name in ('operator','authority','gateway-0','gateway-0-data','gateway-spill','wal'):
            (work/name).mkdir(mode=0o700)
        placement,cold,network = None,None,None
        def write(path,value):
            path.write_text(json.dumps(value)); path.chmod(0o600)
        def call(binary,mode,*args):
            result = subprocess.run([binary,url,mode,str(work),*map(str,args)],capture_output=True,text=True,timeout=300)
            if result.returncode: raise RuntimeError(mode+': '+result.stderr[-3000:])
            return json.loads(result.stdout)
        def configure_gateway():
            call(ledger,'app-config',8080)
            config = json.loads((work/'sql-gateway.json').read_text())
            config.update(native_url=placement.authority,bind_address='0.0.0.0',mysql_port=3306,health_address='0.0.0.0',health_port=8081,activation_directory='/activation',spill_directory='/spill')
            for field in ('certificate_file','certificate_key_file'):
                source = Path(config[field]); shutil.copyfile(source,work/'gateway-0'/source.name)
                config[field] = '/gateway/'+source.name
            for account in config['accounts']:
                source = Path(account['verifier_file']); shutil.copyfile(source,work/'gateway-0'/source.name)
                account['verifier_file'] = '/gateway/'+source.name
                for field,value in account['keys'].items():
                    source = Path(value); shutil.copyfile(source,work/'gateway-0'/source.name)
                    account['keys'][field] = '/gateway/'+source.name
            write(work/'gateway-0/config.json',config)
        def start_gateway():
            process = placement.start_gateway() if profile == 'reference' else placement.start('gateway-0')
            ports = {kind:placement.endpoint(kind) for kind in ('postgres','mysql','health')}
            wait_ready(http,process,f'http://127.0.0.1:{ports["health"]}/health')
            return process,ports
        def clients(ports,recovered=False):
            pg = dict(host='localhost',hostaddr='127.0.0.1',port=ports['postgres'],user='proof',password='proof-password',dbname='data',sslmode='verify-full',sslrootcert=str(work/'certificate.pem'),autocommit=True,connect_timeout=10)
            my = dict(host='localhost',port=ports['mysql'],user='proof',password='proof-password',database='data',ssl_ca=str(work/'certificate.pem'),ssl_verify_cert=True,ssl_verify_identity=True,autocommit=True,use_pure=True,charset='utf8mb4',collation='utf8mb4_0900_bin',sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES')
            values = (1,decimal.Decimal(2**64-1),-1.25,True,'snow ☃',b'\0\xff')
            with psycopg.connect(**pg) as connection:
                if not recovered:
                    connection.execute('CREATE TABLE placement_rows (id BIGINT PRIMARY KEY, n UINT64, f FLOAT64, b BOOLEAN, label UTF8, payload BINARY)')
                    assert connection.execute('INSERT INTO placement_rows (id,n,f,b,label,payload) VALUES (%s,%s,%s,%s,%s,%s)',values,prepare=True).rowcount == 1
                for binary in (False,True):
                    with connection.cursor(binary=binary) as reader:
                        reader.execute('SELECT id,n,f,b,label,payload FROM placement_rows WHERE id=%s',(1,),prepare=True)
                        assert reader.fetchone() == values and reader.fetchone() is None
            with mysql.connector.connect(**my) as connection:
                reader = connection.cursor(prepared=True)
                reader.execute('SELECT id,n,f,b,label,payload FROM placement_rows WHERE id=%s',(1,))
                assert reader.fetchone() == (1,2**64-1,-1.25,1,'snow ☃',b'\0\xff')
                reader.execute('UPDATE placement_rows SET label=%s WHERE id=%s',('snow ☃',1))
                assert reader.rowcount == 0
                if recovered:
                    reader.execute('DELETE FROM placement_rows WHERE id=%s',(1,))
                    assert reader.rowcount == 1
                reader.close()
        try:
            placement = (Compose if profile == 'compose' else Reference)(work)
            if profile == 'compose':
                (work/'ursula.toml').touch()
                placement.call('create','ursula')
                network = placement.project+'_storage'
            else:
                network = 'kind'
            addresses = json.loads(subprocess.check_output(['docker','network','inspect',network]))[0]['IPAM']['Config']
            bridge = next(item['Gateway'] for item in addresses if item.get('Gateway') and ipaddress.ip_address(item['Gateway']).version == 4)
            cold = owned.enter_context(ColdStore(bind_address=bridge))
            placement.cold_address = bridge
            placement.cold_port = cold.port
            wal = '/data/wal' if profile == 'reference' else '/wal'
            (work/'ursula.toml').write_text('[server]\nlisten="0.0.0.0:8080"\nadmin_listen="127.0.0.1:0"\n[runtime]\ncore_count=2\n[raft]\nnode_id=1\ngroup_count=1\n[raft.wal]\nbackend="disk"\npath="'+wal+'"\n'+cold.config())
            (work/'ursula.toml').chmod(0o600)
            public = json.loads(subprocess.check_output([catalog,'public'],timeout=10))
            node_config = dict(profile='native_v1',genesis=dict(realm=46,root_key=public,max_clock_error_ms=10000),local_directory='/authority',port=8080,listen='0.0.0.0',resident_pages=8,request_timeout_ms=10000)
            write(work/'operator/node.json', node_config)
            storage = placement.start('ursula'); wait_ready(http,storage,placement.url('ursula')+'/__ursula/ready')
            placement.initialize()
            authority = placement.start('node'); url = placement.url('node'); wait_ready(http,authority,url+'/health')
            call(catalog,'provision')
            placement.stop_for_recovery('node',authority)
            table = json.loads((work/'catalog-node.json').read_text())
            table['registrar']['seed_file'] = '/operator/registrar.seed'
            shutil.copyfile(work/'registrar.seed',work/'operator/registrar.seed')
            (work/'operator/registrar.seed').chmod(0o600)
            node_config['table'] = table
            write(work/'operator/node.json',node_config)
            authority = placement.start('node'); url = placement.url('node'); wait_ready(http,authority,url+'/health')
            call(catalog,'initialize'); call(catalog,'external-provision'); call(ledger,'provision',1235)
            assert call(ledger,'raw-denied')['raw_denied']
            subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost','-keyout',str(work/'key.pem'),'-out',str(work/'certificate.pem')],capture_output=True,check=True,timeout=30)
            (work/'key.pem').chmod(0o600)
            configure_gateway(); server,ports = start_gateway(); clients(ports)
            print(f'SQL {profile}: verified TLS, six types and direct Table counts passed; replacing gateway and node.',flush=True)
            for name,process in (('gateway-0',server),('node',authority),('ursula',storage)):
                placement.stop_for_recovery(name,process)
            storage = placement.start('ursula'); wait_ready(http,storage,placement.url('ursula')+'/__ursula/ready')
            authority = placement.start('node'); url = placement.url('node'); wait_ready(http,authority,url+'/health')
            call(ledger,'fence'); configure_gateway(); server,ports = start_gateway(); clients(ports,True)
            print(json.dumps(dict(profile='sql_wire_'+profile,types=6,verified_tls=True,physical_recovery=True,fresh_native_generation=True,direct_tables=True,raw_resource_denied=True,seconds=round(time.monotonic()-started,3))),flush=True)
        except BaseException:
            if placement:
                print(placement.call('logs')[-12000:],file=sys.stderr)
            raise
        finally:
            if placement: placement.close()


if __name__ == '__main__':
    assert sys.argv[1] in ('compose','reference')
    run(*sys.argv[1:])
