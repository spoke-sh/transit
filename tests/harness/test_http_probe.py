"""The diagnostic proxy must not hide sequential socket lifetime behavior."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading
import json
import unittest
from harness.http_probe import Probe


class Reuse(unittest.TestCase):
    def test_bulk_reads_count_attempts_without_retaining_bytes(self):
        body = json.dumps({'response': {'position': 17}, 'blocks': 'UFJJVkFURQ=='}).encode()
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                self.rfile.read(int(self.headers['Content-Length']))
                self.send_response(200)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        probe = Probe(f'http://127.0.0.1:{server.server_port}', native=True)
        client = HTTPConnection('127.0.0.1', probe.server.server_port, timeout=3)
        try:
            self.assertFalse(probe.wait_completed(1, timeout=0))
            client.request('POST', '/v1/blocks', json.dumps({'query': {'principal': 9, 'kind': {'block_entries': {}}}}))
            self.assertEqual(client.getresponse().read(), body)
            self.assertTrue(probe.wait_completed(1, timeout=3))
            self.assertEqual(probe.snapshot()['read:block_entries'], 1)
            self.assertEqual(probe.trace()['retained'][0]['position'], 17)
            self.assertNotIn('UFJJVkFURQ', json.dumps(probe.trace()))
        finally:
            client.close()
            probe.close()
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_upstream_reuse_and_advertised_retirement(self):
        peers = []
        class Handler(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def log_message(self, *_):
                pass
            def do_GET(self):
                peers.append(self.client_address)
                self.send_response(503 if len(peers) == 2 else 200)
                self.send_header('Content-Length', '2')
                if len(peers) == 3:
                    self.send_header('Connection', 'close')
                    self.close_connection = True
                self.end_headers()
                self.wfile.write(b'{}')
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        server.daemon_threads = True
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        probe = Probe(f'http://127.0.0.1:{server.server_port}', native=True)
        client = HTTPConnection('127.0.0.1', probe.server.server_port, timeout=3)
        try:
            for index in range(4):
                client.request('GET', '/health')
                response = client.getresponse()
                self.assertEqual(response.read(), b'{}')
                self.assertEqual(response.will_close, index == 2)
            self.assertTrue(probe.wait_completed(4, timeout=3))
            self.assertEqual(peers[0], peers[1])
            self.assertEqual(peers[1], peers[2])
            self.assertNotEqual(peers[2], peers[3])
            self.assertEqual(probe.snapshot()['attempts'], 4)
            self.assertEqual(probe.trace()['failed_completed'], 1)
            self.assertEqual(probe.trace()['failed_retained'][0]['status'], 503)
        finally:
            client.close()
            probe.close()
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)


if __name__ == '__main__':
    unittest.main()
