"""Public administration CLI, C ABI and host recovery on disk-backed Ursula."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import subprocess
import time

from inspection import System
from storage import wait_ready

ROOT = Path(__file__).resolve().parents[1]


def run(node, signer, transit, library, host, report):
    started = time.monotonic()
    with System(node, signer, request_timeout_ms=30000) as system:
        definition = system.native_query({'capabilities': {}})['definition']
        connection = dict(definition=definition, realm=72, principal=0, role=None)
        config = system.root / 'administration.json'
        config.write_text(json.dumps(dict(version=1, connection=connection, url=system.url,
                                         seed_file=system.seed.name, request_timeout_ms=30000)))

        def invoke(mode, source, *args, ok=True):
            result = subprocess.run([str(transit), '--diagnostics=json', 'auth', mode,
                                     '--config', str(config), '--file', str(source), *map(str, args)],
                                    capture_output=True, text=True, timeout=90)
            assert (result.returncode == 0) == ok, (result.returncode, result.stdout, result.stderr)
            assert system.seed.read_text().strip() not in result.stderr
            return json.loads(result.stdout) if ok else result

        def query(kind):
            return system.native_query({'authorization': {'role': None, 'kind': kind}})['body']['authorization']

        def prepare(name):
            source = system.root / f'{name}-action.json'
            source.write_text(json.dumps(dict(expected_revision=query({'identity': {}})['revision'],
                action={'create_role': {'name': name.encode().hex(), 'login': False, 'create_role': False}})))
            artifact = system.root / f'{name}-saved.json'
            before = system.native_query({'identity': {}})
            result = invoke('prepare', source, '--output', artifact)
            assert result['prepared']['preview']['complete']
            assert system.native_query({'identity': {}}) == before
            assert artifact.stat().st_mode & 0o777 == 0o600
            return source, artifact

        source, artifact = prepare('cli-reader')
        retained = artifact.read_bytes()
        receipt = invoke('submit', artifact)['receipt']
        assert artifact.read_bytes() == retained
        system.authority.kill()
        system.authority.wait(timeout=10)
        system.store.stop()
        system.store.start()
        system.authority = system.start(node, system.config)
        wait_ready(system.store.http, system.authority, system.url + '/health')
        assert invoke('submit', artifact)['receipt'] == receipt
        result = invoke('apply', artifact, '--steps', '1')
        assert result['terminal']['status'] == 'published' and result['steps'] == 1
        role = query({'resolve': b'cli-reader'.hex()})['body']['resolve']['id']
        assert invoke('apply', artifact)['terminal']['created_id'] == role
        assert invoke('observe', artifact)['observation']['body']['authorization']['body']['operation']['outcome']['created_id'] == role
        completed = artifact.read_bytes()
        invoke('prepare', source, '--output', artifact, ok=False)
        assert artifact.read_bytes() == completed

        _, budgeted = prepare('cli-budgeted')
        pending = invoke('apply', budgeted, '--steps', '1')
        assert pending['pending'] and pending['steps'] == 1
        frozen = json.loads(json.loads(budgeted.read_text())['record'])
        assert frozen['pending']['signed']['request']['command']['authorization'] == {'publish': pending['change']}
        assert query({'change': pending['change']})['body']['change']['status'] == 'ready'
        assert invoke('apply', budgeted)['terminal']['status'] == 'published'

        _, stale = prepare('cli-stale')
        original = stale.read_bytes()
        _, winner = prepare('cli-winner')
        assert invoke('apply', winner)['terminal']['status'] == 'published'
        before = system.native_query({'identity': {}})
        invoke('apply', stale, ok=False)
        assert stale.read_bytes() == original
        assert system.native_query({'identity': {}}) == before
        invalid = system.root / 'foreign-saved.json'
        foreign = json.loads(original)
        foreign['definition'] = 'foreign-v1'
        invalid.write_text(json.dumps(foreign))
        invoke('apply', invalid, ok=False)
        del foreign['definition']
        invalid.write_text(json.dumps(foreign))
        invoke('apply', invalid, ok=False)
        assert system.native_query({'identity': {}}) == before
        print('Authorization CLI: private checkpoints, bounded apply, exact restart recovery and stale/foreign rejection passed.', flush=True)

        api = ctypes.CDLL(str(library))
        pointer = ctypes.c_void_p
        api.transit_client_create.argtypes = [ctypes.c_uint32, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_uint32, ctypes.POINTER(pointer)]
        api.transit_client_create.restype = ctypes.c_uint32
        api.transit_client_destroy.argtypes = [pointer]
        api.transit_authorization_apply.argtypes = [pointer, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_size_t, ctypes.POINTER(pointer)]
        api.transit_authorization_apply.restype = ctypes.c_uint32
        api.transit_buffer_data.argtypes = [pointer]
        api.transit_buffer_data.restype = pointer
        api.transit_buffer_size.argtypes = [pointer]
        api.transit_buffer_size.restype = ctypes.c_size_t
        api.transit_buffer_destroy.argtypes = [pointer]
        client = pointer()
        url = system.url.encode()
        assert api.transit_client_create(1, url, len(url), 30000, ctypes.byref(client)) == 0

        def abi(action, selected=connection, status=0):
            config_bytes = json.dumps(selected).encode()
            action_bytes = json.dumps(action).encode()
            buffer = pointer()
            try:
                actual = api.transit_authorization_apply(client, bytes.fromhex(system.seed.read_text().strip()),
                    config_bytes, len(config_bytes), action_bytes, len(action_bytes), ctypes.byref(buffer))
                result = json.loads(ctypes.string_at(api.transit_buffer_data(buffer), api.transit_buffer_size(buffer))) if buffer else None
                assert actual == status, (actual, result)
                return result
            finally:
                if buffer:
                    api.transit_buffer_destroy(buffer)

        host_config = system.root / 'host.json'
        host_config.write_text(json.dumps(dict(url=system.url, timeout_ms=30000)))
        process = subprocess.Popen([str(host), str(host_config)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        system.children.append(process)

        def port(action):
            process.stdin.write(json.dumps({'authorization': dict(seed_file=str(system.seed), connection=connection, action=action)}) + '\n')
            process.stdin.flush()
            result = json.loads(process.stdout.readline())
            assert result['status'] == 0, result
            return result['value']

        try:
            prepared = abi({'prepare': dict(expected_revision=query({'identity': {}})['revision'],
                action={'create_role': {'name': b'abi-role'.hex(), 'login': False, 'create_role': False}})})['prepared']
            saved = prepared['record']
            assert port({'next': saved}) == {'next': {'pending': saved}}
            first = abi({'submit': saved})['receipt']
            assert port({'submit': saved})['receipt'] == first
            recovered = port({'recover_pending': saved})['recovered']
            assert json.loads(recovered)['pending'] is None
            publication = abi({'next': recovered})['next']['pending']
            receipt = port({'submit': publication})['receipt']
            completed = abi({'received': dict(record=publication, receipt=receipt)})['record']
            terminal = port({'next': completed})['next']['terminal']
            assert terminal['status'] == 'published'
            assert abi({'observe': completed})['observation']['body']['authorization']['body']['operation']['outcome'] == terminal
            denied = abi({'submit': saved}, dict(connection, principal=9), status=1)
            assert denied['diagnostic']['outcome'] == 'not_submitted'
            assert abi({'restore': completed})['record'] == completed
            assert query({'resolve': b'abi-role'.hex()})['body']['resolve']['id'] == terminal['created_id']
        finally:
            api.transit_client_destroy(client)
            process.stdin.write('{"shutdown":{}}\n')
            process.stdin.flush()
            assert json.loads(process.stdout.readline())['status'] == 0
            process.wait(timeout=10)
            process.stdin.close()
            process.stdout.close()
            process.stderr.close()
        print('Authorization ABI/host: shared saved bytes, explicit submit, receipt recovery and current identity validation passed.', flush=True)
        observations = dict(restarts=1, cli_reader=role, abi_role=terminal['created_id'],
                            bounded_apply=True, foreign_missing_definition_rejected=True,
                            stale_record_preserved=True, cli_abi_host=True)
    result = dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        dirty=bool(subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT, text=True)),
        definition=definition, elapsed_seconds=time.monotonic() - started,
        artifacts={path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in (node, transit, library, host)},
        observations=observations, assertions='passed')
    if report:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('node', 'signer', 'transit', 'library', 'host'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    run(*(getattr(args, name).resolve(strict=True) for name in ('node', 'signer', 'transit', 'library', 'host')), args.report)
