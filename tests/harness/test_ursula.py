"""Provider listener ownership, with a deterministic ephemeral-port collision."""
import contextlib
import io
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from harness.ursula import Fixture


class Listeners(unittest.TestCase):
    @contextlib.contextmanager
    def provider(self):
        # Follow the pinned provider's admin-first bind order. If admin requests
        # port zero, force the legal kernel choice that collides with public.
        # This control owns real child processes/listeners, not a storage engine.
        with tempfile.TemporaryDirectory(prefix="transit-listener-control-") as temporary:
            script = Path(temporary) / "provider.py"
            script.write_text('''from http.server import BaseHTTPRequestHandler, HTTPServer
import socket, sys, tomllib
with open(sys.argv[1], 'rb') as source: config = tomllib.load(source)['server']
host, public = config['listen'].rsplit(':', 1)
admin_host, admin_port = config['admin_listen'].rsplit(':', 1)
admin = socket.socket()
admin.bind((admin_host, int(admin_port) or int(public)))
admin.listen()
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        self.send_response(200 if self.path == '/__ursula/ready' else 404)
        self.end_headers()
HTTPServer((host, int(public)), Handler).serve_forever()
''')
            popen = subprocess.Popen

            def launch(arguments, *args, **kwargs):
                if arguments[0] == "ursula":
                    arguments = [sys.executable, "-B", script, arguments[-1]]
                return popen(arguments, *args, **kwargs)

            with patch("harness.ursula.subprocess.Popen", side_effect=launch):
                yield

    def test_ephemeral_admin_can_take_the_public_listener(self):
        with self.provider(), contextlib.redirect_stderr(io.StringIO()) as errors:
            fixture = Fixture()
            config = tomllib.loads(fixture.config.read_text())
            fixture.config.write_text(fixture.config.read_text().replace(
                f'admin_listen = "{config["server"]["admin_listen"]}"',
                'admin_listen = "127.0.0.1:0"'))
            with self.assertRaisesRegex(RuntimeError, "exited before readiness"):
                fixture.__enter__()
            self.assertIsNone(fixture.server)
            self.assertIn("Address already in use", errors.getvalue())

    def test_distinct_fixed_listeners_keep_their_identity_across_restart(self):
        with self.provider(), Fixture() as fixture:
            original = fixture.config.read_bytes()
            config = tomllib.loads(original.decode())["server"]
            self.assertNotEqual(config["listen"], config["admin_listen"])
            self.assertFalse(config["admin_listen"].endswith(":0"))
            first = fixture.server
            fixture.stop()
            self.assertIsNotNone(first.poll())
            fixture.start()
            self.assertNotEqual(fixture.server.pid, first.pid)
            self.assertEqual(fixture.config.read_bytes(), original)
            self.assertIsNone(fixture.server.poll())
        self.assertIsNone(fixture.server)

    def test_another_owner_is_not_retried_or_replaced(self):
        with self.provider(), contextlib.redirect_stderr(io.StringIO()):
            fixture = Fixture()
            port = fixture.port
            with socket.socket() as occupied:
                occupied.bind(("127.0.0.1", port))
                occupied.listen()
                with self.assertRaisesRegex(RuntimeError, "exited before readiness"):
                    fixture.__enter__()
                self.assertEqual(fixture.port, port)
                self.assertIsNone(fixture.server)
                self.assertGreaterEqual(occupied.fileno(), 0)

    def test_recovery_retention_preserves_original_paths_after_joining(self):
        for failed in (False, True):
            with self.subTest(failed=failed), self.provider(), contextlib.redirect_stderr(io.StringIO()) as errors:
                fixture = Fixture(retain_on_failure=True)
                original = fixture.config.read_bytes()
                try:
                    outcome = self.assertRaisesRegex(RuntimeError, "accepted outcome needs investigation") if failed else contextlib.nullcontext()
                    with outcome:
                        with fixture:
                            process = fixture.server
                            if failed:
                                raise RuntimeError("accepted outcome needs investigation")
                    self.assertIsNotNone(process.poll())
                    self.assertIsNone(fixture.server)
                    self.assertEqual(fixture.root.exists(), failed)
                    if failed:
                        self.assertEqual(fixture.config.read_bytes(), original)
                        self.assertEqual(fixture.root.parent, Path("/var/tmp"))
                        self.assertIn(str(fixture.root), errors.getvalue())
                finally:
                    fixture.directory.cleanup()


if __name__ == "__main__":
    unittest.main()
