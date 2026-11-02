"""Original-request recovery across a temporary native listener withdrawal."""
import json
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import urllib.error

from interfaces.inspection import inspection
from interfaces.installation import server_board


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

    @staticmethod
    def board_response(status, cause=None):
        data = {} if status == 200 else dict(err='Unavailable', diagnostic=dict(
            cause='AuthorityUnavailable', facts=[dict(field='native_cause', value=dict(text=cause))]))
        response = io.BytesIO(json.dumps(data).encode())
        response.status = status
        return response

    def test_board_capacity_retries_only_the_original_read(self):
        for cause in ('HttpCapacity', 'ControlCapacity'):
            with self.subTest(cause=cause):
                board = object.__new__(server_board.Board)
                board.board_url = 'http://localhost:1'
                board.http = Mock()
                board.http.open.side_effect = [self.board_response(503, cause), self.board_response(200)]
                with patch.object(server_board.time, 'sleep'), patch.object(server_board.time, 'monotonic', return_value=0):
                    self.assertEqual(board.request('/api/v1/storage'), b'{}')
                self.assertEqual(board.http.open.call_count, 2)
                for call in board.http.open.call_args_list:
                    self.assertEqual(call.args[0].full_url, 'http://localhost:1/api/v1/storage')
                    self.assertEqual(call.args[0].method, 'GET')
                    self.assertIsNone(call.args[0].data)

    def test_board_capacity_does_not_retry_sql_or_other_refusals(self):
        for method, status, cause in [('POST', 503, 'ControlCapacity'), ('GET', 503, 'AccessDenied'), ('GET', 403, 'ControlCapacity')]:
            with self.subTest(method=method, status=status, cause=cause):
                board = object.__new__(server_board.Board)
                board.board_url = 'http://localhost:1'
                board.http = Mock()
                board.http.open.return_value = self.board_response(status, cause)
                with self.assertRaises(AssertionError):
                    board.request('/api/v1/sql-read', method=method, body=b'{}' if method == 'POST' else None)
                board.http.open.assert_called_once()

    def test_board_capacity_keeps_the_existing_read_deadline(self):
        board = object.__new__(server_board.Board)
        board.board_url = 'http://localhost:1'
        board.http = Mock()
        board.http.open.return_value = self.board_response(503, 'ControlCapacity')
        with patch.object(server_board.time, 'sleep') as sleep, patch.object(server_board.time, 'monotonic', side_effect=[0, 10]):
            with self.assertRaises(AssertionError):
                board.request('/api/v1/storage')
        board.http.open.assert_called_once()
        sleep.assert_not_called()


if __name__ == "__main__":
    unittest.main()
