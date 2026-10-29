"""Native contract failures and prepared-value lifetime against the real service."""
import json
import os
import struct

from query.logical.fuze_types import descriptor


def run(first, second, operation):
    first.call('touch', patch=dict(version=2), error='IncompatibleSqlDefinition')
    # A foreign definition is rejected by the exact-tag JSON decoder before
    # a typed request exists; version mismatch reaches envelope validation.
    first.call('touch', patch=dict(definition='00'*32), error='InvalidJsonShape')
    first.call('touch', patch=dict(instance=[0]*16), error='SqlInstanceChanged')
    first.call('touch', patch=dict(session=[0]*32), error='SqlSessionExpired')
    first.call('touch', lane='/v1/sql/control', error='InvalidSqlLane')
    first.call(dict(status=dict(operation=dict(operation, account=[0]*32))), error='GatewayDenied')
    first.call(dict(status=dict(token=list(os.urandom(16)))), error='MissingGatewayOperation')
    # Browser identity and forwarding headers are not an authentication path.
    for header in ('Origin', 'Cookie', 'Authorization', 'Forwarded', 'X-Forwarded-User', 'X-Transit-Uid'):
        first.http.close()
        first.transport()
        first.http.request('POST', '/v1/sql/session', '{}', {'Content-Type': 'application/json', header: 'untrusted'})
        reply = first.http.getresponse()
        assert reply.status == 400 and json.loads(reply.read())['err'] == 'InvalidSqlHeaders'
    first.http.close()
    first.last = 0
    # Rejected preparation must leave no partially initialized statement slot.
    # Reset destroys all occupied slots, then another preparation must succeed.
    for _ in range(3):
        first.call(dict(prepare=dict(sql='SET sql.idle_ms = 1')), error='SettingNotSessionMutable')
        first.call('reset')
    # The independently encoded parameter includes its descriptor and nullable
    # flag. It cannot silently inherit a different prepared type after reset.
    prepared = first.call(dict(prepare=dict(sql='SELECT id FROM native_sessions WHERE id = $1')))['described']
    kind = descriptor('int64')
    assert prepared['parameters'] == [kind.hex()]
    parameter = (b'FVL1' + struct.pack('<H', len(kind)) + kind + b'\x01\x03' + struct.pack('<q', 1)).hex()
    value = first.call(dict(execute=dict(statement=prepared['statement'], parameters=[parameter])))['batch']
    assert value['rows'] == [[(b'\x03' + struct.pack('<q', 1)).hex()]]
    second.call(dict(describe=prepared['statement']), error='SqlStatementExpired')
    first.call(dict(release=prepared['statement']), error='SqlResultActive')
    # Any failed request closes a partial cursor rather than letting a caller
    # append a fresh snapshot to it. The prepared statement itself remains.
    first.call(dict(fetch=dict(cursor=value['cursor'], batch=value['batch'])), error='SqlResultIncomplete')
    first.call(dict(execute=dict(statement=prepared['statement'], parameters=['00000000'])), error='InvalidValueEncoding')
    first.call('reset')
    first.call(dict(describe=prepared['statement']), error='SqlStatementExpired')
    first.call(dict(fetch=dict(cursor=value['cursor'], batch=value['batch'])), error='SqlResultIncomplete')
