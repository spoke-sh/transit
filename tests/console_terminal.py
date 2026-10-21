"""Real Linux controlling PTY, independent JSON stdout and native metadata."""
import fcntl
import json
import os
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time
import tempfile
from unified_shell import Shell
from console_settings import read_show

ANSI = re.compile(rb'\x1b\[[0-?]*[ -/]*[@-~]')


class Terminal(Shell):
    def __init__(self, binary, config=None, format='json', shared_output=False, cwd=None, home=None, *, env=None, pass_fds=()):
        self.history_home = tempfile.TemporaryDirectory(prefix='transit-terminal-home-') if home is None else None
        environment = os.environ | {'HOME': str(home) if home is not None else self.history_home.name} | (env or {})
        environment = {key: value for key, value in environment.items() if value is not None}
        self.master, self.slave = pty.openpty()
        self.resize(80)
        self.original = termios.tcgetattr(self.slave)

        def child():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen([binary, 'console', '--no-rc', *(['--config', str(config)] if config is not None else []), '--format', format],
                                        stdin=self.slave, stdout=self.slave if shared_output else subprocess.PIPE, stderr=self.slave, preexec_fn=child, cwd=cwd, env=environment, pass_fds=pass_fds)
        self.buffer = b''
        self.screen = b''
        self.expect('transit> ')

    def resize(self, width):
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, width, 0, 0))

    def send(self, value):
        self.screen = b''
        os.write(self.master, value.encode() if isinstance(value, str) else value)

    def expect(self, text, timeout=15):
        until = time.monotonic()+timeout
        expected = text.encode()
        while expected not in ANSI.sub(b'', self.screen):
            assert self.process.poll() is None, ('terminal exited', self.process.returncode, self.screen)
            assert time.monotonic() < until, (text, ANSI.sub(b'', self.screen)[-4000:])
            if select.select([self.master], [], [], .1)[0]:
                self.screen += os.read(self.master, 65536)
            assert len(self.screen) <= 1048576, 'terminal rendering bound'

    def call(self, text):
        self.send(text+'\r')
        return self.read()

    def read(self, json_line=True, timeout=60):
        # A real terminal consumes its display while waiting for command output.
        # Drain both channels so the PTY's tiny kernel queue is not the test's
        # accidental backpressure fault.
        until = time.monotonic()+timeout
        while b'\n' not in self.buffer:
            assert time.monotonic() < until, ('terminal response deadline', ANSI.sub(b'', self.screen)[-1000:])
            for source in select.select([self.process.stdout, self.master], [], [], .1)[0]:
                block = os.read(source if isinstance(source, int) else source.fileno(), 65536)
                assert block, ('terminal exited', self.process.poll(), self.screen[-1000:])
                if source == self.master: self.screen += block
                else: self.buffer += block
            assert len(self.buffer) <= 1048576 and len(self.screen) <= 1048576
        line, self.buffer = self.buffer.split(b'\n', 1)
        return json.loads(line) if json_line else line

    def close(self):
        try:
            if self.process.poll() is None:
                # Queue an ordinary disconnect after any command output. A
                # signal here can interrupt metadata (correctly exiting 130),
                # and an unread prompt cannot acknowledge that signal. Clear
                # any remaining draft with editor keys before submitting quit.
                self.send('\x05\x15.quit\r')
                assert self.process.wait(timeout=10) == 0
            assert termios.tcgetattr(self.slave) == self.original, 'terminal attributes were not restored'
        except (AssertionError, subprocess.TimeoutExpired) as error:
            # Preserve the final rendered command when an interrupt/quit race
            # recurs. Do not turn an unexpected exit or timeout into a pass.
            if select.select([self.master], [], [], 0)[0]:
                try:
                    self.screen += os.read(self.master, 65536)
                except OSError:
                    pass  # A closed PTY may report EIO after child exit.
            error.add_note(f'Terminal close: exit={self.process.poll()}, display={ANSI.sub(b"", self.screen)[-1000:]!r}')
            raise
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait(timeout=10)
            if self.process.stdout is not None: self.process.stdout.close()
            os.close(self.master); os.close(self.slave)
            if self.history_home is not None: self.history_home.cleanup()


def local_transcript(binary, cwd):
    """An actual shared terminal retains submitted SQL above its human table."""
    terminal = Terminal(binary, format='table', shared_output=True, cwd=cwd, env={'XDG_RUNTIME_DIR': None})
    try:
        terminal.send('.show\r')
        terminal.expect('       connection: (automatic)\r\nconnection_source: local installation\r\n')
        terminal.expect('           format: table\r\n    format_source: --format\r\n')
        terminal.send('SELECT * FROM items;\r')
        terminal.expect('transit> SELECT * FROM items;\r\n')
        terminal.expect('0 rows; complete coverage\r\n', timeout=120)
        transcript = ANSI.sub(b'', terminal.screen)
        assert transcript.index(b'transit> SELECT * FROM items;\r\n') < transcript.index('│  id'.encode())
        assert b'value' in transcript and b'int64' in transcript and '┌'.encode() in transcript
        print('Transit console transcript: submitted SELECT and bordered empty result remain in shared terminal scrollback.', flush=True)
    finally:
        terminal.close()
