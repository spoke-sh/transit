"""Exercise the pinned upstream compiler/runtime before transitc extraction."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


class UpstreamIntegration(unittest.TestCase):
    transit: Path
    revision: str
    fixtures: Path

    @classmethod
    def setUpClass(cls):
        # Fail before running any fixtures if a different Transit is selected.
        version = subprocess.run(
            [str(cls.transit), "--version"],
            capture_output=True,
            text=True,
            timeout=30,
            check=True,
        ).stdout.strip()
        if not re.fullmatch(
            rf"Transit \S+ \(git {re.escape(cls.revision)}; CLI contract 1\)", version
        ):
            raise AssertionError(f"Expected upstream revision {cls.revision}, got {version!r}")
        print(f"Upstream: {version}", flush=True)

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="transitc-integration-")
        self.addCleanup(temporary.cleanup)
        # Transit rejects symlinked path components; /tmp is a symlink on Darwin.
        self.root = Path(temporary.name).resolve()
        self.workspace = self.root / "application"
        shutil.copytree(self.fixtures / "application", self.workspace)
        # Nix store inputs are read-only. Only the per-test copies are mutable.
        self.workspace.chmod(0o700)
        for path in self.workspace.rglob("*"):
            path.chmod(0o700 if path.is_dir() else 0o600)
        # Deliberately do not inherit Transit configuration, credentials, or paths.
        self.env = {"PATH": os.defpath, "LANG": "C", "NO_COLOR": "1"}
        for key, name in (
            ("HOME", "home"),
            ("XDG_CONFIG_HOME", "config"),
            ("XDG_CACHE_HOME", "cache"),
            ("XDG_DATA_HOME", "data"),
            ("TMPDIR", "tmp"),
        ):
            directory = self.root / name
            directory.mkdir()
            self.env[key] = str(directory)

    def invoke(self, *arguments, exit_code=0):
        result = subprocess.run(
            [str(self.transit), *arguments, "--format", "json", "--color", "off"],
            cwd=self.workspace,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=120,
        )
        self.assertEqual(
            result.returncode,
            exit_code,
            f"transit {' '.join(arguments)}\nstdout: {result.stdout}\nstderr: {result.stderr}",
        )
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as error:
            self.fail(f"Expected one complete JSON report: {error}\n{result.stdout}\n{result.stderr}")

    def assert_diagnostic(self, report, code):
        self.assertEqual(report["version"], 1)
        self.assertEqual(report["code"], code)
        self.assertEqual(report["outcome"], "not_submitted")
        self.assertEqual(report["evidence"], "local_before_dispatch")

    def assert_no_artifacts(self):
        self.assertFalse((self.workspace / ".transit" / "build").exists())

    def test_check_validates_without_publishing(self):
        report = self.invoke("build", "--check")
        self.assertIs(report["ok"], True)
        self.assertEqual(report["action"], "check")
        self.assertEqual(report["target"], "default")
        self.assertEqual(report["statements"], 4)
        expected = (self.fixtures / "expected.sql").read_bytes()
        self.assertEqual(report["sql_digest"], hashlib.sha256(expected).hexdigest())
        self.assert_no_artifacts()

    def test_build_is_reproducible_and_records_provenance(self):
        outputs = [self.root / "first", self.root / "second"]
        reports = [self.invoke("build", "--out", str(output)) for output in outputs]
        expected = (self.fixtures / "expected.sql").read_bytes()
        for output, report in zip(outputs, reports):
            self.assertIs(report["ok"], True)
            self.assertEqual(report["action"], "build")
            self.assertEqual(report["statements"], 4)
            self.assertEqual((output / "application.sql").read_bytes(), expected)
            provenance = json.loads((output / "provenance.json").read_text())
            self.assertIs(provenance["complete"], True)
            self.assertEqual(provenance["format"], "transit_source_v1")
            self.assertEqual(provenance["compiler_revision"], self.revision)
            self.assertEqual(provenance["sql_digest"], hashlib.sha256(expected).hexdigest())
            self.assertEqual(provenance["input_digest"], report["input_digest"])
            self.assertEqual(provenance["dependencies"], [])
            self.assertEqual(len(provenance["steps"]), 4)
            self.assertEqual(
                {source["path"]: source["digest"] for source in provenance["sources"]},
                {
                    path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in self.workspace.glob("*.transit")
                },
            )
        for name in ("application.sql", "provenance.json"):
            self.assertEqual((outputs[0] / name).read_bytes(), (outputs[1] / name).read_bytes())
        self.assertEqual(reports[0]["input_digest"], reports[1]["input_digest"])

    def test_build_reuses_only_intact_artifacts(self):
        first = self.invoke("build")
        self.assertIs(first["reused"], False)
        second = self.invoke("build")
        self.assertIs(second["reused"], True)
        self.assertEqual(first["directory"], second["directory"])
        artifact = Path(first["directory"]) / "application.sql"
        artifact.write_text("-- deliberately corrupted\n")
        failure = self.invoke("build", exit_code=1)
        self.assert_diagnostic(failure, "application.source.output")
        self.assertEqual(artifact.read_text(), "-- deliberately corrupted\n")

    def test_missing_entry_and_unknown_target_fail_without_artifacts(self):
        missing = self.invoke("build", "-f", "missing.transit", exit_code=1)
        self.assert_diagnostic(missing, "application.source.entry")
        target = self.invoke("build", "--target", "unknown", exit_code=1)
        self.assert_diagnostic(target, "application.source.target")
        self.assert_no_artifacts()

    def test_syntax_failure_has_a_source_location(self):
        (self.workspace / "build.transit").write_text(
            "CREATE TARGET default AS BEGIN\n  SELECT ;\nEND;\n"
        )
        failure = self.invoke("build", exit_code=1)
        self.assert_diagnostic(failure, "application.source.syntax")
        location = failure["location"]
        self.assertEqual(location["source"], "root/build.transit")
        self.assertEqual(
            {key: int(location[key]) for key in ("offset", "length", "line", "byte_column")},
            {"offset": 40, "length": 0, "line": 2, "byte_column": 10},
        )
        self.assert_no_artifacts()

    def test_runtime_executes_cases_in_isolation(self):
        report = self.invoke("test")
        self.assertEqual(report["format"], "transit_test_v1")
        self.assertEqual(report["compiler_revision"], self.revision)
        self.assertIs(report["complete"], True)
        self.assertIs(report["ok"], True)
        self.assertEqual(
            [(case["name"], case["status"]) for case in report["cases"]],
            [("writes and duplicate rejection", "passed"), ("fresh state", "passed")],
        )
        self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_wrong_runtime_expectation_fails(self):
        entry = self.workspace / "build.transit"
        entry.write_text(entry.read_text().replace("EQUAL ((3))", "EQUAL ((999))"))
        report = self.invoke("test", exit_code=1)
        self.assertIs(report["complete"], True)
        self.assertIs(report["ok"], False)
        self.assertEqual([case["status"] for case in report["cases"]], ["passed", "failed"])
        self.assertEqual(list((self.root / "tmp").iterdir()), [])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--transit", default=os.environ.get("TRANSIT_UPSTREAM_BIN"))
    parser.add_argument("--expected-revision", default=os.environ.get("TRANSIT_UPSTREAM_REVISION"))
    parser.add_argument("--fixtures", type=Path, default=Path(__file__).parent / "fixtures")
    args = parser.parse_args()
    if not args.transit or not args.expected_revision:
        parser.error("enter nix develop or supply --transit and --expected-revision explicitly")
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_revision):
        parser.error("--expected-revision must be a full Git commit")
    UpstreamIntegration.transit = Path(args.transit).resolve(strict=True)
    UpstreamIntegration.revision = args.expected_revision
    UpstreamIntegration.fixtures = args.fixtures.resolve(strict=True)
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(UpstreamIntegration)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())


if __name__ == "__main__":
    main()
