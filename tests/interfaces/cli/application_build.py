#!/usr/bin/env python3
"""Real offline source builds and ordinary SQL execution without source access."""
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tempfile

from runner.paths import ROOT as REPO
from interfaces.cli.table_console import records
from interfaces.installation.server import Fixture
from interfaces.sql_sessions.local import Client
from interfaces.cli.migrate_lifecycle import disable_sql_credential


def offline(interrupt_publish=False):
    """Deny socket creation/connect and io_uring setup in the actual child."""
    arch, socket_nr, connect_nr = {'x86_64': (0xc000003e, 41, 42), 'aarch64': (0xc00000b7, 198, 203)}[platform.machine()]
    code = [(0x20, 0, 0, 4), (0x15, 1, 0, arch), (0x06, 0, 0, 0x80000000), (0x20, 0, 0, 0)]
    for number in (socket_nr, connect_nr, 425):
        code += [(0x15, 0, 1, number), (0x06, 0, 0, 0x00050000 | errno.ENOSYS)]
    if interrupt_publish:
        renameat2 = 316 if platform.machine() == 'x86_64' else 276
        code += [(0x15, 0, 1, renameat2), (0x06, 0, 0, 0x80000000)]
    code += [(0x06, 0, 0, 0x7fff0000)]
    class Filter(ctypes.Structure):
        _fields_ = [('code', ctypes.c_ushort), ('jt', ctypes.c_ubyte), ('jf', ctypes.c_ubyte), ('k', ctypes.c_uint)]
    class Program(ctypes.Structure):
        _fields_ = [('length', ctypes.c_ushort), ('filter', ctypes.POINTER(Filter))]
    filters = (Filter * len(code))(*(Filter(*item) for item in code))
    program = Program(len(code), filters)
    libc = ctypes.CDLL(None, use_errno=True)
    for option, argument in ((38, 1), (22, 2)):
        if libc.prctl(option, argument, ctypes.byref(program) if option == 22 else 0, 0, 0):
            raise OSError(ctypes.get_errno(), 'Cannot install offline proof filter')


def cli_build(cli, root, *args, expected=0, fetch=False):
    result = subprocess.run([str(cli), 'build', '--format', 'json', *map(str, args)],
                            cwd=root, text=True, capture_output=True, timeout=150,
                            env=os.environ.copy() if fetch else {'PATH': '/unavailable'},
                            preexec_fn=None if fetch else offline)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    assert not result.stderr, result.stderr
    value = json.loads(result.stdout)
    assert value.get('ok', False) == (expected == 0), value
    if expected:
        assert value['outcome'] == 'not_submitted', value
    return value


def git(root, *args):
    result = subprocess.run(['git', '-C', str(root), *args], text=True, capture_output=True, timeout=30)
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


def repository(root, content):
    root.mkdir()
    for name, text in content.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    git(root, 'init', '--quiet')
    git(root, 'add', '.')
    git(root, '-c', 'user.name=Transit proof', '-c', 'user.email=proof@example.invalid', 'commit', '--quiet', '-m', 'Frozen source fixture')
    return git(root, 'rev-parse', 'HEAD')


def source(root, name, text):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def compiler_journey(cli, root):
    control = subprocess.run([sys.executable, '-c', 'import socket; socket.socket()'], capture_output=True, preexec_fn=offline)
    assert control.returncode != 0 and b'Function not implemented' in control.stderr, control
    corpus = REPO / 'tests/fixtures/application-build'
    project = root / 'project'
    project.mkdir()
    for name in ('build.transit', 'rows.transit'):
        shutil.copy(corpus / name, project / name)
    checked = cli_build(cli, project, '--check')
    assert checked['statements'] == 8 and not (project / '.transit').exists()
    first = cli_build(cli, project)
    built = Path(first['directory'])
    sql = (built / 'application.sql').read_text()
    assert hashlib.sha256(sql.encode()).hexdigest() == first['sql_digest']
    assert sql == (corpus / 'expected.sql').read_text()
    second = cli_build(cli, project)
    assert second['reused'] and second['input_digest'] == first['input_digest']
    cli_build(cli, project, '--out', built, expected=1)
    provenance = json.loads((built / 'provenance.json').read_text())
    assert provenance['complete'] and len(provenance['steps']) == 8
    assert provenance['steps'][0]['call'] is not None
    # Every returned byte is checked; a content-addressed directory is no oracle.
    original = (built / 'application.sql').read_bytes()
    (built / 'application.sql').write_bytes(original + b'-- corruption')
    cli_build(cli, project, expected=1)
    (built / 'application.sql').write_bytes(original)
    interrupted = root / 'interrupted-output'
    killed = subprocess.run([str(cli), 'build', '--out', str(interrupted)], cwd=project,
                            capture_output=True, timeout=60, env={'PATH': '/unavailable'},
                            preexec_fn=lambda: offline(interrupt_publish=True))
    assert killed.returncode == -signal.SIGSYS, killed
    assert not interrupted.exists() and (built / 'application.sql').read_bytes() == original
    assert list(root.glob('.pending-*')), 'No staged artifact existed at the publication cut'
    cli_build(cli, project, '--out', interrupted)
    assert (interrupted / 'application.sql').read_bytes() == original
    for args in (('--check', '--out', 'out'), ('--fetch', '--check'), ('--target', '../escape'), ('--config', 'secret.json')):
        cli_build(cli, project, *args, expected=2)
    source(project, 'invalid.transit', 'CREATE QUEUE unsupported (id BIGINT);')
    refusal = cli_build(cli, project, '--check', expected=1)
    assert refusal['location']['line'] == '1' and refusal['location']['source'], refusal
    (project / 'invalid.transit').unlink()
    bad_type = root / 'bad-type'
    bad_type.mkdir()
    source(bad_type, 'build.transit', "CREATE MODULE M(t TYPE) AS BEGIN CREATE PUBLIC TABLE $t (id BIGINT); END; CREATE TARGET default AS BEGIN USE M(TYPE BIGINT); END;")
    refused_type = cli_build(cli, bad_type, expected=1)
    assert any(fact and fact['field'] == 'native_cause' and fact['value'] == {'text': 'InvalidSourceTypeOperand'} for fact in refused_type['facts']), refused_type
    assert not (bad_type / '.transit').exists()

    (project / 'linked.transit').symlink_to(project / 'rows.transit')
    cli_build(cli, project, '--check', expected=1)
    (project / 'linked.transit').unlink()
    # A moved root/alias affects provenance, never explicit object bindings.
    moved = root / 'relocated'
    shutil.copytree(project, moved, ignore=shutil.ignore_patterns('.transit'))
    text = (moved / 'build.transit').read_text().replace("IMPORT rows FROM 'rows.transit'", "IMPORT library FROM 'renamed.transit'").replace('rows.Rows', 'library.Rows')
    (moved / 'build.transit').write_text(text)
    (moved / 'rows.transit').rename(moved / 'renamed.transit')
    relocated = cli_build(cli, moved)
    assert relocated['sql_digest'] == first['sql_digest'] and relocated['input_digest'] != first['input_digest']
    # Independent child target uses the same module language.
    child = cli_build(cli, moved, '-f', 'renamed.transit')
    assert child['statements'] > 0 and child['sql_digest'] != first['sql_digest']
    unsupported = root / 'platform'
    unsupported.mkdir()
    inventory = json.loads((corpus / 'platform/inputs.json').read_text())
    assert len(inventory['files']) == 7
    for item in inventory['files']:
        body = (corpus / 'platform' / item['path']).read_bytes()
        assert len(body) == item['bytes'] and hashlib.sha256(body).hexdigest() == item['sha256']
        (unsupported / 'build.transit').write_bytes(body)
        rejected = cli_build(cli, unsupported, '--check', expected=1)
        assert rejected['location'] is not None, rejected
    leaf = root / 'leaf-repository'
    leaf_rev = repository(leaf, {'pkg/build.transit': 'CREATE PUBLIC MODULE Rows(name IDENTIFIER) AS BEGIN CREATE PUBLIC TABLE $name (id BIGINT PRIMARY KEY); INSERT INTO $name VALUES (42); END;'})
    dependency = f"DEPENDENCY leaf FROM '{leaf}' REVISION '{leaf_rev}' SUBDIRECTORY 'pkg';\n"
    bridge = root / 'bridge-repository'
    bridge_text = dependency + "IMPORT leaf FROM PACKAGE leaf FILE 'build.transit'; CREATE PUBLIC MODULE Wrap(name IDENTIFIER) AS BEGIN USE leaf.Rows(name); END;"
    bridge_rev = repository(bridge, {'source/build.transit': bridge_text})
    remote = root / 'remote-project'
    remote.mkdir()
    main = f"DEPENDENCY bridge FROM '{bridge}' REVISION '{bridge_rev}' SUBDIRECTORY 'source';\nIMPORT bridge FROM PACKAGE bridge FILE 'build.transit'; CREATE TARGET default AS BEGIN USE bridge.Wrap(NAME 'remote_items'); SELECT * FROM remote_items; END;"
    source(remote, 'build.transit', main)
    cli_build(cli, remote, '--check', expected=1)
    # Kill the real fetch at cache publication, after verified source and its
    # manifest are staged. A partial cache must not publish a usable lock.
    killed = subprocess.run([str(cli), 'build', '--fetch'], cwd=remote,
                            capture_output=True, timeout=150,
                            preexec_fn=lambda: offline(interrupt_publish=True))
    assert killed.returncode == -signal.SIGSYS, (killed.returncode, killed.stdout, killed.stderr)
    assert not (remote / 'transit.lock').exists()
    packages = remote / '.transit/packages'
    staged = list(packages.glob('.pending-*'))
    assert any((item / 'manifest.json').is_file() and (item / 'tree/build.transit').is_file() for item in staged)
    assert all(item.name.startswith('.pending-') for item in packages.iterdir())
    cli_build(cli, remote, '--check', expected=1)
    fetched = cli_build(cli, remote, '--fetch', fetch=True)
    assert fetched['dependencies'] == 2
    lock_path = remote / 'transit.lock'
    lock_bytes = lock_path.read_bytes()
    locked = json.loads(lock_bytes)
    assert [pin['name'] for pin in locked['dependencies']] == ['bridge', 'leaf']
    # Hide origin repositories and forbid socket/Git access for frozen rebuilds.
    leaf.rename(root / 'leaf-absent')
    bridge.rename(root / 'bridge-absent')
    cold = cli_build(cli, remote)
    warm = cli_build(cli, remote)
    assert cold['sql_digest'] == warm['sql_digest'] and warm['reused']
    assert lock_path.read_bytes() == lock_bytes
    override = root / 'override'
    override.mkdir()
    source(override, 'build.transit', (root / 'leaf-absent/pkg/build.transit').read_text().replace('42', '43'))
    local = cli_build(cli, remote, '--override', f'leaf={override}')
    assert local['sql_digest'] != cold['sql_digest'] and local['input_digest'] != cold['input_digest']
    assert lock_path.read_bytes() == lock_bytes
    assert any(item['override'] for item in json.loads((Path(local['directory']) / 'provenance.json').read_text())['dependencies'])
    # Foreign/missing definitions and stale pins refuse before artifact creation.
    for changed in ({**locked, 'definition': 'foreign'}, {key: value for key, value in locked.items() if key != 'definition'}):
        lock_path.write_text(json.dumps(changed))
        cli_build(cli, remote, '--check', expected=1)
    lock_path.write_bytes(lock_bytes)
    leaf_pin = locked['dependencies'][1]
    cached = remote / '.transit/packages' / leaf_pin['digest'] / 'tree/build.transit'
    previous = cached.read_bytes()
    cached.write_bytes(previous + b'\n-- altered')
    cli_build(cli, remote, '--check', expected=1)
    cached.write_bytes(previous)
    (remote / 'build.transit').write_text(main.replace(bridge_rev, '0' * 40))
    cli_build(cli, remote, '--check', expected=1)
    (remote / 'build.transit').write_text(main)
    cli_build(cli, remote, '--override', f'undeclared={override}', '--check', expected=1)
    # Partial publications cannot be mistaken for complete results.
    pending = remote / '.transit/build/default/.pending-interrupted'
    pending.mkdir()
    (pending / 'application.sql').write_text('CREATE TABLE incomplete')
    assert cli_build(cli, remote)['input_digest'] == cold['input_digest']
    output = root / 'saved-application.sql'
    output.write_text(sql)
    # Retain only ordinary SQL before the execution proof.
    for directory in (project, moved, remote, override, root / 'leaf-absent', root / 'bridge-absent'):
        shutil.rmtree(directory)
    return output


def execute_program(cli, sql):
    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        outcomes = fixture.console(sql)
        commands = [value['completion'] for value in outcomes if 'completion' in value]
        mutations = [(item['kind'], item['counts']) for item in commands if item['kind'] in ('insert', 'update', 'delete')]
        assert mutations == [('insert', {'matched': '1', 'changed': '1'}), ('insert', {'matched': '1', 'changed': '1'}), ('update', {'matched': '1', 'changed': '1'}), ('delete', {'matched': '0', 'changed': '0'})], mutations
        rows = [records(value) for value in outcomes if 'schema' in value]
        assert rows[-2:] == [[{'id': '8'}], [{'id': '9'}]], rows
        # A failed duplicate write leaves accepted rows unchanged.
        fixture.console('INSERT INTO first_items VALUES (8);', expected=1)
        assert records(fixture.console('SELECT * FROM first_items;')[-1]) == [{'id': '8'}]
        # Lose every response outcome byte for an original emitted INSERT.
        # Source changes cannot replace that SQL or create a fresh admission.
        saved = fixture.root / 'original.sql'
        saved.write_text(sql.splitlines()[1])
        frozen = saved.read_bytes()
        client = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            token = list(os.urandom(16))
            client.call(dict(execute=dict(sql=saved.read_text(), token=token)), discard_response=True)
            source(fixture.root, 'build.transit', 'CREATE TARGET changed AS BEGIN unsupported; END;')
            recovered = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
            assert recovered['matched'] == recovered['changed'] == 1, recovered
            assert saved.read_bytes() == frozen
            client.call(dict(execute=dict(sql=saved.read_text().replace('7', '99'), token=token)), error='SqlTokenConflict')
            assert client.call(dict(status=dict(token=token)))['operation']['identity'] == recovered['identity']
        finally:
            client.close()
        assert sorted(records(fixture.console('SELECT * FROM first_items;')[-1]), key=lambda row: int(row['id'])) == [{'id': '7'}, {'id': '8'}]
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        assert records(fixture.console('SELECT * FROM second_items;')[-1]) == [{'id': '9'}]
        disable_sql_credential(fixture.root, fixture.config['ports'], installation=fixture.installation)
        fixture.console('SELECT * FROM first_items;', expected=1)
        passed = True
        return outcomes
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed application build execution: {fixture.root}', file=sys.stderr)


def main():
    cli = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix='transit-application-build-') as temporary:
        sql = compiler_journey(cli, Path(temporary)).read_text()
        generated = execute_program(cli, sql)
        oracle = execute_program(cli, (REPO / 'tests/fixtures/application-build/expected.sql').read_text())
        # Both sessions decode verified terminal coverage. Compare logical rows;
        # durable IDs/observation cuts legitimately differ between installations.
        def logical(outcomes):
            return [dict(schema=value['schema']['type'], rows=value['rows'], count=value['complete']['rows']) for value in outcomes if 'schema' in value]
        assert logical(generated) == logical(oracle)
    print('Application build: locked offline composition, source-free SQL, restart and revocation passed')


if __name__ == '__main__':
    main()
