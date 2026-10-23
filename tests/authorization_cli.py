"""Private administration caller, C ABI and host recovery on disk-backed Ursula."""
import argparse
import ctypes
import hashlib
import json
from operation_helpers import operations
from pathlib import Path
import subprocess
import time

from inspection import System
from storage import wait_ready
from serving import Key, compact

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
            result = subprocess.run([operations(), '--structured', 'auth', mode,
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
        print('Authorization caller: private checkpoints, bounded apply, exact restart recovery and stale/foreign rejection passed.', flush=True)

        realm_object = {'kind': 'realm', 'id': 0}
        group = query({'resolve': b'cli-budgeted'.hex()})['body']['resolve']['id']
        grant = {'object': realm_object, 'grantee': role, 'privileges': 16, 'grant_options': 0}
        membership = {'member': role, 'role': group, 'admin': False, 'inherit': True, 'set': True}

        def set_document(intents):
            return dict(definition=definition, realm=72, base_revision=query({'identity': {}})['revision'],
                managed_scope=dict(objects=[realm_object], memberships=[dict(member=role, role=group)], defaults=[]),
                intents=intents)

        def prepare_set(name, document):
            source = system.root / f'{name}-document.json'
            target = system.root / f'{name}-saved.json'
            source.write_text(json.dumps(document))
            before = system.native_query({'identity': {}})
            result = invoke('prepare-set', source, '--output', target)
            assert result['changeset']['prepared']['preview']['complete']
            assert system.native_query({'identity': {}}) == before
            assert target.stat().st_mode & 0o777 == 0o600
            return source, target

        before_grants = query({'grants': {'object': realm_object, 'grantee': 0, 'cursor': None}})['body']['grants']['records']
        document = set_document([{'grant': grant}, {'membership': membership}])
        set_source, set_saved = prepare_set('scoped', document)
        tampered = json.loads(set_saved.read_text())
        content = json.loads(tampered['record'])
        content['seal']['document']['intents'][1]['membership']['admin'] = True
        tampered['record'] = json.dumps(content)
        invalid.write_text(json.dumps(tampered))
        before = system.native_query({'identity': {}})
        invoke('apply', invalid, ok=False)
        assert system.native_query({'identity': {}}) == before
        out_of_scope = dict(document, managed_scope=dict(objects=[], memberships=[], defaults=[]))
        invalid.write_text(json.dumps(out_of_scope))
        invoke('prepare-set', invalid, '--output', system.root / 'denied-set.json', ok=False)
        assert system.native_query({'identity': {}}) == before
        pending = invoke('apply', set_saved, '--steps', '2')
        assert pending['pending'] and pending['completed'] == 1 and pending['total'] == 2
        retained = set_saved.read_bytes()
        # Re-sealing with an unrelated key must not borrow a real published
        # first step to have the current administrator sign an altered successor.
        forged = json.loads(retained)
        content = json.loads(forged['record'])
        content['current'] = None
        content['seal']['document']['intents'][1]['membership']['admin'] = True
        attacker = Key(system.root, 'changeset-substitution-test', 19)
        seal = content['seal']
        seal['public_key'] = attacker.public
        sealed = {field: seal[field] for field in ('document', 'principal', 'role', 'public_key')}
        seal['signature'] = attacker.sign(hashlib.sha256(b'transit.authorization.changeset.v1\0' + compact(sealed)).digest())
        begin = content['completed'][0]['record']['begin']
        begin['public_key'] = attacker.public
        begin['signed']['signature'] = attacker.sign(hashlib.sha256(b'transit.request.v1\0' + compact(begin['signed']['request'])).digest())
        forged['record'] = compact(content).decode()
        invalid.write_text(json.dumps(forged))
        before = system.native_query({'identity': {}})
        rejected = invoke('apply', invalid, ok=False)
        diagnostic = json.loads(rejected.stderr)
        assert diagnostic['code'] == 'authorization.operation_failed'
        assert diagnostic['category'] == 'binding', diagnostic
        assert system.native_query({'identity': {}}) == before
        assert set_saved.read_bytes() == retained
        # Lose the second begin reply from the recovery file, then restart disk.
        receipt = invoke('submit', set_saved)['changeset']['receipt']
        assert set_saved.read_bytes() == retained
        system.authority.kill()
        system.authority.wait(timeout=10)
        system.store.stop()
        system.store.start()
        system.authority = system.start(node, system.config)
        wait_ready(system.store.http, system.authority, system.url + '/health')
        assert invoke('submit', set_saved)['changeset']['receipt'] == receipt
        summary = invoke('apply', set_saved)['terminal']
        assert summary['status'] == 'published' and summary['completed'] == summary['total'] == 2
        assert invoke('observe', set_saved)['changeset']['observation'] == summary
        assert invoke('apply', set_saved)['terminal'] == summary
        after_grants = query({'grants': {'object': realm_object, 'grantee': 0, 'cursor': None}})['body']['grants']['records']
        assert all(before in after_grants for before in before_grants if before is not None)

        # A later policy change cannot rebase the remaining explicit removal.
        _, interrupted = prepare_set('interrupted', set_document([{'grant': grant},
            {'revoke_membership': dict(member=role, role=group, option=None, behavior='restrict')}]))
        invoke('submit', interrupted)
        recovered = system.root / 'set-first-received.json'
        invoke('recover', interrupted, '--output', recovered)
        publish = system.root / 'set-first-publish.json'
        invoke('next', recovered, '--output', publish)
        invoke('submit', publish)
        received = system.root / 'set-published.json'
        invoke('recover', publish, '--output', received)
        checkpoint = system.root / 'set-checkpoint.json'
        invoke('next', received, '--output', checkpoint)
        partial = json.loads(json.loads(checkpoint.read_text())['record'])
        assert len(partial['completed']) == 1 and partial['current'] is None
        _, interloper = prepare('set-intervening-role')
        invoke('apply', interloper)
        retained = checkpoint.read_bytes()
        before = system.native_query({'identity': {}})
        invoke('apply', checkpoint, ok=False)
        assert checkpoint.read_bytes() == retained and system.native_query({'identity': {}}) == before
        assert invoke('observe', checkpoint)['changeset']['observation']['completed'] == 1
        _, removal = prepare_set('explicit-removal', set_document([
            {'revoke_membership': dict(member=role, role=group, option=None, behavior='restrict')}]))
        assert invoke('apply', removal)['terminal']['status'] == 'published'
        assert all(edge is None or edge['role'] != group for edge in query({'memberships': {'member': role, 'cursor': None}})['body']['memberships']['records'])
        assert any(edge and edge['grantee'] == role and edge['privileges'] & 16 for edge in query({'grants': {'object': realm_object, 'grantee': role, 'cursor': None}})['body']['grants']['records'])
        print('Authorization changesets: sealed scope, explicit removal, partial publication, lost replies, disk restart and stale-basis refusal passed.', flush=True)

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
            change_set = abi({'changeset': {'prepare': set_document([{'grant': grant}])}})['changeset']['prepared']['record']
            assert port({'changeset': {'next': change_set}})['changeset']['next']['record'] == change_set
            first = abi({'changeset': {'submit': change_set}})['changeset']['receipt']
            recovered = port({'changeset': {'recover_pending': change_set}})['changeset']['recovered']
            publication = abi({'changeset': {'next': recovered}})['changeset']['next']['record']
            receipt = port({'changeset': {'submit': publication}})['changeset']['receipt']
            received_set = abi({'changeset': {'received': dict(record=publication, receipt=receipt)}})['changeset']['record']
            done = port({'changeset': {'next': received_set}})['changeset']['next']['record']
            assert abi({'changeset': {'next': done}})['changeset']['next']['terminal']['status'] == 'published'
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
        observations = dict(restarts=2, cli_reader=role, abi_role=terminal['created_id'],
                            bounded_apply=True, foreign_missing_definition_rejected=True,
                            stale_record_preserved=True, cli_abi_host=True, scoped_changesets=True,
                            changeset_partial_recovery=True, changeset_explicit_removal=True,
                            changeset_signer_substitution_rejected=True)
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
