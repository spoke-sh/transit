"""Real PTY history across processes; no native service or execution needed."""
import fcntl
import json
import os
from pathlib import Path
import select
import stat
import subprocess
import sys
import tempfile
import threading

from console_terminal import Terminal, ANSI
from console_signals import check as check_signals
from console_edit import check as check_edit
from console_help import check as check_help
from console_outcomes import check as check_outcomes
from console_multiline import check as check_multiline
from console_editing import check as check_editing
from sql_sessions.editor_peer import peer as session_peer


def clear(terminal):
    terminal.send('\x03')
    terminal.expect('transit> ')


def command(terminal, text):
    terminal.send(text + '\r')
    terminal.expect('error:')  # Deliberately invalid, recorded before validation.


def search(terminal, query, result):
    terminal.send('\x12' + query)
    terminal.expect('>\r\n' + result)


def check(binary, signal_gate):
    with tempfile.TemporaryDirectory(prefix='transit-history-') as directory, session_peer() as (endpoint, actions):
        root = Path(directory)
        home = root / 'home'
        home.mkdir()
        config = root / 'console.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        history = home / '.transit_history'
        terminal = Terminal(binary, config, home=home)
        multiline = "SELECT /* 東京\nsecond line */;"
        try:
            terminal.send('\x12')
            terminal.expect('search  >\r\n(type to search)')
            terminal.send('absent')
            terminal.expect('(no match)')
            terminal.send('\x1b')
            terminal.expect('transit> ')
            for i in range(12):
                command(terminal, f'.unknown_history_{i:02}')
            terminal.send('\x1b[200~' + multiline + '\x1b[201~\r')
            terminal.expect('error:')
            records = [json.loads(line) for line in history.read_text().splitlines()]
            assert records == [f'.unknown_history_{i:02}' for i in range(12)] + [multiline], records
            assert stat.S_IMODE(history.stat().st_mode) == 0o600
            terminal.send('draft')
            terminal.expect('transit> draft')
            search(terminal, 'history_', '.unknown_history_11')
            terminal.send('\x12')
            terminal.expect('>\r\n.unknown_history_10')
            terminal.send('absent')
            terminal.expect('(no match)')
            terminal.send('\x7f' * 6)
            terminal.expect('>\r\n.unknown_history_11')
            terminal.send('\x07')
            terminal.expect('transit> draft')
            clear(terminal)
            search(terminal, 'history_00', '.unknown_history_00')
            terminal.send('\r')
            terminal.expect('transit> .unknown_history_00')
            assert b'error:' not in ANSI.sub(b'', terminal.screen), 'search acceptance executed the match'
            assert history.read_text().count('unknown_history_00') == 1
            # A second Enter explicitly submits the recalled dot command.
            terminal.send('\r')
            terminal.expect('error:')
            assert history.read_text().count('unknown_history_00') == 2
            terminal.send('unfinished input')
            terminal.expect('unfinished input')
            clear(terminal)
        finally:
            terminal.close()
        assert 'unfinished' not in history.read_text()
        # Saved records stay literal, and malformed/control/oversized/torn lines
        # do not become commands or prevent older records from being searched.
        with history.open('a') as output:
            output.write('bad json\n' + json.dumps('.bad\x1b[2J') + '\n' + 'x' * 50000 + '\n"torn')
        terminal = Terminal(binary, config, home=home)
        peer = Terminal(binary, config, home=home)
        try:
            search(terminal, 'history_00', '.unknown_history_00')
            clear(terminal)
            search(terminal, '東京', 'SELECT /* \\u{6771}')
            terminal.send('\x7f')  # Removes the complete UTF-8 character.
            terminal.expect('search \\u{6771} >')
            terminal.send('\t')
            terminal.expect('   ...> ')
            terminal.send('\r')
            terminal.expect('error:')
            assert sum(line == json.dumps(multiline, ensure_ascii=False) for line in history.read_text().splitlines()) == 2
            search(terminal, '\x1b[200~東京\rsecond\x1b[201~', 'SELECT /* \\u{6771}')
            clear(terminal)
            command(terminal, '.first_session')
            command(peer, '.second_session')
            search(terminal, 'second_session', '.second_session')
            clear(terminal)
            terminal.send('keep draft\x1b[A')
            terminal.expect('transit> .second_session')
            terminal.send('\x1b[A')
            terminal.expect('transit> .first_session')
            terminal.send('\x1b[B\x1b[B')
            terminal.expect('transit> keep draft')
            clear(terminal)
            terminal.send('original\x12missing\x07')
            terminal.expect('transit> original')
            clear(terminal)
            terminal.resize(8)
            search(terminal, '', '')
            terminal.send('history')
            terminal.resize(80)
            terminal.screen = b''
            terminal.expect('search history >\r\n.unknown_history_00')
            clear(terminal)
        finally:
            terminal.close()
            peer.close()
        saved = history.read_bytes()
        assert b'".first_session"\n' in saved and b'".second_session"\n' in saved
        with history.open('r+') as locked:
            terminal = Terminal(binary, config, home=home)
            try:
                fcntl.flock(locked, fcntl.LOCK_EX)
                release = threading.Timer(.05, lambda: fcntl.flock(locked, fcntl.LOCK_UN))
                release.start()
                try:
                    command(terminal, '.waited_for_lock')
                finally:
                    release.join()
                assert b'".waited_for_lock"\n' in history.read_bytes()
                fcntl.flock(locked, fcntl.LOCK_EX)
                command(terminal, '.busy_lock_fallback')
                terminal.expect('history file unavailable (HistoryBusy)')
                assert b'busy_lock_fallback' not in history.read_bytes()
                search(terminal, 'busy_lock', '.busy_lock_fallback')
                clear(terminal)
            finally:
                fcntl.flock(locked, fcntl.LOCK_UN)
                terminal.close()
        saved = history.read_bytes()
        # Batch/rc input does not populate or touch interactive history.
        result = subprocess.run([binary, 'console', '--no-rc', '--config', str(config)], input=b'.help\n',
                                env=os.environ | {'HOME': str(home)}, capture_output=True, timeout=10)
        assert result.returncode == 0 and not result.stderr, result
        assert history.read_bytes() == saved
        for kind in ('directory', 'symlink', 'missing-home'):
            unavailable = root / kind
            if kind != 'missing-home':
                unavailable.mkdir()
                if kind == 'directory': (unavailable / '.transit_history').mkdir()
                else: (unavailable / '.transit_history').symlink_to(history)
            terminal = Terminal(binary, config, home=unavailable)
            try:
                terminal.expect('history file unavailable')
                command(terminal, '.session_only')
                search(terminal, 'session_only', '.session_only')
                clear(terminal)
            finally:
                terminal.close()
        assert history.read_bytes() == saved, 'fallback modified another history file'
        with history.open('a') as output:
            output.write('".signal_schedule"\n')
        saved = history.read_bytes()
        check_signals(binary, config, home, signal_gate)
        assert history.read_bytes() == saved, 'signal schedule executed an old draft'
        assert [value['sql'] for action, value in actions if action == 'execute'] == [multiline, multiline], 'Editing dispatched an unsubmitted draft'
    print('Console history: PTY search/accept/cancel, dot commands, Unicode/multiline, restart, concurrent append, bounded malformed records, private permissions and unavailable-file fallback passed.')


if __name__ == '__main__':
    check_multiline(str(Path(sys.argv[1]).resolve()))
    check_editing(str(Path(sys.argv[1]).resolve()))
    check(str(Path(sys.argv[1]).resolve()), Path(sys.argv[2]).resolve())
    check_edit(str(Path(sys.argv[1]).resolve()))

    check_help(str(Path(sys.argv[1]).resolve()))
    check_outcomes(str(Path(sys.argv[1]).resolve()))
