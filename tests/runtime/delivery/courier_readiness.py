"""Interrupt the launcher server's courier while a Station reply is pending.

Signed-read outages and readiness withdrawal execute in server_application_faults
on both storage profiles; this schedule checks the real launcher composition.
"""
import os
from pathlib import Path
import signal
import time

from harness.launcher_roles import courier_pid
from harness.processes import command


class ReadinessOutage:
    def __init__(self, installation, launcher):
        self.installation, self.launcher = installation, launcher
        self.recovery = None
        self.cleanup_restart_started = False
        self.cleanup_restart_completed = False

    def __enter__(self):
        self.before = courier_pid(self.launcher)
        os.kill(self.before, signal.SIGSTOP)
        deadline = time.monotonic() + 5
        while '\nState:\tT' not in Path(f'/proc/{self.before}/status').read_text():
            assert time.monotonic() < deadline
            time.sleep(.01)
        return self

    def recover(self, deadline):
        started = time.monotonic()
        os.kill(self.before, signal.SIGKILL)
        while time.monotonic() < deadline:
            try:
                current = courier_pid(self.launcher)
            except AssertionError:
                current = None
            if current is not None and current != self.before:
                assert '/courier.json' not in command(self.before)
                self.recovery = {'old_role': self.before, 'replacement_role': current,
                                 'replacement_seconds': round(time.monotonic()-started, 3)}
                return self.recovery
            time.sleep(.1)
        raise AssertionError('Server did not replace its interrupted courier')

    def __exit__(self, *_):
        if '/courier.json' in command(self.before):
            os.kill(self.before, signal.SIGCONT)
        self.cleanup_restart_started = True
        self.launcher.restart('node')
        self.cleanup_restart_completed = True
