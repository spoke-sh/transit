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
