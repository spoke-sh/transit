"""Changed dependencies must retain every reviewed consumer and fail closed."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from ci_select import ROOT, SUITE, affected, select


class Selection(unittest.TestCase):
    def test_transitive_package_and_combined_model_inputs(self):
        plan = select(["sdks/go/client/types.go", "tests/verification/models/Wal.cfg"], mode="enabled")
        self.assertFalse(plan["full"])
        self.assertEqual({row["optimize"] for row in plan["native_matrix"]["include"]}, {"Debug"})
        self.assertEqual(plan["lanes"], {"formal": ["test::wal-model"], "sdks-systems": ["bindings::go-sdk-test"]})
        self.assertTrue({"go-module", "go-package", "go-installed-consumer"} <= set(plan["groups"]))
        self.assertIn("private-disk-authority", plan["resources"])
        self.assertEqual({row["lane"]: row["cache_writer"] for row in plan["matrix"]["include"]},
                         {"formal": False, "sdks-systems": True})
        mixed = select(["sdks/go/client/types.go", "docs/handbook/reference/callers.md"], mode="enabled")
        self.assertTrue(mixed["checks"] and mixed["documentation"])
        self.assertFalse(plan["documentation"])
        generated = select(["sdks/go/internal/nativeclient/transit_client.h"], mode="enabled")
        self.assertEqual(generated["lanes"], {"sdks-conformance": ["bindings::check"],
                                              "sdks-systems": ["bindings::go-sdk-test"]})

    def test_each_reviewed_input_reaches_an_executable_owner(self):
        for group in SUITE["selection"]["groups"].values():
            for path in [*group.get("paths", []), *(p + "new-input.go" for p in group.get("prefixes", []))]:
                with self.subTest(path=path):
                    self.assertTrue(affected([path])["tasks"])
        for path in ("bindings/build_go.py", "tests/sdk/consumers/go/go_client_sdk.py", "examples/go-client/main.go"):
            self.assertEqual(affected([path])["tasks"], ["bindings::go-sdk-test"])

    def test_shared_unknown_budget_fixture_and_policy_changes_remain_full(self):
        for path in ("packages/zig/transit-client/src/root.zig", "tests/sdk/consumer_registry.py",
                     "contracts/client.json", "tests/harness/services.py", "tests/sdk/sdk-codecs-v1.json",
                     "tests/performance/query/budgets/new.json", "tests/runner/suite.json", "build/checks.zig",
                     "pnpm-lock.yaml", "unknown", "../sdks/go/client/types.go", "/sdks/go/client/types.go"):
            with self.subTest(path=path):
                self.assertTrue(select([path], mode="enabled")["full"])
        for event in ("push", "merge_group", "workflow_dispatch", "unknown"):
            self.assertTrue(select(["sdks/go/client/types.go"], event, mode="enabled")["full"])

    def test_installed_languages_preserve_shared_consumers_without_unrelated_runtime(self):
        for language, task in (("rust", "rust-sdk-test"), ("java", "java-sdk-test"),
                               ("python", "python-test"), ("ts", "node-sdk-test")):
            with self.subTest(language=language):
                plan = select([f"sdks/{language}/new-source"])
                self.assertFalse(plan["full"])
                tasks = {task for selected in plan["lanes"].values() for task in selected}
                self.assertTrue({f"bindings::{task}", "bindings::check", "bindings::sdk-interop"} <= tasks)
                self.assertNotIn("core", plan["lanes"])
        for path in ("apps/transit-board-web/src/data-workbench.tsx",
                     "packages/ts/transit-query-client/src/read.ts"):
            plan = select([path])
            self.assertEqual(list(plan["lanes"]), ["installation-ui", "browser"])
            self.assertEqual(plan["lanes"]["browser"], SUITE["lanes"]["browser"])
        # A mixed change cannot hide a shared native dependency behind a known SDK path.
        self.assertTrue(select(["sdks/rust/transit-client/src/lib.rs", "packages/zig/transit-client/src/root.zig"])["full"])

    def test_shadow_keeps_full_qualification_and_records_proposal(self):
        plan = select(["sdks/go/client/types.go"], mode="shadow")
        self.assertTrue(plan["full"])
        self.assertEqual(plan["proposed_tasks"], ["bindings::go-sdk-test"])
        self.assertEqual(list(plan["lanes"]), SUITE["tiers"]["ordinary"])

    def test_missing_dependencies_cycles_and_unowned_tasks_reject(self):
        for change in ("missing", "cycle", "task", "uncovered"):
            suite = copy.deepcopy(SUITE)
            groups = suite["selection"]["groups"]
            if change == "missing":
                groups["go-package"]["depends_on"] = ["missing"]
            elif change == "cycle":
                groups["go-module"]["depends_on"] = ["go-installed-consumer"]
            elif change == "task":
                groups["go-installed-consumer"]["tasks"] = ["unknown::task"]
            else:
                groups["go-installed-consumer"]["tasks"] = []
            with self.subTest(change=change), self.assertRaises(AssertionError):
                affected(["sdks/go/client/types.go"], suite)

    def fixture(self, root):
        runner = root / "tests/runner"
        runner.mkdir(parents=True)
        for name in ("ci.py", "ci_select.py", "capture.py"):
            shutil.copy2(ROOT / "tests/runner" / name, runner / name)
        suite = copy.deepcopy(SUITE)
        suite["selection"]["mode"] = "enabled"
        (runner / "suite.json").write_text(json.dumps(suite))
        (root / ".gitignore").write_text(".cache/\nselection.json\nexecuted\n")
        sdk = root / "sdks/go/client"
        sdk.mkdir(parents=True)
        (sdk / "types.go").write_text("package client\n")
        executable = root / "just"
        executable.write_text(f"#!{sys.executable}\nimport os, sys\nfrom pathlib import Path\n"
                              "assert 'TRANSIT_CI_SELECTION_PATH' not in os.environ, 'runner selection leaked into application configuration'\n"
                              "with Path('executed').open('a') as output: output.write(sys.argv[1]+'\\n')\n")
        executable.chmod(0o700)

        def git(*args):
            return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.DEVNULL).decode().strip()

        git("init", "-q")
        git("config", "user.name", "Selection fixture")
        git("config", "user.email", "fixture@example.invalid")
        git("add", ".")
        git("commit", "-qm", "test(selection): seed inputs")
        return runner, git

    def test_real_deletion_rename_and_missing_comparison(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner, git = self.fixture(root)
            base = git("rev-parse", "HEAD")
            (root / "docs").mkdir()
            git("mv", "sdks/go/client/types.go", "docs/example.md")
            git("commit", "-qm", "test(selection): move package source")
            command = [sys.executable, "-B", runner / "ci_select.py", "--base"]
            result = subprocess.run([*command, base], cwd=root, capture_output=True, check=True)
            plan = json.loads(result.stdout)
            self.assertEqual(plan["paths"], ["docs/example.md", "sdks/go/client/types.go"])
            self.assertEqual(plan["lanes"], {"sdks-systems": ["bindings::go-sdk-test"]})
            self.assertTrue(plan["documentation"])
            self.assertNotEqual(subprocess.run([*command, "missing"], cwd=root, capture_output=True).returncode, 0)
            # A move into an unreviewed owner must widen, not follow the old owner alone.
            git("mv", "docs/example.md", "unknown.zig")
            git("commit", "-qm", "test(selection): add unknown endpoint")
            result = subprocess.run([*command, base], cwd=root, capture_output=True, check=True)
            self.assertTrue(json.loads(result.stdout)["full"])

    def test_real_scoped_runner_and_tampered_or_foreign_plans(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner, git = self.fixture(root)
            base = git("rev-parse", "HEAD")
            (root / "sdks/go/client/types.go").write_text("package client\n// changed\n")
            git("add", ".")
            git("commit", "-qm", "test(selection): change package")
            subprocess.run([sys.executable, "-B", runner / "ci_select.py", "--base", base,
                            "--output", "selection.json"], cwd=root, check=True, capture_output=True)
            selection = root / "selection.json"
            original = json.loads(selection.read_text())
            env = {k: v for k, v in os.environ.items() if k != "TRANSIT_CI_SELECTION_PATH"}
            env["PATH"] = str(root) + os.pathsep + env["PATH"]
            env["TRANSIT_CI_SELECTION_PATH"] = str(selection)
            command = [sys.executable, "-B", runner / "ci.py", "sdks-systems", "--selection", selection]
            # Hosted jobs supply the selection through the environment. It must
            # select this task without becoming an unknown Transit setting in
            # the actual child process. Later calls also check explicit arguments.
            subprocess.run(command[:-2], cwd=root, env=env, check=True, capture_output=True)
            self.assertEqual((root / "executed").read_text().splitlines(), ["bindings::go-sdk-test"])
            metadata = json.loads((root / ".cache/ci/sdks-systems.meta.json").read_text())
            self.assertTrue(metadata["completed"])
            self.assertEqual(metadata["expected_tasks"], ["bindings::go-sdk-test"])
            self.assertEqual(metadata["selection"], original)
            for kind in ("unknown-format", "missing-source", "foreign-source", "omitted-task", "unknown-task", "duplicate-task"):
                tampered = copy.deepcopy(original)
                if kind == "unknown-format":
                    tampered["version"] = 2
                elif kind == "missing-source":
                    del tampered["checkout_sha"]
                elif kind == "foreign-source":
                    tampered["checkout_sha"] = base
                else:
                    tampered["lanes"]["sdks-systems"] = {"omitted-task": [], "unknown-task": ["unknown::task"],
                        "duplicate-task": ["bindings::go-sdk-test"] * 2}[kind]
                selection.write_text(json.dumps(tampered))
                (root / "executed").unlink(missing_ok=True)
                result = subprocess.run(command, cwd=root, env=env, capture_output=True)
                self.assertNotEqual(result.returncode, 0, kind)
                self.assertFalse((root / "executed").exists(), kind)
            # The hosted installation-ui job runs the browser lane separately after
            # ordinary checks, using the same source-bound selection.
            subprocess.run([sys.executable, "-B", runner / "ci_select.py", "--event", "push",
                            "--output", "selection.json"], cwd=root, check=True, capture_output=True)
            subprocess.run([sys.executable, "-B", runner / "ci.py", "browser", "--selection", selection],
                           cwd=root, env=env, check=True, capture_output=True)
            self.assertEqual((root / "executed").read_text().splitlines(), SUITE["lanes"]["browser"])


if __name__ == "__main__":
    unittest.main()
