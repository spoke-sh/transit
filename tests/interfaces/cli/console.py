"""Piped native-session console used by real deployment proofs."""
import json
import os
import signal
import stat
import subprocess
import time
from unified_shell import Shell
from interfaces.cli.console_settings import parse_show


class Console(Shell):
    def __init__(self, binary, config=None, cwd=None):
        self.process = subprocess.Popen([binary, 'console', '--no-rc', *(['--config', str(config)] if config is not None else []), '--format', 'json'],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd,
                                        env={'PATH': '/unavailable', 'LANG': 'C'})
        self.buffer = b''

    def close(self, status=0):
        if self.process.poll() is None:
            self.process.stdin.write(b'.quit\n'); self.process.stdin.flush()
            self.process.stdin.close()
        assert self.process.wait(timeout=10) == status, self.process.stderr.read()
        self.process.stdout.close(); self.process.stderr.close()
