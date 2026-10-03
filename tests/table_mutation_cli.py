"""Real CLI commands and durable private artifacts in the shared fault schedule."""
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import uuid
from unified_abi import Failure


class Cli:
    def __init__(self, executable, root, url, connection):
        self.executable = str(Path(executable).resolve())
        self.root = root/'cli-mutations'
        self.root.mkdir(exist_ok=True)
        self.config = self.root/'connection.json'
        self.config.write_text(json.dumps(dict(version=1,url=url,seed_file='../caller.seed',connection=connection,request_timeout_ms=10000)))
        self.closed = False

    def close(self):
        self.closed = True

    def artifact(self, value, kind):
        if kind == 'prepared':
            # Find the CLI-created file again after caller replacement; no
            # in-memory handle or outer JSON re-encoding supplies recovery.
            for candidate in self.root.glob('output-*.json'):
                if json.loads(candidate.read_bytes()) == value: return candidate
            raise AssertionError('Prepared command must come from a saved CLI artifact')
        encoded = json.dumps(value).encode()
        digest = hashlib.sha256(encoded).hexdigest()
        path = self.root/f'{kind}-{digest}.json'
        if not path.exists(): path.write_bytes(encoded)
        assert json.loads(path.read_bytes()) == value
        return path

    def invoke(self, command, arguments):
        result = subprocess.run([self.executable,'--diagnostics=json','mutate',command,*map(str,arguments)],cwd=self.root,capture_output=True,text=True,timeout=30)
        if result.returncode:
            assert not result.stdout and result.returncode == 1, result.stderr
            diagnostic = json.loads(result.stderr)
            assert diagnostic['code'] != 'cli.diagnostic_unavailable', diagnostic
            detail = dict(err=diagnostic['cause'], diagnostic=diagnostic)
            if diagnostic['outcome'] == 'unknown': raise Failure(6, detail)
            status = {'conflict':5, 'access':4, 'limit':10}.get(diagnostic['category'], 1)
            raise Failure(status, detail)
        assert not result.stderr, result.stderr
        return json.loads(result.stdout)

    def call(self, action):
        assert not self.closed
        name,value = next(iter(action.items()))
        if name == 'capabilities': return self.invoke('capabilities',[])
        args = ['--config',self.config]
        output = None
        prepared_path = None
        if name == 'compile':
            sql = self.root/f'{uuid.uuid4().hex}.sql'; sql.write_text(value['sql'])
            args += ['--file',sql,'--name',value['name'],'--namespace',value['namespace']]
        elif name == 'next':
            args += ['--file',self.artifact(dict(compiled=value),'compiled')]
        elif name in ('prepare','status'):
            if name == 'prepare': control,reference = next(iter(value.items()))
            else: reference = value
            compiled = json.loads((self.root/f'request-{reference}.json').read_bytes())
            args += ['--file',self.artifact(dict(compiled=compiled),'compiled')]
            if name == 'prepare': args += ['--control',control]
        elif name in ('submit','observe','rejection'):
            token = value if name == 'submit' else value['prepared']
            prepared_path = self.artifact(dict(prepared=token),'prepared')
            original = prepared_path.read_bytes()
            args += ['--file',prepared_path]
            if name != 'submit': args += ['--input',str(value['input'])]
        else: assert name == 'describe'
        if name in ('compile','next','prepare'):
            output = self.root/f'output-{uuid.uuid4().hex}.json'
            args += ['--output',output]
        try: result = self.invoke(name,args)
        finally:
            if prepared_path: assert prepared_path.read_bytes() == original
        if output:
            assert stat.S_IMODE(output.stat().st_mode) == 0o600
            assert json.loads(output.read_bytes()) == result
            if name == 'compile':
                reference = result['compiled']['reference']
                (self.root/f'request-{reference}.json').write_text(json.dumps(result['compiled']))
                # The command refuses to replace a recovery artifact even when
                # preparation could produce a valid replacement.
                before = output.read_bytes()
                duplicate = subprocess.run([self.executable,'mutate',name,*map(str,args)],cwd=self.root,capture_output=True,text=True,timeout=30)
                assert duplicate.returncode == 1 and not duplicate.stdout and 'PathAlreadyExists' in duplicate.stderr
                assert output.read_bytes() == before
        return result
