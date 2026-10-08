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


def check(binary, path, root, kind, invoke, fault):
    terminal = Terminal(binary, path)
    sends = fault['console_sends']
    try:
        saved = (root/'console-recovery.json').read_bytes()
        terminal.send('.show\r')
        settings = read_show(terminal)
        assert settings['connection'] == str(path) and settings['connection_source'] == '--config'
        assert settings['format'] == 'json' and settings['format_source'] == '--format'
        for mode in ('table', 'json'):
            terminal.send('.mode '+mode+'\r.show\r')
            settings = read_show(terminal)
            assert settings['format'] == mode and settings['format_source'] == '.mode'
        assert fault['console_sends'] == sends, 'settings inspection sent a native mutation'
        assert (root/'console-recovery.json').read_bytes() == saved
        for statement, message in (
            ('SELECT;', 'line 1, column 7'),
            ('INSERT INTO items (id, value) VALUES (1, 100);', '.help INSERT'),
        ):
            terminal.send(statement+'\r')
            terminal.expect(message)
            if statement.startswith('SELECT'):
                terminal.expect('^--- error here')
            terminal.expect('transit> ')
            assert not select.select([terminal.process.stdout], [], [], .1)[0], 'SQL error leaked to result stdout'
        assert fault['console_sends'] == sends and (root/'console-recovery.json').read_bytes() == saved
        terminal.send('SE')
        terminal.expect('transit> SE')
        started = time.monotonic()
        terminal.send(b'\0')
        terminal.expect('[1/1 SELECT]')
        cold_ms = (time.monotonic()-started)*1000
        terminal.send('\t')
        terminal.expect('transit> SELECT')
        terminal.send('\x1a')
        terminal.expect('transit> SE')
        terminal.send('\x15SELECT * FROM itxx\x1b[D\x1b[D')
        terminal.expect('SELECT * FROM itxx')
        started = time.monotonic()
        terminal.send(b'\0')
        terminal.expect('[1/1 "items"]')
        warm_ms = (time.monotonic()-started)*1000
        terminal.send('\t')
        terminal.expect('transit> SELECT * FROM "items"')
        terminal.send('\x1a')
        terminal.expect('SELECT * FROM itxx')
        terminal.send('\x03')
        terminal.expect('transit> ')
        terminal.send('SELECT \'東京🙂; .quit\'')
        terminal.expect('\\u{6771}')
        terminal.send(b'\0')
        terminal.expect('[no completion]')
        terminal.send('\x03')
        terminal.expect('transit> ')
        # Input queued during a catalog read invalidates its old generation.
        terminal.send('SE')
        terminal.expect('transit> SE')
        fault['console_waiting'].clear(); fault['console_delay'].set()
        terminal.send(b'\0')
        assert fault['console_waiting'].wait(10)
        terminal.send('Z')
        terminal.expect('transit> SEZ')
        assert b'[1/1 SELECT]' not in ANSI.sub(b'', terminal.screen)
        fault['console_delay'].clear()
        terminal.send('\x03')
        terminal.expect('transit> ')
        terminal.send('SE')
        terminal.expect('transit> SE')
        terminal.send(b'\0')
        terminal.expect('[1/1 SELECT]')
        terminal.screen = b''
        terminal.expect('transit> SE', timeout=8)  # The five-second metadata lease expires.
        terminal.resize(24)
        terminal.screen = b''
        terminal.expect('transit> SE')
        terminal.resize(100)
        terminal.send('\x03')
        terminal.expect('transit> ')
        assert fault['console_sends'] == sends, 'editing/completion sent a native mutation'
        terminal.send('.timer on\r')
        terminal.expect('transit> .timer on\r\n')
        terminal.send('.connect '+str(path)+'\r')
        terminal.expect('transit> .connect '+str(path)+'\r\n')
        terminal.send('.show\r')
        shown = read_show(terminal)
        assert shown['timing'] == 'on' and shown['timing_source'] == '.timer', shown
        terminal.send('.timer off\r')
        terminal.expect('transit> .timer off\r\n')
        assert terminal.call('.tables')['description']['source']['capabilities'][kind]
        terminal.expect('transit> .tables\r\n')
        terminal.send('SELECT * FROM items\r')
        terminal.expect('   ...> ')
        assert fault['console_sends'] == sends, 'unterminated SQL executed'
        terminal.send('\x03')
        terminal.expect('transit> ')
        # Bracketed paste keeps embedded newlines/semicolon inert until Enter.
        pasted = 'SELECT COUNT(*)\n/* ; .quit */ FROM items;'
        terminal.send('\x1b[200~'+pasted+'\x1b[201~')
        terminal.expect('COUNT')
        assert fault['console_sends'] == sends, 'paste executed before explicit Enter'
        terminal.send('\r')
        page = terminal.read(timeout=420)
        terminal.expect('transit> SELECT COUNT(*)\r\n   ...> /* ; .quit */ FROM items;\r\n')
        assert page['cells'][0][0]['value']['atom']['unsigned'] in ('12', '41') and page['complete_coverage']
        with open(f'/proc/{terminal.process.pid}/status') as status:
            high_water = int(next(line.split()[1] for line in status if line.startswith('VmHWM:')))*1024
        assert high_water < 64*1024*1024, high_water
        terminal.send('\x1b[A')
        terminal.expect('COUNT')
        terminal.send('\x03')
        terminal.expect('transit> ')
        terminal.send('SE')
        terminal.expect('transit> SE')
        terminal.send(b'\0')
        terminal.expect('[1/1 SELECT]')
        invoke('revoke', direct=True)
        terminal.send('\t')  # Acceptance must reauthorize and erase history.
        terminal.expect('error: AccessDenied')
        terminal.send('\x1b[A')
        terminal.expect('transit> ')
        assert b'COUNT' not in ANSI.sub(b'', terminal.screen)
        invoke('restore', direct=True)
        sends = fault['console_sends']
        terminal.send('.timer on\r.connect '+json.dumps(str(path))+'\r.show\r')
        settings = read_show(terminal)
        assert settings['connection'] == str(path) and settings['connection_source'] == '.connect'
        assert settings['format'] == 'json' and settings['format_source'] == '.mode'
        assert settings['timing'] == 'on' and settings['timing_source'] == '.timer'
        assert fault['console_sends'] == sends
        # Interrupt a real native read; no durable cancellation or fresh query.
        sends = fault['console_sends']
        fault['console_waiting'].clear(); fault['console_delay'].set()
        terminal.send('.schema\r')
        assert fault['console_waiting'].wait(10)
        terminal.process.send_signal(signal.SIGINT)
        assert terminal.process.wait(timeout=15) == 130
        assert fault['console_sends'] == sends
        fault['console_delay'].clear()
        record = json.loads((root/'console-recovery.json').read_text())
        assert record['namespace'] > 0 and record['complete']
        print(f'Transit terminal {kind}: controlling PTY, editing/undo, safe Unicode, paste, stale/expired/denied completion, resize, history clearing and interrupt passed; cold {cold_ms:.2f} ms / warm {warm_ms:.2f} ms; RSS high-water {high_water} bytes.', flush=True)
    finally:
        fault['console_delay'].clear()
        terminal.close()


def local_transcript(binary, cwd):
    """An actual shared terminal retains submitted SQL above its human table."""
    terminal = Terminal(binary, format='table', shared_output=True, cwd=cwd)
    try:
        terminal.send('.show\r')
        terminal.expect('       connection: (automatic)\r\nconnection_source: local installation\r\n')
        terminal.expect('           format: table\r\n    format_source: --format\r\n')
        terminal.send('SELECT * FROM items;\r')
        terminal.expect('transit> SELECT * FROM items;\r\n')
        terminal.expect('0 rows\r\n', timeout=120)
        transcript = ANSI.sub(b'', terminal.screen)
        assert transcript.index(b'transit> SELECT * FROM items;\r\n') < transcript.index('│  id'.encode())
        assert b'value' in transcript and b'int64' in transcript and '┌'.encode() in transcript
        print('Transit console transcript: submitted SELECT and bordered empty result remain in shared terminal scrollback.', flush=True)
    finally:
        terminal.close()
