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
    config = dict(config, version=1, profile='unified_v1', execution='durable', transport='loopback', format='table', recovery_file='console-recovery.json')
    config['seed_file'] = os.path.relpath(config['seed_file'], root)
    path = root/'console.json'
    path.write_text(json.dumps(config))
    recovery = root/'console-recovery.json'

    def run(data=b'', args=(), expected_code=0, selected=path, timed=False):
        result = subprocess.run([binary, 'console', '--no-rc', '--config', str(selected), *args], input=data,
                                capture_output=True, timeout=420)
        assert result.returncode == expected_code, result
        if timed:
            import re
            assert re.fullmatch(rb'Time: \d+ ms \(prepare \d+ ms, compile \d+ ms, submit \d+ ms, wait \d+ ms, fetch \d+ ms, render \d+ ms, persist \d+ ms\)\n', result.stderr), result.stderr
        elif expected_code == 0: assert not result.stderr, result
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
        invalid = run(b'.timer on\nCREATE KV items (UTF8);', expected_code=1)
        assert b'Time: ' in invalid.stderr and b'error: ' in invalid.stderr and not invalid.stdout
        assert invalid.stderr.count(b'Time: ') == 1 and invalid.stderr.splitlines()[-1].startswith(b'Time: '), invalid.stderr
        assert fault['console_sends'] == before
        for statement, fragments in (
            ('SELECT;', (b'[syntax]', b'line 1, column 7', b'^--- error here')),
            ('INSERT INTO items VALUES (1, 100);', (b'no Table catalog is configured', b'.help INSERT')),
            ('INSERT INTO items (id, value) VALUES (1, 100);', (b'no Table catalog is configured', b'.help INSERT')),
            ('SHOW SOURCES;', (b'[grammar_only]', b'SHOW TABLES')),
        ):
            invalid = run(args=('-c', statement), expected_code=1)
            assert all(fragment in invalid.stderr for fragment in fragments), invalid
            assert not invalid.stdout and fault['console_sends'] == before
        fault['lost'], fault['retry'] = None, False
        sql = 'SELECT *' if kind == 'document' else 'SELECT value'
        statement = sql+'\n/* ; .quit /* nested ; */ */ FROM items\nLIMIT 33;\n'
        result = run(('.timer on\n'+statement).encode(), expected_code=1)
        assert not result.stdout and b'InvalidAuthorityResponse' in result.stderr, result
        assert result.stderr.count(b'Time: ') == 1 and result.stderr.splitlines()[-1].startswith(b'Time: '), result.stderr
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
        result = run(b'.timer on\n.resume\n', args=('--format', 'json'), timed=True)
        assert fault['retry'], 'resume did not retry the original signed request'
        pages = [json.loads(line) for line in result.stdout.splitlines()]
        assert pages and pages[-1]['complete_coverage']
        assert all(page['manifest']['basis']['cut']['kind'] == kind for page in pages)
        rows = [row for page in pages for row in page['cells']]
        assert [row[0]['value']['atom']['utf8'] for row in rows] == [row['value']['value'] for row in expected[:33]]
        assert json.loads(recovery.read_text())['namespace'] == query_id
        assert json.loads(recovery.read_text())['complete']

        # Explicit resume rereads the same result under current grants.
        invoke('revoke', direct=True)
        denied = run(b'.resume\n', expected_code=1)
        assert not denied.stdout and b'Code: query.saved_work_unresolved; stage: reconcile.' in denied.stderr, denied
        assert b'Cause: AccessDenied.' in denied.stderr and f'query {query_id}: unknown.'.encode() in denied.stderr, denied
        assert json.loads(recovery.read_text())['namespace'] == query_id
        invoke('restore', direct=True)
        table = run(b'.resume\n').stdout
        assert table.startswith('┌'.encode()) and b' rows\n' in table and b'\x1b' not in table

        print(f'Transit console {kind}: saved-intent resume, all result pages and current read denial passed.', flush=True)
        parameter_file = root / 'console diagnostic parameters.json'
        retained_before = recovery.read_bytes()
        before = fault['console_sends']
        for mode in ('durable', 'interactive'):
            diagnostic_config = root / ('console-diagnostic-' + mode + '.json')
            diagnostic_config.write_text(json.dumps(dict(config, execution=mode)))
            for template, bindings, fragments in (
                ('SELECT * FROM items LIMIT $1', [], (b'Expected bindings: 1; supplied: 0',)),
                ('SELECT * FROM items LIMIT $1', [{'signed': '2'}], (b'Parameter: $1', b'Expected uint64; supplied signed', b'Value: 2')),
                ('SELECT * FROM items LIMIT $2', [{'unsigned': '1'}, {'unsigned': '2'}], (b'Missing parameter: $1', b'Parameter: $2')),
            ):
                parameter_file.write_text(json.dumps(bindings))
                invalid = run(args=('-c', template, '--parameters', str(parameter_file)), selected=diagnostic_config, expected_code=1)
                assert all(fragment in invalid.stderr for fragment in fragments), invalid
                assert not invalid.stdout and fault['console_sends'] == before
                assert recovery.read_bytes() == retained_before
                assert b'Use .resume' not in invalid.stderr
        parameter_file.unlink()
        print(f'Transit console {kind}: parameter type/count/gap context in both execution modes, with no send or recovery mutation.', flush=True)
        for query_file in (False, True):
            parameter_file = root / 'console query input.json'
            template = sql + ' FROM items LIMIT $1'
            bindings = [{'unsigned': '33'}]
            parameter_file.write_text(json.dumps({'sql': template, 'parameters': bindings} if query_file else bindings))
            data = ('.execute ' + json.dumps(str(parameter_file)) + '\n').encode() if query_file else b''
            arguments = ('--format', 'json') if query_file else ('--format', 'json', '-c', template, '--parameters', str(parameter_file))
            fault['lost'], fault['retry'] = None, False
            uncertain = run(data, args=arguments, expected_code=1)
            assert not uncertain.stdout and b'InvalidAuthorityResponse' in uncertain.stderr, uncertain
            frozen = recovery.read_bytes()
            retained = json.loads(frozen)
            assert retained['pending']['signed'] == json.loads(fault['lost'][0])
            parameter_file.write_text(json.dumps({'sql': template, 'parameters': [{'unsigned': '1'}]} if query_file else [{'unsigned': '1'}]))
            before = fault['console_sends']
            run(data, args=arguments, expected_code=1)
            assert fault['console_sends'] == before and recovery.read_bytes() == frozen
            parameter_file.unlink()
            resumed = run(b'.resume\n', args=('--format', 'json'))
            pages = [json.loads(line) for line in resumed.stdout.splitlines()]
            assert pages[-1]['complete_coverage'] and fault['retry']
            rows = [row for page in pages for row in page['cells']]
            assert [row[0]['value']['atom']['utf8'] for row in rows] == [row['value']['value'] for row in expected[:33]]
            assert json.loads(recovery.read_text())['namespace'] == retained['namespace']
        print(f'Transit console {kind}: flag/file bindings preserve saved query identity after changed/deleted inputs and uncertain upload.', flush=True)
        count_sql = 'SELECT COUNT(*) FROM items'
        result = run(args=('-c', count_sql, '--format', 'json'))
        assert json.loads(result.stdout)['cells'][0][0]['value']['atom']['unsigned'] in ('12', '41')
        next_id = json.loads(recovery.read_text())['namespace']
        assert next_id != query_id
        script = root/'queries.sql'
        script.write_text(count_sql+';\n'+count_sql)
        result = run(args=('-f', str(script), '--format', 'json'))
        assert len(result.stdout.splitlines()) == 2
        result = run(('.timer on\n.show\n'+count_sql).encode(), args=('--format', 'json'), timed=True)
        shown, page = result.stdout.rsplit(b'\n', 2)[:2]
        settings = parse_show(shown+b'\n')
        assert settings['format'] == 'json' and settings['timing'] == 'on'
        assert json.loads(page)['complete_coverage']
        # A shared destination observes result output before the timing footer.
        combined = subprocess.run([binary, 'console', '--no-rc', '--config', str(path), '--format', 'json'],
                                  input=('.timer on\n'+count_sql).encode(), stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=420)
        assert combined.returncode == 0, combined
        lines = combined.stdout.splitlines()
        assert json.loads(lines[0])['complete_coverage'], combined.stdout
        assert len(lines) == 2 and lines[-1].startswith(b'Time: '), combined.stdout
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
        from console_interrupt import check as interrupt
        interrupt(binary, path, root, kind, invoke, fault)
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
