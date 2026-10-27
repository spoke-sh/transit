"""Exercise process death, discovery, bounded joining and adopted grandchildren."""
import ctypes
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import unittest

from processes import children, command, joined


class Processes(unittest.TestCase):
    def test_live_child_cannot_count_as_joined(self):
        child = subprocess.Popen(
            [sys.executable, "-B", "-c", "import time; print('ready', flush=True); time.sleep(30)"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        try:
            # The pinned interpreter launcher can still be replacing its process
            # image when Popen returns. Inspect the command only after Python runs.
            self.assertTrue(select.select([child.stdout], [], [], 5)[0])
            self.assertEqual(child.stdout.readline(), "ready\n")
            self.assertIn(child.pid, children(os.getpid()))
            self.assertIn("time.sleep(30)", command(child.pid))
            with self.assertRaisesRegex(AssertionError, "Unjoined children"):
                joined([child.pid], timeout=0.1)
            self.assertIsNone(child.poll())
        finally:
            child.kill()
            child.wait(timeout=5)
            child.stdout.close()
        joined([child.pid])
        self.assertEqual(command(child.pid), "")
        self.assertEqual(children(child.pid), set())

    def test_killed_manager_grandchild_is_adopted_and_reaped(self):
        libc = ctypes.CDLL(None)
        previous = ctypes.c_int()
        self.assertEqual(libc.prctl(37, ctypes.byref(previous), 0, 0, 0), 0)
        self.assertEqual(libc.prctl(36, 1, 0, 0, 0), 0)
        manager = None
        grandchild = None
        try:
            script = """import subprocess, sys
p = subprocess.Popen([sys.executable, '-B', '-c', 'import time; time.sleep(30)'])
print(p.pid, flush=True)
p.wait()
"""
            manager = subprocess.Popen([sys.executable, "-B", "-c", script],
                                       stdout=subprocess.PIPE, text=True)
            self.assertTrue(select.select([manager.stdout], [], [], 5)[0])
            grandchild = int(manager.stdout.readline())
            self.assertEqual(children(manager.pid), {grandchild})
            manager.kill()
            manager.wait(timeout=5)
            self.assertIn(grandchild, children(os.getpid()))
            os.kill(grandchild, signal.SIGKILL)
            joined([grandchild])
            self.assertFalse(Path(f"/proc/{grandchild}").exists())
        finally:
            if manager is not None:
                if manager.poll() is None:
                    manager.kill()
                manager.wait(timeout=5)
                manager.stdout.close()
            if grandchild is not None and Path(f"/proc/{grandchild}").exists():
                os.kill(grandchild, signal.SIGKILL)
                joined([grandchild])
            self.assertEqual(libc.prctl(36, previous.value, 0, 0, 0), 0)


if __name__ == "__main__":
    unittest.main()
