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


def idle_menu(terminal, selected):
    # Keep consuming the real display past the former five-second refresh.
    until = time.monotonic() + 6
    while time.monotonic() < until:
        assert terminal.process.poll() is None, 'terminal exited while idle'
        if select.select([terminal.master], [], [], .1)[0]:
            terminal.record_display(os.read(terminal.master, 65536))
    assert selected in terminal.display.text(), terminal.display.text()


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
            terminal.send('\x1b[B')
            terminal.expect('> on')
            idle_menu(terminal, '> on')
            terminal.send('\t')
            draft(['.timer on'])
            terminal.send('\x1a')
            draft(['.timer o'])
            terminal.send('\x07')
            draft(['.timer o'])
            terminal.send('\t\x1b[B')
            terminal.expect('> on')
            terminal.send('n')
            terminal.expect('transit> .timer on')
            terminal.expect('> on')
            assert 'off' not in '\n'.join(terminal.display.text()), terminal.display.text()
            terminal.send('\x7f')
            terminal.expect('> on')  # synchronous local refresh preserves selection
            assert 'off' in '\n'.join(terminal.display.text()), terminal.display.text()
            terminal.send('\x07')
            draft(['.timer o'])
            assert all(action in ('hello', 'open', 'touch') for action, _ in actions), actions
        finally:
            terminal.close()
    delayed(binary)
    responsive(binary)
    session_loss(binary)
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
        if state.get('unavailable'):
            return dict(err=dict(code='AuthorityUnavailable', sqlstate=list(b'53000'), message='Unavailable', retry='never', operation=None, diagnostic=None))
        text, cursor = value['text'], value['cursor']
        start = text.rfind(' ', 0, cursor) + 1
        return dict(assistance=dict(coverage=state['coverage'], status='ready', profile='catalog_v1', resource=4,
                                    contract=[7]*32, resource_revision=state['revision'], policy_revision='1',
                                    range=dict(start=start, end=len(text), quoted=False),
                                    items=[] if state.get('empty') else [dict(text=text, kind='keyword', detail='SQL grammar') for text in state.get('candidates', [state.get('candidate', 'SELECT')])]))
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
            state['candidates'] = ['SELECT', 'SET']
            terminal.send('\t')
            terminal.expect('> SELECT')
            terminal.expect('Limited list')
            terminal.send('\x1b[B')
            terminal.expect('> SET')
            calls = state['calls']
            idle_menu(terminal, '> SET')
            assert state['calls'] == calls, 'idle menu reacquired metadata'
            terminal.send('\t')
            expect_draft(terminal, ['transit> SET'], (0, 12))
            assert state['calls'] == calls + 1, 'acceptance must revalidate metadata'
            terminal.send('\x1a')
            expect_draft(terminal, ['transit> SE'], (0, 11))
            state.pop('candidates')
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
            terminal.send('\x1b')
            expect_draft(terminal, ['transit>'], (0, 9))
            state['candidate'] = '"' + 'a' * 120 + 'tail"'
            terminal.resize(20, 6)
            terminal.display.resize(20, 6)
            terminal.send('a\t')
            terminal.expect('> "aaaa')
            terminal.send('\x1b[6~' * 6)
            terminal.expect('tail"')  # full selected spelling remains accessible
            terminal.send('\x1b')
            expect_draft(terminal, ['transit>'], (0, 9))
            terminal.resize(80)
            terminal.display.resize(80)
            state.pop('candidate')
            state['empty'] = True
            state['coverage'] = 'complete'
            terminal.send('SE\t')
            terminal.expect('No matching suggestions')
            terminal.send('\r')
            expect_draft(terminal, ['transit> SE'], (0, 11))
            state['empty'] = False
            state['coverage'] = 'limited'
            state['unavailable'] = True
            terminal.send('\t')
            terminal.expect('Completion unavailable; Tab retries')
            terminal.send('\x07')
            expect_draft(terminal, ['transit> SE'], (0, 11))
            state['unavailable'] = False
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


def responsive(binary):
    began, release = threading.Event(), threading.Event()
    calls = []
    def assist(value):
        text = value['text']
        calls.append(text)
        began.set()
        assert release.wait(3), 'test did not release metadata'
        candidates = {'SE': ['SELECT', 'SET'], 'SET': ['SET', 'SETTINGS'],
                      'SEL': ['SELECT'], 'SELE': ['SELECT'], 'SEZ': ['SEZ_NEW']}.get(text, [])
        return dict(assistance=dict(coverage='limited', status='ready', profile='catalog_v1', resource=4,
                                    contract=[7]*32, resource_revision=1, policy_revision='1',
                                    range=dict(start=0, end=len(text), quoted=False),
                                    items=[dict(text=item, kind='keyword', detail='SQL grammar') for item in candidates]))
    with tempfile.TemporaryDirectory(prefix='transit-responsive-') as directory, peer(assist=assist) as (endpoint, actions):
        root = Path(directory)
        config = root / 'connection.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        terminal = Terminal(binary, config, home=root)
        terminal.display = Screen()
        terminal.display.feed(terminal.screen)
        def observe(seconds=.2):
            until = time.monotonic() + seconds
            while time.monotonic() < until:
                assert terminal.process.poll() is None
                if select.select([terminal.master], [], [], .01)[0]:
                    terminal.record_display(os.read(terminal.master, 65536))
            for placeholder in (b'Loading suggestions', b'Checking suggestion', b'Suggestions'):
                assert placeholder not in terminal.screen, terminal.screen
            return '\n'.join(terminal.display.text())
        def pause():
            release.clear()
            began.clear()
        try:
            terminal.send('SE\t')
            assert began.wait(.6), 'opening should start acquisition immediately'
            observe()
            expect_draft(terminal, ['transit> SE'], (0, 11))  # no initial placeholder or menu space
            release.set()
            terminal.expect('> SELECT')
            terminal.send('\x1b[B')
            terminal.expect('> SET')
            pause()
            terminal.send('T')
            terminal.expect('transit> SET', timeout=.6)
            screen = observe()
            assert '> SET' in screen and 'SELECT' not in screen, screen
            assert began.is_set() and calls == ['SE', 'SET'], calls
            terminal.send('\t\r')  # pending refresh must not replay acceptance or submit
            assert '> SET' in observe()
            release.set()
            terminal.expect('SETTINGS')
            assert 'transit> SET' in observe()
            pause()
            terminal.send('\x7f')
            assert '> SET' in observe(), terminal.display.text()
            assert began.is_set()
            release.set()
            terminal.expect('  SELECT')
            assert '> SET' in observe(), 'selection must survive result reordering'
            pause()
            terminal.send('\t')
            assert began.wait(.6)
            assert '> SET' in observe(), 'validation must keep the menu visible'
            release.set()
            expect_draft(terminal, ['transit> SET'], (0, 12))

            terminal.send('\x1b')
            expect_draft(terminal, ['transit>'], (0, 9))
            terminal.send('SE\t')
            terminal.expect('> SELECT')
            pause()
            terminal.send('L')
            assert began.wait(.6)
            terminal.send('ECT\x7f\x7f')  # coalesce several edits while SEL is in flight
            screen = observe()
            assert 'transit> SELE' in screen and '> SELECT' in screen, screen
            assert calls[-1] == 'SEL', calls
            count = len(calls)
            release.set()
            terminal.expect('> SELECT')
            observe()
            assert calls[count:] == ['SELE'], calls  # no intervening drafts acquired
            terminal.send('\x07')
            expect_draft(terminal, ['transit> SELE'], (0, 13))

            terminal.send('\x1b')
            expect_draft(terminal, ['transit>'], (0, 9))
            terminal.send('SE\t')
            terminal.expect('> SELECT')
            pause()
            terminal.send('Z')
            observe()
            expect_draft(terminal, ['transit> SEZ'], (0, 12))  # empty preview is not proof of no matches
            assert b'No matching' not in terminal.screen
            release.set()
            terminal.expect('SEZ_NEW')  # omitted from the old bounded shortlist
            pause()
            terminal.send(' ')
            observe()
            assert 'SEZ_NEW' not in '\n'.join(terminal.display.text()), 'changed context retained old candidates'
            release.set()
            terminal.expect('Limited search; type more to narrow')
            assert not [a for a, _ in actions if a == 'execute'], actions
        finally:
            release.set()
            terminal.close()
    print('Console completion: immediate filtering, quiet acquisition/validation, stable selection, latest-draft coalescing and empty-preview coverage passed.')


def session_loss(binary):
    for changed_instance, preview in ((False, False), (True, False), (False, True), (True, True)):
        began, release = threading.Event(), threading.Event()
        calls = []
        def assist(value):
            calls.append(value)
            if preview and len(calls) == 1:
                return dict(assistance=dict(coverage='limited', status='ready', profile='catalog_v1', resource=4,
                                            contract=[7]*32, resource_revision=1, policy_revision='1',
                                            range=dict(start=0, end=2, quoted=False),
                                            items=[dict(text='SELECT', kind='keyword', detail='SQL grammar')]))
            began.set()
            release.wait(3)
            return dict(err=dict(code='SqlSessionExpired', sqlstate=list(b'08003'), message='Expired', retry='never', operation=None, diagnostic=None))
        def instance(action):
            return [9 if changed_instance and action == 'assist' and began.is_set() else 2] * 16
        with tempfile.TemporaryDirectory(prefix='transit-completion-session-') as directory, peer(assist=assist, instance=instance) as (endpoint, actions):
            root = Path(directory)
            config = root / 'connection.json'
            config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
            terminal = Terminal(binary, config, home=root)
            terminal.display = Screen()
            terminal.display.feed(terminal.screen)
            try:
                terminal.send('SE\t')
                if preview:
                    terminal.expect('> SELECT')
                    terminal.send('\t')  # fail validation while the disclosed menu stays visible
                assert began.wait(3)
                terminal.send('L')  # response now belongs to an older draft
                terminal.expect('transit> SEL', timeout=.6)
                release.set()
                expect_draft(terminal, ['transit>'], (0, 9))
                terminal.send('\x1a')
                expect_draft(terminal, ['transit>'], (0, 9))
                assert len([a for a, _ in actions if a == 'assist']) == 1 + preview, actions
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
