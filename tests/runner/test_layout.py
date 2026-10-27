"""Exercise layout admission against actual added, deleted and moved files."""
import json
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from layout import validate, validate_migration, verify_archives

ENTRY = Path(__file__).with_name("layout.py")


class Layout(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="transit-layout-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        for name in ("README.md", "AGENTS.md", "runner/README.md", "runner/AGENTS.md"):
            self.write(name, "Owner navigation\n")
        self.policy = dict(version=1, owners=["runner", "storage"], migration_exceptions=[])
        self.save()

    def write(self, name, text="fixture\n"):
        path = self.root / "tests" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def save(self):
        self.write("runner/layout.json", json.dumps(self.policy))

    def test_current_files_and_ignored_outputs(self):
        self.write("runner/check.py")
        (self.root / ".gitignore").write_text("tests/output.log\n")
        self.write("output.log")
        count, exceptions = validate(self.root)
        self.assertEqual((count, exceptions), (6, 0))

    def test_new_root_file_is_rejected_by_entry_point(self):
        self.write("unclaimed.py")
        result = subprocess.run([sys.executable, "-B", ENTRY, "--root", self.root], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unowned test path: tests/unclaimed.py", result.stderr)

    def test_unknown_owner(self):
        self.write("misc/cases.py")
        with self.assertRaisesRegex(AssertionError, "Unowned test path"):
            validate(self.root)

    def test_new_owner_requires_navigation_and_instructions(self):
        self.write("storage/cases.py")
        with self.assertRaisesRegex(AssertionError, "Missing owner navigation"):
            validate(self.root)
        self.write("storage/README.md")
        with self.assertRaisesRegex(AssertionError, "storage/AGENTS.md"):
            validate(self.root)
        self.write("storage/AGENTS.md")
        validate(self.root)

    def test_move_requires_removing_exception(self):
        old = self.write("legacy.py")
        self.policy["migration_exceptions"] = ["tests/legacy.py"]
        self.save()
        validate(self.root)
        old.rename(self.root / "tests/runner/legacy.py")
        with self.assertRaisesRegex(AssertionError, "stale migration exceptions"):
            validate(self.root)
        self.policy["migration_exceptions"] = []
        self.save()
        validate(self.root)

    def test_exception_does_not_admit_a_new_sibling(self):
        self.write("old/scenario.py")
        self.policy["migration_exceptions"] = ["tests/old/scenario.py"]
        self.save()
        validate(self.root)
        self.write("old/new.py")
        with self.assertRaisesRegex(AssertionError, "Unowned test path"):
            validate(self.root)

    def test_duplicate_and_owned_exceptions(self):
        self.write("legacy.py")
        self.policy["migration_exceptions"] = ["tests/legacy.py"] * 2
        self.save()
        with self.assertRaisesRegex(AssertionError, "Duplicate migration"):
            validate(self.root)
        self.policy["migration_exceptions"] = ["tests/runner/layout.json"]
        self.save()
        with self.assertRaisesRegex(AssertionError, "Already owned"):
            validate(self.root)

    def test_deleted_tracked_exception(self):
        old = self.write("legacy.py")
        self.policy["migration_exceptions"] = ["tests/legacy.py"]
        self.save()
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        old.unlink()
        with self.assertRaisesRegex(AssertionError, "stale migration exceptions"):
            validate(self.root)

    def migration(self):
        first = self.write("old/one.log", "original failed observation\n")
        second = self.write("old/two.py", "independent oracle\n")
        baseline = dict(revision="basis", files=[dict(path=str(p.relative_to(self.root)), bytes=p.stat().st_size,
            sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in (first, second)])
        self.write("runner/baseline.json", json.dumps(baseline))
        mapping = dict(version=1, baseline="tests/runner/baseline.json", baseline_revision="basis", files=[
            dict(source="tests/old/one.log", destination="tests/runner/one.log", owner="runner", role="retained-observation"),
            dict(source="tests/old/two.py", destination="tests/runner/two.py", owner="runner", role="oracle")])
        return mapping

    def check_migration(self, mapping, complete=False):
        self.write("runner/migration.json", json.dumps(mapping))
        validate_migration(self.root, "tests/runner/migration.json", ["runner"], complete)

    def test_duplicate_destinations_and_missing_dispositions(self):
        mapping = self.migration()
        mapping["files"][1]["destination"] = mapping["files"][0]["destination"]
        with self.assertRaisesRegex(AssertionError, "Duplicate migration destinations"):
            self.check_migration(mapping)
        mapping["files"].pop()
        with self.assertRaisesRegex(AssertionError, "Missing or duplicate source"):
            self.check_migration(mapping)

    def test_evidence_bytes_survive_move_and_detect_edit(self):
        mapping = self.migration()
        self.check_migration(mapping)
        (self.root / "tests/old/one.log").rename(self.root / "tests/runner/one.log")
        self.check_migration(mapping)
        self.write("runner/one.log", "passed\n")
        with self.assertRaisesRegex(AssertionError, "Changed retained evidence"):
            self.check_migration(mapping)

    def test_complete_requires_destinations_and_removal_of_old_paths(self):
        mapping = self.migration()
        with self.assertRaisesRegex(AssertionError, "Unmigrated file"):
            self.check_migration(mapping, complete=True)
        for entry in mapping["files"]:
            source = self.root / entry["source"]
            (self.root / entry["destination"]).write_bytes(source.read_bytes())
        with self.assertRaisesRegex(AssertionError, "Old migration path remains"):
            self.check_migration(mapping, complete=True)
        for entry in mapping["files"]:
            (self.root / entry["source"]).unlink()
        self.check_migration(mapping, complete=True)

    def test_archived_bytes_are_available_at_original_revision(self):
        mapping = self.migration()
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                        "commit", "--no-gpg-sign", "-qm", "test: capture original observation"], cwd=self.root, check=True)
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=self.root, text=True).strip()
        baseline_path = self.root / mapping["baseline"]
        baseline = json.loads(baseline_path.read_text())
        baseline["revision"] = revision
        baseline_path.write_text(json.dumps(baseline))
        mapping["baseline_revision"] = revision
        entry = mapping["files"][0]
        entry.update(disposition="archive", destination=None, owner="evidence", archive=dict(
            revision=revision, path=entry["source"], sha256=baseline["files"][0]["sha256"]))
        (self.root / entry["source"]).unlink()
        self.check_migration(mapping)
        self.assertEqual(verify_archives(self.root, "tests/runner/migration.json"), 1)
        entry["archive"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(AssertionError, "Changed archive identity"):
            self.check_migration(mapping)
        with self.assertRaisesRegex(AssertionError, "Changed archive bytes"):
            verify_archives(self.root, "tests/runner/migration.json")
        entry["archive"]["revision"] = "0" * 40
        self.write("runner/migration.json", json.dumps(mapping))
        with self.assertRaisesRegex(AssertionError, "Unavailable archive object"):
            verify_archives(self.root, "tests/runner/migration.json")


if __name__ == "__main__":
    unittest.main()
