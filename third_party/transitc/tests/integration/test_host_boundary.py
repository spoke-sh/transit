"""Real compiled-case execution plus adversarial child-process/result controls."""
import copy
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from workspace.build import offline

ROOT = Path(__file__).resolve().parents[2]


@contextmanager
def private_root():
    root = Path(tempfile.mkdtemp(prefix='transitc-host-boundary-'))
    try:
        yield root
    except BaseException:
        print(f'Private failed host-boundary evidence retained at {root}', file=sys.stderr)
        raise
    else:
        shutil.rmtree(root)


def script(path, body):
    pid_file = path.with_suffix('.pid')
    path.write_text(f'#!{sys.executable}\nimport os\nfrom pathlib import Path\nPath({str(pid_file)!r}).write_text(str(os.getpid()))\n' + body)
    path.chmod(0o700)
    return path


def main():
    compiler = Path(sys.argv[1] if len(sys.argv) > 1 else 'zig-out/bin/transitc').resolve()
    runtime = Path(os.environ['TRANSIT_TEST_RUNTIME']).resolve()
    with private_root() as root:
        project = root / 'project'
        fixture = ROOT / 'tests/fixtures/application-tests'
        shutil.copytree(fixture, project)
        storage = root / 'cases'
        storage.mkdir()
        environment = {'PATH': '/unavailable', 'TMPDIR': str(storage), 'TRANSIT_CONSOLE_CONFIG': '/private/unreadable'}

        def invoke(host, expected=1, timeout=60):
            result = subprocess.run([str(compiler), 'test', '--runtime', str(host), '--format', 'json'],
                                    cwd=project, env=environment, capture_output=True, text=True, timeout=timeout, preexec_fn=offline)
            assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
            assert not result.stderr, result.stderr
            report = json.loads(result.stdout)
            assert report['ok'] is (expected == 0), report
            assert not list(storage.iterdir()), 'Owned child case storage survived checked cleanup'
            if host.with_suffix('.pid').exists():
                pid = int(host.with_suffix('.pid').read_text())
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    raise AssertionError(f'Test host process {pid} was not joined')
            return report

        captured = root / 'captured.json'
        capture = script(root / 'capture',
                         'from pathlib import Path\nimport sys\n'
                         f'Path({str(captured)!r}).write_bytes((Path(sys.argv[2]) / "case.json").read_bytes())\n'
                         'raise SystemExit(1)\n')
        report = invoke(capture)
        assert not report['complete'] and [case['status'] for case in report['cases']] == ['failed', 'not_run']
        request = json.loads(captured.read_text())
        golden = (fixture / 'expected.sql').read_bytes()
        assert ''.join(step + ';\n' for step in request['steps']).encode() == golden
        assert request['sql_digest'] == list(hashlib.sha256(golden).digest())
        shutil.rmtree(project)

        def native(value, expected=0):
            directory = Path(tempfile.mkdtemp(prefix='native-', dir=root))
            payload = value if isinstance(value, bytes) else json.dumps(value).encode()
            (directory / 'case.json').write_bytes(payload)
            result = subprocess.run([str(runtime), '__transit_test_case_v1', str(directory)],
                                    env=environment, capture_output=True, text=True, timeout=40, preexec_fn=offline)
            assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
            if expected:
                assert not result.stdout
                assert sorted(path.name for path in directory.iterdir()) == ['case.json'], 'Invalid request initialized native state'
                return None
            assert not result.stderr, result.stderr
            response = json.loads(result.stdout)
            assert response['request_digest'] == list(hashlib.sha256(payload).digest())
            assert response['identity'] == value['identity'] and response['sql_digest'] == value['sql_digest']
            assert response['runtime']['executable_digest'] == list(hashlib.sha256(runtime.read_bytes()).digest())
            return response

        # The source tree is absent: only the frozen SQL/expectations reach the host.
        response = native(request)
        assert response['complete'] and response['passed'] and response['observation']['rows'] == 4, response
        wrong = copy.deepcopy(request)
        rows = next(action['expectation']['rows'] for action in wrong['actions'] if 'rows' in action['expectation'])
        rows['values'][0] = rows['values'][1]
        failed = native(wrong)
        assert failed['complete'] and not failed['passed'] and failed['observation']['failure'] == 'rows', failed
        invalid = []
        for field in ('definition', 'source_definition'):
            value = copy.deepcopy(request)
            value.pop(field)
            invalid.append(value)
            value = copy.deepcopy(request)
            value[field] = 'foreign'
            invalid.append(value)
        value = copy.deepcopy(request)
        value['sql_digest'][0] ^= 1
        invalid.append(value)
        value = copy.deepcopy(request)
        value['actions'][0]['step'] = len(value['steps'])
        invalid.append(value)
        value = copy.deepcopy(request)
        value['milliseconds'] = 30001
        invalid.append(value)
        value = copy.deepcopy(request)
        value['actions'] *= 1025
        invalid.append(value)
        value = copy.deepcopy(request)
        value['unexpected'] = True
        invalid.append(value)
        value = copy.deepcopy(request)
        next(action['expectation']['rows'] for action in value['actions'] if 'rows' in action['expectation'])['schema'] = '00'
        invalid.append(value)
        for value in invalid:
            native(value, expected=1)
        native(b'x' * (64 * 1024 * 1024 + 1), expected=1)

        shutil.copytree(fixture, project)
        response_file = root / 'response.json'
        response_file.write_text(json.dumps(response))
        # These synthetic children only test result admission, never runtime correctness.
        mutations = {
            'foreign': "reply['definition'] = 'foreign'",
            'missing': "del reply['source_definition']",
            'request': "reply['request_digest'][0] ^= 1",
            'case': "reply['identity'][0] ^= 1",
            'sql': "reply['sql_digest'][0] ^= 1",
            'incomplete': "reply['complete'] = False",
            'prefix': "reply['observation']['actions'] -= 1",
            'rows': "reply['observation']['rows'] = 10001",
            'resources': "reply['observation']['resources']['memory_peak_bytes'] = 0",
            'detail': "reply['detail']['expected_reason_len'] = 33",
            'truncated': "print('{'); raise SystemExit(0)",
            'oversized': "print('x' * 65537); raise SystemExit(0)",
            'stderr': "print('unexpected child stderr', file=sys.stderr)",
            'nonzero': "print(json.dumps(reply)); raise SystemExit(1)",
            'killed': "os.kill(os.getpid(), signal.SIGKILL)",
        }
        prelude = ('import hashlib, json, os, signal, sys\nfrom pathlib import Path\n'
                   'raw = (Path(sys.argv[2]) / "case.json").read_bytes()\nrequest = json.loads(raw)\n'
                   f'reply = json.loads(Path({str(response_file)!r}).read_text())\n'
                   'reply["request_digest"] = list(hashlib.sha256(raw).digest())\n'
                   'reply["identity"] = request["identity"]\nreply["sql_digest"] = request["sql_digest"]\n'
                   'reply["observation"]["actions"] = len(request["actions"])\n')
        for name, mutation in mutations.items():
            fake = script(root / name, prelude + mutation + '\nprint(json.dumps(reply))\n')
            refused = invoke(fake)
            assert not refused['complete'] and [case['status'] for case in refused['cases']] == ['failed', 'not_run'], (name, refused)
        absent = invoke(root / 'missing-runtime')
        assert absent['cases'][0]['error_code'] == 'TestRuntimeUnavailable', absent
        counter = root / 'counter'
        changing = script(root / 'changing', prelude +
                          f'counter = Path({str(counter)!r})\n'
                          'if counter.exists(): reply["runtime"]["revision"] = "changed-runtime"\n'
                          'counter.touch()\nprint(json.dumps(reply))\n')
        changed = invoke(changing)
        assert not changed['complete'] and changed['cases'][1]['error_code'] == 'TestRuntimeChanged', changed
        sleeping = script(root / 'timeout', 'import time\ntime.sleep(60)\n')
        timed = invoke(sleeping, timeout=45)
        assert not timed['complete'] and timed['cases'][0]['status'] == 'failed', timed
    print('PASS compiled test host: source-free native assertions, 11 request refusals, 15 response/process refusals, missing/changed runtime, timeout and joined cleanup')


if __name__ == '__main__':
    main()
