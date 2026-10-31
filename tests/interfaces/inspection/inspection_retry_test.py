"""Original-request recovery across a temporary native listener withdrawal."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import urllib.error

from interfaces.inspection import inspection


class Retry(unittest.TestCase):
    def test_wrapped_disconnects_preserve_the_signed_request(self):
        signed = {"request": {"sequence": 9}, "signature": "original"}
        outcome = {"position": 9}
        for failure in (ConnectionRefusedError(), ConnectionResetError(), TimeoutError()):
            with self.subTest(failure=type(failure).__name__):
                post = Mock(side_effect=[urllib.error.URLError(failure), (200, outcome)])
                with patch.object(inspection.time, "sleep"), patch.object(inspection.time, "monotonic", return_value=0):
                    self.assertIs(inspection.available_post(post, "/v1/command", signed), outcome)
                self.assertEqual(post.call_count, 2)
                for call in post.call_args_list:
                    self.assertIs(call.args[1], signed)
                    self.assertEqual(call.args[0], "/v1/command")

    def test_wrapped_disconnect_cannot_extend_the_deadline(self):
        failure = urllib.error.URLError(ConnectionRefusedError())
        post = Mock(side_effect=failure)
        with patch.object(inspection.time, "sleep") as sleep, patch.object(inspection.time, "monotonic", side_effect=[0, 10]):
            with self.assertRaises(urllib.error.URLError) as raised:
                inspection.available_post(post, "/v1/command", {})
        self.assertIs(raised.exception, failure)
        post.assert_called_once()
        sleep.assert_not_called()

    def test_url_configuration_and_denial_are_not_retried(self):
        failure = urllib.error.URLError("unsupported URL scheme")
        post = Mock(side_effect=failure)
        with self.assertRaises(urllib.error.URLError):
            inspection.available_post(post, "/v1/command", {})
        post.assert_called_once()
        denied = Mock(return_value=(403, {"err": "Forbidden"}))
        with self.assertRaises(AssertionError):
            inspection.available_post(denied, "/v1/command", {})
        denied.assert_called_once()

    def test_uncertain_request_is_retained_until_original_completion(self):
        with tempfile.TemporaryDirectory() as temporary:
            system = object.__new__(inspection.System)
            system.root = Path(temporary)
            system.post = Mock()
            signed = {"request": {"sequence": 9}, "signature": "original"}
            with patch.object(inspection, "available_post", side_effect=TimeoutError()):
                with self.assertRaises(TimeoutError):
                    system.available_post("/v1/command", signed)
                pending, = (system.root / "pending-native-commands").glob("*.json")
                # Another unresolved identity cannot overwrite the first one.
                with self.assertRaises(TimeoutError):
                    system.available_post("/v1/command", {"request": {"sequence": 10}, "signature": "second"})
            self.assertEqual(len(list(pending.parent.glob("*.json"))), 2)
            self.assertEqual(json.loads(pending.read_text()), signed)
            with patch.object(inspection, "available_post", return_value={"position": 9}):
                self.assertEqual(system.available_post("/v1/command", signed), {"position": 9})
            self.assertFalse(pending.exists())
            self.assertEqual(len(list(pending.parent.glob("*.json"))), 1)

    def test_failed_installations_are_kept_private(self):
        with patch.object(inspection, "Fixture") as fixture:
            inspection.System("node", "admin")
        fixture.assert_called_once_with(None, retain_on_failure=True)


if __name__ == "__main__":
    unittest.main()
