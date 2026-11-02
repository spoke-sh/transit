"""Bounded recovery of the workbench fixture's exact retained-history identity."""
import copy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from interfaces.installation import board_workbench as workbench


class HistoryRecovery(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.fixture = SimpleNamespace(root=Path(temporary.name), config={'ports': {'node': 1}})
        self.definition = 'ab' * 32
        self.connection = dict(scope=dict(realm=1, resource=2, catalog=3),
                               principal=4, branch=5, audience=[6] * 32, role=None)
        self.token = dict(definition=self.definition, connection=self.connection,
                          account=[91] * 32, token=list((900031).to_bytes(16, 'little')))
        self.selection = dict(owner=dict(scope=self.connection['scope'], principal=4, operation=900031),
                              branch=5, directory=dict(bytes=17, sha256=[7] * 32))
        self.intent = dict(connection=self.connection, namespace=1, operation=900031,
                           selection=self.selection['directory'], common=None)
        self.budget = dict(limits=dict(operations=1000000, bytes=4294967296, pending=1024), bytes=4608)
        self.acquisition = dict(acquire=dict(key=self.token, intent=self.intent, budget=self.budget))
        self.actions = []
        self.responses = []
        identity = dict(body=dict(authorization=dict(body=dict(identity=dict(credential_epoch=1)))))
        for name, value in (
            ('ExistingKey', Mock(return_value=Mock(sign=Mock(return_value=[0] * 64)))),
            ('native', Mock(return_value={})),
            ('post', Mock(return_value=identity)),
            ('exchange', Mock(side_effect=self.exchange)),
        ):
            replacement = patch.object(workbench, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)

    def exchange(self, port, route, request, headers):
        self.assertEqual((port, route), (1, '/table/v1'))
        action = request['action']['historical_catalog']
        self.actions.append(copy.deepcopy(action))
        if 'select' in action:
            return 200, json.dumps(dict(result=dict(historical_catalog=dict(selection=self.selection)))).encode()
        # The saved identity must exist before any acquisition dispatch.
        self.assertEqual(json.loads((self.fixture.root / 'history-intent-900031.json').read_text()),
                         dict(key=self.token, intent=self.intent))
        status, body = self.responses.pop(0)
        return status, json.dumps(body).encode()

    def status(self, phase):
        state = dict(phase=phase, inflight=None, after=None, descriptor_after=None,
                     snapshot=dict(catalog_root=dict(bytes=18, sha256=[8] * 32),
                                   sources_root=dict(bytes=19, sha256=[9] * 32),
                                   consistency=dict(single_partition=dict(partition=10, next_lsn=11))))
        return dict(receipt=dict(binding=dict(key=self.token, intent=dict(history=self.intent), budget=self.budget)),
                    state=state)

    @staticmethod
    def observed(status):
        return 200, dict(result=dict(historical_catalog=dict(status=status)))

    def retain(self):
        return workbench.retained_metrics(self.fixture, self.definition, self.connection, 'unused', operation=900031)

    def test_capacity_before_and_after_acceptance_preserves_identity_and_release(self):
        capacity = (503, {'err': 'ControlCapacity'})
        self.responses = [capacity, self.observed(None), self.observed(self.status('acquiring')),
                          capacity, self.observed(self.status('published')),
                          capacity, self.observed(self.status('released'))]
        with patch.object(workbench.time, 'sleep') as sleep:
            selector, release = self.retain()
            self.assertTrue(selector.startswith(b'THSNAP01'.hex()))
            release()
        self.assertEqual(sum('select' in action for action in self.actions), 1)
        self.assertEqual(self.actions[1:], [self.acquisition, dict(inspect=self.token), self.acquisition,
                         dict(advance=self.token), dict(inspect=self.token),
                         dict(release=self.token), dict(inspect=self.token)])
        self.assertEqual(sleep.call_count, 3)
        self.assertFalse(self.responses)

    def test_persistent_capacity_exhausts_the_existing_schedule(self):
        self.responses = [(503, {'err': 'ControlCapacity'})] * 32
        with patch.object(workbench.time, 'sleep'), self.assertRaisesRegex(AssertionError, 'bounded schedule'):
            self.retain()
        self.assertEqual(self.actions[1:], [self.acquisition] + [dict(inspect=self.token)] * 31)
        self.assertFalse(self.responses)

    def test_denials_and_other_failures_are_not_retried(self):
        for failure in [(403, {'err': 'AccessDenied'}), (503, {'err': 'AuthorityUnavailable'}),
                        (403, {'err': 'ControlCapacity'}), (503, {'err': 'ControlCapacity', 'extra': True})]:
            with self.subTest(failure=failure):
                self.actions.clear()
                self.responses = [failure]
                with self.assertRaises(AssertionError):
                    self.retain()
                self.assertEqual(self.actions[1:], [self.acquisition])

    def test_recovery_cannot_adopt_another_intent_or_budget(self):
        for field in ('key', 'intent', 'budget'):
            with self.subTest(field=field):
                self.actions.clear()
                status = copy.deepcopy(self.status('published'))
                status['receipt']['binding'][field] = {}
                self.responses = [(503, {'err': 'ControlCapacity'}), self.observed(status)]
                with patch.object(workbench.time, 'sleep'), self.assertRaisesRegex(AssertionError, 'changed the saved'):
                    self.retain()
                self.assertEqual(self.actions[1:], [self.acquisition, dict(inspect=self.token)])


if __name__ == '__main__':
    unittest.main()
