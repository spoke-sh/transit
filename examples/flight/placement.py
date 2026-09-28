"""Reuse owned disk, Substrate activation and confined gateway placement."""
import base64
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location('serving_placement', Path(__file__).resolve().parents[1] / 'serving/placement.py')
serving = importlib.util.module_from_spec(spec)
spec.loader.exec_module(serving)
BINARIES = dict(NODE='transit-node', CALLER='transit-query-host', CONNECTOR='transit-query-host', BOARD='transit-flight-gateway')


class Compose(serving.Compose):
    binary_names = BINARIES

    def __init__(self, work):
        serving.BaseCompose.__init__(self, work, 'flight')
        self.command[-1] = str(Path(__file__).with_name('docker-compose.yaml'))


class Reference(serving.Reference):
    binary_names = BINARIES

    def __init__(self, work):
        serving.query.Reference.__init__(self, work, 'flight')

    def secret(self, name, directory):
        # This gateway has separate observer, caller and ticket keys. Each is
        # private deployment configuration, never a principal supplied by RPC.
        if name != 'gateway-0': return super().secret(name, directory)
        self.apply(dict(apiVersion='v1', kind='Secret', metadata=dict(name=name),
            data={p.name: base64.b64encode(p.read_bytes()).decode() for p in directory.iterdir() if p.is_file()}))

    def start_gateway(self):
        return super().start_gateway('gateway-0', board=True)
