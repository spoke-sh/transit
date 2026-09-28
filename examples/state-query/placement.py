"""Physical query hosts; grants/ownership remain signed Transit operations."""
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'exchange'))
from compose import Compose as BaseCompose
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'station-document'))
# Import the existing storage recovery behavior without importing its workload.
import importlib.util
spec = importlib.util.spec_from_file_location('document_placement', Path(__file__).resolve().parents[1]/'station-document/placement.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

BINARIES = dict(NODE='transit-node', CALLER='transit-query-host', CONNECTOR='example-state-query')


class Compose(BaseCompose):
    binary_names = BINARIES
    def __init__(self, work):
        super().__init__(work, 'query')
        self.command[-1] = str(Path(__file__).with_name('docker-compose.yaml'))

    def stop_for_recovery(self, service, process):
        process.kill(); process.wait(timeout=10)


class Reference(module.Reference):
    binary_names = BINARIES
    def __init__(self, work, protocol='query'):
        super().__init__(work, protocol)

    def register_host(self, config):
        self.counter += 1
        handle = self.launch_actor(self.caller_template('query-'+str(self.counter), config))
        until = time.monotonic()+180
        while time.monotonic() < until:
            registrations = [m['growing_bootstrap'] for m in self.messages(handle) if 'growing_bootstrap' in m]
            assert len(registrations) <= 1, 'ambiguous physical registration'
            if registrations: return handle, registrations[0]
            time.sleep(.2)
        raise TimeoutError('Query host did not register')

    def stop_host(self, handle):
        actor = self.actor(handle)
        if actor['status']['state'] == 'ACTOR_STATE_RUNNING':
            self.ate('suspend', 'actor', handle['name'], '-a', self.namespace)
        handle['stopped'] = True

    def check_hosts(self, handles):
        for handle in handles:
            logs = self.actor_logs(handle)
            if 'service.failed' in logs:
                raise RuntimeError('Query host stopped: '+logs[-1500:])
