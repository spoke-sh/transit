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


def check(binary, root, kind, invoke, expected, fault):
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
        assert shell.call('.next')['err'] == 'NamespaceRequired'
        invoke('restore', direct=True)
        assert shell.call('.new 2')['status'] is None
        assert shell.call('CREATE KV items (UTF8)')['err'] == 'UnsupportedStatement'
        assert shell.call('.status')['status'] is None
        sql = 'SELECT * FROM items LIMIT 33' if kind == 'document' else 'SELECT value FROM items LIMIT 33'
        fault['lost'], fault['retry'] = None, False
        assert 'receipt' in shell.call(sql)
        progress = shell.read()
        assert progress == {'err': 'InvalidAuthorityResponse', 'uncertain': True}, progress
        bundle = shell.call('.bundle')['bundle']
        pending = shell.call('.pending')['token']
        assert bundle and pending
        shell.close()
        shell = Shell(binary, root)
        assert shell.call('.resume 2')['status']['phase'] == 'uploading'
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
        while shell.call('.status')['status']['phase'] != 'complete':
            assert time.monotonic() < until
            time.sleep(0.1)
        rows = []
        while True:
            page = shell.call('.next')
            assert page['manifest']['basis']['kind'] == kind
            rows.extend(page['cells'])
            if page['complete_coverage']: break
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
        assert shell.call('.new 2')['err'] == 'QueryUploadIdentityConflict'
        print(f'Unified {kind} SQL shell: truthful capabilities, pre-submit rejection, frozen bundle/exact retry across shell exit, current prefix denial, '
              'owned nested rows, complete coverage and permanent retirement/collection passed.', flush=True)
    finally:
        if shell.process.poll() is None: shell.close()
