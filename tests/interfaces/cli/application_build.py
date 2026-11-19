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
        assert 'error: ' in human and 'Code: application.source' not in human and 'native_cause:' not in human, human
        if command == 'build':
            assert 'Build Summary:' in human and 'steps succeeded; 1 failed' in human, human
        else:
            assert 'Test Summary:' in human and '(no SQL submitted)' in human, human
        for field, expected in (('actual_source', path), ('source_kind', kind)):
            if expected is not None:
                assert facts[field]['value']['text'] == expected, value
                assert expected in human, human
        if value['location']:
            at = value['location']
            shown = at['source'].removeprefix('root/')
            assert f"{shown}:{at['line']}:{at['byte_column']}: error:" in human and 'root/' not in human, human
            assert '\n^' in human or ' ^' in human, human
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
    assert int(syntax['location']['length']) == 1, syntax
    colored = subprocess.run([str(cli), command, '--color', 'on'], cwd=root, capture_output=True, text=True,
                             timeout=30, env={'PATH': '/unavailable'}, preexec_fn=offline)
    assert colored.returncode == 1 and not colored.stdout, colored
    assert '\x1b[1;31merror:\x1b[0m' in colored.stderr and '\x1b[1;32m^\x1b[0m' in colored.stderr, colored.stderr
    assert "expected identifier, found ';'" in colored.stderr, colored.stderr
    plain_forced = subprocess.run([str(cli), command, '--color', 'off'], cwd=root, capture_output=True, text=True,
                                  timeout=30, env={'PATH': '/unavailable'}, preexec_fn=offline)
    assert plain_forced.returncode == 1 and '\x1b' not in plain_forced.stderr, plain_forced.stderr
    json_colored = subprocess.run([str(cli), command, '--format', 'json', '--color', 'on'], cwd=root,
                                  capture_output=True, text=True, timeout=30, env={'PATH': '/unavailable'}, preexec_fn=offline)
    assert json_colored.returncode == 1 and not json_colored.stderr and '\x1b' not in json_colored.stdout
    assert json.loads(json_colored.stdout)['code'] == 'application.source.syntax'
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
    corpus = REPO / 'third_party/transitc/tests/fixtures/application-build'
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
    fixture = REPO / 'third_party/transitc/tests/fixtures/application-typed-targets'
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
    fixture = REPO / 'third_party/transitc/tests/fixtures/application-queue-programs'
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
    fixture = REPO / 'third_party/transitc/tests/fixtures/application-typed-queue'
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
    entry = (moved / 'build.transit').read_text().replace("IMPORT resources FROM 'resources.transit'", "IMPORT library FROM 'renamed.transit'").replace('resources.Resources', 'library.Resources')
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
    assert fetched['dependencies'] == 1
    lock = (remote / 'transit.lock').read_bytes()
    shutil.rmtree(repository_path)
    assert cli_build(cli, remote)['sql_digest'] == product['sql_digest']
    assert (remote / 'transit.lock').read_bytes() == lock
    for directory in (project, moved, remote):
        shutil.rmtree(directory)
    return sql


def modular_programs_journey(cli, root):
    fixture = REPO / 'third_party/transitc/tests/fixtures/application-modular-programs'
    project = root / 'modular-programs-project'
    shutil.copytree(fixture, project)
    checked = cli_build(cli, project, '--check')
    assert checked['statements'] == 32 and not (project / '.transit').exists()
    product = cli_build(cli, project)
    sql = (Path(product['directory']) / 'application.sql').read_text()
    assert max(len(line.encode()) for line in sql.splitlines()) > 4096
    assert max(len(line.encode()) for line in sql.splitlines()) <= 65536
    assert sql == (fixture / 'expected.sql').read_text()
    assert '__t$' in sql and '__t$' not in (fixture / 'oracle.sql').read_text()
    assert cli_build(cli, project)['reused']
    workflow_text = (project / 'workflow.transit').read_text()
    helpers_text = (project / 'helpers.transit').read_text()
    for filename, original_text, changed_text, expected_code in (
            ('workflow.transit', workflow_text,
             workflow_text.replace("LET summary = 'caller-local-shadow-sentinel';", "LET summary = helpers.clean_note(order_item.note);"),
             'application.source.import'),
            ('workflow.transit', workflow_text,
             workflow_text.replace('helpers.verify_account($accounts, order_item.account_id, order_item.amount)',
                                   'helpers.verify_account($accounts, order_item.id, order_item.amount)'),
             'application.source.domain'),
            ('helpers.transit', helpers_text,
             helpers_text.replace('RETURN token = token;', 'RETURN token = RANDOM_TOKEN(16);'),
             'application.source.unsupported'),
            ('helpers.transit', helpers_text,
             helpers_text.replace('RETURN order_id;', 'RETURN preserve_order(order_id);'),
             'application.source.unsupported')):
        source(project, filename, changed_text)
        refused = cli_build(cli, project, expected=1)
        assert refused['code'] == expected_code and refused['location'] is not None, (filename, expected_code, refused)
        assert (Path(product['directory']) / 'application.sql').read_text() == sql
        source(project, filename, original_text)
    moved = root / 'modular-programs-relocated'
    shutil.copytree(project, moved, ignore=shutil.ignore_patterns('.transit'))
    entry = (moved / 'build.transit').read_text().replace("IMPORT resources FROM 'resources.transit'", "IMPORT library FROM 'renamed.transit'").replace('resources.', 'library.')
    source(moved, 'build.transit', entry)
    (moved / 'resources.transit').rename(moved / 'renamed.transit')
    relocated = cli_build(cli, moved)
    assert relocated['sql_digest'] == product['sql_digest'] and relocated['input_digest'] != product['input_digest']
    repository_path = root / 'modular-programs-repository'
    revision = repository(repository_path, {f'pkg/{path.name}': path.read_text() for path in fixture.glob('*.transit')})
    remote = root / 'modular-programs-remote'
    remote.mkdir()
    source(remote, 'build.transit', f"DEPENDENCY modular FROM '{repository_path}' REVISION '{revision}' SUBDIRECTORY 'pkg'; IMPORT library FROM PACKAGE modular FILE 'build.transit'; CREATE TARGET default AS BEGIN USE library.Scenario(); END;")
    fetched = cli_build(cli, remote, '--fetch', fetch=True)
    assert fetched['dependencies'] == 1
    lock = (remote / 'transit.lock').read_bytes()
    shutil.rmtree(repository_path)
    assert cli_build(cli, remote)['sql_digest'] == product['sql_digest']
    assert (remote / 'transit.lock').read_bytes() == lock
    for directory in (project, moved, remote):
        shutil.rmtree(directory)
    return sql


def install_modular_programs(fixture, sql):
    lines = sql.splitlines()
    assert len(lines) == 32, len(lines)
    # Configure 120s Queue leases before binding Dataflows and activate one
    # Queue consumer at a time so 50-state 6-participant commits retain wide
    # margin on synchronous disk storage under CI and host I/O contention.
    fixture.console(
        '\n'.join(lines[:6]) + '\n'
        "ALTER QUEUE modular_requests_a SET (lease_duration = '120s', max_lease_duration = '120s');\n"
        "ALTER QUEUE modular_followup_a SET (lease_duration = '120s', max_lease_duration = '120s');\n"
        + '\n'.join(lines[6:9]))
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        token = list(os.urandom(16))
        client.call(dict(execute=dict(sql=lines[26], token=token)), discard_response=True)
        original = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
        assert original['matched'] == original['changed'] == 1, original
        client.call(dict(execute=dict(sql=lines[26].replace("'priority'", "'changed'"), token=token)), error='SqlTokenConflict')
        assert client.call(dict(status=dict(token=token)))['operation']['identity'] == original['identity']
    finally:
        client.close()
    head_a = await_head(fixture, 'modular_orders_a', lambda h: h['completed'] + h['refused'] >= 1)['observation']['head']
    assert (head_a['completed'], head_a['refused']) == (1, 0), head_a
    fixture.console('\n'.join(lines[27:31]))
    for terminal_count in range(2, 6):
        head_a = await_head(fixture, 'modular_orders_a', lambda h, expected=terminal_count: h['completed'] + h['refused'] >= expected)['observation']['head']
    assert (head_a['completed'], head_a['refused']) == (1, 4), head_a
    await_head(fixture, 'modular_orders_a', lambda h: h['pending'] is not None and h['attempt'] == 6)
    fixture.console('SUSPEND DATAFLOW modular_orders_a;')
    settled_orders_a = await_head(fixture, 'modular_orders_a', lambda h: h['pending'] is None)['observation']['head']
    assert (settled_orders_a['completed'], settled_orders_a['refused']) == (1, 5), settled_orders_a

    fixture.console('\n'.join(lines[9:13]))
    dispatch_head_a = await_head(fixture, 'modular_dispatch_a', lambda h: h['completed'] + h['refused'] >= 1)['observation']['head']
    assert (dispatch_head_a['completed'], dispatch_head_a['refused']) == (1, 0), dispatch_head_a
    await_head(fixture, 'modular_dispatch_a', lambda h: h['pending'] is not None and h['attempt'] == 2)
    fixture.console('SUSPEND DATAFLOW modular_dispatch_a;')
    settled_dispatch_a = await_head(fixture, 'modular_dispatch_a', lambda h: h['pending'] is None)['observation']['head']
    assert (settled_dispatch_a['completed'], settled_dispatch_a['refused']) == (1, 1), settled_dispatch_a

    fixture.console(
        '\n'.join(lines[13:19]) + '\n'
        "ALTER QUEUE modular_requests_b SET (lease_duration = '120s', max_lease_duration = '120s');\n"
        "ALTER QUEUE modular_followup_b SET (lease_duration = '120s', max_lease_duration = '120s');\n"
        + '\n'.join(lines[19:22]) + '\n' + lines[31])
    head_b = await_head(fixture, 'modular_orders_b', lambda h: h['completed'] + h['refused'] >= 1)['observation']['head']
    assert (head_b['completed'], head_b['refused']) == (1, 0), head_b
    await_head(fixture, 'modular_orders_b', lambda h: h['pending'] is not None and h['attempt'] == 2)
    fixture.console('SUSPEND DATAFLOW modular_orders_b;')
    settled_orders_b = await_head(fixture, 'modular_orders_b', lambda h: h['pending'] is None)['observation']['head']
    assert (settled_orders_b['completed'], settled_orders_b['refused']) == (1, 1), settled_orders_b

    fixture.console('\n'.join(lines[22:26]))
    dispatch_head_b = await_head(fixture, 'modular_dispatch_b', lambda h: h['completed'] + h['refused'] >= 1)['observation']['head']
    assert (dispatch_head_b['completed'], dispatch_head_b['refused']) == (1, 0), dispatch_head_b
    await_head(fixture, 'modular_dispatch_b', lambda h: h['pending'] is not None and h['attempt'] == 2)
    fixture.console('SUSPEND DATAFLOW modular_dispatch_b;')
    settled_dispatch_b = await_head(fixture, 'modular_dispatch_b', lambda h: h['pending'] is None)['observation']['head']
    assert (settled_dispatch_b['completed'], settled_dispatch_b['refused']) == (1, 1), settled_dispatch_b

    expected_a = 'medium:expedited:priority-note:window=commercial-clearance-corridor-v1/band=medium/ledger-policy=standard-verified-settlement-lane-beta-02|schedule=tier-beta/corridor=standard-commercial-settlement-profile-v1/settlement-class=commercial-mid-value-order|compliance=verified-account-tier-credit-guard-atomic-v1/hygiene=lexical-frame-isolated/audit-band=commercial-std'
    expected_b = 'large:review:empty:window=institutional-clearance-corridor-v1/band=large/ledger-policy=primary-verified-settlement-lane-alpha-01|schedule=tier-alpha/corridor=priority-wire-settlement-profile-v1/settlement-class=institutional-high-value-order|compliance=dual-control-ledger-stream-followup-atomic-v1/hygiene=lexical-frame-isolated/audit-band=institutional'
    outcomes = []
    for suffix, order_id, amount, summary in (
            ('a', '101', '250', expected_a),
            ('b', '201', '1500', expected_b)):
        rows = fixture.console(
            f'SELECT id, account_id, amount, summary FROM modular_ledger_{suffix} ORDER BY id; '
            f'CONSUME id, account_id, summary FROM modular_events_{suffix}; '
            f'SELECT id, account_id, summary FROM modular_dispatched_{suffix} ORDER BY id;')
        observed = [records(value) for value in rows if 'schema' in value]
        assert observed == [
            [{'id': order_id, 'account_id': '7', 'amount': amount, 'summary': summary}],
            [{'id': order_id, 'account_id': '7', 'summary': summary}],
            [{'id': order_id, 'account_id': '7', 'summary': summary}],
        ], observed
        outcomes += rows
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        token = list(os.urandom(16))
        client.call(dict(execute=dict(sql="ENQUEUE INTO modular_requests_a VALUES (106, 7, 300, 'retained');", token=token)), discard_response=True)
        original = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
        assert original['matched'] == original['changed'] == 1
        return outcomes, token, original['identity']
    finally:
        client.close()


def resume_modular_programs(fixture, token, identity):
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        original = client.terminal(client.call(dict(status=dict(token=token)))['operation'])
        assert original['identity'] == identity and original['matched'] == original['changed'] == 1, original
    finally:
        client.close()
    orders_head = observation(fixture, 'modular_orders_a')['observation']['head']
    assert orders_head['control']['state'] == 'suspended' and (orders_head['completed'], orders_head['refused']) == (1, 5), orders_head
    dispatch_head = observation(fixture, 'modular_dispatch_a')['observation']['head']
    assert dispatch_head['control']['state'] == 'suspended' and (dispatch_head['completed'], dispatch_head['refused']) == (1, 1), dispatch_head
    fixture.console('RESUME DATAFLOW modular_orders_a;')
    settled_orders = await_head(fixture, 'modular_orders_a', lambda h: h['completed'] >= 2)['observation']['head']
    assert settled_orders['refused'] == 5, settled_orders
    await_head(fixture, 'modular_orders_a', lambda h: h['pending'] is not None and h['attempt'] == 8)
    fixture.console('SUSPEND DATAFLOW modular_orders_a;')
    await_head(fixture, 'modular_orders_a', lambda h: h['pending'] is None)
    fixture.console('RESUME DATAFLOW modular_dispatch_a;')
    settled_dispatch = await_head(fixture, 'modular_dispatch_a', lambda h: h['completed'] >= 2)['observation']['head']
    assert settled_dispatch['refused'] == 1, settled_dispatch
    first_summary = 'medium:expedited:priority-note:window=commercial-clearance-corridor-v1/band=medium/ledger-policy=standard-verified-settlement-lane-beta-02|schedule=tier-beta/corridor=standard-commercial-settlement-profile-v1/settlement-class=commercial-mid-value-order|compliance=verified-account-tier-credit-guard-atomic-v1/hygiene=lexical-frame-isolated/audit-band=commercial-std'
    retained_summary = 'medium:routine:retained:window=commercial-clearance-corridor-v1/band=medium/ledger-policy=standard-verified-settlement-lane-beta-02|schedule=tier-beta/corridor=standard-commercial-settlement-profile-v1/settlement-class=commercial-mid-value-order|compliance=verified-account-tier-credit-guard-atomic-v1/hygiene=lexical-frame-isolated/audit-band=commercial-std'
    expected_ledger = [
        {'id': '101', 'account_id': '7', 'amount': '250', 'summary': first_summary},
        {'id': '106', 'account_id': '7', 'amount': '300', 'summary': retained_summary},
    ]
    expected_outputs = [
        {'id': '101', 'account_id': '7', 'summary': first_summary},
        {'id': '106', 'account_id': '7', 'summary': retained_summary},
    ]
    outcomes = fixture.console(
        'SELECT id, account_id, amount, summary FROM modular_ledger_a ORDER BY id; '
        'CONSUME id, account_id, summary FROM modular_events_a; '
        'SELECT id, account_id, summary FROM modular_dispatched_a ORDER BY id;')
    observed = [sorted(records(value), key=lambda row: int(row['id'])) for value in outcomes if 'schema' in value]
    assert observed == [expected_ledger, expected_outputs, expected_outputs], observed
    return outcomes


def execute_modular_programs(cli, sql):
    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        outcomes, token, identity = install_modular_programs(fixture, sql)
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        outcomes += resume_modular_programs(fixture, token, identity)
        disable_sql_credential(fixture.root, fixture.config['ports'], installation=fixture.installation)
        fixture.console('CONSUME * FROM modular_events_a;', expected=1)
        fixture.console('SHOW DATAFLOW modular_orders_a;', expected=1)
        fixture.console('SELECT * FROM modular_ledger_a;', expected=1)
        fixture.console('SELECT * FROM modular_dispatched_a;', expected=1)
        passed = True
        return outcomes
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed modular Queue execution: {fixture.root}', file=sys.stderr)


def install_typed_queue(fixture, sql):
    lines = sql.splitlines()
    assert len(lines) == 25, len(lines)
    fixture.console(
        '\n'.join(lines[:7]) + '\n'
        "ALTER QUEUE typed_requests_a SET (lease_duration = '120s', max_lease_duration = '120s');\n"
        + '\n'.join(lines[7:17]) + '\n'
        "ALTER QUEUE typed_requests_b SET (lease_duration = '120s', max_lease_duration = '120s');\n"
        + '\n'.join(lines[17:20]))
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
    first_head = await_head(fixture, 'typed_process_a', lambda h: h['completed'] + h['refused'] >= 1)['observation']['head']
    assert (first_head['completed'], first_head['refused']) == (1, 0), first_head
    fixture.console('\n'.join(lines[21:]))
    outcomes = []
    for suffix, refused in (('a', 3), ('b', 0)):
        name = f'typed_process_{suffix}'
        # Both pipelines keep running after the same batch of enqueues. Give
        # each expected terminal outcome the existing bounded observation wait;
        # attempts and pending work cannot reset it. A's first item settled above.
        for terminal_count in range(2 if suffix == 'a' else 1, refused + 2):
            head = await_head(fixture, name, lambda h, expected=terminal_count: h['completed'] + h['refused'] >= expected)['observation']['head']
        assert (head['completed'], head['refused']) == (1, refused), head
        rows = fixture.console(f'SELECT id, machine_id, body FROM typed_accepted_{suffix} ORDER BY id; CONSUME id, machine_id, body FROM typed_events_{suffix};')
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
    outcomes = fixture.console('SELECT id, machine_id, body FROM typed_accepted_a ORDER BY id; CONSUME id, machine_id, body FROM typed_events_a;')
    for value in outcomes:
        if 'schema' in value:
            assert sorted(records(value), key=lambda row: int(row['id'])) == expected, value
    return outcomes

def execute_program(cli, sql, typed_sql, queue_sql):
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
        queue_lines = queue_sql.splitlines()
        assert len(queue_lines) == 7, len(queue_lines)
        fixture.console(
            '\n'.join(queue_lines[:3]) + '\n'
            "ALTER QUEUE requests SET (lease_duration = '120s', max_lease_duration = '120s');\n"
            + '\n'.join(queue_lines[3:6]))
        enqueue = queue_lines[6]
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
        passed = True
        return outcomes
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed application build execution: {fixture.root}', file=sys.stderr)



def execute_typed_queue(cli, sql):
    # Keep the existing untyped schedule's authority/resource inventory intact.
    # This installation still exercises both explicitly named typed pipelines.
    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        outcomes, token, identity = install_typed_queue(fixture, sql)
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        outcomes += resume_typed_queue(fixture, token, identity)
        disable_sql_credential(fixture.root, fixture.config['ports'], installation=fixture.installation)
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
            print(f'Private failed typed Queue execution: {fixture.root}', file=sys.stderr)

def migration_journey(cli, temporary):
    root = temporary / 'migration-source'
    root.mkdir()
    source = root / 'build.transit'
    definitions = root / 'tables.transit'
    definitions.write_text("CREATE PUBLIC MODULE Tables() AS BEGIN CREATE PUBLIC TABLE migration_items (id BIGINT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'initial', CHECK (id > 0)); END;\n")
    def target(basis='EMPTY', version='0001'):
        source.write_text("IMPORT tables FROM 'tables.transit';\n"
                          f"CREATE MIGRATION TARGET default FROM {basis} FOR DATABASE 'transit' SCHEMA 'public' VERSION '{version}' NAME 'tables' AS BEGIN USE tables.Tables(); END;\n")
    target()
    first = cli_build(cli, root)
    first_dir = Path(first['directory'])
    first_basis = (first_dir / 'basis.json').read_bytes()
    first_sql = first_dir / 'migrations/0001-tables.sql'
    original = first_sql.read_bytes()
    assert first['statements'] == 1 and b'CREATE TABLE' in original
    assert cli_build(cli, root)['reused']
    target(version='0001_patch')
    failure = cli_build(cli, root, '--out', root / 'ambiguous-version', expected=1)
    assert 'InvalidMigrationVersion' in json.dumps(failure)
    assert not (root / 'ambiguous-version').exists()
    basis_path = first_dir.relative_to(root) / 'basis.json'
    target(f"'{basis_path}'", '0002')
    definitions.write_text(definitions.read_text().replace(", CHECK (id > 0)", ", extra TEXT DEFAULT 'a,b', amount BIGINT NOT NULL DEFAULT 7, CHECK (id > 0)"))
    check = cli_build(cli, root, '--check')
    assert check['statements'] == 2
    second = cli_build(cli, root)
    second_dir = Path(second['directory'])
    assert second['statements'] == 2 and cli_build(cli, root)['reused']
    desired_sql = (second_dir / 'desired.sql').read_text()
    cached_delta = second_dir / 'migrations/0002-tables.sql'
    original_delta = cached_delta.read_bytes()
    cached_delta.write_bytes(original_delta.replace(b'EXTRA', b'WRONG'))
    cli_build(cli, root, expected=1)
    cached_delta.write_bytes(original_delta)
    assert (second_dir / 'migrations/0001-tables.sql').read_bytes() == original
    assert (second_dir / 'migrations/0002-tables.sql').read_text().count('ADD COLUMN') == 2
    # Both the explicit basis and every historical byte participate in checking.
    first_sql.write_bytes(original + b'-- changed history\n')
    failure = cli_build(cli, root, '--check', expected=1)
    assert 'MigrationHistoryChanged' in json.dumps(failure)
    first_sql.write_bytes(original)
    foreign = json.loads(first_basis)
    foreign['definition'] = 'foreign'
    (first_dir / 'basis.json').write_text(json.dumps(foreign))
    failure = cli_build(cli, root, '--check', expected=1)
    assert 'IncompatibleMigrationBasis' in json.dumps(failure)
    (first_dir / 'basis.json').write_bytes(first_basis)
    outside = root / 'linked-basis'
    outside.symlink_to(first_dir, target_is_directory=True)
    target("'linked-basis/basis.json'", '0002')
    cli_build(cli, root, '--check', expected=1)
    outside.unlink()
    target("'../escape/basis.json'", '0002')
    cli_build(cli, root, '--check', expected=1)
    target(f"'{second_dir.relative_to(root) / 'basis.json'}'", '0003')
    unchanged = cli_build(cli, root)
    assert unchanged['statements'] == 0
    assert len(list((Path(unchanged['directory']) / 'migrations').glob('*.sql'))) == 2
    preserved = definitions.read_text()
    definitions.write_text(preserved.replace("DEFAULT 'initial'", "DEFAULT 'changed'"))
    failure = cli_build(cli, root, '--out', root / 'refused', expected=1)
    assert 'MigrationTransformRequired' in json.dumps(failure) and not (root / 'refused').exists()
    definitions.write_text(preserved)
    # Source relocation keeps the same explicit object names and SQL bytes.
    relocated = temporary / 'relocated-migration-source'
    shutil.copytree(root, relocated)
    copied = cli_build(cli, relocated, '--out', relocated / 'reviewed')
    assert (Path(copied['directory']) / 'desired.sql').read_bytes() == (second_dir / 'desired.sql').read_bytes()

    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        migrations = fixture.root / 'migrations'
        shutil.copytree(first_dir / 'migrations', migrations)
        def migrate(action, *args, expected=0):
            result = subprocess.run([fixture.cli, 'migrate', action, '--format', 'json', *map(str, args)],
                                    cwd=fixture.root, env=fixture.environment, text=True, capture_output=True, timeout=90)
            assert result.returncode == expected, (action, result.stdout, result.stderr)
            return json.loads(result.stdout)
        first_applied = migrate('apply', '--dir', migrations, '--database', 'transit', '--schema', 'public')
        assert first_applied['outcome'] == 'applied', first_applied
        fixture.console("INSERT INTO migration_items (id) VALUES (7);")
        shutil.copy2(second_dir / 'migrations/0002-tables.sql', migrations)
        plan_file = fixture.root / 'plan.json'
        planned = migrate('plan', '--dir', migrations, '--out', plan_file)
        saved = json.loads(plan_file.read_text())
        # Lose the complete semantic response, then destroy all source/sidecars.
        client = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            client.call(dict(migrate=dict(kind='apply', sources=saved['sources'],
                        expected_plan_digest=saved['plan_digest'], attempt_id=[0x72] * 16,
                        target=dict(database='transit', schema='public'))), discard_response=True)
        finally:
            client.close()
        shutil.rmtree(root)
        shutil.rmtree(relocated)
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        resumed = migrate('resume', '--dir', migrations)
        assert resumed['outcome'] in ('applied', 'verified', 'already_satisfied'), resumed
        assert [step['step_token'] for step in resumed['versions'][1]['steps']] == [step['step_token'] for step in planned['versions'][1]['steps']]
        expected_rows = [{'id': '7', 'note': 'initial', 'extra': 'a,b', 'amount': '7'}]
        assert records(fixture.console('SELECT * FROM migration_items;')[-1]) == expected_rows
        verified = migrate('verify', '--dir', migrations)
        assert verified['outcome'] == 'verified', verified
        assert [step['operation_id'] for step in verified['versions'][1]['steps']] == [step['operation_id'] for step in resumed['versions'][1]['steps']]
        fixture.console('INSERT INTO migration_items (id) VALUES (0);', expected=1)
        # A live CHECK rewrite is drift even when legacy receipt digests agree.
        fixture.console('ALTER TABLE migration_items DROP CONSTRAINT constraint_1;')
        drift = migrate('verify', '--dir', migrations, expected=3)
        assert drift['outcome'] == 'drift_detected', drift
        assert any(step.get('drift', {}).get('aspect') == 'integrity'
                   for version in drift['versions'] for step in version['steps'] if step.get('drift'))
        passed = True
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed generated migration execution: {fixture.root}', file=sys.stderr)

    fresh = Fixture(cli)
    fresh.use_private_runtime()
    passed = False
    try:
        fresh.start()
        fresh.ready()
        fresh.console(desired_sql)
        fresh.console('INSERT INTO migration_items (id) VALUES (7);')
        assert records(fresh.console('SELECT * FROM migration_items;')[-1]) == expected_rows
        fresh.console('INSERT INTO migration_items (id) VALUES (0);', expected=1)
        passed = True
    finally:
        fresh.cleanup()
        if passed:
            shutil.rmtree(fresh.root)
        else:
            print(f'Private failed fresh migration definition: {fresh.root}', file=sys.stderr)


def workspace_composition_journey(cli, temporary):
    root = temporary / 'workspace-composition'
    source(root, 'build.transit', (
        "IMPORT MODULE apps FROM './apps/build.transit';\n"
        "EXPORT TARGET app_sql = apps.app_sql;\n"
        "EXPORT TARGET app_migrations = apps.app_migrations;\n"
        "EXPORT DEFAULT TARGET app_sql;\n"
    ))
    source(root, 'apps/build.transit', (
        "IMPORT MODULE app FROM './app/build.transit';\n"
        "EXPORT TARGET app_sql = app.sql;\n"
        "EXPORT TARGET app_migrations = app.migrations;\n"
    ))
    source(root, 'apps/app/shared/helpers.transit', (
        "CREATE PUBLIC FUNCTION normalize_label(raw TEXT) RETURNS TEXT AS BEGIN\n"
        "  RETURN CASE WHEN raw = '' THEN 'unnamed' ELSE raw END;\n"
        "END;\n"
    ))
    source(root, 'apps/app/tenancy/state.transit', (
        "CREATE PUBLIC TABLE ws_tenants (id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL);\n"
    ))
    source(root, 'apps/app/tenancy/guards.transit', (
        "CREATE GUARD require_tenant(tenants_tbl TABLE(id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL), tenant_id BIGINT) AS BEGIN\n"
        "  LET found = SELECT active FROM tenants_tbl WHERE id = tenant_id;\n"
        "  REQUIRE found IS NOT NULL ELSE 'MissingTenant';\n"
        "  REQUIRE found.active ELSE 'InactiveTenant';\n"
        "END;\n"
    ))
    source(root, 'apps/app/tenancy/build.transit', (
        "EXPORT MODULE application(schema SCHEMA_BINDING) AS BEGIN\n"
        "  BIND SCHEMA tenancy TO schema;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './guards.transit';\n"
        "  EXPORT TABLE ws_tenants;\n"
        "  EXPORT GUARD require_tenant;\n"
        "END;\n"
    ))
    net_state_v1 = "CREATE PUBLIC TABLE ws_networks (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL);\n"
    source(root, 'apps/app/networking/state.transit', net_state_v1)
    source(root, 'apps/app/networking/procedures.transit', (
        "CREATE PROCEDURE attach_network(\n"
        "  tenants_tbl TABLE(id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL),\n"
        "  networks_tbl TABLE(id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL),\n"
        "  net_id BIGINT,\n"
        "  tenant_id BIGINT,\n"
        "  label TEXT\n"
        ") RETURNS BIGINT AS BEGIN ATOMIC\n"
        "  CHECK GUARD tenancy.require_tenant(tenants_tbl, tenant_id);\n"
        "  INSERT INTO networks_tbl VALUES (net_id, tenant_id, normalize_label(label)) ON CONFLICT (id) DO ASSERT SAME ROW;\n"
        "  RETURN net_id;\n"
        "END;\n"
    ))
    source(root, 'apps/app/networking/build.transit', (
        "IMPORT MODULE helpers FROM '../shared/helpers.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, tenancy MODULE OF tenancy_build.application) AS BEGIN\n"
        "  BIND SCHEMA networking TO schema;\n"
        "  USE MODULE helpers;\n"
        "  USE MODULE tenancy;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './procedures.transit';\n"
        "  EXPORT TABLE ws_networks;\n"
        "  EXPORT PROCEDURE attach_network;\n"
        "END;\n"
    ))
    source(root, 'apps/app/ingress/flow.transit', (
        "CREATE PUBLIC QUEUE ws_ingress_requests (id BIGINT NOT NULL, tenant_id BIGINT NOT NULL, label TEXT NOT NULL);\n"
        "CREATE PUBLIC STREAM ws_ingress_events (id BIGINT NOT NULL, tenant_id BIGINT NOT NULL);\n"
        "CREATE PUBLIC DATAFLOW ws_process_ingress FROM QUEUE ws_ingress_requests AS req AS BEGIN\n"
        "  CHECK GUARD require_tenant(ws_tenants, req.tenant_id);\n"
        "  BEGIN ATOMIC\n"
        "    LET attached = CALL networking.attach_network(tenancy.ws_tenants, networking.ws_networks, req.id, req.tenant_id, req.label);\n"
        "    PRODUCE INTO ws_ingress_events VALUES (attached, req.tenant_id);\n"
        "  END;\n"
        "END;\n"
        "AUTHORIZE DATAFLOW ws_process_ingress AS ROLE CURRENT_ROLE;\n"
        "ACTIVATE DATAFLOW ws_process_ingress;\n"
    ))
    source(root, 'apps/app/ingress/build.transit', (
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "IMPORT MODULE networking_build FROM '../networking/build.transit';\n"
        "EXPORT MODULE application(\n"
        "  schema SCHEMA_BINDING,\n"
        "  tenancy MODULE OF tenancy_build.application,\n"
        "  networking MODULE OF networking_build.application\n"
        ") AS BEGIN\n"
        "  BIND SCHEMA ingress TO schema;\n"
        "  USE MODULE tenancy;\n"
        "  USE MODULE networking;\n"
        "  DECLARE FROM './flow.transit';\n"
        "END;\n"
    ))
    def write_app_build(mig_basis='EMPTY', mig_version='0001', sql_into="'../../.local/build/app/application.sql'", mig_clause="FOR DATABASE 'transit' SCHEMA 'public' VERSION '{ver}' NAME 'workspace'"):
        clause = mig_clause.format(ver=mig_version)
        source(root, 'apps/app/build.transit', (
            "IMPORT MODULE tenancy FROM './tenancy/build.transit';\n"
            "IMPORT MODULE networking FROM './networking/build.transit';\n"
            "IMPORT MODULE ingress FROM './ingress/build.transit';\n"
            "EXPORT MODULE schema_bundle(bindings ROW(tenancy SCHEMA_BINDING, networking SCHEMA_BINDING)) AS BEGIN\n"
            "  LET tenancy_mod = USE MODULE tenancy.application(schema => bindings.tenancy);\n"
            "  LET net_mod = USE MODULE networking.application(schema => bindings.networking, tenancy => tenancy_mod);\n"
            "END;\n"
            "EXPORT MODULE full_application(bindings ROW(tenancy SCHEMA_BINDING, networking SCHEMA_BINDING)) AS BEGIN\n"
            "  LET tenancy_mod = USE MODULE tenancy.application(schema => bindings.tenancy);\n"
            "  LET net_mod = USE MODULE networking.application(schema => bindings.networking, tenancy => tenancy_mod);\n"
            "  LET ingress_mod = USE MODULE ingress.application(schema => bindings.networking, tenancy => tenancy_mod, networking => net_mod);\n"
            "END;\n"
            "LET tables_only = USE MODULE schema_bundle(bindings => ROW(tenancy => SCHEMA_BINDING('tenancy'), networking => SCHEMA_BINDING('networking')));\n"
            "LET control = USE MODULE full_application(bindings => ROW(tenancy => SCHEMA_BINDING('tenancy'), networking => SCHEMA_BINDING('networking')));\n"
            f"EXPORT TARGET sql AS SQL OF control INTO {sql_into};\n"
            f"EXPORT TARGET migrations AS MIGRATIONS OF tables_only FROM {mig_basis} {clause} INTO '../../.local/build/app/migrations';\n"
        ))
    write_app_build()
    # Omitted --target selects EXPORT DEFAULT TARGET app_sql across 3 levels.
    built = cli_build(cli, root)
    assert built['target'] == 'app_sql' and not built['reused'], built
    assert cli_build(cli, root)['reused']
    out_dir = Path(built['directory'])
    provenance = json.loads((out_dir / 'provenance.json').read_text())
    assert provenance['target'] == 'app_sql'
    assert provenance['declared_output'] == '.local/build/app/application.sql', provenance
    app_sql = (out_dir / 'application.sql').read_text()
    assert app_sql.count('CREATE TABLE WS_TENANTS') == 1, app_sql
    assert app_sql.count('CREATE TABLE WS_NETWORKS') == 1, app_sql

    # Delegated migration target resolves child-relative basis paths and synthesizes v1 -> v2.
    mig_v1 = cli_build(cli, root, '--target', 'app_migrations')
    assert mig_v1['target'] == 'app_migrations' and mig_v1['statements'] == 2, mig_v1
    v1_rel_from_app = '../../' + str(Path(mig_v1['directory']).relative_to(root) / 'basis.json')
    source(root, 'apps/app/networking/state.transit',
           "CREATE PUBLIC TABLE ws_networks (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL, region TEXT);\n")
    source(root, 'apps/app/networking/procedures.transit',
           (root / 'apps/app/networking/procedures.transit').read_text().replace(
               'networks_tbl TABLE(id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL)',
               'networks_tbl TABLE(id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL, region TEXT)',
           ).replace(
               'normalize_label(label))', "normalize_label(label), 'us-east')"
           ))
    write_app_build(mig_basis=f"'{v1_rel_from_app}'", mig_version='0002')
    mig_v2 = cli_build(cli, root, '--target', 'app_migrations')
    assert mig_v2['statements'] == 1, mig_v2
    assert 'ADD COLUMN' in (Path(mig_v2['directory']) / 'migrations/0002-workspace.sql').read_text()

    # Negative controls: escaping INTO path and omitted FOR DATABASE clause.
    write_app_build(sql_into="'../../../outside/application.sql'")
    escaped = cli_build(cli, root, '--check', expected=1)
    assert escaped['code'] == 'application.source.path', escaped
    write_app_build(mig_clause='')
    missing_db = cli_build(cli, root, '--target', 'app_migrations', '--check', expected=1)
    assert missing_db['code'] == 'application.source.syntax', missing_db

    # Execute generated diamond SQL against a real local installation without source files.
    shutil.rmtree(root)
    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        lines = app_sql.splitlines()
        assert len(lines) == 7, lines
        fixture.console(
            '\n'.join(lines[:3]) + '\n'
            "ALTER QUEUE ws_ingress_requests SET (lease_duration = '120s', max_lease_duration = '120s');\n"
            + '\n'.join(lines[3:])
        )
        fixture.console("INSERT INTO ws_tenants VALUES (10, TRUE, 'core');")
        fixture.console("ENQUEUE INTO ws_ingress_requests VALUES (99, 10, '');")
        head = await_head(fixture, 'ws_process_ingress', lambda h: h['completed'] >= 1)['observation']['head']
        assert (head['completed'], head['refused']) == (1, 0), head
        assert records(fixture.console('SELECT id, tenant_id, label FROM ws_networks;')[-1]) == [
            {'id': '99', 'tenant_id': '10', 'label': 'unnamed'}
        ]
        assert records(fixture.console('CONSUME id, tenant_id FROM ws_ingress_events;')[-1]) == [
            {'id': '99', 'tenant_id': '10'}
        ]
        passed = True
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed workspace composition execution: {fixture.root}', file=sys.stderr)


def multi_schema_platform_journey(cli, temporary):
    root = temporary / 'multi-schema-platform'
    source(root, 'build.transit', (
        "IMPORT MODULE apps FROM './apps/build.transit';\n"
        "EXPORT TARGET platform_sql = apps.platform_sql;\n"
        "EXPORT TARGET platform_migrations = apps.platform_migrations;\n"
        "EXPORT DEFAULT TARGET platform_sql;\n"
    ))
    source(root, 'apps/build.transit', (
        "IMPORT MODULE platform FROM './platform/build.transit';\n"
        "EXPORT TARGET platform_sql = platform.sql;\n"
        "EXPORT TARGET platform_migrations = platform.migrations;\n"
    ))
    source(root, 'apps/platform/shared/types.transit', (
        "CREATE PUBLIC DOMAIN EnvId AS UUID IDENTITY 'platform.env-id';\n"
        "CREATE PUBLIC FUNCTION format_tag(meta ROW(region TEXT, active BOOLEAN)) RETURNS TEXT AS BEGIN\n"
        "  RETURN CASE WHEN meta.active THEN meta.region ELSE 'disabled' END;\n"
        "END;\n"
    ))
    tenancy_state_v1 = (
        "CREATE SCHEMA tenancy;\n"
        "CREATE PUBLIC TABLE tenancy.environments (\n"
        "  id $env_ty PRIMARY KEY,\n"
        "  tenant_code TEXT NOT NULL,\n"
        "  active BOOLEAN NOT NULL,\n"
        "  secret_note TEXT NOT NULL\n"
        ");\n"
        "CREATE PUBLIC TABLE tenancy.audit_internal (id BIGINT PRIMARY KEY, note TEXT NOT NULL);\n"
    )
    source(root, 'apps/platform/tenancy/state.transit', tenancy_state_v1)
    source(root, 'apps/platform/tenancy/guards.transit', (
        "IMPORT types FROM '../shared/types.transit';\n"
        "CREATE GUARD tenancy.require_scope(scope ROW(expected_tenant TEXT, actual_tenant TEXT, active BOOLEAN)) AS\n"
        "  REQUIRE scope.active ELSE 'InactiveEnvironment',\n"
        "  REQUIRE scope.actual_tenant = scope.expected_tenant ELSE 'TenantMismatch';\n"
        "CREATE GUARD tenancy.require_environment(env_id types.EnvId, expected_tenant TEXT) AS BEGIN\n"
        "  LET found = SELECT tenant_code, active FROM tenancy.environments WHERE id = env_id;\n"
        "  REQUIRE found IS NOT NULL ELSE 'MissingEnvironment';\n"
        "  CHECK GUARD tenancy.require_scope(ROW(expected_tenant, found.tenant_code, found.active));\n"
        "END;\n"
    ))
    source(root, 'apps/platform/tenancy/build.transit', (
        "IMPORT MODULE types FROM '../shared/types.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, env_ty TYPE) AS BEGIN\n"
        "  BIND SCHEMA tenancy TO schema;\n"
        "  USE MODULE types;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './guards.transit';\n"
        "  EXPORT REFERENCE TABLE tenancy.environments(id, tenant_code);\n"
        "  EXPORT GUARD tenancy.require_environment;\n"
        "  EXPORT GUARD tenancy.require_scope;\n"
        "END;\n"
    ))
    source(root, 'apps/platform/networking/state.transit', (
        "CREATE SCHEMA networking;\n"
        "CREATE PUBLIC TABLE networking.networks (\n"
        "  id BIGINT PRIMARY KEY,\n"
        "  env_id $env_ty NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  cidr TEXT NOT NULL\n"
        ");\n"
        "CREATE PUBLIC TABLE networking.attachments (\n"
        "  net_id BIGINT PRIMARY KEY,\n"
        "  env_id $env_ty NOT NULL,\n"
        "  tag TEXT NOT NULL\n"
        ");\n"
    ))
    source(root, 'apps/platform/networking/procedures.transit', (
        "IMPORT types FROM '../shared/types.transit';\n"
        "CREATE PROCEDURE networking.attach_consumer(\n"
        "  net_id BIGINT,\n"
        "  env_id types.EnvId,\n"
        "  meta ROW(region TEXT, active BOOLEAN)\n"
        ") RETURNS TEXT AS BEGIN ATOMIC\n"
        "  LET net = SELECT cidr FROM networking.networks WHERE id = net_id;\n"
        "  REQUIRE net IS NOT NULL ELSE 'MissingNetwork';\n"
        "  LET tag = types.format_tag(meta);\n"
        "  INSERT INTO networking.attachments VALUES (net_id, env_id, tag) ON CONFLICT (net_id) DO ASSERT SAME ROW;\n"
        "  RETURN tag;\n"
        "END;\n"
    ))
    source(root, 'apps/platform/networking/build.transit', (
        "IMPORT MODULE types FROM '../shared/types.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, env_ty TYPE, tenancy MODULE OF tenancy_build.application) AS BEGIN\n"
        "  BIND SCHEMA networking TO schema;\n"
        "  USE MODULE types;\n"
        "  USE MODULE tenancy;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './procedures.transit';\n"
        "  EXPORT REFERENCE TABLE networking.networks(id);\n"
        "  EXPORT PROCEDURE networking.attach_consumer;\n"
        "END;\n"
    ))
    deployments_state = (
        "CREATE SCHEMA deployments;\n"
        "CREATE PUBLIC TABLE deployments.releases (\n"
        "  id BIGINT PRIMARY KEY,\n"
        "  env_id $env_ty NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  net_id BIGINT NOT NULL REFERENCES networking.networks(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  deployed_at TIMESTAMPTZ NOT NULL,\n"
        "  digest BINARY NOT NULL,\n"
        "  tag TEXT NOT NULL\n"
        ");\n"
    )
    source(root, 'apps/platform/deployments/state.transit', deployments_state)
    source(root, 'apps/platform/deployments/build.transit', (
        "IMPORT MODULE types FROM '../shared/types.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "IMPORT MODULE networking_build FROM '../networking/build.transit';\n"
        "EXPORT MODULE application(\n"
        "  schema SCHEMA_BINDING,\n"
        "  env_ty TYPE,\n"
        "  tenancy MODULE OF tenancy_build.application,\n"
        "  networking MODULE OF networking_build.application\n"
        ") AS BEGIN\n"
        "  BIND SCHEMA deployments TO schema;\n"
        "  USE MODULE types;\n"
        "  USE MODULE tenancy;\n"
        "  USE MODULE networking;\n"
        "  DECLARE FROM './state.transit';\n"
        "  EXPORT TABLE deployments.releases;\n"
        "END;\n"
    ))
    source(root, 'apps/platform/operations/state.transit', (
        "CREATE SCHEMA operations;\n"
        "CREATE PUBLIC TABLE operations.heartbeats (\n"
        "  release_id BIGINT PRIMARY KEY REFERENCES deployments.releases(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  checked_at TIMESTAMPTZ NOT NULL\n"
        ");\n"
    ))
    source(root, 'apps/platform/operations/build.transit', (
        "IMPORT MODULE types FROM '../shared/types.transit';\n"
        "IMPORT MODULE deployments_build FROM '../deployments/build.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, deployments MODULE OF deployments_build.application) AS BEGIN\n"
        "  BIND SCHEMA operations TO schema;\n"
        "  USE MODULE types;\n"
        "  USE MODULE deployments;\n"
        "  DECLARE FROM './state.transit';\n"
        "  EXPORT TABLE operations.heartbeats;\n"
        "END;\n"
    ))
    source(root, 'apps/platform/billing/state.transit', (
        "CREATE SCHEMA billing;\n"
        "CREATE PUBLIC TABLE billing.ledgers (\n"
        "  id BIGINT PRIMARY KEY,\n"
        "  env_id $env_ty NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  units BIGINT NOT NULL CHECK (units >= 0)\n"
        ");\n"
    ))
    source(root, 'apps/platform/billing/build.transit', (
        "IMPORT MODULE types FROM '../shared/types.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, env_ty TYPE, tenancy MODULE OF tenancy_build.application) AS BEGIN\n"
        "  BIND SCHEMA billing TO schema;\n"
        "  USE MODULE types;\n"
        "  USE MODULE tenancy;\n"
        "  DECLARE FROM './state.transit';\n"
        "  EXPORT TABLE billing.ledgers;\n"
        "END;\n"
    ))
    source(root, 'apps/platform/ingress/flow.transit', (
        "CREATE SCHEMA ingress;\n"
        "CREATE PUBLIC QUEUE ingress.deploy_requests (\n"
        "  release_id BIGINT NOT NULL,\n"
        "  env_id $env_ty NOT NULL,\n"
        "  tenant_code TEXT NOT NULL,\n"
        "  net_id BIGINT NOT NULL,\n"
        "  region TEXT NOT NULL,\n"
        "  deployed_at TIMESTAMPTZ NOT NULL,\n"
        "  digest BINARY NOT NULL,\n"
        "  units BIGINT NOT NULL\n"
        ");\n"
        "CREATE PUBLIC STREAM ingress.deploy_events (release_id BIGINT NOT NULL, tag TEXT NOT NULL);\n"
        "CREATE PUBLIC DATAFLOW ingress.provision_release FROM QUEUE ingress.deploy_requests AS req AS BEGIN\n"
        "  CHECK GUARD tenancy.require_environment(req.env_id, req.tenant_code);\n"
        "  BEGIN ATOMIC\n"
        "    LET tag = CALL networking.attach_consumer(req.net_id, req.env_id, ROW(req.region, TRUE));\n"
        "    INSERT INTO deployments.releases VALUES (req.release_id, req.env_id, req.net_id, req.deployed_at, req.digest, tag) ON CONFLICT (id) DO ASSERT SAME ROW;\n"
        "    INSERT INTO operations.heartbeats VALUES (req.release_id, req.deployed_at) ON CONFLICT (release_id) DO ASSERT SAME ROW;\n"
        "    INSERT INTO billing.ledgers VALUES (req.release_id, req.env_id, req.units) ON CONFLICT (id) DO ASSERT SAME ROW;\n"
        "    PRODUCE INTO ingress.deploy_events VALUES (req.release_id, tag);\n"
        "  END;\n"
        "END;\n"
        "AUTHORIZE DATAFLOW ingress.provision_release AS ROLE CURRENT_ROLE;\n"
        "ACTIVATE DATAFLOW ingress.provision_release;\n"
    ))
    source(root, 'apps/platform/ingress/build.transit', (
        "IMPORT MODULE types FROM '../shared/types.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "IMPORT MODULE networking_build FROM '../networking/build.transit';\n"
        "IMPORT MODULE deployments_build FROM '../deployments/build.transit';\n"
        "IMPORT MODULE operations_build FROM '../operations/build.transit';\n"
        "IMPORT MODULE billing_build FROM '../billing/build.transit';\n"
        "EXPORT MODULE application(\n"
        "  schema SCHEMA_BINDING,\n"
        "  env_ty TYPE,\n"
        "  tenancy MODULE OF tenancy_build.application,\n"
        "  networking MODULE OF networking_build.application,\n"
        "  deployments MODULE OF deployments_build.application,\n"
        "  operations MODULE OF operations_build.application,\n"
        "  billing MODULE OF billing_build.application\n"
        ") AS BEGIN\n"
        "  BIND SCHEMA ingress TO schema;\n"
        "  USE MODULE types;\n"
        "  USE MODULE tenancy;\n"
        "  USE MODULE networking;\n"
        "  USE MODULE deployments;\n"
        "  USE MODULE operations;\n"
        "  USE MODULE billing;\n"
        "  DECLARE FROM './flow.transit';\n"
        "END;\n"
    ))

    def write_platform_build(mig_basis='EMPTY', mig_version='0001-platform'):
        source(root, 'apps/platform/build.transit', (
            "IMPORT MODULE types FROM './shared/types.transit';\n"
            "IMPORT MODULE tenancy FROM './tenancy/build.transit';\n"
            "IMPORT MODULE networking FROM './networking/build.transit';\n"
            "IMPORT MODULE deployments FROM './deployments/build.transit';\n"
            "IMPORT MODULE operations FROM './operations/build.transit';\n"
            "IMPORT MODULE billing FROM './billing/build.transit';\n"
            "IMPORT MODULE ingress FROM './ingress/build.transit';\n"
            "EXPORT MODULE schema_tables() AS BEGIN\n"
            "  LET t = USE MODULE tenancy.application(schema => SCHEMA_BINDING('tenancy'), env_ty => TYPE types.EnvId);\n"
            "  LET n = USE MODULE networking.application(schema => SCHEMA_BINDING('networking'), env_ty => TYPE types.EnvId, tenancy => t);\n"
            "  LET d = USE MODULE deployments.application(schema => SCHEMA_BINDING('deployments'), env_ty => TYPE types.EnvId, tenancy => t, networking => n);\n"
            "  LET o = USE MODULE operations.application(schema => SCHEMA_BINDING('operations'), deployments => d);\n"
            "  LET b = USE MODULE billing.application(schema => SCHEMA_BINDING('billing'), env_ty => TYPE types.EnvId, tenancy => t);\n"
            "END;\n"
            "EXPORT MODULE full_platform() AS BEGIN\n"
            "  LET t = USE MODULE tenancy.application(schema => SCHEMA_BINDING('tenancy'), env_ty => TYPE types.EnvId);\n"
            "  LET n = USE MODULE networking.application(schema => SCHEMA_BINDING('networking'), env_ty => TYPE types.EnvId, tenancy => t);\n"
            "  LET d = USE MODULE deployments.application(schema => SCHEMA_BINDING('deployments'), env_ty => TYPE types.EnvId, tenancy => t, networking => n);\n"
            "  LET o = USE MODULE operations.application(schema => SCHEMA_BINDING('operations'), deployments => d);\n"
            "  LET b = USE MODULE billing.application(schema => SCHEMA_BINDING('billing'), env_ty => TYPE types.EnvId, tenancy => t);\n"
            "  LET i = USE MODULE ingress.application(schema => SCHEMA_BINDING('ingress'), env_ty => TYPE types.EnvId, tenancy => t, networking => n, deployments => d, operations => o, billing => b);\n"
            "END;\n"
            "LET tables_only = USE MODULE schema_tables();\n"
            "LET control = USE MODULE full_platform();\n"
            "EXPORT TARGET sql AS SQL OF control INTO '../../.local/build/platform/application.sql';\n"
            f"EXPORT TARGET migrations AS MIGRATIONS OF tables_only FROM {mig_basis} VERSION '{mig_version}' INTO '../../.local/build/platform/migrations';\n"
        ))

    write_platform_build()
    mig_v1 = cli_build(cli, root, '--target', 'platform_migrations')
    assert mig_v1['target'] == 'platform_migrations' and mig_v1['statements'] == 12, mig_v1
    v1_dir = Path(mig_v1['directory'])
    v1_sql = (v1_dir / 'migrations/0001-platform.sql').read_text()
    for s_name in ('tenancy', 'networking', 'deployments', 'operations', 'billing'):
        assert f'CREATE SCHEMA "{s_name}"' in v1_sql, v1_sql

    # Negative capability & FK controls before v2 evolution.
    for mutated, expected_cause in (
        (deployments_state + "SELECT id FROM tenancy.environments;\n", 'ReferenceOnlyTableAccess'),
        (deployments_state.replace('REFERENCES tenancy.environments(id)', 'REFERENCES tenancy.environments(secret_note)'), 'ReferenceOnlyTableAccess'),
        (deployments_state + "SELECT id FROM tenancy.audit_internal;\n", 'UnexportedModuleResource'),
    ):
        source(root, 'apps/platform/deployments/state.transit', mutated)
        refused = cli_build(cli, root, '--check', expected=1)
        assert any(f and f['field'] == 'native_cause' and f['value'] == {'text': expected_cause} for f in refused['facts']), refused
    source(root, 'apps/platform/deployments/state.transit', deployments_state.replace(' NOT ENFORCED', '', 1))
    omitted_fk = subprocess.run([str(cli), 'build', '--check', '--color', 'off'], cwd=root,
                                capture_output=True, text=True, timeout=60, env={'PATH': '/unavailable'}, preexec_fn=offline)
    assert omitted_fk.returncode == 1 and "note: append 'NOT ENFORCED' for catalog-tracked foreign keys" in omitted_fk.stderr, omitted_fk.stderr
    source(root, 'apps/platform/deployments/state.transit', deployments_state)

    # Evolve v2: add a nullable column on parent table tenancy.environments without invalidating child FKs.
    v1_basis_rel = '../../' + str(v1_dir.relative_to(root) / 'basis.json')
    source(root, 'apps/platform/tenancy/state.transit',
           tenancy_state_v1.replace('secret_note TEXT NOT NULL\n', 'secret_note TEXT NOT NULL,\n  region TEXT\n'))
    write_platform_build(mig_basis=f"'{v1_basis_rel}'", mig_version='0002-platform')
    mig_v2 = cli_build(cli, root, '--target', 'platform_migrations')
    assert mig_v2['statements'] == 1, mig_v2
    v2_dir = Path(mig_v2['directory'])
    v2_delta = (v2_dir / 'migrations/0002-platform.sql').read_text()
    assert 'ALTER TABLE "tenancy"."environments" ADD COLUMN REGION TEXT;' in v2_delta, v2_delta

    built_sql = cli_build(cli, root, '--target', 'platform_sql')
    app_lines = (Path(built_sql['directory']) / 'application.sql').read_text().splitlines()
    assert len(app_lines) == 18, app_lines

    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        migrations = fixture.root / 'migrations'
        shutil.copytree(v1_dir / 'migrations', migrations)

        def migrate(action, *args, expected=0):
            result = subprocess.run([fixture.cli, 'migrate', action, '--format', 'json', *map(str, args)],
                                    cwd=fixture.root, env=fixture.environment, text=True, capture_output=True, timeout=90)
            assert result.returncode == expected, (action, result.stdout, result.stderr)
            return json.loads(result.stdout)

        assert migrate('apply', '--dir', migrations)['outcome'] == 'applied'
        shutil.copy2(v2_dir / 'migrations/0002-platform.sql', migrations)
        assert migrate('apply', '--dir', migrations)['outcome'] == 'applied'
        assert migrate('verify', '--dir', migrations)['outcome'] == 'verified'
        shutil.rmtree(root)

        shown_schemas = [row['schema'] for row in records(fixture.console('SHOW SCHEMAS;')[-1])]
        for s_name in ('public', 'tenancy', 'networking', 'deployments', 'operations', 'billing'):
            assert s_name in shown_schemas, shown_schemas

        # Runtime NOT ENFORCED cross-schema FK catalog dependency protection.
        fixture.console('DROP TABLE tenancy.environments RESTRICT;', expected=1)
        fixture.console('DROP SCHEMA tenancy RESTRICT;', expected=1)

        # Install the 6th schema ('ingress') Queue, Stream and cross-schema Dataflow.
        ingress_lines = app_lines[12:]
        assert ingress_lines[0].startswith('CREATE SCHEMA "ingress"')
        fixture.console(
            '\n'.join(ingress_lines[:3]) + '\n'
            "ALTER QUEUE ingress.deploy_requests SET (lease_duration = '120s', max_lease_duration = '120s');\n"
            + '\n'.join(ingress_lines[3:])
        )
        env_ok = '550e8400-e29b-41d4-a716-446655440000'
        fixture.console(
            f"INSERT INTO tenancy.environments VALUES (UUID '{env_ok}', 'acme', TRUE, 'sealed', 'us-west');\n"
            f"INSERT INTO networking.networks VALUES (10, UUID '{env_ok}', '10.0.0.0/16');"
        )
        fixture.console(
            f"ENQUEUE INTO ingress.deploy_requests VALUES (501, UUID '{env_ok}', 'acme', 10, 'us-west-2', TIMESTAMP '2026-06-01T12:00:00Z', X'CAFE', 42);"
        )
        first = await_head(fixture, 'ingress.provision_release', lambda h: h['completed'] >= 1)['observation']['head']
        assert (first['completed'], first['refused']) == (1, 0), first
        fixture.console(
            f"ENQUEUE INTO ingress.deploy_requests VALUES (502, UUID '{env_ok}', 'wrong-tenant', 10, 'us-west-2', TIMESTAMP '2026-06-01T12:01:00Z', X'BEEF', 10);"
        )
        head = await_head(fixture, 'ingress.provision_release', lambda h: h['refused'] >= 1)['observation']['head']
        assert (head['completed'], head['refused']) == (1, 1), head

        env_hex = env_ok.replace('-', '')
        releases = records(fixture.console('SELECT id, env_id, net_id, tag FROM deployments.releases;')[-1])
        assert releases == [{'id': '501', 'env_id': env_hex, 'net_id': '10', 'tag': 'us-west-2'}], releases
        attachments = records(fixture.console('SELECT net_id, env_id, tag FROM networking.attachments;')[-1])
        assert attachments == [{'net_id': '10', 'env_id': env_hex, 'tag': 'us-west-2'}], attachments
        heartbeats = records(fixture.console('SELECT release_id FROM operations.heartbeats;')[-1])
        assert heartbeats == [{'release_id': '501'}], heartbeats
        ledgers = records(fixture.console('SELECT id, units FROM billing.ledgers;')[-1])
        assert ledgers == [{'id': '501', 'units': '42'}], ledgers
        events = records(fixture.console('CONSUME release_id, tag FROM ingress.deploy_events;')[-1])
        assert events == [{'release_id': '501', 'tag': 'us-west-2'}], events
        passed = True
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed multi-schema platform execution: {fixture.root}', file=sys.stderr)


def main():
    cli = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix='transit-application-build-') as temporary:
        sql = compiler_journey(cli, Path(temporary)).read_text()
        typed_sql = typed_journey(cli, Path(temporary))
        queue_sql = queue_journey(cli, Path(temporary))
        typed_queue_sql = typed_queue_journey(cli, Path(temporary))
        modular_sql = modular_programs_journey(cli, Path(temporary))
        print('Application build: generated Table migration and recovery', flush=True)
        migration_journey(cli, Path(temporary))
        print('Application build: workspace module-instance DAG and delegated targets', flush=True)
        workspace_composition_journey(cli, Path(temporary))
        print('Application build: 6-schema reference exports, migrations and cross-schema dataflow', flush=True)
        multi_schema_platform_journey(cli, Path(temporary))
        print('Application build: generated ordinary fixture', flush=True)
        generated = execute_program(cli, sql, typed_sql, queue_sql)
        print('Application build: generated typed Queue fixture', flush=True)
        generated += execute_typed_queue(cli, typed_queue_sql)
        print('Application build: generated modular Queue fixture', flush=True)
        generated += execute_modular_programs(cli, modular_sql)
        print('Application build: independent ordinary SQL oracle', flush=True)
        oracle = execute_program(cli, (REPO / 'third_party/transitc/tests/fixtures/application-build/expected.sql').read_text(),
                                 (REPO / 'third_party/transitc/tests/fixtures/application-typed-targets/expected.sql').read_text(),
                                 (REPO / 'third_party/transitc/tests/fixtures/application-queue-programs/expected.sql').read_text())
        print('Application build: independent typed Queue SQL oracle', flush=True)
        oracle += execute_typed_queue(cli, (REPO / 'third_party/transitc/tests/fixtures/application-typed-queue/expected.sql').read_text())
        print('Application build: independent modular Queue SQL oracle', flush=True)
        oracle += execute_modular_programs(cli, (REPO / 'third_party/transitc/tests/fixtures/application-modular-programs/oracle.sql').read_text())
        # Both sessions decode verified terminal coverage. Compare logical rows;
        # durable IDs/observation cuts legitimately differ between installations.
        def logical(outcomes):
            return [dict(schema=value['schema']['type'], rows=value['rows'], count=value['complete']['rows']) for value in outcomes if 'schema' in value]
        actual, expected = logical(generated), logical(oracle)
        assert actual == expected, [(index, left, right) for index, (left, right) in enumerate(zip(actual, expected, strict=True)) if left != right]
    print('Application build: locked offline composition, source-free SQL, restart and revocation passed')


if __name__ == '__main__':
    main()
