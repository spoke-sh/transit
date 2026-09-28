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
