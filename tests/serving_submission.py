"""The fixture preserves exact commands and explicit failures under backpressure."""
from contextlib import ExitStack
import unittest
from unittest.mock import patch

import serving


class Submission(unittest.TestCase):
    value = {'request': {'principal': 34, 'sequence': 77, 'command': {'send': {'pid': 9, 'value': '00ff'}}}, 'signature': [19] * 64}
    capacity = (503, {'err': 'HttpCapacity'})
    accepted = (200, {'position': 91})

    def invoke(self, replies, *, path='/v1/command', status=200, clocks=(0, 1, 2), fails=False):
        requests, closed = [], []
        replies, clocks = iter(replies), iter(clocks)

        class Connection:
            def __init__(self, *_args, **_kwargs):
                pass

            def request(self, method, target, body, headers):
                requests.append((method, target, body, dict(headers)))

            def getresponse(self):
                self.status, self.body = next(replies)
                return self

            def read(self):
                return serving.compact(self.body)

            def close(self):
                closed.append(True)

        with ExitStack() as stack:
            stack.enter_context(patch.object(serving, 'HTTPConnection', Connection))
            stack.enter_context(patch.object(serving.time, 'monotonic', lambda: next(clocks)))
            stack.enter_context(patch.object(serving.time, 'sleep'))
            if fails:
                with self.assertRaises(AssertionError):
                    serving.post(12345, path, self.value, status=status)
                result = None
            else:
                result = serving.post(12345, path, self.value, status=status)
        self.assertEqual(len(closed), len(requests))
        self.assertTrue(requests)
        self.assertTrue(all(request == requests[0] for request in requests))
        self.assertEqual(requests[0][2], serving.compact(self.value))
        return result, len(requests)

    def test_exact_native_command_after_capacity(self):
        result, attempts = self.invoke([self.capacity, self.capacity, self.accepted])
        self.assertEqual((result, attempts), ({'position': 91}, 3))

    def test_existing_deadline_remains_finite(self):
        _, attempts = self.invoke([self.capacity, self.capacity], clocks=(0, 1, 11), fails=True)
        self.assertEqual(attempts, 2)

    def test_explicit_capacity_assertions_are_not_retried(self):
        self.assertEqual(self.invoke([self.capacity], status=None), (self.capacity, 1))
        self.assertEqual(self.invoke([self.capacity], status=503), (self.capacity[1], 1))

    def test_other_rejections_and_routes_are_not_retried(self):
        for rejection in [(403, {'err': 'AccessDenied'}), (409, {'err': 'Conflict'}),
                          (503, {'err': 'AuthorityUnavailable'})]:
            with self.subTest(rejection=rejection):
                self.assertEqual(self.invoke([rejection], fails=True)[1], 1)
        self.assertEqual(self.invoke([self.capacity], path='/v1/query', fails=True)[1], 1)

    def test_existing_serving_capacity_retry(self):
        rejection = (503, {'diagnostic': {'facts': [{'field': 'native_cause', 'value': {'text': 'HttpCapacity'}}]}})
        self.assertEqual(self.invoke([rejection, (202, {'position': 91})], path='/serving/v1/command', status=202),
                         ({'position': 91}, 2))


if __name__ == '__main__':
    unittest.main()
