"""Explicit, resumable native authorization for trusted development provisioning.

The injected command owner journals exact native requests and receipts. This
layer freezes each policy basis before handing it a begin/advance/publish step.
Repeating provisioning recovers those changes; it never reinstates a revoked
grant by preparing a replacement change.
"""
import hashlib
import json
import struct

from common import write


class Changes:
    def __init__(self, directory, command, query):
        self.directory, self.command, self.query = directory, command, query
        self.definition = query({'capabilities': {}})['definition']

    def read(self, kind):
        return self.query({'authorization': {'role': None, 'kind': kind}})['body']['authorization']

    def apply(self, name, action):
        path = self.directory / (name + '.json')
        if path.exists():
            record = json.loads(path.read_text())
            if record['definition'] != self.definition or record['begin']['action'] != action:
                raise RuntimeError('Authorization provisioning definition or action changed')
        else:
            record = dict(definition=self.definition, begin=dict(
                expected_revision=self.read({'identity': {}})['revision'], role=None, action=action))
            write(path, record)
        change = self.command('auth-' + name + '-begin', {'authorization': {'begin': record['begin']}})
        for _ in range(128):
            status = self.read({'change': change})['body']['change']
            if status['status'] == 'published':
                return status['created_id']
            if status['status'] == 'ready':
                self.command('auth-' + name + '-publish', {'authorization': {'publish': change}})
            elif status['status'] == 'preparing':
                self.command('auth-' + name + '-step-' + str(status['steps']), {'authorization': {'advance': change}})
            else:
                raise RuntimeError('Authorization provisioning change was abandoned')
        raise RuntimeError('Authorization change remains pending; repeat the same provisioning')


def station(changes, realm, workers):
    """Create stable worker login roles and an explicitly selected data role.

    Workers contain principal, pid, resource and initial public_key. They are
    bound once, before activation; later credential rotation preserves roles.
    All mutations go through the public native administration protocol.
    """
    ledger = workers['ledger']
    roles = {}
    for name, worker in workers.items():
        role = changes.apply(name + '-login', {'create_role': {
            'name': f'station/{ledger["pid"]}/{name}'.encode().hex(), 'login': True}})
        roles[name] = role
        changes.apply(name + '-credential', {'bind_credential': dict(
            principal=worker['principal'], role=role, public_key=worker['public_key'], pid=worker['pid'])})
        changes.apply(name + '-native', {'grant': dict(
            object={'kind': 'process', 'id': worker['pid']}, grantee=role, privileges=88)})
        changes.command('auth-' + name + '-state', {'grant_resource': dict(
            resource=worker['resource'], subject=worker['principal'], permissions=7)})
    data = changes.apply('data-role', {'create_role': {
        'name': f'station/{ledger["pid"]}/data'.encode().hex(), 'login': False}})
    for name, role in roles.items():
        changes.apply(name + '-data-role', {'membership': dict(member=role, role=data, inherit=False, set=True)})
    domains = [changes.apply('domain-' + name, {'register_domain': dict(registrar=ledger['principal'], actions=mask)})
               for name, mask in (('database', 1), ('schema', 3), ('table', 15))]

    def binding(kind, identity):
        return list(hashlib.sha256(b'transit.catalog.authorization.binding.v1\0' + bytes.fromhex(changes.definition)
            + struct.pack('<QQQBQ', realm, ledger['resource'], 1, kind, identity)).digest())

    database = changes.apply('database', {'register_object': dict(domain=domains[0], owner=0, schema=None, binding=binding(1, 0))})
    schema = changes.apply('schema', {'register_object': dict(domain=domains[1], owner=0,
        schema={'kind': 'domain', 'id': database}, binding=binding(2, 1))})
    for name, identity in (('connect', database), ('usage', schema)):
        changes.apply(name, {'grant': dict(object={'kind': 'domain', 'id': identity}, grantee=data, privileges=1)})
    changes.apply('table-defaults', {'default_grant': dict(creator=0, schema={'kind': 'domain', 'id': schema},
        domain=domains[2], grantee=data, privileges=7)})
    return dict(role=data, profile=dict(database_domain=domains[0], schema_domain=domains[1], table_domain=domains[2],
        database=database, initial_schema=1, initial_schema_authority=schema))
