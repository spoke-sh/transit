"""Lost or duplicate SDK schedules must fail before expensive qualification."""
import copy
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from task_coverage import read_recipes, validate_ownership, validate_required_tiers

ROOT = Path(__file__).resolve().parents[2]


class TaskCoverage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.suite = json.loads((ROOT / "tests/runner/suite.json").read_text())
        cls.invariants = json.loads((ROOT / "tests/verification/invariants.json").read_text())
        cls.recipes = read_recipes(ROOT)

    def validate(self, suite, recipes=None):
        tasks, nesting = validate_ownership(suite, self.recipes if recipes is None else recipes)
        validate_required_tiers(suite, self.invariants, nesting)
        return tasks

    def test_current_schedules_and_order_independent_nesting(self):
        suite = copy.deepcopy(self.suite)
        suite["nested_tasks"] = dict(reversed(list(suite["nested_tasks"].items())))
        tasks = self.validate(suite)
        self.assertIn("bindings::direct-catalog-beam", tasks)
        self.assertNotIn("bindings::authorization", suite["lanes"]["sdks-scripting"])
        self.assertIn("bindings::authorization", suite["external_tasks"]["focused"])

    def test_each_missing_language_owner_fails(self):
        for parent in self.suite["recipe_nested_tasks"]:
            if parent == "bindings::authorization":
                continue
            with self.subTest(parent=parent):
                suite = copy.deepcopy(self.suite)
                for lane in suite["lanes"].values():
                    if parent in lane:
                        lane.remove(parent)
                # Keep its focused recipe available: existence alone cannot
                # satisfy the invariant's required ordinary tier.
                suite["external_tasks"]["focused"].append(parent)
                with self.assertRaisesRegex(AssertionError, "SQL-MUTATION-01.*found 0"):
                    self.validate(suite)

    def test_duplicate_aggregate_and_direct_schedule_fail(self):
        for task in ("bindings::authorization", "bindings::direct-catalog-python"):
            with self.subTest(task=task):
                suite = copy.deepcopy(self.suite)
                suite["lanes"]["sdks-scripting"].append(task)
                with self.assertRaisesRegex(AssertionError, "SQL-MUTATION-01.*found 2"):
                    self.validate(suite)

    def test_missing_catalog_registration_fails(self):
        suite = copy.deepcopy(self.suite)
        del suite["recipe_nested_tasks"]["bindings::python-test"]
        with self.assertRaisesRegex(AssertionError, "SQL-MUTATION-01.*found 0"):
            self.validate(suite)

    def test_real_recipe_edit_cannot_hide_behind_metadata(self):
        with tempfile.TemporaryDirectory(prefix="transit-task-coverage-") as directory:
            root = Path(directory)
            shutil.copyfile(ROOT / "justfile", root / "justfile")
            shutil.copytree(ROOT / "tasks", root / "tasks")
            path = root / "tasks/bindings.just"
            original = path.read_text()
            call = "    just bindings::direct-catalog-python\n"
            self.assertEqual(original.count(call), 1)
            for replacement in (
                "", "    # just bindings::direct-catalog-python\n",
                "    echo just bindings::direct-catalog-python\n",
                "    just bindings::direct-catalog-python || true\n", call + call,
            ):
                with self.subTest(replacement=replacement):
                    path.write_text(original.replace(call, replacement))
                    with self.assertRaisesRegex(AssertionError, "python-test must invoke"):
                        self.validate(self.suite, read_recipes(root))
            # The focused aggregate must keep the same eight schedules too.
            path.write_text(original.replace(
                "authorization: direct-catalog-python ", "authorization: "))
            with self.assertRaisesRegex(AssertionError, "authorization must invoke"):
                self.validate(self.suite, read_recipes(root))
            path.write_text("this is not valid Just syntax\n")
            with self.assertRaises(subprocess.CalledProcessError):
                read_recipes(root)

    def test_cycles_or_unowned_nesting_fail(self):
        suite = copy.deepcopy(self.suite)
        suite["nested_tasks"]["check::fast"].append("check::core")
        with self.assertRaisesRegex(AssertionError, "nested task cycle"):
            self.validate(suite)
        suite = copy.deepcopy(self.suite)
        suite["nested_tasks"]["bindings::build"] = ["bindings::native"]
        with self.assertRaisesRegex(AssertionError, "unowned nested tasks"):
            self.validate(suite)


if __name__ == "__main__":
    unittest.main()
