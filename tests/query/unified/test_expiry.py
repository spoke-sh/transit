"""A failed transport read must never qualify an expiry denial."""
import unittest
from unittest.mock import Mock

from query.unified.unified_abi import Failure
from query.unified.unified_expiry import assert_expired_read


class ExpiryEvidence(unittest.TestCase):
    def test_stale_connection_retries_the_original_cursor_before_denial(self):
        operation = {'page': {'namespace': '1', 'cursor': 'original-cursor'}}
        client = Mock()
        client.call.side_effect = [Failure(7, {'err': 'HttpConnectionClosing'}),
                                   Failure(4, {'err': 'AccessDenied'})]
        assert_expired_read(client, operation)
        self.assertEqual(client.call.call_count, 2)
        self.assertTrue(all(call.args == (operation,) for call in client.call.call_args_list))

    def test_transport_failure_is_not_denial(self):
        client = Mock()
        client.call.side_effect = Failure(7, {'err': 'HttpConnectionClosing'})
        with self.assertRaises(AssertionError):
            assert_expired_read(client, {'status': '1'})
        self.assertEqual(client.call.call_count, 2)

    def test_disclosed_results_and_other_errors_fail_without_retry(self):
        for outcome in ({'page': {'rows': 1}}, Failure(7, {'err': 'CorruptManifest'})):
            client = Mock()
            if isinstance(outcome, Failure):
                client.call.side_effect = outcome
            else:
                client.call.return_value = outcome
            with self.assertRaises(AssertionError):
                assert_expired_read(client, {'page': {'namespace': '1'}})
            client.call.assert_called_once()

    def test_mutations_cannot_use_the_read_retry(self):
        client = Mock()
        with self.assertRaises(AssertionError):
            assert_expired_read(client, {'submit': 'saved-command'})
        client.call.assert_not_called()


if __name__ == '__main__':
    unittest.main()
