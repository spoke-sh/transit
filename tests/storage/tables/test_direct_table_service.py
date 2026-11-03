"""A failed caller must not leave HTTP fault handlers alive at fixture exit."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler
import subprocess
import sys
import threading
import unittest

from storage.tables.direct_table_service import FaultProxy


class ProxyCleanup(unittest.TestCase):
    def test_caller_timeout_waits_for_response_and_error_handlers(self):
        for handler_error in (False, True):
            with self.subTest(handler_error=handler_error):
                entered = threading.Event()
                release = threading.Event()
                closing = threading.Event()
                closed = threading.Event()
                workers, errors, outcomes = [], [], []
                original = subprocess.TimeoutExpired("saved-workload-caller", 180)

                class Handler(BaseHTTPRequestHandler):
                    def log_message(self, *_):
                        pass

                    def do_GET(self):
                        workers.append(threading.current_thread())
                        entered.set()
                        if not release.wait(5):
                            raise AssertionError("test did not release the handler")
                        if handler_error:
                            raise BrokenPipeError("caller disconnected before its response")
                        self.send_response(204)
                        self.end_headers()

                class RecordingProxy(FaultProxy):
                    def handle_error(self, *_):
                        # Real handlers report errors from their worker thread;
                        # that reporting must finish before fixture teardown.
                        errors.append(sys.exception())

                server = RecordingProxy(("127.0.0.1", 0), Handler)
                serving = threading.Thread(target=server.serve_forever)
                serving.start()
                client = HTTPConnection("127.0.0.1", server.server_port, timeout=5)

                def fail_caller():
                    try:
                        try:
                            raise original
                        finally:
                            server.shutdown()
                            closing.set()
                            server.server_close()
                            serving.join(timeout=5)
                    except BaseException as error:
                        outcomes.append(error)
                    finally:
                        closed.set()

                cleanup = threading.Thread(target=fail_caller)
                try:
                    client.request("GET", "/")
                    self.assertTrue(entered.wait(5))
                    if handler_error:
                        client.close()
                    cleanup.start()
                    self.assertTrue(closing.wait(5))
                    self.assertFalse(closed.wait(.05), "fixture closed with a live request")
                    release.set()
                    cleanup.join(timeout=5)
                    self.assertFalse(cleanup.is_alive())
                    self.assertFalse(serving.is_alive())
                    self.assertFalse(workers[0].is_alive())
                    self.assertEqual(outcomes, [original])
                    if handler_error:
                        self.assertEqual(len(errors), 1)
                        self.assertIsInstance(errors[0], BrokenPipeError)
                    else:
                        self.assertEqual(errors, [])
                        self.assertEqual(client.getresponse().status, 204)
                finally:
                    release.set()
                    client.close()
                    if cleanup.ident is not None:
                        cleanup.join(timeout=5)
                    server.shutdown()
                    server.server_close()
                    serving.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
