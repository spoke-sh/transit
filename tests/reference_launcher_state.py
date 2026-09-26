"""Reference startup refuses lost/replaced history before infrastructure mutation."""
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "launchers"))
from kubernetes import Reference, infrastructure
from station_reference import StationReference


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
        self.state = {"cluster": "rey-m1-original", "registry": "rey-m1-original-registry", "node_ids": ["node-id"], "registry_id": "registry-id"}
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
        self.state_file.write_text(json.dumps({**self.state, "cluster": "rey-m1-replacement"}))
        for cls in (Reference, StationReference):
            with self.subTest(example=cls.__name__):
                with self.assertRaisesRegex(RuntimeError, "rey-m1-original.*rey-m1-replacement"):
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
        self.state_file.write_text(json.dumps({**self.state, "cluster": "rey-m1-replacement"}))
        self.run.side_effect = None
        self.run.return_value = ""
        Reference(self.installation).reset_missing_cluster()
        self.assertFalse(self.path.exists())
        self.assertFalse(self.selection.exists())
        self.assertEqual(json.loads(self.state_file.read_text())["cluster"], "rey-m1-replacement")
        self.assertIn("label=io.x-k8s.kind.cluster=rey-m1-original", self.run.call_args.args[0])
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


if __name__ == "__main__":
    unittest.main()
