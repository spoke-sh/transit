"""Real catalog CLI invocations; recovery uses the CLI's original private files."""
import json
from pathlib import Path
import stat
import subprocess
import uuid
from unified_abi import Failure


class Cli:
    def __init__(self, executable, root, url, connection):
        self.executable = str(Path(executable).resolve())
        self.root = root / 'cli-catalog'
        self.root.mkdir(exist_ok=True)
        self.config = self.root / 'connection.json'
        self.config.write_text(json.dumps(dict(version=1, url=url, seed_file='../caller.seed', connection=connection, request_timeout_ms=10000)))
        self.closed = False

    def close(self):
        self.closed = True

    def saved(self, kind, value):
        for path in self.root.glob('output-*.json'):
            artifact = json.loads(path.read_bytes())
            if kind in artifact and (artifact[kind]['request'] if kind == 'compiled' else artifact[kind]['next'] if kind == 'page' else artifact[kind]) == value:
                return path
        raise AssertionError('Recovery must use the original saved CLI artifact')

    def invoke(self, command, arguments):
        result = subprocess.run([self.executable, '--diagnostics=json', 'catalog', command, *map(str, arguments)], cwd=self.root, capture_output=True, text=True, timeout=30)
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
        name, value = next(iter(action.items()))
        if name == 'capabilities': return self.invoke('capabilities', [])
        args = ['--config', self.config]
        output = original = path = None
        command = name.replace('_', '-')
        if name == 'compile':
            sql = self.root / f'{uuid.uuid4().hex}.sql'
            sql.write_text(value['sql'])
            args += ['--file', sql, '--operation', value['operation'], '--object', value['object'], '--table', value['table']]
        elif name == 'lookup':
            args += ['--name', value]
        elif name == 'definition':
            args += ['--object', value['object'], '--revision', value['revision']]
        elif name == 'list':
            if value is not None:
                path = self.saved('page', value)
                args += ['--file', path]
        elif name in ('prepare_create', 'status'):
            path = self.saved('compiled', value)
            args += ['--file', path]
        elif name in ('prepare_initialize', 'prepare_policy'):
            control = self.root / f'control-{uuid.uuid4().hex}.json'
            control.write_text(json.dumps(value))
            args += ['--file', control]
        elif name in ('submit', 'observe', 'input_disposition'):
            path = self.saved('prepared', value if name == 'submit' else value['prepared'])
            args += ['--file', path]
            if name != 'submit': args += ['--input', value['input']]
            if name == 'input_disposition': command = 'disposition'
        else:
            assert name == 'describe'
        if path: original = path.read_bytes()
        if name in ('compile', 'list') or name.startswith('prepare_'):
            output = self.root / f'output-{uuid.uuid4().hex}.json'
            args += ['--output', output]
        try:
            result = self.invoke(command, args)
        finally:
            if path: assert path.read_bytes() == original
        if output:
            assert stat.S_IMODE(output.stat().st_mode) == 0o600
            assert json.loads(output.read_bytes()) == result
        return result
