"""Actual console configuration, framing and exact on-disk recovery."""
import json
import os
import signal
import stat
import subprocess
import time
from unified_shell import Shell


class Console(Shell):
    def __init__(self, binary, config):
        self.process = subprocess.Popen([binary, 'console', '--config', str(config), '--format', 'json'],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.buffer = b''

    def close(self, status=0):
        self.process.stdin.write(b'/quit\n'); self.process.stdin.flush()
        self.process.stdin.close()
        assert self.process.wait(timeout=10) == status, self.process.stderr.read()
        self.process.stdout.close(); self.process.stderr.close()


def check(binary, root, kind, invoke, expected, fault, config, tls=False):
    started = time.monotonic()
    for args in (['--help'], ['--version'], ['console', '--help'], ['server', '--help']):
        result = subprocess.run([binary, *args], capture_output=True, timeout=10)
        assert result.returncode == 0 and result.stdout and not result.stderr, result
    for args in (['unknown'], ['console'], ['console', '--config', 'missing', '--config', 'again'],
                 ['console', '--config', 'missing', '--format', 'csv'], ['server', '--format', 'json']):
        result = subprocess.run([binary, *args], capture_output=True, timeout=10)
        assert result.returncode == 2 and not result.stdout, result
    config = dict(config, version=1, profile='unified_v2', transport='loopback', format='table', recovery_file='console-recovery.json')
    # Relative credential/recovery paths resolve against the config directory.
    config['seed_file'] = os.path.relpath(config['seed_file'], root)
    path = root/'console.json'
    path.write_text(json.dumps(config))
    for changes in ({'version': 2}, {'unknown': 'private-must-not-appear'}, {'url': 'http://example.com:1234'},
                    {'url': 'http://user:private-must-not-appear@127.0.0.1:1234'}, {'transport': 'tls_ca'}):
        invalid = root/'console-invalid.json'
        invalid.write_text(json.dumps(dict(config, **changes)))
        result = subprocess.run([binary, 'console', '--config', str(invalid)], input=b'', capture_output=True, timeout=10)
        assert result.returncode == 2 and b'private-must-not-appear' not in result.stderr, result
    shell = Console(binary, path)
    try:
        assert 'new' in shell.call('/help')['commands']
        assert shell.call('/tables')['description']['source']['capabilities'][kind]
        assert shell.call('/new 3')['status'] is None
        assert shell.call('CREATE KV items (UTF8);')['err'] == 'UnsupportedStatement'
        assert shell.call('/status')['status'] is None
        duplicate = subprocess.run([binary, 'console', '--config', str(path)], input=b'/quit\n', capture_output=True, timeout=10)
        assert duplicate.returncode == 1 and b'ConsoleRecoveryInUse' in duplicate.stderr
        fault['lost'], fault['retry'] = None, False
        sql = 'SELECT *' if kind == 'document' else 'SELECT value'
        shell.process.stdin.write((sql+'\n/* ; /quit /* nested ; */ */ FROM items\nLIMIT 33;\n').encode()); shell.process.stdin.flush()
        assert 'receipt' in shell.read()
        assert shell.read() == {'err': 'InvalidAuthorityResponse', 'uncertain': True}
        recovery = root/'console-recovery.json'
        record = json.loads(recovery.read_text())
        assert record['pending']['signed'] == json.loads(fault['lost'][0])
        assert record['bundle'] and record['namespace'] == 3
        assert stat.S_IMODE(recovery.stat().st_mode) == 0o600
        shell.process.kill(); shell.process.wait(timeout=10)
        for stream in (shell.process.stdin, shell.process.stdout, shell.process.stderr): stream.close()
        shell = Console(binary, path)
        assert shell.call('/info')['uncertain']
        assert 'receipt' in shell.call('/retry')
        progress = shell.read()
        assert fault['retry'], 'console restart replaced its frozen signed request'
        until = time.monotonic()+300
        while 'waiting_for_input' in progress:
            assert time.monotonic() < until, progress
            progress = shell.call('/advance')
        assert progress['status']['phase'] in ('admitted', 'complete'), progress
        while shell.call('/status')['status']['phase'] != 'complete':
            assert time.monotonic() < until
            time.sleep(.1)
        rows = []
        first_page_rows = None
        while True:
            page = shell.call('/next')
            if first_page_rows is None: first_page_rows = len(page['cells'])
            assert page['manifest']['basis']['kind'] == kind
            rows.extend(page['cells'])
            if page['complete_coverage']: break
        assert [row[0]['value']['utf8'] for row in rows] == [row['value']['value'] for row in expected[:33]]
        assert shell.call('/format table') == {'format': 'table'}
        assert shell.call('/resume 3')['status']['phase'] == 'complete'
        shell.process.stdin.write(b'/next\n'); shell.process.stdin.flush()
        assert shell.read(json_line=False).startswith(b'Verified complete result; page evidence: ')
        assert shell.read(json_line=False).startswith(b'"')
        # Rendering emits one line per row; consume exactly the first page.
        for _ in range(first_page_rows):
            line = shell.read(json_line=False)
            assert b'\x1b' not in line and b'"utf8"' in line
        assert shell.call('/format json') == {'format': 'json'}
        invoke('revoke', direct=True)
        assert shell.call('/next')['err'] == 'AccessDenied'
        assert json.loads(recovery.read_text())['cursor'] is None
        invoke('restore', direct=True)
        assert 'receipt' in shell.call('/retire')
        progress = shell.read()
        while 'waiting_for_input' in progress: progress = shell.call('/advance')
        assert progress['status']['phase'] == 'retired'
        shell.close(status=1)  # The denied command is a machine-session failure.
        for text in (b'SELECT value FROM items', b'/* unfinished;', b"SELECT 'unfinished; /quit"):
            result = subprocess.run([binary, 'console', '--config', str(path), '--format', 'json'], input=text, capture_output=True, timeout=10)
            assert result.returncode == 1 and not result.stdout and b'IncompleteSqlStatement' in result.stderr, result
        shell = Console(binary, path)
        assert 'commands' in shell.call('/help')
        shell.process.send_signal(signal.SIGINT)
        assert shell.process.wait(timeout=10) == 130
        for stream in (shell.process.stdin, shell.process.stdout, shell.process.stderr): stream.close()
        from console_terminal import check as terminal
        terminal(binary, path, root, kind, invoke, fault)
        # A blocked stdout is a local disconnect, never a cancellation. The
        # bounded output task joins before the session and private buffers die.
        stalled = Console(binary, path)
        stalled.process.stdin.write(b'/help\n'*300); stalled.process.stdin.flush()
        assert stalled.process.wait(timeout=10) == 1
        assert b'ConsoleOutputTimeout' in stalled.process.stderr.read()
        for stream in (stalled.process.stdin, stalled.process.stdout, stalled.process.stderr): stream.close()
        if tls:
            from console_tls import check as tls_check
            tls_check(binary, root, config, kind)
        print(f'Transit console {kind}: strict offline options, pipe/multiline framing, locked private recovery, killed-session exact retry, verified bounded results, current denial and signal disconnect passed in {time.monotonic()-started:.2f}s.', flush=True)
    finally:
        if shell.process.poll() is None: shell.process.kill(); shell.process.wait(timeout=10)
