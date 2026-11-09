"""Fault selection and joined HTTP handler cleanup preserve real proof failures."""
import base64
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler
import json
import subprocess
import sys
import threading
import unittest

from storage.tables.direct_table_service import ApplicationFaults, FaultProxy


class ApplicationFaultSelection(unittest.TestCase):
    def test_physical_admission_loses_only_the_retained_original_reply(self):
        faults = ApplicationFaults()
        key = {"token": [9] * 16}
        effect = {"descriptor": {"program": {"object": {"object": 748020}},
                                 "input": {"operation": {"operation": 748103}}},
                  "phase": "dispatching"}
        def encode(value):
            return {"base64": base64.b64encode(json.dumps(value).encode()).decode()}
        staged = {"binding": {"key": key}, "format": 0xC1454631,
                  "bytes": encode({"payload": encode(effect)})}
        def reply(phase):
            return json.dumps({"result": {"client_progress": {"state": {
                "original": {"phase": phase}}}}}).encode()
        self.assertIsNone(faults.select({"action": {"client_progress": {
            "stage_original": staged}}}, reply("ready")))
        self.assertFalse(faults.passed)
        other = {"action": {"client_progress": {"retain_original": {
            "key": {"token": [10] * 16}}}}}
        self.assertIsNone(faults.select(other, reply("retained")))
        retained = {"action": {"client_progress": {"retain_original": {"key": key}}}}
        with self.assertRaises(AssertionError):
            faults.select(retained, reply("ready"))
        self.assertFalse(faults.passed)
        self.assertEqual(faults.select(retained, reply("retained")), "physical_effect_admission")
        self.assertIsNone(faults.select(retained, reply("retained")))
        self.assertEqual(faults.passed, {"physical_effect_admission"})

    def test_unexpected_physical_refusal_reaches_the_original_caller(self):
        effect = {"descriptor": {"program": {"object": {"object": 748020}},
                                 "input": {"operation": {"operation": 748100}}},
                  "phase": "finished", "outcome": {"not_dispatched": "budget"}}
        def encode(value):
            return {"base64": base64.b64encode(json.dumps(value).encode()).decode()}
        envelope = {"action": {"client_progress": {"advance": {
            "format": 0xC1454631, "bytes": encode({"payload": encode(effect)})}}}}
        response = json.dumps({"result": {"client_progress": {"state": {"pending": False}}}}).encode()
        faults = ApplicationFaults()
        self.assertIsNone(faults.select(envelope, response))
        self.assertFalse(faults.passed)

    def test_original_stage_and_progress_bind_the_same_attachment_once(self):
        key = {"token": [7] * 16}
        payload = {
            "lease": {"target": {"object": {"object": 733020}}, "epoch": 1},
            "claim": {"operation": {"operation": 13}},
            "execution": {"phase": "evaluate", "transaction": None},
        }
        encoded = {"base64": base64.b64encode(json.dumps(payload).encode()).decode()}
        for action, identity in (("stage_original", {"binding": {"key": key}}),
                                 ("advance", {"key": key})):
            with self.subTest(action=action):
                faults = ApplicationFaults()
                work = dict(identity, format=0x41505731, bytes=encoded)
                self.assertIsNone(faults.select({"action": {"client_progress": {action: work}}}, b"{}"))
                response = json.dumps({"result": {"client_progress": {"state": {"original": {"phase": "attached"}}}}}).encode()
                other = {"action": {"client_progress": {"attach_original": {"key": {"token": [8] * 16}}}}}
                self.assertIsNone(faults.select(other, response))
                request = {"action": {"client_progress": {"attach_original": {"key": key}}}}
                self.assertEqual(faults.select(request, response), "attachment")
                self.assertIsNone(faults.select(request, response))
                self.assertEqual(faults.passed, {"attachment"})


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
