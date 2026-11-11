#!/usr/bin/env python3
"""Execute the real Table test command under network and executable denial."""
import ctypes
import errno
import platform
import signal
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from runner.paths import ROOT
from interfaces.cli.application_build import offline, cli_build, repository, source
from interfaces.cli.table_console import records
from interfaces.installation.server import Fixture


def invoke(cli, root, *args, expected=0):
    temporary = root / '.test-tmp'
    temporary.mkdir(exist_ok=True)
    result = subprocess.run([str(cli), 'test', '--format', 'json', *map(str, args)],
                            cwd=root, capture_output=True, text=True, timeout=60,
                            env={'PATH': '/unavailable', 'TRANSIT_CONSOLE_CONFIG': '/private/unreadable', 'TMPDIR': str(temporary)},
                            preexec_fn=offline)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    assert not result.stderr, result.stderr
    assert not list(temporary.iterdir()), "Case storage survived normal cleanup"
    report = json.loads(result.stdout)
    assert report.get('ok', False) == (expected == 0), report
    if 'cases' in report:
        assert len(result.stdout.encode()) <= 1024 * 1024
        assert not any(value in result.stdout for value in ('root.seed', 'registrar.seed', 'credential.json', '.pending-'))
    return report


def fault_filter(mode):
    offline()
    numbers = {'x86_64': {'sync': 74, 'unlink': 263}, 'aarch64': {'sync': 82, 'unlink': 35}}[platform.machine()]
    number = numbers['unlink' if mode == 'cleanup' else 'sync']
    result = 0x80000000 if mode == 'killed' else 0x00050000 | (errno.EACCES if mode == 'cleanup' else errno.ENOSPC)
    code = [(0x20, 0, 0, 0), (0x15, 0, 1, number), (0x06, 0, 0, result), (0x06, 0, 0, 0x7fff0000)]
    class Filter(ctypes.Structure):
        _fields_ = [('code', ctypes.c_ushort), ('jt', ctypes.c_ubyte), ('jf', ctypes.c_ubyte), ('k', ctypes.c_uint)]
    class Program(ctypes.Structure):
        _fields_ = [('length', ctypes.c_ushort), ('filter', ctypes.POINTER(Filter))]
    filters = (Filter * len(code))(*(Filter(*item) for item in code))
    program = Program(len(code), filters)
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(22, 2, ctypes.byref(program), 0, 0):
        raise OSError(ctypes.get_errno(), 'Cannot install failure proof filter')


def failure_lifecycle(cli, project, root):
    for mode in ('initialization', 'cleanup', 'killed'):
        directory = root / mode
        directory.mkdir()
        result = subprocess.run([str(cli), 'test', '--format', 'json'], cwd=project,
                                capture_output=True, text=True, timeout=60,
                                env={'PATH': '/unavailable', 'TMPDIR': str(directory)},
                                preexec_fn=lambda: fault_filter(mode))
        if mode == 'killed':
            assert result.returncode == -signal.SIGSYS and not result.stdout, result
            assert list(directory.iterdir()), 'Process death did not reach private host storage'
        else:
            assert result.returncode == 1 and not result.stderr, result
            report = json.loads(result.stdout)
            assert not report['ok'] and not report['complete'], report
            assert report['cases'][0]['status'] == 'failed'
            assert report['cases'][1]['status'] == 'not_run'
            if mode == 'initialization':
                assert not list(directory.iterdir()), 'Failed initialization leaked storage'
            else:
                assert list(directory.iterdir()), 'Deletion refusal was not exercised'
        # The proof owns this entire directory. Never discover/sweep others.
        shutil.rmtree(directory)


def suite(body, name='case'):
    return f"CREATE TEST TARGET tests AS BEGIN TEST '{name}' USING MODULES () AS BEGIN {body} END; END;"


def installed_oracle(cli, sql):
    """The same independently written SQL through an ordinary installed caller."""
    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        fixture.console('DROP TABLE items;')
        rows = []
        counts = []
        for index, statement in enumerate(sql.splitlines()):
            outcomes = fixture.console(statement, expected=1 if index == 4 else 0)
            if index == 4:
                continue
            for value in outcomes:
                if 'schema' in value:
                    rows.append(sorted(records(value), key=lambda row: int(row['id'])))
                    assert value['complete']['rows'] == '2'
                elif value.get('completion', {}).get('kind') == 'insert':
                    counts.append(value['completion']['counts'])
        assert counts == [{'matched': '1', 'changed': '1'}] * 2, counts
        expected = [{'id': '7', 'value': 'initial'}, {'id': '9', 'value': None}]
        assert rows == [expected, expected], rows
        passed = True
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed Table test oracle: {fixture.root}', file=sys.stderr)


def main():
    cli = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix='transit-application-test-') as temporary:
        root = Path(temporary)
        typed = root / 'typed-targets'
        shutil.copytree(ROOT / 'tests/fixtures/application-typed-targets', typed)
        typed_report = invoke(cli, typed)
        assert typed_report['complete'] and [case['status'] for case in typed_report['cases']] == ['passed', 'passed']
        assert [case['observation']['rows'] for case in typed_report['cases']] == [2, 1]
        routing = (typed / 'routing.transit').read_text()
        source(typed, 'routing.transit', routing.replace('INSERT INTO $sites VALUES ($id)', 'INSERT INTO $machines VALUES ($id)'))
        refused = invoke(cli, typed, expected=1)
        assert refused['outcome'] == 'not_submitted' and 'cases' not in refused
        assert not (typed / '.transit').exists()
        project = root / 'project'
        shutil.copytree(ROOT / 'tests/fixtures/application-tests', project)
        oracle = (project / 'expected.sql').read_text()
        first = invoke(cli, project)
        repeat = invoke(cli, project)
        assert first['complete'] and len(first['cases']) == 2, first
        assert all(case['status'] == 'passed' for case in first['cases'])
        for key in ('input_digest', 'sql_digest'):
            assert first[key] == repeat[key]
        assert first['cases'][0]['sql_digest'] == hashlib.sha256((project / 'expected.sql').read_bytes()).hexdigest()
        assert first['cases'][0]['observation']['rows'] == 4
        assert first['cases'][1]['observation']['rows'] == 1
        assert 0 < first['compiler_peak_bytes'] <= 64 * 1024 * 1024
        for case in first['cases']:
            resources = case['observation']['resources']
            assert 0 < resources['memory_peak_bytes'] <= first['limits']['host_bytes']
            assert 0 < resources['storage_reserved_bytes'] <= first['limits']['storage_bytes']
        assert not (project / '.transit').exists()
        for args in (['--verify-replay'], ['--fetch'], ['--out', 'result'], ['--config', '/private'], ['--target', '../escape']):
            failure = invoke(cli, project, *args, expected=2)
            assert failure['outcome'] == 'not_submitted'
        invoke(cli, project, '--target', 'default', expected=1)
        # Ordinary build target coexists with test declarations without running them.
        cli_build(cli, project, '--check')
        failure_lifecycle(cli, project, root)
        original = (project / 'build.transit').read_text()
        for before, after, failure in (
                ('MATCHED 1 CHANGED 1', 'MATCHED 2 CHANGED 1', 'counts'),
                ("(9, NULL), (7, 'initial')", "(9, NULL), (8, 'initial')", 'rows'),
                ("'duplicate_key'", "'check_violation'", 'refusal_reason')):
            source(project, 'build.transit', original.replace(before, after, 1))
            report = invoke(cli, project, expected=1)
            assert report['complete'] and not report['ok']
            assert [case['status'] for case in report['cases']] == ['failed', 'passed']
            assert report['cases'][0]['observation']['failure'] == failure
        source(project, 'build.transit', original.replace("(7, 'duplicate')", "(8, 'duplicate')"))
        report = invoke(cli, project, expected=1)
        assert report['cases'][0]['observation']['failure'] == 'expected_refusal'
        # An unexpected real refusal stops execution and identifies the suffix.
        source(project, 'build.transit', original.replace('(9, NULL)', '(7, NULL)', 1))
        report = invoke(cli, project, expected=1)
        assert not report['complete'] and [case['status'] for case in report['cases']] == ['failed', 'not_run']
        assert report['cases'][0]['error_code'] == 'GatewayMutationRejected'
        source(project, 'build.transit', original + '\nCREATE TEST TARGET empty AS BEGIN END;')
        invoke(cli, project, '--target', 'empty', expected=1)
        # Three batches, nulls, duplicate projected values, full-width integers,
        # authoritative updates/deletes and genuinely empty final results.
        inserts = ''.join(f'INSERT INTO data VALUES ({i}, NULL);' for i in range(70))
        expected = ','.join(f'({i}, NULL)' for i in range(70))
        body = ('CREATE PUBLIC TABLE data (id BIGINT PRIMARY KEY, value TEXT);' + inserts +
                f'ASSERT ROWS (SELECT * FROM data) EQUAL ({expected});' +
                'ASSERT ROWS (SELECT value FROM data) EQUAL (' + ','.join('(NULL)' for _ in range(70)) + ');' +
                'ASSERT COMMAND (UPDATE data SET id = 9223372036854775807 WHERE id = 0) MATCHED 1 CHANGED 1;' +
                'ASSERT ROWS (SELECT id FROM data WHERE id = 9223372036854775807) EQUAL ((9223372036854775807));' +
                'ASSERT COMMAND (DELETE FROM data) MATCHED 70 CHANGED 70;' +
                'ASSERT ROWS (SELECT * FROM data) EQUAL ();')
        source(project, 'build.transit', suite(body))
        report = invoke(cli, project)
        assert report['cases'][0]['observation']['rows'] == 141
        # Runtime constraint evidence and unchanged state use the same owners.
        source(project, 'build.transit', suite("CREATE PUBLIC TABLE items(id BIGINT PRIMARY KEY, CHECK (id > 0)); INSERT INTO items VALUES (1); ASSERT STATEMENT (UPDATE items SET id = -1) FAILS WITH 'check_violation'; ASSERT ROWS (SELECT * FROM items) EQUAL ((1));"))
        invoke(cli, project)
        # Case row accounting includes every statement, including plain SELECT.
        seed = 'CREATE PUBLIC TABLE items(id BIGINT); INSERT INTO items VALUES ' + ','.join(f'({i})' for i in range(100)) + ';'
        source(project, 'build.transit', suite(seed + 'SELECT * FROM items;' * 100))
        limit = invoke(cli, project)
        assert limit['cases'][0]['observation']['rows'] == 10000
        source(project, 'build.transit', suite(seed + 'SELECT * FROM items;' * 101))
        limit = invoke(cli, project, expected=1)
        assert not limit['complete'] and limit['cases'][0]['error_code'] == 'TestRowsLimit'
        columns = ','.join(f'c{i} TEXT' for i in range(32))
        values = ','.join('NULL' for _ in range(32))
        seed_wide = ('INSERT INTO items VALUES ' + ','.join(f'({values})' for _ in range(10)) + ';') * 16
        assignments = ','.join(f"c{i} = '" + 'x' * 90 + "'" for i in range(32))
        body = f'CREATE PUBLIC TABLE items({columns});' + seed_wide + f'UPDATE items SET {assignments};' + 'SELECT * FROM items;' * 40
        source(project, 'build.transit', suite(body))
        limit = invoke(cli, project, expected=1)
        assert not limit['complete'] and limit['cases'][0]['error_code'] == 'TestResultBytesLimit', limit
        # Bad expected types and shapes never reach native execution.
        for expected_rows in ("(('seven'))", '((1, 2))', '((NULL))'):
            source(project, 'build.transit', suite('CREATE PUBLIC TABLE items(id BIGINT PRIMARY KEY); ASSERT ROWS (SELECT * FROM items) EQUAL ' + expected_rows + ';'))
            failure = invoke(cli, project, expected=1)
            assert failure['outcome'] == 'not_submitted' and 'cases' not in failure
        # Independent child roots use the same resolver and default test target.
        child = project / 'child'
        child.mkdir()
        source(child, 'build.transit', suite('CREATE PUBLIC TABLE items(id BIGINT); ASSERT ROWS (SELECT * FROM items) EQUAL ();'))
        invoke(cli, project, '-f', 'child/build.transit')
        # All cases compile first: a valid first case cannot conceal a later error.
        source(project, 'build.transit', original.replace('SELECT id FROM items', 'SELECT missing FROM items'))
        report = invoke(cli, project, expected=1)
        assert 'cases' not in report and report['outcome'] == 'not_submitted'
        # Frozen repository test composition and override remain offline, including
        # with the original repository and git absent at execution time.
        remote = root / 'remote'
        remote.mkdir()
        revision = repository(root / 'origin', {'pkg/build.transit': "CREATE PUBLIC MODULE Cases() AS BEGIN TEST 'remote' USING MODULES () AS BEGIN CREATE PUBLIC TABLE items (id BIGINT); INSERT INTO items VALUES (7); ASSERT ROWS (SELECT * FROM items) EQUAL ((7)); END; END;"})
        text = f"DEPENDENCY checks FROM '{root / 'origin'}' REVISION '{revision}' SUBDIRECTORY 'pkg'; IMPORT checks FROM PACKAGE checks FILE 'build.transit'; CREATE TEST TARGET tests AS BEGIN USE checks.Cases(); END;"
        source(remote, 'build.transit', text)
        invoke(cli, remote, expected=1)
        cli_build(cli, remote, '--fetch', fetch=True)
        (root / 'origin').rename(root / 'hidden-origin')
        locked = invoke(cli, remote)
        override = root / 'override'
        override.mkdir()
        source(override, 'build.transit', (root / 'hidden-origin/pkg/build.transit').read_text().replace('7', '8'))
        overridden = invoke(cli, remote, '--override', f'checks={override}')
        assert locked['input_digest'] != overridden['input_digest']
        assert locked['sql_digest'] != overridden['sql_digest']
        lock = (remote / 'transit.lock').read_text()
        changed = json.loads(lock)
        changed['definition'] = 'foreign'
        (remote / 'transit.lock').write_text(json.dumps(changed))
        invoke(cli, remote, expected=1)
        (remote / 'transit.lock').write_text(lock)
        pin = json.loads(lock)['dependencies'][0]
        cached = remote / '.transit/packages' / pin['digest'] / 'tree/build.transit'
        cached.write_text(cached.read_text() + '\n')
        invoke(cli, remote, expected=1)
        shutil.rmtree(project)
        shutil.rmtree(remote)
        installed_oracle(cli, oracle)
    print('Application tests: offline isolation, typed rows, counts, refusals, child/remote targets and failure coverage passed')


if __name__ == '__main__':
    main()
