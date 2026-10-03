"""Installed sync/async public catalog callers for the shared recovery schedule."""
import asyncio
from dataclasses import asdict
import json
from pathlib import Path
import sys
from transit_client import ProcessRef, ResourceRef
from transit_client.errors import TransitError, UncertainOperation
from transit_station import catalog as m
from transit_station import CellType


def scope(v): return m.Scope(ResourceRef(v['realm'], v['resource']), int(v['catalog']))
def scope_json(v): return dict(realm=v.resource.realm, resource=v.resource.resource, catalog=str(v.catalog))
def configuration(v):
    s = scope(v['scope'])
    return m.Configuration(s, ProcessRef(s.resource.realm, v['owner']), v['administrator'])
def configuration_json(v): return dict(scope=scope_json(v.scope), owner=v.owner.pid, administrator=v.administrator)
def policy(v): return m.Policy(scope(v['scope']), v['principal'], int(v['revision']), v['inspect'], v['create'])
def policy_json(v): return dict(scope=scope_json(v.scope), principal=v.principal, revision=str(v.revision), inspect=v.inspect, create=v.create)
def request(v):
    schema = m.Schema(tuple(v['schema']['names']), CellType(v['schema']['value_type']))
    return m.CreateTable(scope(v['scope']), int(v['operation']), int(v['object']), v['table'], v['name'], schema)
def request_json(v):
    return dict(scope=scope_json(v.scope), operation=str(v.operation), object=str(v.object_id), table=v.table, name=v.name,
                schema=dict(names=list(v.schema.names), value_type=v.schema.value_type.value))

def cursor(v): return None if v is None else m.Cursor(v['definition'], scope(v['scope']), v['resource_revision'], v['after'])
def cursor_json(v): return None if v is None else dict(definition=v.definition, scope=scope_json(v.scope), resource_revision=v.resource_revision, after=v.after)
def definition_json(v):
    return None if v is None else dict(scope=scope_json(v.scope), object=str(v.object_id), revision=str(v.revision), name=v.name,
        source=dict(table=dict(id=v.source.table, schema=dict(names=list(v.source.schema.names), value_type=v.source.schema.value_type.value))),
        principal=v.principal, operation=str(v.operation), input=v.input)


def translate(client, action):
    name, value = next(iter(action.items()))
    if name in ('capabilities', 'describe'): return getattr(client, name)()
    if name == 'lookup': return client.lookup(value)
    if name == 'definition': return client.definition(int(value['object']), int(value['revision']))
    if name == 'list': return client.list(cursor(value))
    if name == 'compile': return client.compile_sql(value['sql'], int(value['operation']), int(value['object']), value['table'])
    if name == 'prepare_initialize': return client.prepare_initialize(configuration(value))
    if name == 'prepare_create': return client.prepare_create(request(value))
    if name == 'prepare_policy': return client.prepare_policy(m.PolicyChange(int(value['expected_revision']), policy(value['policy'])))
    if name == 'submit': return client.submit(m.Prepared(value.encode()))
    if name in ('observe', 'input_disposition'): return getattr(client, name)(m.Prepared(value['prepared'].encode()), value['input'])
    if name == 'status': return client.status(request(value))
    raise AssertionError('Unknown catalog test action')


def result(action, value):
    name = next(iter(action))
    if name == 'capabilities': return dict(capabilities=asdict(value))
    if name in ('lookup', 'definition'): return dict(definition=definition_json(value))
    if name == 'list': return dict(page=dict(resource_revision=value.resource_revision,
        entries=[definition_json(entry) for entry in value.entries] + [None] * (8 - len(value.entries)), next=cursor_json(value.next)))
    if name == 'describe':
        return dict(description=dict(configuration=configuration_json(value.configuration), policy=policy_json(value.policy), resource_revision=value.resource_revision))
    if name == 'compile': return dict(compiled=dict(request=request_json(value.request), canonical=value.canonical.hex()))
    if name.startswith('prepare_'): return dict(prepared=value.data.decode())
    if name == 'submit': return dict(receipt=dict(position=value))
    if name == 'observe': return dict(observation=value.value)
    if name == 'input_disposition':
        return dict(disposition=None if value is None else dict(scope=scope_json(value.scope), origin=value.origin.value,
            principal=value.principal, input=value.input, payload=value.payload.hex(), outcome=value.outcome.value))
    if name == 'status':
        return dict(status=None if value is None else dict(request=request_json(value.request), principal=value.principal, input=value.input, outcome=value.outcome.value))
    raise AssertionError('Unknown catalog test result')


def read():
    line = sys.stdin.readline()
    return json.loads(line) if line else None

def write(value): print(json.dumps(value), flush=True)

def failed(action, error):
    if isinstance(error, UncertainOperation): assert error.recovery == action['submit'].encode()
    return dict(status=error.status, value=dict(err=error.code,diagnostic=error.diagnostic,diagnostic_invalid=error.diagnostic_invalid))


def run(mode, path):
    config = json.loads(Path(path).read_text()); c = config['connection']; s = scope(c['scope'])
    connection = m.Connection(ProcessRef(s.resource.realm, c['owner']), s)
    args = config['url'], c['principal'], Path(config['seed_file']), connection
    if mode == 'sync':
        with m.Client(*args, timeout_ms=10000) as client:
            write(dict(ready=True))
            while action := read():
                if 'close' in action: break
                try: output = dict(status=0, value=result(action, translate(client, action)))
                except TransitError as error: output = failed(action, error)
                write(output)
        write(dict(closed=True))
    else:
        async def execute():
            async with m.AsyncClient(*args, timeout_ms=10000) as client:
                write(dict(ready=True))
                while action := read():
                    if 'close' in action: break
                    try: output = dict(status=0, value=result(action, await translate(client, action)))
                    except TransitError as error: output = failed(action, error)
                    write(output)
            write(dict(closed=True))
        asyncio.run(execute())


if __name__ == '__main__': run(*sys.argv[1:])
