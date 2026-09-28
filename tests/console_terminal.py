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
from unified_shell import Shell

ANSI = re.compile(rb'\x1b\[[0-?]*[ -/]*[@-~]')


class Terminal(Shell):
    def __init__(self, binary, config):
        self.master, self.slave = pty.openpty()
        self.resize(80)
        self.original = termios.tcgetattr(self.slave)

        def child():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen([binary, 'console', '--config', str(config), '--format', 'json'],
                                        stdin=self.slave, stdout=subprocess.PIPE, stderr=self.slave, preexec_fn=child)
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

    def read(self, json_line=True):
        # A real terminal consumes its display while waiting for command output.
        # Drain both channels so the PTY's tiny kernel queue is not the test's
        # accidental backpressure fault.
        until = time.monotonic()+60
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
        if self.process.poll() is None:
            self.send('\x03')
            try:
                self.expect('transit> ')
                self.send('/quit\r')
                assert self.process.wait(timeout=10) == 0
            except AssertionError:
                if self.process.poll() is None: self.process.kill(); self.process.wait(timeout=10)
        assert termios.tcgetattr(self.slave) == self.original, 'terminal attributes were not restored'
        self.process.stdout.close()
        os.close(self.master); os.close(self.slave)


def check(binary, path, root, kind, invoke, fault):
    terminal = Terminal(binary, path)
    sends = fault['console_sends']
    try:
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
        terminal.send('SELECT \'東京🙂; /quit\'')
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
        assert terminal.call('/tables')['description']['source']['capabilities'][kind]
        assert terminal.call('/new 4')['status'] is None
        # Bracketed paste keeps embedded newlines/semicolon inert until Enter.
        pasted = 'SELECT COUNT(*)\n/* ; /quit */ FROM items;'
        terminal.send('\x1b[200~'+pasted+'\x1b[201~')
        terminal.expect('COUNT')
        assert fault['console_sends'] == sends, 'paste executed before explicit Enter'
        terminal.send('\r')
        assert 'receipt' in terminal.read()
        progress = terminal.read()
        while 'waiting_for_input' in progress: progress = terminal.call('/advance')
        until = time.monotonic()+180
        while terminal.call('/status')['status']['phase'] != 'complete':
            assert time.monotonic() < until
            time.sleep(.1)
        page = terminal.call('/next')
        assert page['cells'][0][0]['value']['uint64'] in ('12', '41') and page['complete_coverage']
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
        # Interrupt a real native read; no durable cancellation or fresh query.
        sends = fault['console_sends']
        fault['console_waiting'].clear(); fault['console_delay'].set()
        terminal.send('/schema\r')
        assert fault['console_waiting'].wait(10)
        terminal.process.send_signal(signal.SIGINT)
        assert terminal.process.wait(timeout=15) == 130
        assert fault['console_sends'] == sends
        fault['console_delay'].clear()
        record = json.loads((root/'console-recovery.json').read_text())
        assert record['namespace'] == 4 and record['complete']
        print(f'Transit terminal {kind}: controlling PTY, editing/undo, safe Unicode, paste, stale/expired/denied completion, resize, history clearing and interrupt passed; cold {cold_ms:.2f} ms / warm {warm_ms:.2f} ms; RSS high-water {high_water} bytes.', flush=True)
    finally:
        fault['console_delay'].clear()
        terminal.close()
