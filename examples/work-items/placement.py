"""Owned physical composition; all rights still come from native commands."""
import base64
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location('work_items_serving_placement', Path(__file__).resolve().parents[1]/'serving/placement.py')
serving = importlib.util.module_from_spec(spec)
spec.loader.exec_module(serving)
BINARIES = dict(NODE='transit-node', CALLER='transit-query-host', CONNECTOR='transit-work-items', BOARD='transit-work-items-gateway')


class Compose(serving.Compose):
    binary_names = BINARIES

    def __init__(self, work):
        serving.BaseCompose.__init__(self, work, 'work-items')
        self.command[-1] = str(Path(__file__).with_name('docker-compose.yaml'))


class Reference(serving.Reference):
    binary_names = BINARIES

    def __init__(self, work):
        serving.query.Reference.__init__(self, work, 'work-items')

    def setup(self):
        if self.namespace_uid is not None: return
        super().setup()
        # Three independently activated logical owners in separate actors.
        self.values['workerPool']['spec']['replicas'] = 3
        self.deploy()
        self.apply(dict(apiVersion='v1', kind='PersistentVolumeClaim',
            metadata=dict(name='work-items-authority'),
            spec=dict(accessModes=['ReadWriteOnce'], resources=dict(requests=dict(storage='1Gi')))))

    def node_files(self):
        directory = self.work / 'operator'
        self.apply(dict(apiVersion='v1', kind='Secret', metadata=dict(name='work-items-authority'),
            data={name: base64.b64encode((directory / name).read_bytes()).decode()
                  for name in ('node.json', 'registrar.seed') if (directory / name).exists()}))

    def node_container(self, initialize=False):
        return dict(name='node', image=self.env['EXCHANGE_NODE_IMAGE'],
            args=['/operator/node.json', *(['--initialize'] if initialize else [])],
            env=[dict(name='LOG_LEVEL', value='warn')],
            volumeMounts=[dict(name='files', mountPath='/operator', readOnly=True),
                          dict(name='authority', mountPath='/authority')])

    def node_volumes(self):
        return [dict(name='files', secret=dict(secretName='work-items-authority')),
                dict(name='authority', persistentVolumeClaim=dict(claimName='work-items-authority'))]

    def initialize(self):
        # The shared chart supplies placement capacity and isolated probe
        # targets. This application's native and Table owner share one PVC.
        self.setup()
        self.node_files()
        container = self.node_container(initialize=True)
        container.update(securityContext=dict(allowPrivilegeEscalation=False,
            readOnlyRootFilesystem=True, capabilities=dict(drop=['ALL'])),
            resources=dict(requests=dict(cpu='100m', memory='64Mi'), limits=dict(cpu='1', memory='512Mi')))
        self.apply(dict(apiVersion='batch/v1', kind='Job', metadata=dict(name='work-items-initialize'),
            spec=dict(backoffLimit=0, activeDeadlineSeconds=120, template=dict(spec=dict(
                restartPolicy='Never', automountServiceAccountToken=False,
                securityContext=dict(runAsUser=65532, runAsGroup=65532, runAsNonRoot=True, fsGroup=65532),
                containers=[container], volumes=self.node_volumes())))))
        self.kube('wait', '--for=condition=complete', 'job/work-items-initialize', '--timeout=150s')

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

    def caller_template(self, name, config):
        template = super().caller_template(name, config)
        if 'application' in config:
            template['containers'][0]['image'] = self.env['EXCHANGE_CONNECTOR_IMAGE']
        return template

    def secret(self, name, directory):
        if name != 'gateway-0': return super().secret(name, directory)
        self.apply(dict(apiVersion='v1',kind='Secret',metadata=dict(name=name),
            data={p.name:base64.b64encode(p.read_bytes()).decode() for p in directory.iterdir() if p.is_file()}))

    def gateway_url(self, port):
        return serving.query.Reference.url(self, 'gateway-0', port)

    def start_gateway(self):
        return super().start_gateway('gateway-0', board=True)
