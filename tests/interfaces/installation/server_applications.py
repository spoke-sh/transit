#!/usr/bin/env python3
"""Separately built consumer over public CLI/configuration, with owned disk faults."""
import ctypes
import json
from harness.operation_helpers import operations
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import sys
import time

from harness.processes import children, command
from interfaces.installation.server import Fixture, freeze_executables
from harness.services import free_port


class Applications(Fixture):
    def __init__(self, cli, node, host, parent="/var/tmp"):
        super().__init__(cli, node, host, parent=parent)
        port = free_port()
        while port in self.config['ports'].values():
            port = free_port()
        self.config.update(version=1, applications={'port': port, 'max_applications': 3, 'max_roles': 8})
        self.path.write_text(json.dumps(self.config))
        self.management = None
        self.max_rss = 0

    def ready(self, timeout=120):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            assert self.process.poll() is None, Path(self.logs[-1].name).read_text()
            if select.select([self.process.stdout], [], [], .1)[0]:
                line = self.process.stdout.readline()
                assert line, Path(self.logs[-1].name).read_text()
                report = json.loads(line)
                assert report['ready'] and report['profile'] == 'local_applications_v1', report
                port = self.config['ports']['gateway']
                assert report['gateway_url'] == self.url, report
                assert report['allowed_hosts'] == [f'127.0.0.1:{port}', f'localhost:{port}'] + self.config.get('gateway_allowed_hosts', []), report
                self.management = Path(report['management_config'])
                return report
        raise TimeoutError(f'Application neighborhood readiness: {self.root}')

    def app(self, mode, *args, expect=None):
        deadline = time.monotonic() + 15
        saved = None
        if mode in ('install', 'replace', 'retry') and '--operation' in args:
            operation = args[args.index('--operation') + 1]
            saved = self.installation / 'management-recovery' / (str(operation) + '.json')
        frozen = saved.read_bytes() if saved and saved.exists() else None
        while True:
            if frozen is not None:
                assert saved.read_bytes() == frozen, 'Saved management request changed during recovery'
            result = subprocess.run([operations(), 'app', mode, '--config', str(self.management), *map(str, args)],
                capture_output=True, text=True, timeout=max(1, deadline-time.monotonic()), env={'PATH': '/unavailable'})
            # Read retries obtain a fresh observation. Mutation retries use the
            # public client's saved signed request for this exact operation;
            # the fixture checks that its bytes stay unchanged.
            if saved and saved.exists():
                current = saved.read_bytes()
                if frozen is not None:
                    assert current == frozen, 'Management retry replaced the original request'
                frozen = current
            first = result.stderr.splitlines()[0] if result.stderr else ''
            if (mode not in ('status', 'connect') and frozen is None) or (expect and expect in result.stderr) or result.returncode == 0 or first not in (
                    'application: AuthorityUnavailable', 'application: AuthorityTimeout',
                    'application: HttpConnectionClosing', 'application: ConnectionRefused') or time.monotonic() >= deadline:
                break
            time.sleep(.05)
        if expect:
            assert result.returncode != 0 and expect in result.stderr, result
            return result
        assert result.returncode == 0, result
        return json.loads(result.stdout) if result.stdout.strip() else None

    def status(self, application='work-items'):
        for line in Path(f'/proc/{self.process.pid}/status').read_text().splitlines():
            if line.startswith('VmHWM:'):
                self.max_rss = max(self.max_rss, int(line.split()[1]) * 1024)
        return self.app('status', '--application', application)

    def active(self, application='work-items', previous=None):
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            status = self.status(application)
            assert not any(role['state'] == 'failed' for role in status['roles']), status
            if status['installed'] and all(role['state'] == 'ready' for role in status['roles']):
                if previous is None or status['roles'][0]['generation'] > previous:
                    return status
            time.sleep(.1)
        raise TimeoutError(status)


def provision_authority(fixture, operator, connections):
    """Use the example's recoverable public authorization provisioning."""
    capabilities = json.loads(subprocess.check_output([operations(), 'auth', 'capabilities'], text=True))
    caller = json.loads(connections['operator'].read_text())
    administrator = fixture.root / 'authorization-admin.json'
    administrator.write_text(json.dumps(dict(version=1, url=caller['url'],
        connection=dict(definition=capabilities['capabilities']['definition'], realm=caller['realm'], principal=0),
        seed_file=str(fixture.installation / 'root.seed'), request_timeout_ms=10000)))
    administrator.chmod(0o600)
    recovery = fixture.root / 'authorization-recovery'
    recovery.mkdir(mode=0o700)
    # Explicit deployment input over the neighborhood's configured direct owner.
    # Resolve the installed worker's private role through public root inspection;
    # the application helper receives a chosen role ID, never a worker key.
    from interfaces.installation.server_application_faults import ExistingKey, native, post
    root = ExistingKey(fixture.root, fixture.installation / 'root.seed')
    worker = next(role for role in fixture.status()['roles'] if role['name'] == 'data')
    after, worker_role = None, None
    while True:
        query = dict(authorization=dict(role=None, kind=dict(roles=after)))
        roles = post(fixture.config['ports']['node'], '/v1/query',
            native(root, caller['realm'], 0, query), retry_unavailable=True)['body']['authorization']['body']['roles']
        for role in roles['records']:
            if role and role['native'] and role['enabled'] and not role['retired'] and bytes.fromhex(role['name']).decode() == f"native/{worker['principal']}/{role['id']}":
                assert worker_role is None
                worker_role = role['id']
        after = roles['next']
        if after is None:
            break
    assert worker_role is not None
    installation = fixture.record()
    connection = installation['default_table']['connection']
    target = fixture.root / 'data-target.json'
    target.write_text(json.dumps(dict(definition=capabilities['capabilities']['definition'],
        connection=connection, seed_file=str(fixture.installation / 'caller.seed'),
        namespace=1, first_object=1000, worker_login_role=worker_role)))
    target.chmod(0o600)
    profile = fixture.root / 'data-binding.json'
    provisioning = [operator, 'provision-authority', str(administrator),
        *(str(connections[name]) for name in ('operator', 'writer', 'inspector')), str(recovery), str(target), str(profile)]
    def invoke(timeout):
        deadline = time.monotonic() + timeout
        while True:
            result = subprocess.run(provisioning, capture_output=True, text=True,
                timeout=max(1, deadline-time.monotonic()), env={'PATH': '/unavailable'})
            if result.returncode == 0:
                return result
            assert result.stderr.strip() in ('error: AuthorityUnavailable', 'error: AuthorityTimeout',
                'error: HttpConnectionClosing', 'error: ConnectionRefused'), result
            assert time.monotonic() < deadline, result
            # The same provisioning directory owns every saved native request.
            time.sleep(.1)
    provisioned = invoke(300)
    recorded = {path.name: path.read_bytes() for path in recovery.glob('authorization-*.json')}
    repeated = invoke(120)
    assert json.loads(repeated.stdout) == json.loads(provisioned.stdout), repeated
    assert {path.name: path.read_bytes() for path in recovery.glob('authorization-*.json')} == recorded
    return profile


def run(cli, node, host, worker, operator):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Applications(cli, node, host)
    freeze_executables(fixture)
    fixture.path.write_text(json.dumps(fixture.config))
    started = time.monotonic()
    success = False
    print(f'Application installation proof: {fixture.root}', flush=True)
    operator = str(Path(operator).resolve())
    worker = str(Path(worker).resolve())

    def domain(connection, mode, operation=None, *args, expect=None):
        command = [operator, str(connection), mode]
        if operation:
            command.append(str(fixture.root / (operation + '.json')))
        command.extend(map(str, args))
        deadline = time.monotonic() + 40
        while True:
            result = subprocess.run(command, capture_output=True, text=True, timeout=40, env={'PATH': '/unavailable'})
            if result.returncode == 0 or result.stderr.strip() not in ('error: AuthorityUnavailable', 'error: AuthorityTimeout', 'error: HttpConnectionClosing', 'error: ConnectionRefused') or time.monotonic() >= deadline:
                break
            # Keep the same recovery path and arguments. A saved uncertain send
            # is retried byte-for-byte by the actual public example binary.
            time.sleep(.05)
        if expect:
            assert result.returncode != 0 and expect in result.stderr, result
            return result
        assert result.returncode == 0, result
        return json.loads(result.stdout)

    try:
        fixture.start()
        fixture.ready()
        courier = json.loads((fixture.installation / 'courier.json').read_text())['role']['courier']
        assert courier == {'destinations': [], 'all_destinations': True}, courier
        from interfaces.installation.server_faults import gateway_hosts
        gateway_hosts(fixture)
        declaration = json.loads(subprocess.check_output([operator, 'manifest', worker], text=True))
        manifest = fixture.root / 'application.yaml'
        manifest.write_text('\n'.join(f'{key}: {json.dumps(value)}' for key, value in declaration.items()))
        initial = fixture.app('install', '--file', manifest, '--operation', 'install-1')
        assert not initial['installed'], initial
        # Interrupt provisioning after an accepted spawn. Resume through public
        # CLI operations; no installation-record editing or downstream supervisor.
        while not (partial := fixture.status())['roles'][0]['pid']:
            time.sleep(.05)
        partial_pid = partial['roles'][0]['pid']
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        fixture.app('retry', '--operation', 'install-1')
        first = fixture.active()
        assert first['roles'][0]['pid'] == partial_pid
        ids = (first['roles'][0]['pid'], first['resources'][0]['id'], first['roles'][0]['principal'])
        again = fixture.app('install', '--file', manifest, '--operation', 'install-2')
        assert again['roles'][0]['pid'] == ids[0] and again['resources'][0]['id'] == ids[1]
        neighbor = json.loads(json.dumps(declaration))
        neighbor['application'] = 'neighbor'
        neighbor_path = fixture.root / 'neighbor.json'
        neighbor_path.write_text(json.dumps(neighbor))
        fixture.app('install', '--file', neighbor_path, '--operation', 'neighbor-1')
        fixture.active('neighbor')
        neighbor_workers = {pid for pid in children(fixture.process.pid) if '/applications/neighbor/' in command(pid)}
        assert len(neighbor_workers) == 1
        conflicting = json.loads(json.dumps(declaration))
        conflicting['roles'][0]['configuration'] = '{"application":10}'
        refused = fixture.root / 'refused.json'
        refused.write_text(json.dumps(conflicting))
        fixture.app('install', '--file', refused, '--operation', 'conflict', expect='ConflictingApplicationDeclaration')
        fixture.app('install', '--file', refused, '--operation', 'install-1', expect='ConflictingApplicationOperation')
        quota = dict(application='over-quota', roles=[dict(declaration['roles'][0], name=f'role{i}', accesses=[]) for i in range(8)], resources=[], callers=[])
        refused.write_text(json.dumps(quota))
        fixture.app('install', '--file', refused, '--operation', 'quota', expect='ApplicationCapacity')
        fixture.app('status', '--application', 'work-items', '--after', 4294967295, expect='InvalidApplicationCursor')
        connections = {}
        for name in ('operator', 'writer', 'inspector'):
            path = fixture.root / (name + '-connection.json')
            fixture.app('connect', '--application', 'work-items', '--caller', name, '--output', path)
            connections[name] = path
        yaml_connection = fixture.root/'inspector.yaml'
        fixture.app('connect', '--application', 'work-items', '--caller', 'inspector', '--output', yaml_connection)
        assert yaml_connection.read_text().startswith('version: 1\n')
        exported = {key: json.loads(value) for key, value in (line.split(': ', 1) for line in yaml_connection.read_text().splitlines())}
        assert exported == json.loads(connections['inspector'].read_text())
        # Real application provisioning uses the installed operator and public
        # native authorization lifecycle. Worker replacement never replays it.
        profile = provision_authority(fixture, operator, connections)
        domain(connections['operator'], 'initialize-catalog', 'catalog-initialize', profile)
        domain(connections['operator'], 'authorize', 'authorize')
        domain(connections['operator'], 'prepare-table', 'prepare-initial', 1)
        invalid = domain(connections['writer'], 'put', 'invalid-state', 99, 99, expect='InvalidWorkItemState')
        rejected = json.loads(invalid.stdout)
        detail = rejected['diagnostic']
        assert rejected['accepted'] > 0 and rejected['committed'] is False, rejected
        assert detail['code'] == 'work_items.invalid_state' and detail['outcome'] == 'input_rejected', detail
        facts = {item['field']: item['value'] for item in detail['facts'] if item}
        assert facts['source_key'] == {'signed': '99'} and facts['supplied_value'] == {'signed': '99'}, facts
        assert 'stack trace' not in invalid.stderr.lower() and 'operator.zig:' not in invalid.stderr, invalid.stderr
        for i in range(19):
            domain(connections['writer'], 'put', f'put-{i}', i - 9, i % 2)
        assert domain(connections['inspector'], 'inspect')['rows'] == 19
        domain(connections['operator'], 'prepare-table', 'prepare-target', 2)
        domain(connections['operator'], 'begin', 'begin')
        domain(connections['operator'], 'step', 'step-1')
        before = domain(connections['operator'], 'inspect')
        assert before['cursor']['copied'] == 1
        # A prior node recovery can legitimately fence every application host.
        # Compare rejection against the active generation immediately before it,
        # while still requiring the original logical identities and data.
        before_replacement = fixture.active()
        assert (before_replacement['roles'][0]['pid'], before_replacement['resources'][0]['id'], before_replacement['roles'][0]['principal']) == ids
        # A compatible configuration revision uses an explicit expected revision.
        replacement = {'application': 'work-items', 'role': 'data', 'expected_revision': before_replacement['roles'][0]['revision'],
            'contract': 'work-items-v1', 'artifact': {'path': worker}, 'configuration': '{ "application": 9 }'}
        path = fixture.root / 'replacement.yaml'
        path.write_text('\n'.join(f'{key}: {json.dumps(value)}' for key, value in replacement.items()))
        incompatible = dict(replacement, contract='incompatible-v2')
        refused.write_text(json.dumps(incompatible))
        fixture.app('replace', '--file', refused, '--operation', 'incompatible', expect='IncompatibleApplicationReplacement')
        assert fixture.status()['roles'][0]['generation'] == before_replacement['roles'][0]['generation']
        fixed_children = {pid for pid in children(fixture.process.pid) if 'data.bootstrap.json' not in command(pid)}
        fixture.app('replace', '--file', path, '--operation', 'replace-1')
        second = fixture.active(previous=before_replacement['roles'][0]['generation'])
        assert second['roles'][0]['revision'] != before_replacement['roles'][0]['revision']
        assert fixed_children | neighbor_workers <= children(fixture.process.pid), 'Replacement restarted unrelated roles'
        assert (second['roles'][0]['pid'], second['resources'][0]['id'], second['roles'][0]['principal']) == ids
        assert domain(connections['operator'], 'inspect')['migration'] == before['migration']
        fixture.app('retry', '--operation', 'replace-1')
        assert fixture.status()['roles'][0]['generation'] == second['roles'][0]['generation']
        domain(connections['operator'], 'step', 'step-1')  # Exact old receipt, no extra row copied.
        assert domain(connections['operator'], 'inspect')['migration'] == before['migration']
        fixture.kill_role('/applications/work-items/data.bootstrap.json')
        recovered = fixture.active(previous=second['roles'][0]['generation'])
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        fixture.active(previous=recovered['roles'][0]['generation'])
        assert domain(connections['operator'], 'inspect')['migration'] == before['migration']
        for ordinal in range(2, 2 * 19 + 5):
            state = domain(connections['operator'], 'inspect')
            if state['head']['epoch'] == '2':
                break
            domain(connections['operator'], 'step', f'step-{ordinal}')
        else:
            raise AssertionError('Migration did not activate')
        complete = domain(connections['inspector'], 'inspect')
        assert complete['head']['epoch'] == '2' and complete['rows'] == 19 and complete['row_steps'] == 19, complete
        domain(connections['writer'], 'put', 'paused-put', 1, 20, expect='WorkItemPublicationPaused')
        domain(connections['operator'], 'release', 'release')
        recovered = domain(connections['writer'], 'put', 'invalid-state', 99, 99, expect='InvalidWorkItemState')
        assert json.loads(recovered.stdout) == rejected, 'original input rejection changed after activation'
        domain(connections['writer'], 'put', 'released-put', 1, 10)
        for physical in ('/transit-node ', '"unified_requester":'):
            prior = fixture.status()['roles'][0]['generation']
            fixture.kill_role(physical)
            fixture.ready()
            fixture.active(previous=prior)
            assert domain(connections['inspector'], 'inspect')['rows'] == 19
        fixture.stop()
        fixture.start()
        fixture.ready()
        final = fixture.active()
        assert final['roles'][0]['pid'] == ids[0]
        receipts, after = [], 0
        while True:
            page = fixture.app('status', '--application', 'work-items', '--after', after)
            receipts.extend(page['receipts'])
            if page['next'] is None:
                break
            after = page['next']
        assert len(receipts) > 8 and len({item['position'] for item in receipts}) == len(receipts)
        checkpoint_bytes = max(path.stat().st_size for path in fixture.installation.glob('applications/*/record.json'))
        assert checkpoint_bytes <= 256 * 1024 and fixture.max_rss < 128 * 1024**2
        report = {'max_manager_rss': fixture.max_rss, 'max_checkpoint_bytes': checkpoint_bytes, 'profile': 'local_applications_v1', 'rows': 19, 'row_steps': complete['row_steps'], 'receipts': len(receipts),
            'generation': final['roles'][0]['generation'], 'elapsed_seconds': round(time.monotonic() - started, 3)}
        print(json.dumps(report), flush=True)
        success = True
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed application evidence retained: {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    run(*sys.argv[1:])
