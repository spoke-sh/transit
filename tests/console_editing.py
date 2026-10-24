"""Actual PTY editing modes and delayed metadata; no SQL execution claims."""
import json
import os
from pathlib import Path
import select
import tempfile
import threading
import time

from console_multiline import Screen, expect_draft
from console_terminal import Terminal, ANSI
from sql_sessions.editor_peer import peer


def check(binary):
    with tempfile.TemporaryDirectory(prefix='transit-editing-') as directory, peer() as (endpoint, actions):
        root = Path(directory)
        config = root / 'connection.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        (root / '.transit_history').write_text(''.join(json.dumps(s)+'\n' for s in ['SELECT *\nFROM items;', '.old', '.new', '.old']))
        terminal = Terminal(binary, config, home=root)
        terminal.display = Screen()
        terminal.display.feed(terminal.screen)
        def draft(lines, cursor=None):
            rows = ['transit> '+lines[0]] + ['    ...> '+line for line in lines[1:]]
            expect_draft(terminal, [row.rstrip() for row in rows], cursor or (len(lines)-1, 9+len(lines[-1])))
        try:
            terminal.send('first second')
            draft(['first second'])
            terminal.send('\x1a')
            draft(['first '])
            terminal.send('\x1f')
            draft(['first'])
            terminal.send('\x18\x15')
            draft([''])
            terminal.send('original')
            draft(['original'])
            terminal.send('\x12old')
            terminal.expect('>\r\n.old')
            terminal.send('\x1a')
            terminal.expect('search  >')
            terminal.send('\x07')
            draft(['original'])
            terminal.send('\x12old')
            terminal.expect('>\r\n.old')
            terminal.send('\x1b')
            draft([''])
            terminal.send('\x1a')
            draft(['original'])
            terminal.send('\x1b')
            draft([''])
            terminal.send('\x12select * from')
            terminal.expect('>\r\nSELECT *\r\nFROM items;')
            terminal.send('\t')
            draft(['SELECT *', 'FROM items;'])
            assert not [a for a, _ in actions if a == 'execute']
            terminal.send('\x1a')
            draft([''])
            terminal.send('\x12\x12')
            terminal.expect('>\r\n.old')
            terminal.send('\x1b[A')
            terminal.expect('>\r\n.new')
            terminal.send('\x1b[A')
            terminal.expect('>\r\nSELECT *')  # older duplicate .old skipped
            terminal.send('\x1b[B')
            terminal.expect('>\r\n.new')
            terminal.send('\x07')
            draft([''])
            terminal.send('\x1b[200~one\r\ntwo\nthree\x1b[201~')
            draft(['one', 'two', 'three'])
            terminal.send('\x1a')
            draft([''])
            terminal.send('\x1b[200~one\ntwo\nthree\x1b[201~')
            draft(['one', 'two', 'three'])
            terminal.send('\x1b[A')
            draft(['one', 'two', 'three'], (1, 12))
            terminal.send('\x1b[A')
            draft(['one', 'two', 'three'], (0, 12))
            terminal.send('\x0e')  # Direct history newer, at original draft: no-op.
            terminal.send('\r')
            draft(['one', '', 'two', 'three'], (1, 9))
            terminal.send('\x1a')
            draft(['one', 'two', 'three'], (0, 12))
            terminal.send('\x1b')
            draft([''])
            terminal.send('kept\x1b[')
            time.sleep(.3)  # Truncated CSI must not turn into bare Esc clear.
            terminal.send('x')
            draft(['keptx'])
            terminal.send('\x1b')
            draft([''])
            terminal.send('.mo\x00')
            draft(['.mode'])  # Proven unique static completion: no network.
            terminal.send('\x1a')
            draft(['.mo'])
            terminal.send('\x1b')
            draft([''])
            terminal.send('.qui\x1b[Z')
            terminal.expect('> .quit')
            terminal.send('\r')
            draft(['.quit'])
            assert terminal.process.poll() is None, 'completion Enter executed .quit'
            terminal.send('\x1b')
            draft([''])
            terminal.send('.timer o\t')
            terminal.expect('> off')
            assert 'transit> .timer o' in ANSI.sub(b'', terminal.screen).decode()
            terminal.send('\x1b[B\t')
            draft(['.timer on'])
            terminal.send('\x1a')
            draft(['.timer o'])
            terminal.send('\x07')
            draft(['.timer o'])
            assert all(action in ('hello', 'open') for action, _ in actions), actions
        finally:
            terminal.close()
    delayed(binary)
    execution_escape(binary)
    print('Console editing: general undo, clear/dismiss, search isolation/deduplication, vertical movement, literal paste, escape decoding and local completion passed.')


def delayed(binary):
    began = threading.Event()
    release = threading.Event()
    state = {'delay': False, 'coverage': 'complete', 'revision': 1, 'denied': False, 'calls': 0}
    def assist(value):
        state['calls'] += 1
        if state['delay']:
            began.set()
            release.wait(3)
        if state['denied']:
            return dict(err=dict(code='AccessDenied', sqlstate=list(b'42501'), message='Denied', retry='never', operation=None, diagnostic=None))
        text, cursor = value['text'], value['cursor']
        start = text.rfind(' ', 0, cursor) + 1
        return dict(assistance=dict(coverage=state['coverage'], status='ready', profile='catalog_v1', resource=4,
                                    contract=[7]*32, resource_revision=state['revision'], policy_revision='1',
                                    range=dict(start=start, end=len(text), quoted=False),
                                    items=[dict(text='SELECT', kind='keyword', detail='SQL grammar')]))
    with tempfile.TemporaryDirectory(prefix='transit-completion-') as directory, peer(assist=assist) as (endpoint, actions):
        root = Path(directory)
        config = root / 'connection.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        terminal = Terminal(binary, config, home=root)
        terminal.display = Screen()
        terminal.display.feed(terminal.screen)
        try:
            terminal.send('SE\t')
            expect_draft(terminal, ['transit> SELECT'], (0, 15))
            assert state['calls'] == 2, state  # reauthorization before unique insertion
            terminal.send('\x1a')
            expect_draft(terminal, ['transit> SE'], (0, 11))
            state['coverage'] = 'limited'
            terminal.send('\t')
            terminal.expect('> SELECT')
            terminal.expect('Limited list')
            terminal.send('\x07')
            expect_draft(terminal, ['transit> SE'], (0, 11))
            state['delay'] = True
            terminal.send('\t')
            assert began.wait(3)
            terminal.send('L')
            terminal.expect('transit> SEL', timeout=.6)
            terminal.send('\x1b')
            expect_draft(terminal, ['transit>'], (0, 9))
            release.set()
            time.sleep(.1)
            terminal.send('new')
            expect_draft(terminal, ['transit> new'], (0, 12))
            release.clear()
            began.clear()
            terminal.send('\x1b')
            expect_draft(terminal, ['transit>'], (0, 9))
            terminal.send('SE\t')
            assert began.wait(3)
            terminal.expect('Completion unavailable; Tab retries', timeout=2)
            terminal.send('L')
            terminal.expect('transit> SEL')
            release.set()
            state['delay'] = False
            terminal.send('\x1b')
            expect_draft(terminal, ['transit>'], (0, 9))
            terminal.send('SE\t')
            terminal.expect('> SELECT')
            state['revision'] = 2
            terminal.send('\t')
            terminal.expect('> SELECT')  # refreshed selection, no replay of acceptance
            terminal.send('\x07')
            expect_draft(terminal, ['transit> SE'], (0, 11))
            terminal.send('\t')
            terminal.expect('> SELECT')
            state['denied'] = True
            terminal.send('\t')
            expect_draft(terminal, ['transit>'], (0, 9))
            terminal.send('\x1a')
            expect_draft(terminal, ['transit>'], (0, 9))  # protected undo was purged
            assert not [a for a, _ in actions if a == 'execute'], actions
        finally:
            release.set()
            terminal.close()


def execution_escape(binary):
    began, release = threading.Event(), threading.Event()
    def execute(_):
        began.set()
        release.wait(3)
    with tempfile.TemporaryDirectory(prefix='transit-executing-') as directory, peer(execute=execute) as (endpoint, actions):
        root = Path(directory)
        config = root / 'connection.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        terminal = Terminal(binary, config, home=root)
        terminal.display = Screen()
        terminal.display.feed(terminal.screen)
        try:
            terminal.send('\x1b[200~SELECT 1;keep\x1b[201~\r')
            assert began.wait(3)
            terminal.send('\x1b')
            time.sleep(.1)
            release.set()
            expect_draft(terminal, ['transit> keep', '    ...>'], (1, 9))
            time.sleep(.1)
            terminal.send('x')
            expect_draft(terminal, ['transit> keep', '    ...> x'], (1, 10))
            assert [value['sql'] for action, value in actions if action == 'execute'] == ['SELECT 1;']
        finally:
            release.set()
            terminal.close()
