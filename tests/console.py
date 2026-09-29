"""Real automatic console execution, exact recovery, bounded results and pipes."""
import json
import os
import signal
import stat
import subprocess
import time
from unified_shell import Shell
from console_settings import parse_show


class Console(Shell):
    def __init__(self, binary, config=None, cwd=None):
        self.process = subprocess.Popen([binary, 'console', '--no-rc', *(['--config', str(config)] if config is not None else []), '--format', 'json'],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd)
        self.buffer = b''

    def close(self, status=0):
        if self.process.poll() is None:
            self.process.stdin.write(b'.quit\n'); self.process.stdin.flush()
            self.process.stdin.close()
        assert self.process.wait(timeout=10) == status, self.process.stderr.read()
        self.process.stdout.close(); self.process.stderr.close()


def check(binary, root, kind, invoke, expected, fault, config, tls=False):
    started = time.monotonic()
    config = dict(config, version=1, profile='unified_v2', transport='loopback', format='table', recovery_file='console-recovery.json')
    config['seed_file'] = os.path.relpath(config['seed_file'], root)
    path = root/'console.json'
    path.write_text(json.dumps(config))
    recovery = root/'console-recovery.json'

    def run(data=b'', args=(), expected_code=0, selected=path):
        result = subprocess.run([binary, 'console', '--no-rc', '--config', str(selected), *args], input=data,
                                capture_output=True, timeout=420)
        assert result.returncode == expected_code, result
        if expected_code == 0: assert not result.stderr, result
        return result

    for changes in ({'version': 2}, {'unknown': 'private-must-not-appear'}, {'url': 'http://example.com:1234'},
                    {'url': 'http://user:private-must-not-appear@127.0.0.1:1234'}, {'transport': 'tls_ca'}):
        invalid = root/'console-invalid.json'
        invalid.write_text(json.dumps(dict(config, **changes)))
        result = run(selected=invalid, expected_code=2)
        assert b'private-must-not-appear' not in result.stderr and not result.stdout
    for command in (b'.new 3\n', b'.retry\n', b'.advance\n', b'.next\n', b'/help\n'):
        result = run(command, expected_code=1)
        assert not result.stdout

    shell = Console(binary, path)
    try:
        commands = shell.call('.help')['commands']
        assert 'resume' in commands and 'cancel' in commands and 'new' not in commands and 'retry' not in commands
        assert shell.call('.tables')['description']['source']['capabilities'][kind]
        duplicate = run(b'.quit\n', expected_code=1)
        assert b'another client holds the recovery lock' in duplicate.stderr
        shell.close()

        # Unsupported SQL does not allocate an identity or send a mutation.
        before = fault['console_sends']
        run(args=('-c', 'CREATE KV items (UTF8);'), expected_code=1)
        assert fault['console_sends'] == before
        fault['lost'], fault['retry'] = None, False
        sql = 'SELECT *' if kind == 'document' else 'SELECT value'
        statement = sql+'\n/* ; .quit /* nested ; */ */ FROM items\nLIMIT 33;\n'
        result = run(statement.encode(), expected_code=1)
        assert not result.stdout and b'InvalidAuthorityResponse' in result.stderr, result
        record = json.loads(recovery.read_text())
        query_id = record['namespace']
        assert query_id and record['bundle']
        assert record['pending']['signed'] == json.loads(fault['lost'][0])
        assert stat.S_IMODE(recovery.stat().st_mode) == 0o600
        # Starting new SQL must not replace uncertain work. Opening does not retry.
        before = fault['console_sends']
        run(args=('-c', 'SELECT COUNT(*) FROM items'), expected_code=1)
        assert fault['console_sends'] == before
        result = run(b'.info\n', args=('--format', 'json'))
        assert json.loads(result.stdout)['uncertain'] and fault['console_sends'] == before
        saved = recovery.read_bytes()
        shown = run(b'.show\n', args=('--format', 'json')).stdout
        assert parse_show(shown)['format'] == 'json'
        assert recovery.read_bytes() == saved and fault['console_sends'] == before
        assert not fault['retry'], 'settings inspection retried uncertain work'
        result = run(b'.resume\n', args=('--format', 'json'))
        assert fault['retry'], 'resume did not retry the original signed request'
        pages = [json.loads(line) for line in result.stdout.splitlines()]
        assert pages and pages[-1]['complete_coverage']
        assert all(page['manifest']['basis']['kind'] == kind for page in pages)
        rows = [row for page in pages for row in page['cells']]
        assert [row[0]['value']['utf8'] for row in rows] == [row['value']['value'] for row in expected[:33]]
        assert json.loads(recovery.read_text())['namespace'] == query_id
        assert json.loads(recovery.read_text())['complete']

        # Explicit resume rereads the same result under current grants.
        invoke('revoke', direct=True)
        denied = run(b'.resume\n', expected_code=1)
        assert not denied.stdout and b'permission denied' in denied.stderr, denied
        assert json.loads(recovery.read_text())['namespace'] == query_id
        invoke('restore', direct=True)
        table = run(b'.resume\n').stdout
        assert table.startswith(b'+') and b' rows\n' in table and b'\x1b' not in table

        print(f'Transit console {kind}: saved-intent resume, all result pages and current read denial passed.', flush=True)
        count_sql = 'SELECT COUNT(*) FROM items'
        result = run(args=('-c', count_sql, '--format', 'json'))
        assert json.loads(result.stdout)['cells'][0][0]['value']['uint64'] in ('12', '41')
        next_id = json.loads(recovery.read_text())['namespace']
        assert next_id != query_id
        script = root/'queries.sql'
        script.write_text(count_sql+';\n'+count_sql)
        result = run(args=('-f', str(script), '--format', 'json'))
        assert len(result.stdout.splitlines()) == 2
        result = run(('.show\n'+count_sql).encode(), args=('--format', 'json'))
        shown, page = result.stdout.rsplit(b'\n', 2)[:2]
        assert parse_show(shown+b'\n')['format'] == 'json'
        assert json.loads(page)['complete_coverage']
        # Batch stops after the first invalid statement; no later dispatch.
        before = fault['console_sends']
        result = run(('CREATE KV nope (UTF8);'+count_sql+';').encode(), expected_code=1)
        assert not result.stdout and fault['console_sends'] == before
        for text in (b'/* unfinished;', b"SELECT 'unfinished; .quit"):
            result = run(text, expected_code=1)
            assert not result.stdout

        print(f'Transit console {kind}: command/file/stdin batches and first-error stopping passed.', flush=True)
        # Cancellation settles the lost begin, then cancels without uploading the rest.
        fault['lost'], fault['retry'] = None, False
        run(args=('-c', count_sql), expected_code=1)
        cancelled_id = json.loads(recovery.read_text())['namespace']
        before = fault['console_sends']
        cancelled = json.loads(run(b'.cancel\n', args=('--format', 'json')).stdout)
        assert fault['retry'] and fault['console_sends'] == before+2
        assert cancelled['query'] == cancelled_id and cancelled['cancellation_requested']
        assert cancelled['phase'] == 'cancelled', cancelled

        shell = Console(binary, path)
        assert 'commands' in shell.call('.help')
        shell.process.send_signal(signal.SIGINT)
        assert shell.process.wait(timeout=10) == 130
        for stream in (shell.process.stdin, shell.process.stdout, shell.process.stderr): stream.close()
        from console_terminal import check as terminal
        terminal(binary, path, root, kind, invoke, fault)
        stalled = Console(binary, path)
        stalled.process.stdin.write(b'.help\n'*1000); stalled.process.stdin.flush()
        assert stalled.process.wait(timeout=10) == 1
        assert b'ConsoleOutputTimeout' in stalled.process.stderr.read()
        for stream in (stalled.process.stdin, stalled.process.stdout, stalled.process.stderr): stream.close()
        if tls:
            from console_tls import check as tls_check
            tls_check(binary, root, config, kind)
        print(f'Transit console {kind}: automatic command/file/stdin queries, dot commands, stop on error, exact saved resume, bounded results, current denial and signal disconnect passed in {time.monotonic()-started:.2f}s.', flush=True)
    finally:
        if shell.process.poll() is None: shell.process.kill(); shell.process.wait(timeout=10)
