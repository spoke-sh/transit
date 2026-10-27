"""Phase artifacts preserve failed and interrupted work, not just happy timings."""
import json
import io
from contextlib import redirect_stderr
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from harness.phases import Recorder, phase
from runner.paths import ROOT


class Phases(unittest.TestCase):
    def test_recording_failure_cannot_skip_cleanup_or_mask_original_failure(self):
        called = []
        diagnostics = io.StringIO()
        with patch("harness.phases.recorder", side_effect=OSError("unavailable output")), redirect_stderr(diagnostics):
            with phase("teardown", "fixture"):
                called.append("joined")
            with self.assertRaisesRegex(ValueError, "original"):
                with phase("teardown", "fixture"):
                    called.append("joined after failure")
                    raise ValueError("original")
        self.assertEqual(called, ["joined", "joined after failure"])
        self.assertEqual(diagnostics.getvalue().count("Incomplete phase evidence"), 2)

    def test_nested_success_and_failed_cleanup_keep_original_outcome(self):
        with tempfile.TemporaryDirectory() as directory:
            recorder = Recorder(Path(directory))
            with self.assertRaisesRegex(ValueError, "original failure"):
                with recorder.phase("schedule", "fixture"):
                    try:
                        with recorder.phase("install", "consumer"):
                            raise ValueError("original failure")
                    finally:
                        with recorder.phase("teardown", "fixture"):
                            pass
            rows = {path.name: json.loads(path.read_text()) for path in recorder.directory.glob("*.json")
                    if path.name != "source.json"}
            self.assertEqual(len(rows), 3)
            parent = next(name for name, row in rows.items() if row["kind"] == "schedule")
            for name, row in rows.items():
                self.assertGreaterEqual(row["seconds"], 0)
                self.assertEqual(row["parent"], None if name == parent else parent)
                self.assertEqual(row["completed"], row["kind"] == "teardown")
                self.assertEqual(row["outcome"], "passed" if row["kind"] == "teardown" else "failed")

    def test_actual_interruption_leaves_incomplete_phase(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / "interrupt.py"
            script.write_text(
                "import os, signal, sys\nfrom pathlib import Path\n"
                f"sys.path.insert(0, {str(ROOT / 'tests')!r})\n"
                "from harness.phases import Recorder\n"
                f"recorder = Recorder(Path({str(root)!r}))\n"
                "with recorder.phase('compile', 'fixture'):\n"
                "    os.kill(os.getpid(), signal.SIGTERM)\n")
            result = subprocess.run([sys.executable, "-B", script])
            self.assertLess(result.returncode, 0)
            rows = list((root / ".cache/checks/phases").glob("*/compile-*.json"))
            self.assertEqual(len(rows), 1)
            row = json.loads(rows[0].read_text())
            self.assertFalse(row["completed"])
            self.assertEqual(row["outcome"], "incomplete")
            self.assertNotIn("seconds", row)

    def test_failed_command_keeps_exit_status_and_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / "command.py"
            script.write_text(
                "import sys\nfrom pathlib import Path\n"
                f"sys.path.insert(0, {str(ROOT / 'tests')!r})\n"
                "from harness import phases\n"
                f"record = phases.Recorder(Path({str(root)!r}))\n"
                "phases.recorder = lambda: record\n"
                "sys.argv = ['phases', 'packaging', 'fixture', '--', sys.executable, '-c', "
                "\"import sys; print('original diagnostic'); sys.exit(23)\"]\n"
                "phases.main()\n")
            result = subprocess.run([sys.executable, "-B", script], capture_output=True)
            self.assertEqual(result.returncode, 23)
            self.assertIn(b"original diagnostic", result.stdout)
            rows = list((root / ".cache/checks/phases").glob("*/packaging-*.json"))
            self.assertEqual(len(rows), 1)
            row = json.loads(rows[0].read_text())
            self.assertFalse(row["completed"])
            self.assertEqual(row["outcome"], "failed")
            self.assertEqual(row["exit_code"], 23)
            self.assertEqual((rows[0].parent / "command.log").read_text(), "original diagnostic\n")


if __name__ == "__main__":
    unittest.main()
