"""Reference startup refuses lost/replaced history before infrastructure mutation."""
from runner.paths import ROOT
import json
from pathlib import Path
import sys
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(ROOT / "launchers"))
from kubernetes import Reference, infrastructure
from station_reference import StationReference
from common import Installation, transient_read_failure


class ReferenceStateTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.path = root / "installation"
        self.path.mkdir()
        self.state_file = root / "infrastructure.json"
        self.identity = self.path / "reference.json"
        self.artifacts = root / "artifacts"
        self.artifacts.mkdir()
        self.selection = self.artifacts / "selected.json"
        self.selection.write_text('{"old-build":true}')
        self.installation = SimpleNamespace(path=self.path, name="saved", artifacts=SimpleNamespace(path=self.artifacts), load=lambda: {"project": "project-123456"})
        self.state = {"cluster": "transit-m1-original", "registry": "transit-m1-original-registry", "node_ids": ["node-id"], "registry_id": "registry-id"}
        self.saved = {"namespace": "transit-saved-123456", "uid": "namespace-id", "cluster": self.state["cluster"]}
        self.namespace = {"metadata": {"name": self.saved["namespace"], "uid": self.saved["uid"], "labels": {"transit.dev/installation": "project-123456"}}}
        self.enterContext(patch.object(infrastructure, "STATE", self.state_file))
        self.up = self.enterContext(patch.object(infrastructure, "up"))
        self.run = self.enterContext(patch.object(infrastructure, "run", side_effect=self.command))
        self.kube = self.enterContext(patch.object(infrastructure, "kube", return_value=json.dumps(self.namespace)))

    def command(self, argv, **kwargs):
        if argv[:2] == ["docker", "ps"]:
            return "node-id"
        if argv[:2] == ["docker", "inspect"]:
            return "registry-id"
        raise AssertionError(argv)

    def save(self):
        self.identity.write_text(json.dumps(self.saved))
        self.state_file.write_text(json.dumps(self.state))

    def test_missing_infrastructure_never_bootstraps_either_example(self):
        self.identity.write_text(json.dumps(self.saved))
        original = self.identity.read_bytes()
        for cls in (Reference, StationReference):
            with self.subTest(example=cls.__name__):
                with self.assertRaisesRegex(RuntimeError, "infrastructure is missing.*--name NEW_NAME"):
                    cls(self.installation).up()
        self.up.assert_not_called()
        self.run.assert_not_called()
        self.kube.assert_not_called()
        self.assertEqual(self.identity.read_bytes(), original)

    def test_replacement_cluster_rejected_before_contact_for_either_example(self):
        self.save()
        original = self.identity.read_bytes()
        self.state_file.write_text(json.dumps({**self.state, "cluster": "transit-m1-replacement"}))
        for cls in (Reference, StationReference):
            with self.subTest(example=cls.__name__):
                with self.assertRaisesRegex(RuntimeError, "transit-m1-original.*transit-m1-replacement"):
                    cls(self.installation).up()
        self.up.assert_not_called()
        self.run.assert_not_called()
        self.kube.assert_not_called()
        self.assertEqual(self.identity.read_bytes(), original)

    def test_missing_namespace_does_not_create_or_forget_history(self):
        self.save()
        original = self.identity.read_bytes()
        self.kube.return_value = ""
        with self.assertRaisesRegex(RuntimeError, "namespace.*disappeared.*--name NEW_NAME"):
            Reference(self.installation).prepare_infrastructure()
        self.assertEqual(self.kube.call_count, 1)
        self.assertEqual(self.kube.call_args.args[1][2:4], ["get", "namespace"])
        self.assertEqual(self.identity.read_bytes(), original)

    def test_replaced_namespace_does_not_adopt_uid(self):
        self.save()
        original = self.identity.read_bytes()
        self.namespace["metadata"]["uid"] = "replacement"
        self.kube.return_value = json.dumps(self.namespace)
        with self.assertRaisesRegex(RuntimeError, "incarnation changed"):
            Reference(self.installation).prepare_infrastructure()
        self.assertEqual(self.identity.read_bytes(), original)

    def test_original_namespace_can_be_recovered(self):
        self.save()
        self.assertEqual(Reference(self.installation).ownership(), self.saved)
        self.up.assert_not_called()

    def test_new_installation_can_create_namespace_in_existing_cluster(self):
        self.state_file.write_text(json.dumps(self.state))
        self.kube.side_effect = ["", json.dumps(self.namespace)]
        Reference(self.installation).prepare_infrastructure()
        self.up.assert_not_called()
        self.assertEqual(json.loads(self.identity.read_text()), self.saved)
        self.assertEqual(self.kube.call_args.args[1][2:4], ["create", "-f"])

    def test_first_installation_can_bootstrap_infrastructure(self):
        self.up.side_effect = lambda: self.state_file.write_text(json.dumps(self.state))
        self.kube.side_effect = ["", json.dumps(self.namespace)]
        Reference(self.installation).prepare_infrastructure()
        self.up.assert_called_once_with()
        self.assertEqual(json.loads(self.identity.read_text()), self.saved)

    def test_retry_after_namespace_creation_keeps_the_same_identity(self):
        self.state_file.write_text(json.dumps(self.state))
        # The cluster accepted create, but the launcher lost its response before
        # recording the namespace UID. Matching installation labels recover it.
        Reference(self.installation).prepare_infrastructure()
        self.assertEqual(json.loads(self.identity.read_text()), self.saved)
        self.assertEqual(self.kube.call_count, 1)
        self.assertEqual(self.kube.call_args.args[1][2:4], ["get", "namespace"])

    def test_reused_container_name_does_not_adopt_new_cluster(self):
        self.save()
        self.run.side_effect = None
        self.run.return_value = "different-node-id"
        with self.assertRaisesRegex(RuntimeError, "cluster identity changed"):
            Reference(self.installation).prepare_infrastructure()
        self.kube.assert_not_called()

    def test_explicit_discard_checks_original_cluster_not_replacement(self):
        self.save()
        self.state_file.write_text(json.dumps({**self.state, "cluster": "transit-m1-replacement"}))
        self.run.side_effect = None
        self.run.return_value = ""
        Reference(self.installation).reset_missing_cluster()
        self.assertFalse(self.path.exists())
        self.assertFalse(self.selection.exists())
        self.assertEqual(json.loads(self.state_file.read_text())["cluster"], "transit-m1-replacement")
        self.assertIn("label=io.x-k8s.kind.cluster=transit-m1-original", self.run.call_args.args[0])
        self.kube.assert_not_called()
        self.up.assert_not_called()

    def test_explicit_discard_refuses_existing_cluster(self):
        self.save()
        with self.assertRaisesRegex(RuntimeError, "cluster still exists"):
            Reference(self.installation).reset_missing_cluster()
        self.assertTrue(self.identity.exists())
        self.assertTrue(self.selection.exists())

    def test_docker_failure_is_not_missing_cluster(self):
        self.save()
        self.run.side_effect = OSError("Docker unavailable")
        with self.assertRaisesRegex(OSError, "Docker unavailable"):
            Reference(self.installation).reset_missing_cluster()
        self.assertTrue(self.identity.exists())

    def test_discard_refuses_forwarding_manager(self):
        self.save()
        (self.path / "pc.sock").touch()
        with self.assertRaisesRegex(RuntimeError, "forwarding manager"):
            Reference(self.installation).reset_missing_cluster()
        self.run.assert_not_called()
        self.assertTrue(self.identity.exists())


class ReadObservationTest(unittest.TestCase):
    @staticmethod
    def failure(cause="AuthorityUnavailable"):
        return {"schema_version": 1, "service_name": "transit-admin", "event": {
            "name": "service.failed", "level": "err", "outcome": "failed", "error_type": cause}}

    def test_read_retry_uses_json_and_preserves_the_same_request(self):
        with tempfile.TemporaryDirectory() as directory:
            installation = SimpleNamespace(path=Path(directory), cli="transit-admin", url="http://127.0.0.1:1", load=lambda: {"realm": 73})
            kind = {"open_snapshot": {"resource": 9, "nonce": [7] * 16}}
            requests = []
            def invoke(argv, **options):
                self.assertEqual(options["env"]["LOG_FORMAT"], "json")
                self.assertEqual(options["env"]["LOG_LEVEL"], "error")
                requests.append((argv, (installation.path / "operator/read.json").read_bytes()))
                if len(requests) == 1:
                    return subprocess.CompletedProcess(argv, 1, "", json.dumps(self.failure()))
                return subprocess.CompletedProcess(argv, 0, '{"body":{"accepted":true}}', "")
            with patch("common.subprocess.run", side_effect=invoke), patch("common.time.sleep"):
                self.assertEqual(Installation.native_query(installation, kind), {"body": {"accepted": True}})
            self.assertEqual(len(requests), 2)
            self.assertEqual(requests[0], requests[1])
            self.assertEqual(json.loads(requests[0][1])["kind"], kind)

    def test_unknown_denied_malformed_and_nonterminal_events_do_not_authorize_retry(self):
        denied = self.failure("AccessDenied")
        unknown = self.failure("UnexpectedFailure")
        attempt = self.failure()
        attempt["event"]["name"] = "transit.client.request"
        foreign = self.failure()
        foreign["service_name"] = "transit-node"
        for record in (denied, unknown, attempt, foreign, [], None):
            self.assertFalse(transient_read_failure(json.dumps(record)))
        self.assertFalse(transient_read_failure("error: AuthorityUnavailable"))
        self.assertFalse(transient_read_failure(json.dumps(self.failure()) + "\nnot-json"))
        for cause in ("AuthorityUnavailable", "AuthorityTimeout", "HttpConnectionClosing"):
            self.assertTrue(transient_read_failure(json.dumps(self.failure(cause))))


if __name__ == "__main__":
    unittest.main()
