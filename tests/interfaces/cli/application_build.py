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
from interfaces.installation.server_managed_tables import await_head, observation


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


def repository(root, content, links=()):
    root.mkdir()
    for name, text in content.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    for name, target in links:
        (root / name).symlink_to(target)
    git(root, 'init', '--quiet')
    git(root, 'add', '.')
    git(root, '-c', 'user.name=Transit proof', '-c', 'user.email=proof@example.invalid', 'commit', '--quiet', '-m', 'Frozen source fixture')
    return git(root, 'rev-parse', 'HEAD')


def source(root, name, text):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def source_diagnostics(cli, parent, command):
    """Exercise the installed human/JSON boundary with synthetic source only."""
    root = parent / f'{command}-diagnostics'
    root.mkdir()
    original = ("CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE rows (id BIGINT); END;\n"
                "CREATE TEST TARGET tests AS BEGIN TEST 'source checks' USING MODULES () AS BEGIN "
                "CREATE PUBLIC TABLE rows (id BIGINT); END; END;\n")

    def run(*args, json_mode=True, expected=1):
        result = subprocess.run([str(cli), command, *(['--format', 'json'] if json_mode else []), *args],
                                cwd=root, capture_output=True, text=True, timeout=30,
                                env={'PATH': '/unavailable'}, preexec_fn=offline)
        assert result.returncode == expected, (args, result.stdout, result.stderr)
        if json_mode:
            assert not result.stderr, result.stderr
            return json.loads(result.stdout)
        assert not result.stdout, result.stdout
        assert '\x1b' not in result.stderr and 'Correct the reported input' not in result.stderr
        return result.stderr

    def failure(code, *args, path=None, kind=None, stage='input'):
        value = run(*args)
        assert value['code'] == f'application.source.{code}' and value['stage'] == stage, value
        assert value['outcome'] == 'not_submitted', value
        facts = {item['field']: item for item in value['facts'] if item}
        human = run(*args, json_mode=False)
        assert value['message'] in human and 'No SQL was submitted.' in human, human
        for field, expected in (('actual_source', path), ('source_kind', kind)):
            if expected is not None:
                assert facts[field]['value']['text'] == expected, value
                assert expected in human, human
        if value['location']:
            at = value['location']
            assert f"{at['source']}:{at['line']}:{at['byte_column']}: error:" in human, human
        return value

    # Entry validation wins over a bad unrelated candidate discovered later.
    (root / 'bad.transit').symlink_to('/unavailable/source')
    failure('entry', path=str(root / 'build.transit'))
    (root / 'bad.transit').unlink()
    source(root, 'build.transit', original)
    for directory in ('.direnv', 'node_modules', '.git', '.transit'):
        (root / directory).mkdir()
        source(root, f'{directory}/invalid.transit', 'not application source')
        (root / directory / 'link').symlink_to('/unavailable/environment')
    (root / 'unrelated-link').symlink_to('/unavailable/leaf')
    os.mkfifo(root / 'unrelated-fifo')
    assert run(expected=0)['ok']
    for name, make, kind in (
            ('linked.transit', lambda p: p.symlink_to('build.transit'), 'sym_link'),
            ('dangling.transit', lambda p: p.symlink_to('/unavailable/source'), 'sym_link'),
            ('pipe.transit', os.mkfifo, 'named_pipe')):
        path = root / name
        make(path)
        refused = failure('file_kind', path=name, kind=kind)
        assert refused['location'] is None, refused
        path.unlink()
    # Malformed bytes and terminal controls remain distinguishable but inert.
    for name, shown in ((b'bad-\xff.transit', 'bad-\\xff.transit'), (b'bad-\x1b.transit', 'bad-\\x1b.transit')):
        path = os.fsencode(root) + b'/' + name
        os.symlink(b'/unavailable/source', path)
        failure('path' if b'\xff' in name else 'file_kind', path=shown)
        os.unlink(path)
    (root / 'invalid.transit').write_bytes(b'\xff')
    failure('encoding', path='invalid.transit')
    (root / 'invalid.transit').unlink()
    (root / 'oversize.transit').write_bytes(b' ' * (1024 * 1024 + 1))
    limited = failure('limit', path='oversize.transit', kind='file')
    assert any(fact and fact['field'] == 'limit' and fact['value'] == {'unsigned': str(1024 * 1024)} for fact in limited['facts']), limited
    (root / 'oversize.transit').unlink()
    long_part = 'long-' + 'a' * 95
    long_dir = root.joinpath(*([long_part] * 6))
    long_dir.mkdir(parents=True)
    source(long_dir, 'source.transit', '')
    truncated = failure('path')
    assert any(fact and fact['field'] == 'actual_source' and fact['availability'] == 'truncated' for fact in truncated['facts']), truncated
    assert '[truncated]' in run(json_mode=False)
    shutil.rmtree(root / long_part)
    if os.geteuid() != 0:
        unreadable = root / 'unreadable.transit'
        unreadable.write_text('')
        unreadable.chmod(0)
        try:
            failure('io', path='unreadable.transit', kind='file')
        finally:
            unreadable.chmod(0o600)
            unreadable.unlink()
    for imported, family in (('missing.transit', 'import'), ('node_modules/ignored.transit', 'path')):
        source(root, 'build.transit', f"IMPORT missing FROM '{imported}';\n" + original)
        failure(family, path=imported)
    (root / 'linked-dir').symlink_to('/unavailable/directory')
    source(root, 'build.transit', "IMPORT outside FROM 'linked-dir/file.transit';\n" + original)
    failure('file_kind', path='linked-dir', kind='sym_link')
    source(root, 'build.transit', original)
    target = failure('target', '--target', 'missing', stage='bind')
    assert any(fact and fact['field'] == 'name' and fact['value'] == {'text': 'missing'} for fact in target['facts']), target
    failure('target', '--target', 'tests' if command == 'build' else 'default', stage='bind')
    source(root, 'bad.transit', '\nIMPORT;')
    syntax = failure('syntax', stage='parse')
    assert syntax['location']['source'] == 'root/bad.transit' and syntax['location']['line'] == '2', syntax
    source(root, 'bad.transit', '\nCREATE nonsense;')
    failure('unsupported', stage='compile')
    (root / 'bad.transit').unlink()
    if command == 'build':
        destination = root / 'already-exists'
        destination.mkdir()
        failure('output', '--out', str(destination), path=str(destination), stage='output')
    assert (root / 'unrelated-link').is_symlink()
    shutil.rmtree(root)


def compiler_journey(cli, root):
    source_diagnostics(cli, root, 'build')
    for args, position in ((['private-value'], 2), (['--check', 'private-value'], 3)):
        invalid = subprocess.run([str(cli), 'build', *args], cwd=root, text=True,
                                 capture_output=True, timeout=30, env={'PATH': '/unavailable'},
                                 preexec_fn=offline)
        assert invalid.returncode == 2 and not invalid.stdout, invalid
        assert f'unknown build option at argument {position}' in invalid.stderr, invalid.stderr
        assert 'private-value' not in invalid.stderr, invalid.stderr
        cli_build(cli, root, *args, expected=2)
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
    # Exercise the read adapter itself against a FIFO after publication. Its
    # nonblocking open must reject even without the source walk's kind check.
    (built / 'application.sql').unlink()
    os.mkfifo(built / 'application.sql')
    fifo = cli_build(cli, project, expected=1)
    assert fifo['code'] == 'application.source.output', fifo
    (built / 'application.sql').unlink()
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
    leaf_rev = repository(leaf, {
        'pkg/build.transit': 'CREATE PUBLIC MODULE Rows(name IDENTIFIER) AS BEGIN CREATE PUBLIC TABLE $name (id BIGINT PRIMARY KEY); INSERT INTO $name VALUES (42); END;',
        'pkg/node_modules/invalid.transit': 'excluded dependency source',
        'pkg/.direnv/invalid.transit': 'excluded environment source',
    }, links=(('pkg/unrelated-link', '/unavailable/non-source'),))
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
    # Independently construct the old tree key. Frozen builds cannot reinterpret
    # its cache under a changed selection policy, even with identical source bytes.
    package = remote / '.transit/packages' / leaf_pin['digest']
    old_hash = hashlib.sha256(b'transit.source.tree.v1\0')
    for item in sorted((package / 'tree').rglob('*.transit')):
        for data in (item.relative_to(package / 'tree').as_posix().encode(), item.read_bytes()):
            old_hash.update(len(data).to_bytes(8, 'little'))
            old_hash.update(data)
    old_digest = old_hash.hexdigest()
    old_package = package.with_name(old_digest)
    manifest_path = package / 'manifest.json'
    manifest_bytes = manifest_path.read_bytes()
    old_manifest = {**json.loads(manifest_bytes), 'digest': old_digest}
    manifest_path.write_text(json.dumps(old_manifest))
    package.rename(old_package)
    old_lock = json.loads(lock_bytes)
    old_lock['dependencies'][1]['digest'] = old_digest
    lock_path.write_text(json.dumps(old_lock))
    stale = cli_build(cli, remote, '--check', expected=1)
    assert stale['code'] == 'application.source.dependency', stale
    assert json.loads(lock_path.read_text()) == old_lock, 'Offline build rewrote an old lock'
    old_package.rename(package)
    manifest_path.write_bytes(manifest_bytes)
    lock_path.write_bytes(lock_bytes)
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


def typed_journey(cli, root):
    fixture = REPO / 'tests/fixtures/application-typed-targets'
    project = root / 'typed-project'
    shutil.copytree(fixture, project)
    checked = cli_build(cli, project, '--check')
    assert checked['statements'] == 6 and not (project / '.transit').exists()
    first = cli_build(cli, project)
    sql = (Path(first['directory']) / 'application.sql').read_text()
    assert sql == (fixture / 'expected.sql').read_text()
    provenance = json.loads((Path(first['directory']) / 'provenance.json').read_text())
    assert all(set(step) == {'sql', 'plan_digest', 'definition', 'call', 'instance', 'bindings_digest'}
               for step in provenance['steps']), 'Internal checked values leaked into the artifact format'
    assert cli_build(cli, project)['reused']
    build = (project / 'build.transit').read_text()
    routing = (project / 'routing.transit').read_text()
    for filename, original, changed in (
            ('build.transit', build, build.replace('ids.Target.Machine(ids.MachineId(7))', 'ids.Target.Machine(ids.SiteId(7))')),
            ('build.transit', build, build.replace('machines.rows, sites.rows', 'sites.rows, machines.rows')),
            ('routing.transit', routing, routing.replace('INSERT INTO $sites VALUES ($id)', 'INSERT INTO $machines VALUES ($id)'))):
        source(project, filename, changed)
        refused = cli_build(cli, project, expected=1)
        assert refused['outcome'] == 'not_submitted' and refused['location'] is not None
        assert (Path(first['directory']) / 'application.sql').read_text() == sql
        source(project, filename, original)
    shutil.rmtree(project)
    return sql


def queue_journey(cli, root):
    fixture = REPO / 'tests/fixtures/application-queue-programs'
    project = root / 'queue-project'
    shutil.copytree(fixture, project)
    checked = cli_build(cli, project, '--check')
    assert checked['statements'] == 7 and not (project / '.transit').exists()
    product = cli_build(cli, project)
    sql = (Path(product['directory']) / 'application.sql').read_text()
    assert sql == (fixture / 'expected.sql').read_text()
    assert cli_build(cli, project)['reused']
    original = (project / 'workflow.transit').read_text()
    for changed in (original.replace('PRODUCE INTO $output', 'ENQUEUE INTO $output'),
                    original.replace('REQUIRE request.id > 0', 'REQUIRE request.id'),
                    original.replace('AUTHORIZE DATAFLOW $name AS ROLE CURRENT_ROLE;', '')):
        source(project, 'workflow.transit', changed)
        refused = cli_build(cli, project, expected=1)
        assert refused['outcome'] == 'not_submitted' and refused['location'] is not None, refused
        assert (Path(product['directory']) / 'application.sql').read_text() == sql
    shutil.rmtree(project)
    return sql



def typed_queue_journey(cli, root):
    fixture = REPO / 'tests/fixtures/application-typed-queue'
    project = root / 'typed-queue-project'
    shutil.copytree(fixture, project)
    checked = cli_build(cli, project, '--check')
    assert checked['statements'] == 25 and not (project / '.transit').exists()
    product = cli_build(cli, project)
    sql = (Path(product['directory']) / 'application.sql').read_text()
    assert sql == (fixture / 'expected.sql').read_text()
    assert cli_build(cli, project)['reused']
    original = (project / 'workflow.transit').read_text()
    for changed in (original.replace('found.id = request.machine_id', 'found.id = request.id'),
                    original.replace('THEN request.machine_id ELSE found.id', 'THEN request.machine_id ELSE request.id'),
                    original.replace('VALUES (id, machine, request.body)', 'VALUES (id, 7, request.body)'),
                    original.replace('PRODUCE INTO $output', 'PRODUCE INTO typed_events_a')):
        # The literal-name case still checks the destination: force a wrong domain.
        if 'PRODUCE INTO typed_events_a' in changed:
            changed = changed.replace('VALUES (id, machine, request.body)', 'VALUES (machine, machine, request.body)')
        source(project, 'workflow.transit', changed)
        refused = cli_build(cli, project, expected=1)
        assert refused['code'] == 'application.source.domain' and refused['location'] is not None, refused
        assert (Path(product['directory']) / 'application.sql').read_text() == sql
    source(project, 'workflow.transit', original)
    moved = root / 'typed-queue-relocated'
    shutil.copytree(project, moved, ignore=shutil.ignore_patterns('.transit'))
    entry = (moved / 'build.transit').read_text().replace("IMPORT resources FROM 'resources.transit'", "IMPORT data FROM 'renamed.transit'").replace('resources.Resources', 'data.Resources')
    source(moved, 'build.transit', entry)
    (moved / 'resources.transit').rename(moved / 'renamed.transit')
    relocated = cli_build(cli, moved)
    assert relocated['sql_digest'] == product['sql_digest'] and relocated['input_digest'] != product['input_digest']
    source(moved, 'child.transit', "IMPORT library FROM 'build.transit'; CREATE TARGET default AS BEGIN USE library.Scenario(); END;")
    assert cli_build(cli, moved, '-f', 'child.transit')['sql_digest'] == product['sql_digest']
    repository_path = root / 'typed-queue-repository'
    revision = repository(repository_path, {f'pkg/{path.name}': path.read_text() for path in fixture.glob('*.transit')})
    remote = root / 'typed-queue-remote'
    remote.mkdir()
    source(remote, 'build.transit', f"DEPENDENCY typed FROM '{repository_path}' REVISION '{revision}' SUBDIRECTORY 'pkg'; IMPORT library FROM PACKAGE typed FILE 'build.transit'; CREATE TARGET default AS BEGIN USE library.Scenario(); END;")
    fetched = cli_build(cli, remote, '--fetch', fetch=True)
    assert fetched['sql_digest'] == product['sql_digest'] and fetched['dependencies'] == 1
    lock = (remote / 'transit.lock').read_bytes()
    shutil.rmtree(repository_path)
    assert cli_build(cli, remote)['sql_digest'] == product['sql_digest']
    assert (remote / 'transit.lock').read_bytes() == lock
    for directory in (project, moved, remote):
        shutil.rmtree(directory)
    return sql


def install_typed_queue(fixture, sql):
    lines = sql.splitlines()
    fixture.console('\n'.join(lines[:20]))
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        token = list(os.urandom(16))
        client.call(dict(execute=dict(sql=lines[20], token=token)), discard_response=True)
        original = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
        assert original['matched'] == original['changed'] == 1, original
        client.call(dict(execute=dict(sql=lines[20].replace("'ready'", "'changed'"), token=token)), error='SqlTokenConflict')
        assert client.call(dict(status=dict(token=token)))['operation']['identity'] == original['identity']
    finally:
        client.close()
    fixture.console('\n'.join(lines[21:]))
    outcomes = []
    for suffix, refused in (('a', 3), ('b', 0)):
        name = f'typed_process_{suffix}'
        head = await_head(fixture, name, lambda h: h['completed'] + h['refused'] >= refused + 1)['observation']['head']
        assert (head['completed'], head['refused']) == (1, refused), head
        rows = fixture.console(f'SELECT id, machine_id, body FROM typed_accepted_{suffix}; CONSUME id, machine_id, body FROM typed_events_{suffix};')
        assert [records(value) for value in rows if 'schema' in value] == [[{'id': '7', 'machine_id': '7', 'body': 'ready'}]] * 2, rows
        outcomes += rows
        await_head(fixture, name, lambda h: h['pending'] is not None and h['attempt'] == refused + 2)
        fixture.console(f'SUSPEND DATAFLOW {name};')
        settled = await_head(fixture, name, lambda h: h['pending'] is None)['observation']['head']
        assert (settled['completed'], settled['refused']) == (1, refused + 1), settled
    # Accepted scalar SQL is immutable; recovery uses this original append token
    # across the same retained installation, without source files or rebuilding.
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        token = list(os.urandom(16))
        client.call(dict(execute=dict(sql="ENQUEUE INTO typed_requests_a VALUES (11, 7, 'ready', 'retained');", token=token)), discard_response=True)
        original = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
        assert original['matched'] == original['changed'] == 1
        return outcomes, token, original['identity']
    finally:
        client.close()


def resume_typed_queue(fixture, token, identity):
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        original = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
        assert original['identity'] == identity and original['matched'] == original['changed'] == 1, original
    finally:
        client.close()
    head = observation(fixture, 'typed_process_a')['observation']['head']
    assert head['control']['state'] == 'suspended' and (head['completed'], head['refused']) == (1, 4), head
    fixture.console('RESUME DATAFLOW typed_process_a;')
    head = await_head(fixture, 'typed_process_a', lambda h: h['completed'] >= 2)['observation']['head']
    assert head['refused'] == 4, head
    expected = [{'id': '7', 'machine_id': '7', 'body': 'ready'}, {'id': '11', 'machine_id': '7', 'body': 'retained'}]
    outcomes = fixture.console('SELECT id, machine_id, body FROM typed_accepted_a; CONSUME id, machine_id, body FROM typed_events_a;')
    for value in outcomes:
        if 'schema' in value:
            assert sorted(records(value), key=lambda row: int(row['id'])) == expected, value
    return outcomes

def execute_program(cli, sql, typed_sql, queue_sql, typed_queue_sql):
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
        typed_outcomes = fixture.console(typed_sql)
        typed_rows = [records(value) for value in typed_outcomes if 'schema' in value]
        assert typed_rows == [[{'id': '7'}], [{'id': '7'}]], typed_rows
        typed_counts = [value['completion']['counts'] for value in typed_outcomes
                        if value.get('completion', {}).get('kind') == 'insert']
        assert typed_counts == [{'matched': '1', 'changed': '1'}] * 2
        outcomes += typed_outcomes
        typed_queue_rows, typed_token, typed_identity = install_typed_queue(fixture, typed_queue_sql)
        outcomes += typed_queue_rows
        declarations, enqueue = queue_sql.rsplit('\n', 2)[:2]
        fixture.console(declarations)
        # Lose the reply to the emitted append and settle only its original
        # token. Changed source or SQL cannot manufacture another accepted input.
        client = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            token = list(os.urandom(16))
            client.call(dict(execute=dict(sql=enqueue, token=token)), discard_response=True)
            original = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
            assert original['matched'] == original['changed'] == 3, original
            client.call(dict(execute=dict(sql=enqueue.replace("'ready'", "'changed'"), token=token)), error='SqlTokenConflict')
            assert client.call(dict(status=dict(token=token)))['operation']['identity'] == original['identity']
        finally:
            client.close()
        settled = await_head(fixture, 'process', lambda head: head['completed'] + head['refused'] >= 3)
        head = settled['observation']['head']
        assert (head['completed'], head['refused']) == (1, 2), settled
        queue_outcomes = fixture.console('SELECT id, body FROM accepted; CONSUME id, body FROM events;')
        assert [records(value) for value in queue_outcomes if 'schema' in value] == [[{'id': '7', 'body': 'accepted:ready'}]] * 2, queue_outcomes
        outcomes += queue_outcomes
        # Active programs retain an acquisition while waiting for their next
        # input. Fence that exact empty acquisition before retaining work across
        # restart; its cancellation is a separately recorded refused attempt.
        await_head(fixture, 'process', lambda h: h['attempt'] == 4 and h['pending'] is not None)
        fixture.console('SUSPEND DATAFLOW process;')
        suspended = await_head(fixture, 'process', lambda h: h['pending'] is None)['observation']['head']
        assert (suspended['completed'], suspended['refused']) == (1, 3), suspended
        fixture.console("ENQUEUE INTO requests VALUES (9, 'retained input');")
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        outcomes += resume_typed_queue(fixture, typed_token, typed_identity)
        assert records(fixture.console('SELECT * FROM second_items;')[-1]) == [{'id': '9'}]
        assert records(fixture.console('SELECT * FROM sites;')[-1]) == [{'id': '7'}]
        recovered = observation(fixture, 'process')['observation']['head']
        assert (recovered['completed'], recovered['refused'], recovered['checkpoint']) == (1, 3, suspended['checkpoint']), recovered
        assert recovered['control']['state'] == 'suspended', recovered
        fixture.console('RESUME DATAFLOW process;')
        resumed = await_head(fixture, 'process', lambda h: h['completed'] >= 2)
        assert resumed['observation']['head']['refused'] == 3, resumed
        expected = [{'id': '7', 'body': 'accepted:ready'}, {'id': '9', 'body': 'accepted:retained input'}]
        for statement in ('SELECT id, body FROM accepted;', 'CONSUME id, body FROM events;'):
            assert sorted(records(fixture.console(statement)[-1]), key=lambda row: int(row['id'])) == expected
        disable_sql_credential(fixture.root, fixture.config['ports'], installation=fixture.installation)
        fixture.console('SELECT * FROM first_items;', expected=1)
        fixture.console('SELECT * FROM machines;', expected=1)
        fixture.console('CONSUME * FROM events;', expected=1)
        fixture.console('SHOW DATAFLOW process;', expected=1)
        fixture.console('CONSUME * FROM typed_events_a;', expected=1)
        fixture.console('SHOW DATAFLOW typed_process_a;', expected=1)
        fixture.console('SELECT * FROM typed_accepted_a;', expected=1)
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
        typed_sql = typed_journey(cli, Path(temporary))
        queue_sql = queue_journey(cli, Path(temporary))
        typed_queue_sql = typed_queue_journey(cli, Path(temporary))
        generated = execute_program(cli, sql, typed_sql, queue_sql, typed_queue_sql)
        oracle = execute_program(cli, (REPO / 'tests/fixtures/application-build/expected.sql').read_text(),
                                 (REPO / 'tests/fixtures/application-typed-targets/expected.sql').read_text(),
                                 (REPO / 'tests/fixtures/application-queue-programs/expected.sql').read_text(),
                                 (REPO / 'tests/fixtures/application-typed-queue/expected.sql').read_text())
        # Both sessions decode verified terminal coverage. Compare logical rows;
        # durable IDs/observation cuts legitimately differ between installations.
        def logical(outcomes):
            return [dict(schema=value['schema']['type'], rows=value['rows'], count=value['complete']['rows']) for value in outcomes if 'schema' in value]
        assert logical(generated) == logical(oracle)
    print('Application build: locked offline composition, source-free SQL, restart and revocation passed')


if __name__ == '__main__':
    main()
