"""Owned database placement; native grants and generations stay explicit."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('sql_flight_placement', ROOT/'examples/flight/placement.py')
flight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(flight)


class Images:
    binary_names = dict(NODE='transit-node', CALLER='transit-query-host', CONNECTOR='transit-query-host', BOARD='transit-sql-gateway')

    def build(self):
        # The Zig hosts are static. OpenSSL and its pinned dynamic loader travel
        # together in the SQL package's complete Nix runtime closure.
        names = self.binary_names
        self.binary_names = {k:v for k,v in names.items() if k != 'BOARD'}
        try:
            super().build()
        finally:
            self.binary_names = names
        package = subprocess.check_output(['nix','build','.#transit-sql-gateway','--no-link','--print-out-paths'], cwd=ROOT, text=True, timeout=900).strip()
        context = ROOT/'.cache/sql-wire-example/images/gateway'
        context.mkdir(parents=True, exist_ok=True)
        for item in subprocess.check_output(['nix-store','--query','--requisites',package], text=True).splitlines():
            destination = context/item.lstrip('/')
            if not destination.exists():
                shutil.copytree(item,destination,symlinks=True)
        (context/'Dockerfile').write_text('FROM scratch\nCOPY nix /nix\nENTRYPOINT '+json.dumps([package+'/bin/transit-sql-gateway'])+'\n')
        self.env['EXCHANGE_BOARD_IMAGE'] = self.image(context)


class Compose(Images, flight.Compose):
    def __init__(self, work):
        flight.serving.BaseCompose.__init__(self,work,'sql-wire')
        self.command[-1] = str(Path(__file__).with_name('docker-compose.yaml'))

    def endpoint(self, kind):
        port = {'postgres':8080,'mysql':3306,'health':8081}[kind]
        address = self.call('port','gateway-0',str(port)).strip()
        assert address.startswith('127.0.0.1:')
        return int(address.rsplit(':',1)[1])


class Reference(Images, flight.Reference):
    def __init__(self, work):
        flight.serving.query.Reference.__init__(self,work,'sql-wire')

    def pod_deployment(self, name, container, volumes, init_containers=()):
        if name == 'gateway-0':
            self.apply(dict(apiVersion='v1',kind='PersistentVolumeClaim',metadata=dict(name='gateway-activation'),spec=dict(accessModes=['ReadWriteOnce'],resources=dict(requests=dict(storage='1Gi')))))
            volumes = [*volumes,dict(name='activation',persistentVolumeClaim=dict(claimName='gateway-activation')),dict(name='spill',emptyDir=dict(sizeLimit='128Mi'))]
            container['volumeMounts'] += [dict(name='activation',mountPath='/activation'),dict(name='spill',mountPath='/spill')]
            container['readinessProbe'] = dict(httpGet=dict(path='/health',port=8081),periodSeconds=1)
            container['livenessProbe'] = dict(httpGet=dict(path='/live',port=8081),periodSeconds=10,failureThreshold=6)
        return super().pod_deployment(name,container,volumes,init_containers)

    def start_gateway(self):
        pod = flight.serving.Reference.start_gateway(self,'gateway-0',board=True,loopback_ports=(8080,3306,8081))
        for name,port in (('mysql',3306),('health',8081)):
            self.apply(dict(apiVersion='v1',kind='Service',metadata=dict(name='gateway-'+name),spec=dict(selector={'app':'exchange-gateway-0'},ports=[dict(port=8080,targetPort=port)])))
        return pod

    def endpoint(self, kind):
        service = 'gateway-0' if kind == 'postgres' else 'gateway-'+kind
        return int(self.url(service).rsplit(':',1)[1])
