"""General Table CLI invocations using only original private recovery artifacts."""
import json
from pathlib import Path
import stat
import subprocess
import time
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
            actual = artifact.get(kind)
            if kind == 'compiled' and actual:
                actual = actual['intent']['reference']
            elif kind == 'page' and actual:
                actual = actual['next']
            if actual == value:
                return path
        raise AssertionError('Recovery must use the original saved CLI artifact')

    def invoke(self, command, arguments):
        result = subprocess.run([self.executable, '--diagnostics=json', 'catalog', command, *map(str, arguments)], cwd=self.root, capture_output=True, text=True, timeout=45)
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
        original = {}
        output = None
        command = name.replace('_', '-')

        def use(kind, selected, flag='--file'):
            path = self.saved(kind, selected)
            original[path] = path.read_bytes()
            args.extend([flag, path])

        if name == 'compile':
            sql = self.root / f'{uuid.uuid4().hex}.sql'
            sql.write_text(value['sql'])
            args += ['--file', sql, '--operation', value['identity']['operation'], '--namespace', value['identity']['namespace']]
            if value['create_object'] is not None: args += ['--object', value['create_object']]
        elif name == 'lookup':
            args += ['--name', value]
        elif name == 'definition':
            args += ['--object', value['object'], '--revision', value['revision']]
        elif name == 'list':
            if value is not None: use('page', value)
        elif name in ('next', 'status', 'prepare_resume'):
            use('compiled', value)
        elif name == 'prepare_control':
            use('compiled', value['intent'])
            command = dict(cancel_operation='cancel', cleanup_operation='cleanup', cancel_upload='cancel-upload', collect_upload='collect-upload')[value['control']]
        elif name in ('prepare', 'prepare_initialize', 'prepare_dependency'):
            control = self.root / f'control-{uuid.uuid4().hex}.json'
            control.write_text(json.dumps(value))
            control.chmod(0o600)
            args += ['--file', control]
        elif name in ('submit', 'observe', 'input_disposition', 'progress'):
            use('prepared', value if name == 'submit' else value['prepared'])
            if name != 'submit': args += ['--input', value['input']]
            if name == 'input_disposition': command = 'disposition'
            if name == 'progress': use('compiled', value['intent'], '--intent')
        else:
            assert name == 'describe', name
        if name in ('compile', 'prepare', 'next', 'list') or name.startswith('prepare_'):
            output = self.root / f'output-{uuid.uuid4().hex}.json'
            args += ['--output', output]
        try:
            result = self.invoke(command, args)
        finally:
            for path, previous in original.items(): assert path.read_bytes() == previous
        if output:
            assert stat.S_IMODE(output.stat().st_mode) == 0o600
            assert json.loads(output.read_bytes()) == result
        if name == 'next' and 'prepared' in result:
            return {'next': {'send': result['prepared']}}
        return result


def qualify(executable, root, url, query, lose_send):
    connection = json.loads((root/'console.json').read_text())['catalog']
    connection['scope']['catalog'] = str(connection['scope']['catalog'])
    client = Cli(executable, root, url, connection)
    sequence = 12000

    def compile(sql, object_id=None):
        nonlocal sequence
        sequence += 1
        return client.call({'compile': dict(identity=dict(operation=str(sequence), namespace=str(sequence)), create_object=object_id, sql=sql)})['compiled']

    def finish(compiled):
        reference = compiled['intent']['reference']
        deadline = time.monotonic()+180
        while time.monotonic() < deadline:
            step = client.call({'next': reference})['next']
            if 'terminal' in step: return step['terminal']
            if 'running' in step:
                time.sleep(.02)
                continue
            assert 'send' in step, step
            prepared = step['send']
            receipt = client.call({'submit': prepared})['receipt']
            while time.monotonic() < deadline:
                progress = client.call({'progress': dict(intent=reference, prepared=prepared, input=receipt['position'])})['progress']
                if 'pending' in progress:
                    time.sleep(.02)
                    continue
                processed = progress['processed']
                assert processed['disposition'] is None, processed
                if processed['outcome'] and processed['outcome']['terminal']: return processed['outcome']
                break
        raise AssertionError('General Table CLI operation exceeded deadline')

    # DROP retains original identities. Keep this fixture separate from the
    # bridge's 9001/9002 and installed SDK consumers' 12001 + index * 10.
    original_object, replacement_object = '22001', '22002'
    created = compile('CREATE TABLE cli_people (id INTEGER PRIMARY KEY, name TEXT, tags LIST(INT32))', original_object)
    assert finish(created)['phase'] == 'applied'
    original = client.call({'lookup': 'cli_people'})['definition']
    assert len(original['schema']['columns']) == 3
    inserted = compile("INSERT INTO cli_people VALUES (1,'Ada',LIST(2,3)),(2,'Grace',NULL)")
    assert finish(inserted)['counts'] == dict(matched='2', changed='2')
    assert finish(compile("UPDATE cli_people SET name='Ada' WHERE id=1"))['counts'] == dict(matched='1', changed='0')
    rejected = finish(compile("INSERT INTO cli_people VALUES (3,'prefix',NULL),(1,'duplicate',NULL)"))
    assert rejected['phase'] == 'rejected' and rejected['diagnostic']['code'] == 'table.primary_key_conflict', rejected
    assert len(query('SELECT * FROM cli_people')['rows']) == 2

    saved = compile("UPDATE cli_people SET name='recovered' WHERE id=1")
    prepared = client.call({'next': saved['intent']['reference']})['next']['send']
    lose_send()
    try:
        client.call({'submit': prepared})
        raise AssertionError('Lost receipt was reported as success')
    except Failure as error:
        assert error.status == 6, error
    client.close()
    client = Cli(executable, root, url, connection)
    receipt = client.call({'submit': prepared})['receipt']
    assert receipt['position'] > 0
    assert finish(saved)['counts'] == dict(matched='1', changed='1')

    assert finish(compile('ALTER TABLE cli_people ADD COLUMN active BOOLEAN DEFAULT TRUE'))['phase'] == 'applied'
    changed = client.call({'lookup': 'cli_people'})['definition']
    assert changed['metadata']['object'] == original['metadata']['object']
    historical = client.call({'definition': dict(object=original['metadata']['object'], revision=original['metadata']['revision'])})['historical']
    assert historical['schema'] == original['schema'] and 'head' not in historical
    # Save and restore an intent above the former 64 KiB file ceiling, without
    # dispatching this independent artifact/ownership probe.
    large = client.call({'prepare': dict(definition=created['saved']['definition'],
        identity=dict(operation='13000', namespace='13000'), name='cli_people',
        action={'mutate': dict(basis={field: changed['metadata'][field] for field in ('object','revision','schema_fingerprint')},
            mutation=dict(action={'insert': [[dict(column='1', value={'cell': {'value': {'atom': {'signed': '3'}}}}),
                dict(column='2', value={'cell': {'value': {'atom': {'utf8': 'x'*70000}}}})]]}, predicate=None))})})['compiled']
    large_path = client.saved('compiled', large['intent']['reference'])
    assert large_path.stat().st_size > 65536
    assert client.call({'status': large['intent']['reference']})['state'] == dict(outcome=None, upload=None)
    assert finish(compile('DELETE FROM cli_people'))['counts'] == dict(matched='2', changed='2')
    assert finish(compile('DROP TABLE cli_people'))['phase'] == 'applied'
    assert finish(compile('CREATE TABLE cli_people (label TEXT)', replacement_object))['phase'] == 'applied'
    assert client.call({'lookup': 'cli_people'})['definition']['metadata']['object'] == replacement_object
    assert client.call({'status': created['intent']['reference']})['state']['outcome']['object'] == original_object
    assert finish(compile('DROP TABLE cli_people'))['phase'] == 'applied'
    client.close()
    return dict(original_object=original_object, replacement_object=replacement_object, large_artifact_bytes=large_path.stat().st_size, recovered_input=receipt['position'])
