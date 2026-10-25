"""Physical placement only; Transit grants and fencing remain public operations."""
import base64
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

    def __init__(self, work, views=False):
        if views: self.binary_names = BINARIES | dict(BOARD='transit-board')
        super().__init__(work, 'serving')
        self.command[-1] = str(Path(__file__).with_name('docker-compose.yaml'))

    def stop_for_recovery(self, service, process):
        process.kill()
        process.wait(timeout=10)


class Reference(query.Reference):
    binary_names = BINARIES

    def __init__(self, work, views=False):
        if views: self.binary_names = BINARIES | dict(BOARD='transit-board')
        super().__init__(work, 'serving')

    def url(self, service):
        # Keep owned public endpoints stable while their physical pod/forward
        # changes. Observers and browsers retain their original request identity.
        previous = self.forwards.get(service)
        return super().url(service, previous[1] if previous else None)

    def call(self, *args, timeout=120):
        result = super().call(*args, timeout=timeout)
        if args[0] == 'logs':
            # These private gateways are separate from the Helm-owned node;
            # include their bounded diagnostics before owned namespace cleanup.
            for name in ('gateway-0', 'gateway-1'):
                result += self.kube('logs', 'deployment/' + name, '-c', name, '--tail=300', missing=True) or ''
            # The direct native owner has its own Deployment rather than the
            # chart's node label. Preserve restart causes and transport failures
            # before this fixture's namespace is deleted.
            result += self.kube('logs', 'deployment/node', '-c', 'node', '--tail=100', missing=True) or ''
            result += self.kube('logs', 'deployment/node', '-c', 'node', '--previous', '--tail=100', missing=True) or ''
            path = self.work / 'node-forward.log'
            if path.exists(): result += path.read_text()[-4000:]
        return result

    def start_gateway(self, name, board=False, loopback_ports=(8080,)):
        self.secret(name, self.work / name)
        dns = json.loads(self.kube('get', 'service', 'kube-dns', '-n', 'kube-system', '-o', 'json'))['spec']['clusterIP']
        node = self.address('node')
        # Kind's CNI does not enforce NetworkPolicy. Constrain this owned pod's
        # network namespace before launching either the probe or the gateway.
        rules = f'''set -eu
iptables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
{''.join('iptables -w -A OUTPUT -p tcp -d 127.0.0.1 --dport ' + str(port) + ' -j ACCEPT' + chr(10) for port in loopback_ports)}
iptables -w -A OUTPUT -p tcp -d {node} --dport 8080 -j ACCEPT
iptables -w -A OUTPUT -p udp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -w -A OUTPUT -j REJECT
ip6tables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
ip6tables -w -A OUTPUT -j REJECT
'''
        targets = [self.address('ursula') + ':8080', self.cold_address + ':' + str(self.cold_port), '1.1.1.1:443']
        for namespace, service in (('default', 'kubernetes'), ('ate-system', 'api')):
            targets.append(json.loads(self.kube('get', 'service', service, '-n', namespace, '-o', 'json'))['spec']['clusterIP'] + ':443')
        init = [dict(name='egress', image=self.pins['kind_node'], command=['sh', '-ec', rules],
            securityContext=dict(runAsUser=0, runAsNonRoot=False, allowPrivilegeEscalation=False, capabilities=dict(drop=['ALL'], add=['NET_ADMIN']))),
            dict(name='probe', image=self.env['EXCHANGE_PEER_IMAGE'], args=['probe', self.authority, *targets],
                securityContext=dict(allowPrivilegeEscalation=False, readOnlyRootFilesystem=True, capabilities=dict(drop=['ALL'])))]
        self.pod_deployment(name, dict(name=name, image=self.env['EXCHANGE_BOARD_IMAGE' if board else 'EXCHANGE_CALLER_IMAGE'],
            args=['/gateway/config.json'], env=[dict(name='LOG_LEVEL', value='warn')],
            volumeMounts=[dict(name='files', mountPath='/gateway', readOnly=True)],
            readinessProbe=dict(tcpSocket=dict(port=8080), periodSeconds=1)),
            [dict(name='files', secret=dict(secretName=name))], init)
        self.apply(dict(apiVersion='v1', kind='Service', metadata=dict(name=name),
            spec=dict(selector={'app': 'exchange-' + name}, ports=[dict(port=8080, targetPort=8080)])))
        pod = self.wait_pod(name)
        assert json.loads(self.kube('logs', pod.name, '-c', 'probe')) == dict(authority='reachable', denied=len(targets))
        return pod


class DirectReference(Reference):
    """Serving native history and direct Tables persist on one owned PVC."""
    def deploy(self):
        # The native owner below mounts this claim. An unused Helm claim with
        # delayed binding would wait forever for a consumer pod.
        self.values['node']['persistence'] = dict(existingClaim='serving-authority')
        return super().deploy()

    def setup(self):
        if self.namespace_uid is not None: return
        super().setup()
        self.apply(dict(apiVersion='v1', kind='PersistentVolumeClaim',
            metadata=dict(name='serving-authority'),
            spec=dict(accessModes=['ReadWriteOnce'], resources=dict(requests=dict(storage='1Gi')))))

    def node_files(self):
        directory = self.work / 'operator'
        self.apply(dict(apiVersion='v1', kind='Secret', metadata=dict(name='serving-authority'),
            data={name: base64.b64encode((directory / name).read_bytes()).decode()
                  for name in ('node.json', 'registrar.seed') if (directory / name).exists()}))

    def node_container(self, initialize=False):
        return dict(name='node', image=self.env['EXCHANGE_NODE_IMAGE'],
            args=['/operator/node.json', *(['--initialize'] if initialize else [])],
            env=[dict(name='LOG_LEVEL', value='warn')],
            volumeMounts=[dict(name='files', mountPath='/operator', readOnly=True),
                          dict(name='authority', mountPath='/authority')])

    def node_volumes(self):
        return [dict(name='files', secret=dict(secretName='serving-authority')),
                dict(name='authority', persistentVolumeClaim=dict(claimName='serving-authority'))]

    def initialize(self):
        # The shared chart supplies placement capacity and isolated probe
        # targets. This application's native and Table owner share one PVC.
        self.setup()
        self.node_files()
        container = self.node_container(initialize=True)
        container.update(securityContext=dict(allowPrivilegeEscalation=False,
            readOnlyRootFilesystem=True, capabilities=dict(drop=['ALL'])),
            resources=dict(requests=dict(cpu='100m', memory='64Mi'), limits=dict(cpu='1', memory='512Mi')))
        self.apply(dict(apiVersion='batch/v1', kind='Job', metadata=dict(name='serving-initialize'),
            spec=dict(backoffLimit=0, activeDeadlineSeconds=120, template=dict(spec=dict(
                restartPolicy='Never', automountServiceAccountToken=False,
                securityContext=dict(runAsUser=65532, runAsGroup=65532, runAsNonRoot=True, fsGroup=65532),
                containers=[container], volumes=self.node_volumes())))))
        self.kube('wait', '--for=condition=complete', 'job/serving-initialize', '--timeout=150s')

    def start(self, service):
        if service != 'node': return super().start(service)
        self.setup()
        self.node_files()
        container = self.node_container()
        container['readinessProbe'] = dict(httpGet=dict(path='/health', port=8080), periodSeconds=1)
        self.pod_deployment('node', container, self.node_volumes())
        self.apply(dict(apiVersion='v1', kind='Service', metadata=dict(name='node'),
            spec=dict(selector={'app': 'exchange-node'}, ports=[dict(port=8080, targetPort=8080)])))
        return self.wait_pod('node')
