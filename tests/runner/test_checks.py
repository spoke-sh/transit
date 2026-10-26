"""Check runner failures must survive generator pipes and incomplete reports."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from checks import ROOT, execute, expand
from capture import run, verify


class Checks(unittest.TestCase):
    def test_module_defaults_list_without_running_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            # Listing must not start Nix, a compiler or the Python check runner.
            import os
            root = Path(directory)
            for name in ("nix", "zig", "python3"):
                script = root / name
                script.write_text("#!/bin/sh\nexit 91\n")
                script.chmod(0o755)
            env = os.environ | {"PATH": str(root) + os.pathsep + os.environ["PATH"]}
            for module, names in (("check", ("fast", "core", "all")), ("ci", ("all", "clean", "formal"))):
                result = subprocess.run(["just", module], cwd=ROOT / "tests", env=env,
                                        capture_output=True, text=True, check=True)
                self.assertIn("Available recipes:", result.stdout)
                self.assertTrue(all(name in result.stdout for name in names), result.stdout)

    def test_generation_validation_and_failure_evidence(self):
        with tempfile.TemporaryDirectory(prefix="transit-checks-") as directory:
            root = Path(directory)
            generator = root / "generator with spaces"
            generator.write_text(f"#!{sys.executable}\nimport sys\n"
                                 "print('generator diagnostic', file=sys.stderr)\n"
                                 "print('observed schema')\nsys.exit(int(sys.argv[1]))\n")
            generator.chmod(0o755)
            checker = root / "check.py"
            checker.write_text("import sys\nfrom pathlib import Path\n"
                               "Path('observed').write_bytes(sys.stdin.buffer.read())\n"
                               "assert Path('observed').read_text() == 'observed schema\\n'\n"
                               "sys.exit(int(sys.argv[1]))\n")
            later = {"id": "later", "phase": "fixture", "command": [sys.executable, "-c",
                     "from pathlib import Path; Path('later').touch()"]}
            report = root / "report.json"
            for generate_code, validate_code in ((0, 0), (23, 0), (0, 24)):
                (root / "observed").unlink(missing_ok=True)
                (root / "later").unlink(missing_ok=True)
                first = {"id": "schema", "phase": "fixture",
                         "generator": {"name": "fixture", "args": [str(generate_code)]},
                         "command": [sys.executable, str(checker), str(validate_code)]}
                with contextlib.redirect_stdout(io.StringIO()):
                    if generate_code or validate_code:
                        with self.assertRaises(subprocess.CalledProcessError) as caught:
                            execute([first, later], {"fixture": str(generator)}, report, root)
                        self.assertEqual(caught.exception.returncode, generate_code or validate_code)
                    else:
                        execute([first, later], {"fixture": str(generator)}, report, root)
                value = json.loads(report.read_text())
                success = not (generate_code or validate_code)
                self.assertEqual(value["completed"], success)
                self.assertEqual(value["expected_checks"], ["schema", "later"])
                self.assertEqual((root / "observed").exists(), not generate_code)
                self.assertEqual((root / "later").exists(), success)
                if not success:
                    self.assertEqual(len(value["checks"]), 1)
                    self.assertFalse(value["checks"][0]["completed"])
                    self.assertEqual(value["checks"][0]["stages"][-1]["exit_code"], generate_code or validate_code)
                self.assertTrue(all(stage["seconds"] >= 0 for row in value["checks"] for stage in row["stages"]))
                artifacts = root / value["run_directory"]
                generated = value["checks"][0]["stages"][0]
                self.assertEqual((artifacts / generated["log"]).read_text(), "generator diagnostic\n")
                self.assertEqual((artifacts / generated["stdout"]["path"]).read_bytes(), b"observed schema\n")
                if success:
                    verify(artifacts)
                    successful = artifacts
                else:
                    with self.assertRaises(AssertionError):
                        verify(artifacts)
            # Later failures do not overwrite the original successful invocation.
            self.assertEqual(len(list((root / "runs").iterdir())), 3)
            verify(successful)
            original_report = (successful / "report.json").read_text()
            missing_stage = json.loads(original_report)
            missing_stage["checks"][0]["stages"].pop()
            (successful / "report.json").write_text(json.dumps(missing_stage))
            with self.assertRaises(AssertionError):
                verify(successful)
            (successful / "report.json").write_text(original_report)
            original = (successful / "001-generate.stdout").read_bytes()
            (successful / "001-generate.stdout").write_bytes(b"other schema")
            with self.assertRaises(AssertionError):
                verify(successful)
            (successful / "001-generate.stdout").write_bytes(original)
            (successful / "001-validate.log").unlink()
            with self.assertRaises(FileNotFoundError):
                verify(successful)

    def test_bounded_logs_preserve_console_and_semantic_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            command = [sys.executable, "-c",
                       "import sys; sys.stdout.buffer.write(b'A' * 8192); "
                       "sys.stdout.flush(); sys.stderr.buffer.write(b'B' * 8192)"]
            for generated in (False, True):
                result, console = {}, io.BytesIO()
                process = run(command, cwd=root, log=root / "output.log", result=result,
                              console=console, limit=256, capture_stdout=generated)
                self.assertEqual(process.returncode, 0)
                self.assertTrue(result["completed"])
                expected = b'B' * 8192 if generated else b'A' * 8192 + b'B' * 8192
                self.assertEqual(console.getvalue(), expected)
                self.assertEqual(result["diagnostics"]["bytes"], len(expected))
                self.assertEqual(result["diagnostics"]["retained_bytes"], 256)
                self.assertEqual(result["diagnostics"]["omitted_bytes"], len(expected) - 256)
                log = (root / "output.log").read_bytes()
                self.assertTrue(log.startswith(expected[:128]))
                self.assertTrue(log.endswith(expected[-128:]))
                self.assertIn(b"runner omitted", log)
                if generated:
                    self.assertEqual(process.stdout, b'A' * 8192)
                    self.assertEqual((root / "output.stdout").read_bytes(), process.stdout)

    def test_launch_failure_is_incomplete_and_captured(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = root / "report.json"
            with self.assertRaises(FileNotFoundError):
                execute([{"id": "missing", "phase": "tooling", "command": [str(root / "absent")]}],
                        {}, report, root)
            value = json.loads(report.read_text())
            self.assertFalse(value["completed"])
            stage = value["checks"][0]["stages"][0]
            self.assertFalse(stage["completed"])
            self.assertIsNone(stage["exit_code"])
            self.assertEqual(stage["error"], "FileNotFoundError")
            self.assertTrue((root / value["run_directory"] / stage["log"]).is_file())

    def test_empty_inputs_and_missing_generators_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(AssertionError):
                expand(["formatter", {"glob": "missing/*.zig"}], root)
            (root / "one.zig").touch()
            self.assertEqual(expand(["formatter", {"glob": "*.zig"}], root), ["formatter", "one.zig"])
            with self.assertRaises(AssertionError):
                execute([], {}, root / "report.json", root)
            with self.assertRaises(AssertionError):
                execute([{"id": "missing", "generator": {"name": "absent", "args": []}}],
                        {}, root / "report.json", root)
            self.assertFalse((root / "report.json").exists())


if __name__ == "__main__":
    unittest.main()
