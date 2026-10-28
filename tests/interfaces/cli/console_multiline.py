"""Real PTY draft rendering, with cursor/erase interpretation instead of ANSI stripping."""
import codecs
import json
import os
from pathlib import Path
import re
import select
import tempfile
import time

from interfaces.cli.console_terminal import Terminal
from interfaces.sql_sessions.editor_peer import peer


class Screen:
    """The VT cursor, erasure and scrolling subset used by the console."""
    def __init__(self, columns=80, rows=24):
        self.columns, self.rows = columns, rows
        self.lines = [[' '] * columns for _ in range(rows)]
        self.row = self.column = 0
        self.pending = ''
        self.decoder = codecs.getincrementaldecoder('utf-8')()

    def feed(self, block):
        self.pending += self.decoder.decode(block)
        while self.pending:
            char = self.pending[0]
            if char == '\x1b':
                match = re.match(r'\x1b\[([0-?]*)([ -/]*)([@-~])', self.pending)
                if match is None:
                    assert len(self.pending) < 32, self.pending
                    return
                parameters, _, command = match.groups()
                self.pending = self.pending[match.end():]
                value = int(parameters or '0') if not parameters.startswith('?') and ';' not in parameters else 0
                if command == 'A': self.row = max(0, self.row - (value or 1))
                elif command == 'C': self.column = min(self.columns - 1, self.column + (value or 1))
                elif command == 'J':
                    assert value == 0
                    self.lines[self.row][self.column:] = [' '] * (self.columns - self.column)
                    for row in range(self.row + 1, self.rows): self.lines[row] = [' '] * self.columns
                elif command == 'K':
                    assert value == 2
                    self.lines[self.row] = [' '] * self.columns
                else:
                    assert command == 'm' or (parameters == '?2004' and command in 'hl'), match.group()
                continue
            self.pending = self.pending[1:]
            if char == '\r': self.column = 0
            elif char == '\n': self.advance()
            else:
                assert ord(char) >= 32, repr(char)
                if self.column == self.columns:
                    self.column = 0
                    self.advance()
                self.lines[self.row][self.column] = char
                self.column += 1

    def advance(self):
        self.row += 1
        if self.row == self.rows:
            self.lines.pop(0)
            self.lines.append([' '] * self.columns)
            self.row -= 1

    def text(self):
        return [''.join(line).rstrip() for line in self.lines]

    def resize(self, columns, rows=24):
        self.lines = [(line + [' '] * columns)[:columns] for line in self.lines]
        if rows < self.rows:
            removed = max(0, self.row + 1 - rows)
            self.lines = self.lines[removed:removed + rows]
            self.row -= removed
        else:
            self.lines += [[' '] * columns for _ in range(rows - self.rows)]
        self.columns, self.rows = columns, rows
        self.column = min(self.column, columns - 1)


def expect_draft(terminal, lines, cursor):
    deadline = time.monotonic() + 10
    while True:
        screen = terminal.display
        content = screen.text()
        matches = [i for i in range(screen.rows - len(lines) + 1) if content[i:i + len(lines)] == lines]
        if matches:
            start = matches[-1]
            if (screen.row, screen.column) == (start + cursor[0], cursor[1]) and not any(content[start + len(lines):]):
                return
        assert terminal.process.poll() is None, ('terminal exited', terminal.process.returncode)
        assert time.monotonic() < deadline, (lines, cursor, content, (screen.row, screen.column))
        if select.select([terminal.master], [], [], .1)[0]:
            terminal.record_display(os.read(terminal.master, 65536))


def check(binary):
    with tempfile.TemporaryDirectory(prefix='transit-multiline-') as directory, peer() as (endpoint, actions):
        root = Path(directory)
        config = root / 'console.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        terminal = Terminal(binary, config, home=root, env={'TERM': 'xterm', 'NO_COLOR': None})
        terminal.display = Screen()
        terminal.display.feed(terminal.screen)
        try:
            terminal.send('SELECT *\r')
            expect_draft(terminal, ['transit> SELECT *', '    ...>'], (1, 9))
            assert b'\x1b[36m' in terminal.screen, 'SQL token colors were lost'
            terminal.send('FROM items')
            expect_draft(terminal, ['transit> SELECT *', '    ...> FROM items'], (1, 19))
            assert not [a for a, _ in actions if a == 'execute']

            # Cross the newline in both directions; delete and restore it.
            terminal.send('\x1b[D' * 10)
            expect_draft(terminal, ['transit> SELECT *', '    ...> FROM items'], (1, 9))
            terminal.send('\x1b[D')
            expect_draft(terminal, ['transit> SELECT *', '    ...> FROM items'], (0, 17))
            terminal.send('\x1b[C\x7f')
            expect_draft(terminal, ['transit> SELECT *FROM items'], (0, 17))
            terminal.send('\x1b[200~\n\x1b[201~')
            expect_draft(terminal, ['transit> SELECT *', '    ...> FROM items'], (1, 9))
            terminal.send('\x05;')
            expect_draft(terminal, ['transit> SELECT *', '    ...> FROM items;'], (1, 20))
            terminal.send('\r')
            terminal.expect('SQL service: InvalidSqlSyntax')
            expect_draft(terminal, ['transit>'], (0, 9))
            content = terminal.display.text()
            assert content.count('transit> SELECT *') == content.count('    ...> FROM items;') == 1, content
            assert [value['sql'] for action, value in actions if action == 'execute'] == ['SELECT *\nFROM items;']

            # Recalling/searching preserves the actual multiline draft.
            terminal.send('\x1b[A')
            expect_draft(terminal, ['transit> SELECT *', '    ...> FROM items;'], (1, 20))
            terminal.send('\x12\r')
            expect_draft(terminal, ['transit> SELECT *', '    ...> FROM items;'], (1, 20))
            terminal.send('\x03')
            expect_draft(terminal, ['transit>'], (0, 9))
            assert terminal.display.text().count('    ...> FROM items;') == 1, 'cancel left stale draft rows'

            # Visible frame bytes can precede completion of the joined output
            # task. Ctrl-C at that boundary still clears editing, not the shell.
            for _ in range(32):
                terminal.send('render interrupt')
                expect_draft(terminal, ['transit> render interrupt'], (0, 25))
                terminal.send('\x03')
                expect_draft(terminal, ['transit>'], (0, 9))
            assert [value['sql'] for action, value in actions if action == 'execute'] == ['SELECT *\nFROM items;']

            # Blank lines, paste and Ctrl-U; nothing submits without Enter.
            terminal.send('\x1b[200~SELECT *\n\nFROM items;\x1b[201~')
            expect_draft(terminal, ['transit> SELECT *', '    ...>', '    ...> FROM items;'], (2, 20))
            terminal.send('\x15')
            expect_draft(terminal, ['transit>'], (0, 9))

            # Width changes reflow the same draft, with escaped Unicode still
            # owning one input character when deleting across a row boundary.
            text = 'SELECT abcdefghijklmnopqrstuvwxyz'
            terminal.send('\x1b[200~' + text + '\nFROM items\x1b[201~')
            expect_draft(terminal, ['transit> ' + text, '    ...> FROM items'], (1, 19))
            terminal.display.resize(24)
            terminal.resize(24)
            expect_draft(terminal, ['transit> ' + text[:14], '    ...> ' + text[14:28],
                                    '    ...> ' + text[28:], '    ...> FROM items'], (3, 19))
            terminal.display.resize(80)
            terminal.resize(80)
            expect_draft(terminal, ['transit> ' + text, '    ...> FROM items'], (1, 19))
            terminal.send('\x15\x1b[200~SELECT 東京\nFROM items\x1b[201~')
            expect_draft(terminal, [r'transit> SELECT \u{6771}\u{4eac}', '    ...> FROM items'], (1, 19))
            terminal.send('\x1b[D' * 11 + '\x7f')
            expect_draft(terminal, [r'transit> SELECT \u{6771}', '    ...> FROM items'], (0, 24))
            terminal.send('\x03')
            expect_draft(terminal, ['transit>'], (0, 9))

            # A full-width row wraps before the next character, leaving room
            # for the end cursor; Home/End keep it on the corresponding row.
            terminal.send('x' * 70)
            expect_draft(terminal, ['transit> ' + 'x' * 70], (0, 79))
            terminal.send('y')
            expect_draft(terminal, ['transit> ' + 'x' * 70, '    ...> y'], (1, 10))
            terminal.send('\x01')
            expect_draft(terminal, ['transit> ' + 'x' * 70, '    ...> y'], (0, 9))
            terminal.send('\x05\x7f')
            expect_draft(terminal, ['transit> ' + 'x' * 70], (0, 79))
            terminal.send('\x15')
            expect_draft(terminal, ['transit>'], (0, 9))

            # More lines than the screen: the viewport follows the cursor and
            # can be cleared without leaving old draft lines on screen.
            terminal.send('\x1b[200~' + '\n'.join(f'line{i:02}' for i in range(40)) + '\x1b[201~')
            expect_draft(terminal, [f'    ...> line{i:02}' for i in range(17, 40)], (22, 15))
            terminal.send('\x01')
            expect_draft(terminal, ['transit> line00'] + [f'    ...> line{i:02}' for i in range(1, 23)], (0, 9))
            terminal.send('\x05')
            expect_draft(terminal, [f'    ...> line{i:02}' for i in range(17, 40)], (22, 15))
            terminal.display.resize(80, 8)
            terminal.resize(80, 8)
            expect_draft(terminal, [f'    ...> line{i:02}' for i in range(33, 40)], (6, 15))
            terminal.send('\x03')
            expect_draft(terminal, ['transit>'], (0, 9))
            assert not any('line' in line for line in terminal.display.text()), terminal.display.text()
            terminal.display.resize(8, 8)
            terminal.resize(8, 8)
            expect_draft(terminal, ['tran'], (0, 4))
            terminal.send('\x1b[200~東京\nx\x1b[201~')
            expect_draft(terminal, ['tran??', '..> x'], (1, 5))
            terminal.send('\x03')
            expect_draft(terminal, ['tran'], (0, 4))
            assert len([a for a, _ in actions if a == 'execute']) == 1
        finally:
            terminal.close()
    print('Console multiline: aligned rows, cursor movement, paste/history, submission, wrapping, resize, Unicode, viewport and clearing passed.')
