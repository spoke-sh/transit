"""Public help through the executable, independent of SQL result formatting."""
import json
from pathlib import Path
import subprocess
import tempfile
from interfaces.sql_sessions.editor_peer import peer


def check(binary):
    with tempfile.TemporaryDirectory(prefix='transit-help-') as directory, peer() as (endpoint, actions):
        root = Path(directory)
        config = root/'connection.json'
        config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust')))
        def invoke(text, format='json', status=0):
            value = subprocess.run([binary, 'console', '--no-rc', '--config', str(config), '--format', format], input=text+'\n', text=True, capture_output=True, timeout=10)
            assert value.returncode == status, value
            return value
        short = invoke('.help').stdout
        assert short == invoke('.help', 'table').stdout
        expected = ['connect', 'edit', 'execute', 'help', 'info', 'mode', 'quit', 'schema', 'show', 'sources', 'tables', 'timer']
        rows = [row for row in short.splitlines() if row.startswith('.')]
        assert [row.split()[0][1:] for row in rows] == expected, short
        assert len(short.splitlines()) <= 17 and 'SQL:' not in short and 'catalog:' not in short
        extended = invoke('.help --all').stdout
        assert [row for row in extended.splitlines() if row.startswith('.')] == rows
        for name in expected:
            focused = invoke('.help '+name).stdout
            assert focused == invoke('.help .'+name.upper()).stdout
            assert focused == invoke('.help --all '+name).stdout
            assert focused in extended
        insert = invoke('.help INSERT').stdout
        assert 'INSERT INTO' in insert and 'UPDATE people' not in insert and 'DELETE FROM' not in insert
        assert 'ALTER TABLE' in invoke('.help ALTER TABLE').stdout
        shortcuts = invoke('.help shortcuts').stdout
        assert 'Ctrl-R' in shortcuts and 'Esc / Ctrl-G' in shortcuts and 'Ctrl-C' in shortcuts
        assert 'Restore the original draft' in shortcuts and 'Clear the unsubmitted draft' in shortcuts
        assert 'SET query.statement_timeout' in invoke('.help settings').stdout
        assert 'transit migrate plan' in invoke('.help migrations').stdout
        assert 'SELECT COUNT' in invoke('.help sql').stdout
        assert 'Edit the latest SQL' in invoke('.help\tedit').stdout
        for topic in ['recovery', 'status', 'resume', 'cancel', '--unknown', '--all --all', 'edit extra']:
            value = invoke('.help '+topic, status=1)
            assert 'Unknown help topic' in value.stderr and not value.stdout, value
        for command in ['.status', '.resume', '.cancel']:
            value = invoke(command, status=1)
            assert 'UnknownConsoleCommand' in value.stderr and not value.stdout, value
        assert all(action in ('hello', 'open', 'close') for action, _ in actions), actions
    print('Console help: compact/expanded/focused text, topics, argument errors and removed commands passed without SQL requests.')
