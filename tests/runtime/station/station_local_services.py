"""Server-owned local Station services: installation, joined retry and revocation."""
import ctypes
import json
import os
from pathlib import Path
import shutil
import signal
import time

from harness.processes import children, command, joined
from interfaces.installation.server_applications import Applications
from interfaces.installation.server_application_faults import ExistingKey, native, post
from runtime.station.station import frame


def run(server, worker):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Applications(server, server, server)
    fixture.config['executables'] = {}
    fixture.config['sql']['native'] = {'local': False}
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    try:
        fixture.start()
        fixture.ready()
        roles = []
        for name, peer in (('parent', 'child'), ('child', 'parent')):
            accesses = [dict(name='data', resource=name, permissions=7)]
            if name == 'child':
                accesses.append(dict(name='supervisor', resource='parent', permissions=3, required=False))
            roles.append(dict(name=name, contract='station-ledger-v1', artifact=dict(path=str(Path(worker).resolve())),
                configuration=json.dumps(dict(role='coordinator', destination=peer, observer='observer')), accesses=accesses))
        declaration = dict(version=1, application='supervision', roles=roles,
            resources=[dict(name=name, writer=name) for name in ('parent', 'child')],
            callers=[dict(name=name, send_to=name) for name in ('parent', 'child')],
            initialize=[dict(role=name, caller=name, value=frame(b'init')) for name in ('parent', 'child')],
            station=[dict(name='observer', mode='observe', watches=[dict(resource='parent'), dict(resource='child')]),
                     dict(name='lifecycle', mode='lifecycle', watches=[dict(resource='parent', child='child')])])
        path = fixture.root / 'supervision.json'
        path.write_text(json.dumps(declaration))
        fixture.app('install', '--file', path, '--operation', 'install-supervision')
        initial = fixture.active('supervision')
        assert all(service['ready'] for service in initial['services']), initial
        identities = [(service['name'], service['principal']) for service in initial['services']]
        parent, child = (role['pid'] for role in initial['roles'])
        resource = initial['resources'][0]['id']
        root = ExistingKey(fixture.root, fixture.installation / 'root.seed')
        realm = fixture.config['realm']
        port = fixture.config['ports']['node']

        def query(kind):
            return post(port, '/v1/query', native(root, realm, 0, kind), retry_unavailable=True)

        def submit(value):
            sequence = query({'capabilities': {}})['principal_sequence'] + 1
            # Admission pressure can follow acceptance. Retry only this frozen
            # signature/sequence through the shared bounded transport helper.
            signed = native(root, realm, 0, value, sequence)
            return post(port, '/v1/command', signed, retry_unavailable=True)

        def state():
            key = b'\x00c' + child.to_bytes(8, 'little') + b'\x00'
            entry = query({'read_entries': dict(resource=resource, revision=None, view=None, keys=[key.hex()] + [None] * 7)})['body']['read_entries']['entries'][0]
            return bytes.fromhex(entry['value']) if entry else None

        def until(predicate):
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                result = predicate()
                if result: return result
                assert fixture.process.poll() is None
                time.sleep(.05)
            status = fixture.status('supervision')
            observed = {}
            try:
                for name, pid in (('parent', parent), ('child', child)):
                    process = query({'process': pid})['body']['process']['process']
                    observed[name] = {key: process[key] for key in ('pid', 'owner', 'generation', 'failure', 'lifecycle')}
            except Exception as error:
                observed['observation_error'] = str(error)
            raise AssertionError(dict(roles=status['roles'], services=status['services'], native=observed))

        submit({'grant_resource': dict(resource=resource, subject=0, permissions=3)})
        until(lambda: state() is not None)
        # A real private child interruption is repaired without rotating service
        # principals or broadening grants. Workers retain their native identities.
        observer = next(pid for pid in children(fixture.process.pid) if '/station/observer/config.json' in command(pid))
        os.kill(observer, signal.SIGKILL)
        until(lambda: any(pid != observer and '/station/observer/config.json' in command(pid) for pid in children(fixture.process.pid)))
        until(lambda: all(service['ready'] for service in fixture.status('supervision')['services']))
        assert [(service['name'], service['principal']) for service in fixture.status('supervision')['services']] == identities
        old_child = next(pid for pid in children(fixture.process.pid) if '/child.bootstrap.json' in command(pid))
        accepted = submit({'send': dict(pid=child, value=frame(b'invalid'))})
        until(lambda: state()[14] == 4)  # one retry, then exhausted
        outcome = query({'process': child})['body']['process']
        assert outcome['process']['failure'] == accepted['position']
        assert state()[13] == 1 and outcome['process']['failure'] is not None
        joined([old_child])
        directory = fixture.installation / 'applications/supervision/station/lifecycle'
        request = json.loads((directory / 'stop.json').read_text())
        assert json.loads((directory / 'stopped.json').read_text()) == request
        assert request['pid'] == child and request['generation'] < outcome['process']['generation']
        # Retained restart reuses identities and keeps the exhausted head blocked.
        parent_generation = fixture.status('supervision')['roles'][0]['generation']
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        until(lambda: all(service['ready'] for service in fixture.status('supervision')['services']))
        # Service readiness precedes worker activation. Let the manager finish
        # its root-signed rotation before this test uses that same root identity
        # to revoke access; competing root sequencers correctly conflict.
        def parent_active():
            role = fixture.status('supervision')['roles'][0]
            return role['state'] == 'ready' and role['generation'] > parent_generation
        until(parent_active)
        assert state()[13:15] == bytes([1, 4])
        assert query({'process': child})['body']['process']['process']['failure'] == accepted['position']
        assert [(service['name'], service['principal']) for service in fixture.status('supervision')['services']] == identities
        # Idle access loss blocks this application without regranting its scope.
        submit({'grant_resource': dict(resource=resource, subject=identities[0][1], permissions=0)})
        until(lambda: all(not service['ready'] and service['error_name'] for service in fixture.status('supervision')['services']))
        fixture.stop()
        fixture.start()
        fixture.ready()
        assert all(not service['ready'] for service in fixture.status('supervision')['services'])
        success = True
        print('Local Station services: retained identity, child recovery, joined bounded retry, original input and idle revocation passed.')
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print('Failed local Station evidence retained:', fixture.root)
