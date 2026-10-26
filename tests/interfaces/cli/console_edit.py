"""Real PTY/editor processes and save events; the peer only observes submissions."""
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import tempfile
import time

from interfaces.cli.console_terminal import Terminal
from interfaces.sql_sessions.editor_peer import peer


EDITOR = r'''
import json, os, signal, stat, sys, termios, time
from pathlib import Path

mode, record, path = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
attributes = termios.tcgetattr(0)
assert attributes[3] & termios.ICANON and attributes[3] & termios.ECHO
deadline = time.monotonic() + 5
while os.tcgetpgrp(0) != os.getpgrp():
    assert time.monotonic() < deadline, 'editor must own the terminal'
    time.sleep(.001)
assert stat.S_IMODE(path.stat().st_mode) == 0o600
assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700
original = path.read_text()
record.write_text(json.dumps(dict(initial=original, path=str(path), pid=os.getpid())))
print('EDITOR READY', flush=True)  # Must stay off console result stdout.
if mode == 'unchanged':
    path.write_text(original)
elif mode == 'atomic':
    replacement = path.with_suffix('.new')
    replacement.write_text('SELECT edited FROM items;\n')
    replacement.replace(path)
elif mode == 'changed':
    path.write_text('SELECT edited FROM items;\n')
elif mode == 'no-semicolon':
    path.write_text('SELECT edited FROM items')
elif mode == 'local-count':
    path.write_text('SELECT COUNT(*) FROM items;\n')
elif mode == 'empty':
    path.write_text(' \n\t')
elif mode == 'oversized':
    path.write_text('x' * 4097)
elif mode == 'invalid':
    path.write_bytes(b'SELECT \xff;')
elif mode == 'dot':
    path.write_text('.edit')
elif mode == 'symlink':
    other = path.with_suffix('.other')
    other.write_text('SELECT must_not_run;')
    path.unlink()
    path.symlink_to(other)
    # A write notification does not allow following the new symlink.
    with path.open('w') as output:
        output.write('SELECT must_not_run;')
    replacement = path.with_suffix('.link')
    replacement.symlink_to(other)
    replacement.replace(path)
elif mode == 'failure':
    path.write_text('SELECT must_not_run;')
    sys.exit(7)
elif mode == 'signal':
    path.write_text('SELECT must_not_run;')
    os.kill(os.getpid(), signal.SIGTERM)
elif mode == 'interactive':
    assert input() == 'save'
    path.write_text(original)
    print('EDITOR SAVED', flush=True)
    assert input() == 'close'
elif mode == 'wait':
    while True:
        time.sleep(.1)
elif mode != 'quit':
    raise AssertionError(mode)
'''


def editor_command(root, mode):
    script = root / 'editor with spaces.py'
    script.write_text(EDITOR)
    record = root / 'editor-record.json'
    return shlex.join([sys.executable, str(script), mode, str(record)]), record


def executed(actions):
    return [value['sql'] for action, value in actions if action == 'execute']


def check(binary):
    with tempfile.TemporaryDirectory(prefix='transit-edit-proof-') as temporary, peer(lease_ms=600) as (endpoint, actions):
        root = Path(temporary)
        config = root / 'console.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        initial = 'SELECT /* 東京\nsecond line */ missing FROM items;'
        for mode in ('quit', 'unchanged', 'changed', 'atomic', 'empty', 'failure', 'signal', 'oversized', 'invalid', 'dot', 'symlink'):
            home = root / mode
            home.mkdir()
            history = home / '.transit_history'
            history.write_text(json.dumps(initial) + '\n".help"\n".edit"\n')
            command, record = editor_command(home, mode)
            before = len(executed(actions))
            terminal = Terminal(binary, config, home=home, env={'EDITOR': command, 'TMPDIR': str(home)})
            try:
                terminal.send('.edit\r')
                terminal.expect('EDITOR READY')
                terminal.screen = terminal.screen.split(b'EDITOR READY', 1)[1]
                if mode in ('unchanged', 'changed', 'atomic'):
                    terminal.expect('SQL service: InvalidSqlSyntax')
                elif mode in ('failure', 'signal'):
                    terminal.expect('editor did not exit successfully')
                elif mode == 'oversized':
                    terminal.expect('StatementTooLarge')
                elif mode == 'invalid':
                    terminal.expect('InvalidSqlEncoding')
                elif mode == 'dot':
                    terminal.expect('.edit accepts SQL')
                elif mode == 'symlink':
                    terminal.expect('editor output must be a regular SQL file')
                terminal.expect('transit> ')
                edited = json.loads(record.read_text())
                assert edited['initial'] == initial, (mode, edited)
                assert not Path(edited['path']).parent.exists(), (mode, 'temporary files remain')
                expected = [initial] if mode == 'unchanged' else ['SELECT edited FROM items;'] if mode in ('changed', 'atomic') else []
                assert executed(actions)[before:] == expected, (mode, executed(actions)[before:])
                records = [json.loads(line) for line in history.read_text().splitlines()]
                assert records == [initial, '.help', '.edit', '.edit', *expected], (mode, records)
            finally:
                terminal.close()

        # An unchanged save cannot submit while the editor is still open. Failed
        # SQL from this very session is eligible, including after a dot command.
        home = root / 'interactive'
        home.mkdir()
        command, record = editor_command(home, 'interactive')
        terminal = Terminal(binary, config, home=home, env={'EDITOR': command, 'TMPDIR': str(home)})
        try:
            terminal.send(initial.replace('\n', ' ') + '\r')
            terminal.expect('SQL service: InvalidSqlSyntax')
            terminal.send('.timer off\r')
            terminal.expect('transit> ')
            before = len(executed(actions))
            terminal.send('.edit\r')
            terminal.expect('EDITOR READY')
            assert json.loads(record.read_text())['initial'] == initial.replace('\n', ' ')
            terminal.send('save\r')
            terminal.expect('EDITOR SAVED')
            touches = sum(action == 'touch' for action, _ in actions)
            deadline = time.monotonic() + 5
            while sum(action == 'touch' for action, _ in actions) == touches:
                assert time.monotonic() < deadline, 'session was not kept alive in editor'
                time.sleep(.01)
            assert len(executed(actions)) == before
            terminal.send('close\r')
            terminal.expect('SQL service: InvalidSqlSyntax')
            assert executed(actions)[before:] == [initial.replace('\n', ' ')]
            assert not Path(json.loads(record.read_text())['path']).parent.exists()
            terminal.send('\x04')
            assert terminal.process.wait(timeout=10) == 0
            assert terminal.process.stdout.read() == b'', 'editor UI contaminated result stdout'
        finally:
            terminal.close()

        # No prior SQL opens an empty file. A fresh save need not end in a
        # semicolon; it is submitted through the same one-statement SQL call.
        home = root / 'empty-history'
        home.mkdir()
        command, record = editor_command(home, 'no-semicolon')
        terminal = Terminal(binary, config, home=home, env={'EDITOR': command, 'TMPDIR': str(home)})
        try:
            terminal.send('.edit\r')
            terminal.expect('SQL service: InvalidSqlSyntax')
            assert json.loads(record.read_text())['initial'] == ''
            assert executed(actions)[-1] == 'SELECT edited FROM items'
        finally:
            terminal.close()

        # Interrupting the parent cancels/reaps its editor and restores the TTY.
        for sig in (signal.SIGINT, signal.SIGTERM):
            home = root / f'interrupt-{sig}'
            home.mkdir()
            command, record = editor_command(home, 'wait')
            terminal = Terminal(binary, config, home=home, env={'EDITOR': command, 'TMPDIR': str(home)})
            before = len(executed(actions))
            try:
                terminal.send('.edit\r')
                terminal.expect('EDITOR READY')
                edited = json.loads(record.read_text())
                terminal.screen = terminal.screen.split(b'EDITOR READY', 1)[1]
                os.kill(terminal.process.pid, sig)
                if sig == signal.SIGINT:
                    terminal.expect('transit> ')
                else:
                    assert terminal.process.wait(timeout=10) == 130
                assert not Path(edited['path']).parent.exists()
                assert len(executed(actions)) == before
                try:
                    os.kill(edited['pid'], 0)
                except ProcessLookupError:
                    pass
                else:
                    raise AssertionError('editor survived console interruption')
            finally:
                terminal.close()

        # Bad editor configuration and batch input cannot launch a process.
        for command, error in ((None, 'set EDITOR'), ('', 'set EDITOR'), ('"unterminated', 'EDITOR must contain'), ('/no/such/editor', 'could not start EDITOR')):
            terminal = Terminal(binary, config, env={'EDITOR': command})
            try:
                before = len(executed(actions))
                terminal.send('.edit\r')
                terminal.expect(error)
                assert len(executed(actions)) == before
            finally:
                terminal.close()
        # An editor failure after a submitted paste prefix must not leave that
        # prefix in the draft for the next Enter to submit again.
        terminal = Terminal(binary, config, env={'EDITOR': None})
        try:
            before = len(executed(actions))
            terminal.send('\x1b[200~SELECT prefix FROM items;\n.edit\n\x1b[201~\r')
            terminal.expect('set EDITOR')
            assert executed(actions)[before:] == ['SELECT prefix FROM items;']
            terminal.send('\r')
            terminal.expect('transit> ')
            assert executed(actions)[before:] == ['SELECT prefix FROM items;']
        finally:
            terminal.close()
        result = subprocess.run([binary, 'console', '--no-rc', '--config', str(config)], input=b'.edit\n', capture_output=True, timeout=10)
        assert result.returncode == 1 and b'.edit requires an interactive terminal' in result.stderr and not result.stdout, result
        result = subprocess.run([binary, 'console', '--no-rc', '--config', str(config)], input=b'.edit file.sql\n', capture_output=True, timeout=10)
        assert result.returncode == 1 and b'.edit does not accept arguments' in result.stderr, result



def local_edit(binary, cwd):
    """A saved edit reaches the actual server's SQL owner and returns real rows."""
    with tempfile.TemporaryDirectory(prefix='transit-edit-local-') as temporary:
        home = Path(temporary)
        command, record = editor_command(home, 'local-count')
        terminal = Terminal(binary, format='table', shared_output=True, cwd=cwd, home=home,
                            env={'EDITOR': command, 'TMPDIR': str(home), 'XDG_RUNTIME_DIR': None})
        try:
            terminal.send('SELECT typo FROM items;\r')
            terminal.expect('error:')
            terminal.send('.edit\r')
            terminal.expect('EDITOR READY')
            terminal.expect('1 rows; complete coverage', timeout=120)
            assert json.loads(record.read_text())['initial'] == 'SELECT typo FROM items;'
            assert not Path(json.loads(record.read_text())['path']).parent.exists()
            records = [json.loads(line) for line in (home / '.transit_history').read_text().splitlines()]
            assert records == ['SELECT typo FROM items;', '.edit', 'SELECT COUNT(*) FROM items;'], records
        finally:
            terminal.close()
    print('Transit console .edit: failed SQL history edited and executed through the real local SQL service.', flush=True)


def check_vim(binary, vim):
    with tempfile.TemporaryDirectory(prefix='transit-edit-vim-') as temporary, peer() as (endpoint, actions):
        root = Path(temporary)
        config = root / 'console.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        sql = 'SELECT vim_history FROM items;\n'
        (root / '.transit_history').write_text(json.dumps(sql) + '\n')
        terminal = Terminal(binary, config, home=root, env={'EDITOR': shlex.join([vim, '-u', 'NONE', '-i', 'NONE', '-n']), 'TMPDIR': str(root), 'TERM': 'xterm'})
        try:
            terminal.send('.edit\r')
            terminal.expect('query.sql')
            terminal.send(':q\r')
            terminal.expect('transit> ')
            assert not executed(actions), 'vim :q submitted SQL'
            terminal.send('.edit\r')
            terminal.expect('query.sql')
            terminal.send(':wq\r')
            terminal.expect('SQL service: InvalidSqlSyntax')
            assert executed(actions) == [sql.strip()]
            assert not list(root.glob('transit-edit-*'))
        finally:
            terminal.close()
    print('Console .edit with real Vim: :q does not submit; unchanged :wq submits once and restores the terminal.')


if __name__ == '__main__':
    binary = str(Path(sys.argv[1]).resolve())
    check(binary)
    if len(sys.argv) > 2:
        check_vim(binary, sys.argv[2])
