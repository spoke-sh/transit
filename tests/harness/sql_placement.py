"""Private installed SQL host inspection, without logging lifecycle credentials."""
from collections import Counter
import json
import socket
import struct


def call(fixture, action=None, *, definition=None, lose_reply=False):
    config = json.loads((fixture.installation / 'node.json').read_text())
    if action is None:
        action = dict(status={})
    request = dict(definition=definition if definition is not None else fixture.record()['definition'], action=action)
    body = json.dumps(request, separators=(',', ':')).encode()
    assert len(body) <= 256 * 1024 + 1024
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(5)
        connection.connect(config['sql_control']['socket'])
        connection.sendall(struct.pack('<I', len(body)) + body)
        if lose_reply:
            return
        def exact(count):
            result = b''
            while len(result) < count:
                part = connection.recv(count - len(result))
                if not part:
                    raise EOFError('SQL deployment reply ended early')
                result += part
            return result
        length, = struct.unpack('<I', exact(4))
        assert 0 < length <= 256 * 1024 + 1024
        result = json.loads(exact(length))
        assert result['definition'] == fixture.record()['definition']
        return result


class Probe:
    """Counter adapter for the measurement driver's existing snapshots/deltas."""
    def __init__(self, fixture):
        self.fixture = fixture
        self.fingerprint = None
        self.previous = None

    def snapshot(self):
        status = call(self.fixture)
        assert status['state'] == 'running'
        if self.fingerprint is not None:
            assert self.fingerprint == status['fingerprint'], 'SQL host changed during measurement'
        self.fingerprint = status['fingerprint']
        result = Counter({'local:' + key: value for key, value in status['local_requests'].items()})
        if self.previous is not None:
            assert all(result[key] >= value for key, value in self.previous.items()), 'SQL counters reset during measurement'
        self.previous = result
        return result

    def delta(self, before):
        after = self.snapshot()
        assert all(after[key] >= value for key, value in before.items()), 'SQL host restarted during measurement'
        return {key: after[key] - value for key, value in before.items()}

    def close(self):
        pass
