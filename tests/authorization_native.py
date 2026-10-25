"""Signed declarative policy publication and recovery against disk-backed Ursula."""
import argparse
import hashlib
from http.client import HTTPConnection
import json
from pathlib import Path
import subprocess
import time

from inspection import System
from storage import wait_ready

ROOT = Path(__file__).resolve().parents[1]


def run(node, cli, report=None):
    started = time.monotonic()
    with System(node, cli, request_timeout_ms=30000) as system:
        def query(kind, principal=0, seed=None, status=200):
            response = system.native_query({'authorization': {'role': None, 'kind': kind}}, principal, seed, status)
            return response['body']['authorization'] if status == 200 else response

        def begin(action):
            revision = query({'identity': {}})['revision']
            return system.command({'authorization': {'begin': {'expected_revision': revision, 'role': None, 'action': action}}})

        def finish(change):
            while True:
                outcome = query({'change': change})['body']['change']
                if outcome['status'] == 'ready':
                    system.command({'authorization': {'publish': change}})
                    published = query({'change': change})['body']['change']
                    assert published['status'] == 'published'
                    return published['created_id']
                assert outcome['status'] == 'preparing', outcome
                system.command({'authorization': {'advance': change}})

        def apply(action):
            return finish(begin(action))

        def restart():
            system.authority.kill()
            system.authority.wait(timeout=10)
            system.store.stop()
            system.store.start()
            system.authority = system.start(node, system.config)
            wait_ready(system.store.http, system.authority, system.url + '/health')

        assert system.native_query({'capabilities': {}})['body']['capabilities']['declarative_authorization']
        before_preview = system.native_query({'identity': {}})
        preview_action = {'create_role': {'name': b'analyst'.hex(), 'login': True, 'create_role': False}}
        preview = query({'preview': {'expected_revision': 0, 'action': preview_action}})['body']['preview']
        assert preview['complete'] and preview['changed_records'] == 1
        assert system.native_query({'identity': {}}) == before_preview
        assert query({'resolve': b'analyst'.hex()}, status=403)['err'] == 'AccessDenied'
        # Observe durable acceptance independently while leaving the initiating
        # connection's reply unread, then kill both native authority and store.
        system.sequence += 1
        signed = system.signed({'authorization': {'begin': {'expected_revision': 0, 'role': None,
            'action': {'create_role': {'name': b'analyst'.hex(), 'login': True, 'create_role': False}}}}}, system.sequence)
        connection = HTTPConnection('127.0.0.1', system.port, timeout=30)
        connection.request('POST', '/v1/command', json.dumps(signed), {'Content-Type': 'application/json'})
        try:
            deadline = time.monotonic() + 30
            while True:
                observation = system.native_query({'identity': {}})
                if observation['principal_sequence'] == system.sequence:
                    change = observation['position'] - 1
                    break
                assert time.monotonic() < deadline, 'begin was not observed before the proof deadline'
                time.sleep(.05)
        finally:
            connection.close()
        restart()
        receipt = system.available_post('/v1/command', signed)
        assert receipt['position'] == change
        assert query({'receipt': signed['request']})['body']['receipt'] == receipt
        assert query({'operation': change})['body']['operation']['action'] == signed['request']['command']['authorization']['begin']['action']
        assert system.available_post('/v1/command', signed) == receipt
        assert query({'resolve': b'analyst'.hex()}, status=403)['err'] == 'AccessDenied'
        analyst = finish(change)
        print('Authorization: lost begin reply and private candidate survive node/store SIGKILL.', flush=True)

        analyst_seed, analyst_key = system.key('analyst')
        apply({'bind_credential': {'principal': 101, 'role': analyst, 'public_key': analyst_key, 'pid': None}})
        assert query({'identity': {}}, 101, analyst_seed)['body']['identity']['login_role'] == analyst
        domain = apply({'register_domain': {'registrar': 0, 'actions': 3, 'lifetime_resource': None}})
        object_id = apply({'register_object': {'domain': domain, 'owner': 0, 'schema': None}})
        protected = {'kind': 'domain', 'id': object_id}
        grant = apply({'grant': {'object': protected, 'grantee': analyst, 'privileges': 1, 'grant_options': 0}})
        assert apply({'grant': {'object': protected, 'grantee': analyst, 'privileges': 1, 'grant_options': 0}}) == grant
        decision = {'decision': {'object': protected, 'privileges': 1}}
        assert query(decision, 101, analyst_seed)['body']['decision']['allowed'] == 1
        pid = system.command({'spawn': {}})
        resource = system.command({'create_resource': {'writer': pid}})
        for raw in ({'resource': resource}, {'read_access': resource},
                    {'entries': {'resource': resource, 'revision': resource}}):
            assert system.native_query(raw, 101, analyst_seed, 403)['err'] == 'AccessDenied'
        assert query({'roles': None}, 101, analyst_seed, 403)['err'] == 'AccessDenied'

        revoked = begin({'revoke': {'id': grant, 'privileges': 1, 'grant_option_only': False, 'behavior': 'cascade'}})
        restart()
        assert query(decision, 101, analyst_seed)['body']['decision']['allowed'] == 1
        finish(revoked)
        assert query(decision, 101, analyst_seed, 403)['err'] == 'AccessDenied'
        restart()
        assert query(decision, 101, analyst_seed, 403)['err'] == 'AccessDenied'
        print('Authorization: staged revoke is invisible until publication and remains revoked after disk restart.', flush=True)

        # Domain workers guard publication with the separately authenticated
        # original admission; infrastructure execution rights cannot replace it.
        apply({'grant': {'object': {'kind': 'process', 'id': pid}, 'grantee': analyst,
                         'privileges': 4, 'grant_options': 0}})
        system.command({'own': {'pid': pid, 'expected_generation': 0, 'worker': 0}})
        admitted = system.available_post('/v1/command', system.signed(
            {'send': {'pid': pid, 'value': b'original operation'.hex(), 'role': analyst}},
            1, 101, analyst_seed))['position']
        subject = {'accepted': {'pid': pid, 'input': admitted, 'principal': 101}}
        guarded = {'subject': subject, 'requirements': [dict(object=protected, privileges=1, access='all')] + [None] * 15}
        assert query({'check': guarded}, status=403)['err'] == 'AccessDenied'
        current_grant = apply({'grant': {'object': protected, 'grantee': analyst,
                                        'privileges': 1, 'grant_options': 0}})
        assert query({'check': guarded})['body']['check']['role'] == analyst
        forged = dict(guarded, subject={'accepted': dict(subject['accepted'], principal=0)})
        assert query({'check': forged}, status=403)['err'] == 'AccessDenied'
        apply({'revoke': {'id': current_grant, 'privileges': 1, 'grant_option_only': False, 'behavior': 'cascade'}})
        turn = {'turn': {'pid': pid, 'generation': 1, 'input': admitted, 'expected_revision': 0, 'authorization': guarded}}
        denied = system.post('/v1/command', system.signed(turn, system.sequence + 1), 409)
        assert denied['err'] == 'AuthorizationSubjectDenied', denied
        assert system.native_query({'process': pid})['body']['process']['process']['consumed'] == 0
        apply({'grant': {'object': protected, 'grantee': analyst, 'privileges': 1, 'grant_options': 0}})
        system.command(turn)
        assert system.native_query({'process': pid})['body']['process']['process']['consumed'] == 1
        print('Authorization: original admission guards refuse forged subjects and revoked publication without consuming the input.', flush=True)

        for index in range(10):
            apply({'create_role': {'name': f'role-{index}'.encode().hex(), 'login': False, 'create_role': False}})
        first = query({'roles': None})['body']['roles']
        assert len([item for item in first['records'] if item]) == 8
        cursor = first['next']
        assert cursor is not None
        second = query({'roles': cursor})['body']['roles']
        assert second['records'][0]['id'] > cursor['after']
        assert query({'memberships': {'member': 0, 'cursor': cursor}}, status=422)['err'] == 'InvalidAuthorizationCursor'
        old = begin({'create_role': {'name': b'reserved-old'.hex(), 'login': False, 'create_role': False}})
        old_id = query({'change': old})['body']['change']['created_id']
        current = apply({'create_role': {'name': b'reserved-current'.hex(), 'login': False, 'create_role': False}})
        assert current != old_id
        stale = system.signed({'authorization': {'publish': old}}, system.sequence + 1)
        assert system.post('/v1/command', stale, 409)['err'] == 'StaleAuthorizationRevision'
        assert query({'roles': cursor}, status=409)['err'] == 'StaleAuthorizationRevision'
        system.command({'authorization': {'abandon': old}})
        assert query({'role': old_id}, status=403)['err'] == 'AccessDenied'
        restart()
        assert query({'resolve': b'reserved-current'.hex()})['body']['resolve']['id'] == current
        assert query({'change': old})['body']['change']['status'] == 'abandoned'
        print('Authorization: paged inspection, scoped/stale cursors and reserved identity conflicts survive restart.', flush=True)

        # Lose the publication reply while the caller rotates its own key. The
        # old signature cannot be retried; a current authenticated receipt read
        # recovers acceptance without executing or re-signing the old request.
        replacement_seed, replacement_key = system.key('analyst-replacement')
        identity = query({'identity': {}}, 101, analyst_seed)
        rotation_action = {'rotate_credential': {'principal': 101,
            'expected_epoch': identity['body']['identity']['credential_epoch'], 'public_key': replacement_key}}
        rotation_begin = system.signed({'authorization': {'begin': {
            'expected_revision': identity['revision'], 'role': None, 'action': rotation_action}}}, 2, 101, analyst_seed)
        rotation = system.available_post('/v1/command', rotation_begin)['position']
        publication = system.signed({'authorization': {'publish': rotation}}, 3, 101, analyst_seed)
        connection = HTTPConnection('127.0.0.1', system.port, timeout=30)
        connection.request('POST', '/v1/command', json.dumps(publication), {'Content-Type': 'application/json'})
        try:
            deadline = time.monotonic() + 30
            while query({'change': rotation})['body']['change']['status'] != 'published':
                assert time.monotonic() < deadline, 'rotation was not published before the proof deadline'
                time.sleep(.05)
        finally:
            connection.close()
        assert system.post('/v1/command', publication, 403)['err'] == 'AccessDenied'
        recovered = query({'receipt': publication['request']}, 101, replacement_seed)['body']['receipt']
        assert recovered['position'] > rotation
        assert query({'operation': rotation}, 101, replacement_seed)['body']['operation']['action'] == rotation_action
        changed = json.loads(json.dumps(publication['request']))
        changed['command']['authorization'] = {'abandon': rotation}
        assert query({'receipt': changed}, 101, replacement_seed, 422)['err'] == 'ConflictingRetry'
        restart()
        assert query({'receipt': publication['request']}, 101, replacement_seed)['body']['receipt'] == recovered
        print('Authorization: current credentials recover the exact lost rotation receipt after disk restart.', flush=True)

        # Definitions are mandatory on the independently signed request. Merely
        # changing its label cannot make old bytes authenticate as a new request.
        foreign = json.loads(json.dumps(signed))
        foreign['request']['definition'] = '138bd4043de660b50db60d909ab7e29c3d1ab64b1b0658a8a8e000fd15d72365'
        assert system.post('/v1/command', foreign, status=None)[0] == 400
        del foreign['request']['definition']
        assert system.post('/v1/command', foreign, status=None)[0] == 400
        final = query({'identity': {}})
        observations = dict(policy_revision=final['revision'], root_sequence=system.sequence,
                            analyst=analyst, domain_object=object_id, abandoned_identity=old_id,
                            restarts=5, resident_pages=16, preview_without_publication=True,
                            reconciled_grant=grant, recovered_rotation_receipt=recovered['position'])
    result = dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  dirty=bool(subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT, text=True)),
                  node_sha256=hashlib.sha256(node.read_bytes()).hexdigest(), elapsed_seconds=time.monotonic()-started,
                  definition=json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'],
                  observations=observations, assertions='passed')
    if report:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('node', type=Path)
    parser.add_argument('cli', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    run(args.node.resolve(strict=True), args.cli.resolve(strict=True), args.report)
