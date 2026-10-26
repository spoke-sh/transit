"""Check receipt-loss injection against an unavailable then accepting HTTP peer."""
from http.client import HTTPConnection, RemoteDisconnected
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading

from runtime.delivery.vortex import Peer


class Upstream(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        self.rfile.read(int(self.headers['Content-Length']))
        self.server.attempts += 1
        status, body = ((503, {'err': 'AuthorityTimeout'}) if self.server.attempts == 1
                        else (200, {'position': 17}))
        encoded = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def check(fault):
    events = []
    upstream = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
    upstream.attempts = 0
    proxy = Peer(upstream.server_port, lambda event, **fields: events.append((event, fields)))
    threads = [threading.Thread(target=server.serve_forever) for server in (upstream, proxy)]
    for thread in threads:
        thread.start()
    try:
        proxy.arm(1, 'turn', fault, .001)
        body = json.dumps({'request': {'principal': 1, 'sequence': 1, 'command': {'turn': {}}}})
        for attempt in range(2):
            connection = HTTPConnection('127.0.0.1', proxy.server_port, timeout=5)
            try:
                connection.request('POST', '/v1/command', body, {'Content-Type': 'application/json'})
                if attempt == 1 and fault == 'drop_response':
                    try:
                        connection.getresponse()
                    except RemoteDisconnected:
                        pass
                    else:
                        raise AssertionError('accepted response was not dropped')
                else:
                    response = connection.getresponse()
                    expected = {'err': 'AuthorityTimeout'} if attempt == 0 else {'position': 17}
                    assert response.status == (503 if attempt == 0 else 200)
                    assert json.loads(response.read()) == expected
            finally:
                connection.close()
            if attempt == 0:
                assert not proxy.seen.is_set() and not proxy.finished.is_set()
                assert proxy.rule is not None and not proxy.accepted
        assert proxy.seen.wait(5) and proxy.finished.wait(5)
        assert proxy.rule is None and not proxy.errors
        assert proxy.attempts[(1, 1)][1] == 2
        assert json.loads(proxy.accepted[(1, 1)][1]) == {'position': 17}
        assert [name for name, _ in events].count('fault_deferred') == 1
        assert [name for name, _ in events].count('fault_observed') == 1
    finally:
        for server in (proxy, upstream):
            server.shutdown()
            server.server_close()
        for thread in threads:
            thread.join(timeout=5)
            assert not thread.is_alive()


if __name__ == '__main__':
    for fault in ('drop_response', 'delay_response'):
        check(fault)
    print('Vortex response faults wait for an accepted receipt after upstream unavailability.')
