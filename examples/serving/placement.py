"""Physical placement only; Transit grants and fencing remain public operations."""
import importlib.util
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'exchange'))
from compose import Compose as BaseCompose
spec = importlib.util.spec_from_file_location('query_placement', Path(__file__).resolve().parents[1] / 'state-query/placement.py')
query = importlib.util.module_from_spec(spec)
spec.loader.exec_module(query)
BINARIES = dict(NODE='transit-node', CALLER='transit-serving-example', CONNECTOR='transit-query-host')


class Compose(BaseCompose):
    binary_names = BINARIES

    def __init__(self, work):
        super().__init__(work, 'serving')
        self.command[-1] = str(Path(__file__).with_name('docker-compose.yaml'))

    def stop_for_recovery(self, service, process):
        process.kill()
        process.wait(timeout=10)


class Reference(query.Reference):
    binary_names = BINARIES

    def __init__(self, work):
        super().__init__(work, 'serving')

    def start_gateway(self, name):
        self.secret(name, self.work / name)
        dns = json.loads(self.kube('get', 'service', 'kube-dns', '-n', 'kube-system', '-o', 'json'))['spec']['clusterIP']
        node = self.address('node')
        # Kind's CNI does not enforce NetworkPolicy. Constrain this owned pod's
        # network namespace before launching either the probe or the gateway.
        rules = f'''set -eu
iptables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -w -A OUTPUT -p tcp -d 127.0.0.1 --dport 8080 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {node} --dport 8080 -j ACCEPT
iptables -w -A OUTPUT -p udp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -w -A OUTPUT -j REJECT
ip6tables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
ip6tables -w -A OUTPUT -j REJECT
'''
        targets = [self.address('ursula') + ':8080', self.cold_address + ':9000', '1.1.1.1:443']
        for namespace, service in (('default', 'kubernetes'), ('ate-system', 'api')):
            targets.append(json.loads(self.kube('get', 'service', service, '-n', namespace, '-o', 'json'))['spec']['clusterIP'] + ':443')
        init = [dict(name='egress', image=self.pins['kind_node'], command=['sh', '-ec', rules],
            securityContext=dict(runAsUser=0, runAsNonRoot=False, allowPrivilegeEscalation=False, capabilities=dict(drop=['ALL'], add=['NET_ADMIN']))),
            dict(name='probe', image=self.env['EXCHANGE_PEER_IMAGE'], args=['probe', self.authority, *targets],
                securityContext=dict(allowPrivilegeEscalation=False, readOnlyRootFilesystem=True, capabilities=dict(drop=['ALL'])))]
        self.pod_deployment(name, dict(name=name, image=self.env['EXCHANGE_CALLER_IMAGE'],
            args=['/gateway/config.json'], env=[dict(name='LOG_LEVEL', value='warn')],
            volumeMounts=[dict(name='files', mountPath='/gateway', readOnly=True)],
            readinessProbe=dict(tcpSocket=dict(port=8080), periodSeconds=1)),
            [dict(name='files', secret=dict(secretName=name))], init)
        self.apply(dict(apiVersion='v1', kind='Service', metadata=dict(name=name),
            spec=dict(selector={'app': 'exchange-' + name}, ports=[dict(port=8080, targetPort=8080)])))
        pod = self.wait_pod(name)
        assert json.loads(self.kube('logs', pod.name, '-c', 'probe')) == dict(authority='reachable', denied=len(targets))
        return pod
