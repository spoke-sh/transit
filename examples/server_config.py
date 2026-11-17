"""Public external-worker server configuration shared by owned examples."""
import json
import time
import ctypes
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tests'))
from harness.processes import children, joined


class ServerProcess(subprocess.Popen):
    """Join the server's children even in the examples' forced-loss schedules."""
    def __init__(self, *args, **kwargs):
        assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
        self.owned = set()
        super().__init__(*args, **kwargs)

    def send_signal(self, signal):
        self.owned.update(children(self.pid))
        super().send_signal(signal)

    def wait(self, timeout=None):
        result = super().wait(timeout)
        joined(self.owned)
        self.owned.clear()
        return result


def configuration(realm, root_seed, *, installation='/authority/installation', port=8080,
                  listen='0.0.0.0', object_storage=None, request_timeout_ms=10000):
    external = dict(root_seed_file=str(root_seed), listen=listen,
                    request_timeout_ms=request_timeout_ms)
    return dict(version=1, installation=str(installation), realm=realm,
                ports=dict(node=port), sql=dict(native=dict(local=False)),
                external=external, applications=None,
                storage=dict(object_storage=object_storage, maintenance=dict(compact=False,
                    archive=dict(enabled=False), flush=dict(enabled=False))))


def wait_started(process, output, timeout=30):
    """Wait for the supervisor's ready record, beyond native listener health."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError('Transit server exited before readiness')
        for line in output().splitlines():
            try:
                value = json.loads(line)
            except ValueError:
                continue
            if isinstance(value, dict) and value.get('ready') is True:
                return
        time.sleep(.1)
    raise TimeoutError('Transit server did not report readiness')


def wait_delivered(query, destinations=None, timeout=30):
    """Observe delivery through public reads; the server owns the courier."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        position, after, pending = None, None, False
        while time.monotonic() < deadline:
            try:
                response = query({'outputs': dict(after=after, position=position)})
            except RuntimeError as error:
                if (getattr(error, 'status', None) != 5 or
                        getattr(error, 'detail', None) != {'err': 'QueryExpired'}):
                    raise
                # A courier publication invalidated this observation. Discard
                # the whole prefix and start a fresh bounded observation.
                break
            position = response['position']
            page = response['body']['outputs']
            for entry in filter(None, page['entries']):
                if destinations is not None:
                    assert entry['destination'] in destinations
                pending |= entry['phase'] == 'pending'
            after = page['next']
            if after is None:
                if not pending:
                    return
                break
        time.sleep(.05)
    raise TimeoutError('Server delivery did not settle the observed outputs')
