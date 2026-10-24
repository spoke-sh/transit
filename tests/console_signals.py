"""Schedule real PTY input flushes between poll readiness and the stdin read."""
import fcntl
import os
from pathlib import Path
import select
import signal
import struct
import tempfile
import termios

from console_terminal import Terminal


def check(binary, config, home, library):
    for scenario in ('interrupt-flushed', 'empty-read', 'interrupt-queued-eof', 'terminate-flushed'):
        with tempfile.TemporaryDirectory(prefix='transit-console-signal-') as directory:
            marker = Path(directory) / 'arm'
            notify_read, notify_write = os.pipe()
            release_read, release_write = os.pipe()
            terminal = None
            try:
                terminal = Terminal(binary, config, home=home, env={
                    'LD_PRELOAD': str(library),
                    'TRANSIT_TEST_NOTIFY_FD': str(notify_write),
                    'TRANSIT_TEST_RELEASE_FD': str(release_read),
                    'TRANSIT_TEST_READ_MARKER': str(marker),
                }, pass_fds=(notify_write, release_read))
                os.close(notify_write); notify_write = None
                os.close(release_read); release_read = None

                def acknowledged(expected):
                    assert select.select([notify_read], [], [], 15)[0], (scenario, 'missing gate acknowledgment', expected)
                    actual = os.read(notify_read, 1)
                    assert actual == expected, (scenario, actual, expected)

                if scenario == 'interrupt-flushed':
                    terminal.send('\x12signal_schedule')
                    terminal.expect('>\r\n.signal_schedule')
                elif scenario == 'empty-read':
                    terminal.send('kept')
                    terminal.expect('transit> kept')
                marker.touch()
                terminal.send('\x04' if scenario == 'interrupt-queued-eof' else 'x')
                acknowledged(b'r')  # Real poll returned POLLIN; read is held.
                if scenario == 'interrupt-flushed':
                    terminal.send('\x03')  # The line discipline flushes input.
                    acknowledged(b's')   # The real handler has set its flags.
                else:
                    if scenario != 'interrupt-queued-eof':
                        termios.tcflush(terminal.slave, termios.TCIFLUSH)
                    if scenario != 'empty-read':
                        os.kill(terminal.process.pid, signal.SIGTERM if scenario == 'terminate-flushed' else signal.SIGINT)
                        acknowledged(b's')
                queued = struct.unpack('i', fcntl.ioctl(terminal.slave, termios.FIONREAD, struct.pack('i', 0)))[0]
                assert queued == (1 if scenario == 'interrupt-queued-eof' else 0), (scenario, queued)
                os.write(release_write, b'g')
                if scenario == 'empty-read':
                    acknowledged(b'z')  # The real read returned zero, not EOF.
                    terminal.send('!')
                    terminal.expect('transit> kept!')
                    terminal.send('\x15\x04')
                    assert terminal.process.wait(timeout=15) == 0
                elif scenario == 'terminate-flushed':
                    assert terminal.process.wait(timeout=15) == 130
                else:
                    terminal.expect('transit> ')
                    assert terminal.process.poll() is None
                    # A cleared draft cannot execute the old search or queued
                    # Ctrl-D; a subsequent, explicit Ctrl-D still exits normally.
                    terminal.send('\x04')
                    assert terminal.process.wait(timeout=15) == 0
                assert not select.select([terminal.process.stdout], [], [], 0)[0] or terminal.process.stdout.read(1) == b'', (scenario, 'unexpected result stdout')
            except BaseException as error:
                error.add_note(f'Console input schedule: {scenario}')
                raise
            finally:
                # Closing the gate before joining the child also releases it
                # when an assertion failed before the ordinary release byte.
                os.close(release_write)
                try:
                    if terminal is not None:
                        terminal.close()  # Includes exact terminal restoration.
                finally:
                    os.close(notify_read)
                    if notify_write is not None: os.close(notify_write)
                    if release_read is not None: os.close(release_read)
    print('Console input: four scheduled poll/read flush and signal cases, interrupt priority, ordinary Ctrl-D and terminal restoration passed.')
