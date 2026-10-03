"""Actual signed SQL shell: current capabilities, exact results and lifecycle."""
import json
import os
import selectors
import subprocess
import time


class Shell:
    def __init__(self, binary, root):
        self.process = subprocess.Popen([binary, 'query', str(root/'shell.json')],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.buffer = b''
        self.read(json_line=False)

    def read(self, json_line=True):
        while b'\n' not in self.buffer:
            with selectors.DefaultSelector() as selector:
                selector.register(self.process.stdout, selectors.EVENT_READ)
                assert selector.select(60), 'shell response deadline'
            block = os.read(self.process.stdout.fileno(), 65536)
            assert block, ('shell exited', self.process.poll(), self.process.stderr.read() if self.process.stderr else getattr(self, 'screen', b''))
            self.buffer += block
            assert len(self.buffer) <= 1048576, 'shell response bound'
        line, self.buffer = self.buffer.split(b'\n', 1)
        return json.loads(line) if json_line else line

    def call(self, text):
        self.process.stdin.write((text+'\n').encode()); self.process.stdin.flush()
        return self.read()

    def close(self):
        self.process.stdin.write(b'.quit\n'); self.process.stdin.flush()
        self.process.stdin.close()
        assert self.process.wait(timeout=10) == 0, self.process.stderr.read()
        self.process.stdout.close(); self.process.stderr.close()


def check(binary, root, kind, invoke, expected, fault, *, compound=False, counts=False):
    shell = Shell(binary, root)
    try:
        description = shell.call('.sources')['description']
        assert description['source']['capabilities'][kind]
        assert description['sql']['version'] == 1 and not description['sql']['continuous']
        assert kind in description['source']['source']['source']
        assert shell.call('.resume 1')['status']['phase'] == 'complete'
        first = shell.call('.next')
        assert first['cells'] and not first['complete_coverage']
        assert first['manifest']['basis']['kind'] == kind
        invoke('revoke', direct=True)
        assert shell.call('.next')['err'] == 'AccessDenied'
        assert shell.call('.next')['err'] == 'AccessDenied'
        invoke('restore', direct=True)
        for parameterized in ((False,) if compound else (False, True)):
            namespace = 3 if parameterized else 2
            assert shell.call(f'.new {namespace}')['status'] is None
            assert shell.call('CREATE KV items (UTF8)')['err'] == 'UnsupportedStatement'
            assert shell.call('.status')['status'] is None
            assert shell.call('SELECT items.value FROM items AS chosen')['err'] == 'UnknownQualifier'
            assert shell.call('.status')['status'] is None
            columns = [{'name': 'Result', 'type': 'utf8'}]
            if kind == 'document':
                columns += [{'name': name, 'type': 'uint64' if name != 'optional' else 'utf8'} for name in ('counter', 'replica', 'optional')]
            assert first['columns'] == columns
            sql = ('SELECT chosen.value AS "Result", counter, replica, optional FROM items AS chosen LIMIT 33'
                   if kind == 'document' else 'SELECT chosen.value AS "Result" FROM items AS chosen LIMIT 33')
            if compound:
                # Select fewer than the LIMIT so ignoring the Boolean program
                # cannot accidentally produce the same first 33 rows.
                ceiling = f"東京🙂/{'x'*(64 if kind == 'document' else 128)}/{'08' if kind == 'document' else '31'}"
                sql = sql.replace(' LIMIT 33', f" WHERE value <> 'x' AND NOT (value >= '{ceiling}' OR value IS NULL) LIMIT 33")
                expected = expected[:8 if kind == 'document' else 31]
            if counts:
                column = 'optional' if kind == 'document' else 'value'
                sql = f'SELECT COUNT(chosen.amount) AS present FROM (SELECT {column} AS amount FROM items LIMIT 10) AS chosen'
                columns = [{'name': 'present', 'type': 'uint64'}]
            if parameterized:
                input_file = root / 'query input.json'
                request = {'sql': sql.replace('LIMIT ' + ('10' if counts else '33'), 'LIMIT $1'),
                           'parameters': [{'uint64': '10' if counts else '33'}]}
                input_file.write_text(json.dumps(request))
                command = '.execute ' + json.dumps(str(input_file))
            else:
                command = sql
            fault['lost'], fault['retry'] = None, False
            assert 'receipt' in shell.call(command)
            progress = shell.read()
            assert progress == {'err': 'InvalidAuthorityResponse', 'uncertain': True}, progress
            bundle = shell.call('.bundle')['bundle']
            pending = shell.call('.pending')['token']
            assert bundle and pending
            invoke('revoke', direct=True)
            denied = shell.call('.sources')
            assert denied == {'err':'AccessDenied','uncertain':True}, denied
            assert shell.call('.bundle')['bundle'] == bundle
            assert shell.call('.pending')['token'] == pending
            assert shell.call('.new 999999')['err'] == 'UnresolvedSubmission'
            invoke('restore', direct=True)
            if parameterized:
                input_file.write_text(json.dumps({'sql': 'DELETE FROM items WHERE id = 0', 'parameters': []}))
                assert shell.call(command)['err'] == 'UnresolvedSubmission'
                assert shell.call('.bundle')['bundle'] == bundle and shell.call('.pending')['token'] == pending
                input_file.unlink()  # Saved recovery cannot reopen or rebind the file.
            shell.close()
            shell = Shell(binary, root)
            assert shell.call(f'.resume {namespace}')['status']['phase'] == 'uploading'
            restored = shell.call('.restore-bundle '+bundle)
            assert restored == {'restored_bundle': True}, restored
            assert shell.call('.restore '+pending) == {'restored': True}
            assert 'receipt' in shell.call('.retry')
            progress = shell.read()
            assert fault['retry'], 'shell restart replaced the frozen signed request'
            until = time.monotonic()+300
            while 'waiting_for_input' in progress:
                assert time.monotonic() < until, progress
                progress = shell.call('.advance')
            assert progress['status']['phase'] in ('admitted', 'complete'), progress
            while True:
                progress = shell.call('.status')
                assert isinstance(progress.get('status'), dict), progress
                if progress['status']['phase'] == 'complete': break
                assert time.monotonic() < until, progress
                time.sleep(0.1)
            rows = []
            while True:
                page = shell.call('.next')
                assert page['manifest']['basis']['kind'] == kind
                assert page['columns'] == columns
                if counts:
                    assert page['manifest']['selected'] == '10'
                    assert page['manifest']['value_count'] == ('0' if kind == 'document' else '10')
                rows.extend(page['cells'])
                if page['complete_coverage']: break
            if counts:
                assert rows == [[{'value': {'uint64': '0' if kind == 'document' else '10'}}]], rows
            else:
                assert len(rows) == min(33, len(expected))
                assert [row[0]['value']['utf8'] for row in rows] == [row['value']['value'] for row in expected[:33]]
                if kind == 'document':
                    assert all(row[3] == {'missing': {}} for row in rows), rows[:1]
            assert shell.call('.next')['err'] == 'QueryComplete'
            assert 'receipt' in shell.call('.retire')
            progress = shell.read()
            while 'waiting_for_input' in progress: progress = shell.call('.advance')
            assert progress['status']['phase'] == 'retired'
            assert 'receipt' in shell.call('.collect')
            progress = shell.read()
            while 'waiting_for_input' in progress: progress = shell.call('.advance')
            assert progress['status']['collected'], progress
            assert shell.call(f'.new {namespace}')['err'] == 'QueryUploadIdentityConflict'
            print(f'Unified {kind} SQL shell ({"parameter file" if parameterized else "ordinary SQL"}): truthful capabilities, pre-submit rejection, frozen bundle/exact retry across shell exit, current prefix denial and retained signed work after revocation, '
                  f'named output schemas, {"COUNT value/missing counters" if counts else "owned nested rows"}, complete coverage and permanent retirement/collection passed.', flush=True)
    finally:
        if shell.process.poll() is None: shell.close()
