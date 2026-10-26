"""Exercise service readiness independently of any Transit storage provider."""
import contextlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from harness.services import free_port, wait_ready


class Services(unittest.TestCase):
    @contextlib.contextmanager
    def server(self):
        with tempfile.TemporaryDirectory(prefix="transit-readiness-") as directory:
            root = Path(directory)
            script = root / "server.py"
            script.write_text('''from http.server import BaseHTTPRequestHandler, HTTPServer
import sys
class Handler(BaseHTTPRequestHandler):
    attempts = 0
    def log_message(self, *_): pass
    def do_GET(self):
        Handler.attempts += 1
        self.send_response(200 if self.path == '/ready' and Handler.attempts > 1 else 503)
        self.end_headers()
        self.wfile.write(str(Handler.attempts).encode())
HTTPServer(('127.0.0.1', int(sys.argv[1])), Handler).serve_forever()
''')
            port = free_port()
            process = subprocess.Popen([sys.executable, "-B", str(script), str(port)],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            try:
                yield http, process, f"http://127.0.0.1:{port}"
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=10)

    def test_retries_until_http_200(self):
        with self.server() as (http, process, url):
            wait_ready(http, process, url + "/ready")
            self.assertIsNone(process.poll())
            with http.open(url + "/ready", timeout=1) as response:
                self.assertGreaterEqual(int(response.read()), 3)

    def test_exited_child_cannot_be_ready(self):
        with self.server() as (http, process, url):
            process.kill()
            process.wait(timeout=10)
            with self.assertRaisesRegex(RuntimeError, "exited before readiness"):
                wait_ready(http, process, url + "/ready")

    def test_unready_live_child_reaches_deadline(self):
        with self.server() as (http, process, url):
            wait_ready(http, process, url + "/ready")
            # Exercise the unchanged finite deadline without spending 30 seconds
            # per control. The HTTP 503 and live child are real observations.
            with patch("harness.services.time.monotonic", side_effect=[0, 31]):
                with self.assertRaisesRegex(TimeoutError, "readiness deadline"):
                    wait_ready(http, process, url + "/unready")
            self.assertIsNone(process.poll())


if __name__ == "__main__":
    unittest.main()
