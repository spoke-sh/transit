"""Installed public Python mutation caller, sync and async, for shared faults."""
import asyncio
import json
from pathlib import Path
import sys
from transit_client import ProcessRef, ResourceRef
from transit_client.errors import TransitError, UncertainOperation
from transit_station import mutations as m


def read():
    line = sys.stdin.readline()
    return json.loads(line) if line else None


def write(value):
    print(json.dumps(value),flush=True)


def translate(client, action):
    name, value = next(iter(action.items()))
    if name == 'capabilities':
        # Construction already checked the loaded implementation's capabilities.
        return None
    if name == 'describe': return client.describe()
    if name == 'compile': return client.compile_sql(value['name'],value['sql'],int(value['namespace']))
    if name == 'next': return client.prepare_next(m.Compiled(bytes.fromhex(value['request']),m.Reference(bytes.fromhex(value['reference']))))
    if name == 'submit': return client.submit(m.Prepared(value.encode()))
    if name in ('observe','rejection'):
        return getattr(client,name)(m.Prepared(value['prepared'].encode()),value['input'])
    if name == 'status': return client.status(m.Reference(bytes.fromhex(value)))
    if name == 'prepare':
        control, reference = next(iter(value.items()))
        return getattr(client,'prepare_'+control)(m.Reference(bytes.fromhex(reference)))
    raise ValueError('Unsupported test action')


def result(action, value):
    name = next(iter(action))
    if name == 'capabilities': return {'capabilities':dict(version=1,max_rows=3)}
    if name == 'describe':
        return {'description':dict(resource=value.resource.resource,table=value.table,names=list(value.names),value_type=value.value_type.value,
            resource_revision=value.resource_revision,policy_revision=str(value.policy_revision),declaration=value.declaration.hex(),permissions=int(value.permissions),
            active=None if value.active is None else str(value.active))}
    if name == 'compile': return {'compiled':dict(request=value.request.hex(),reference=value.reference.data.hex())}
    if name in ('next','prepare'): return {'prepared':None if value is None else value.data.decode()}
    if name == 'submit': return {'receipt':dict(position=value)}
    if name in ('observe','rejection'): return {'observation' if name == 'observe' else name:None if value is None else value.value}
    if name == 'status':
        return {'status':None if value is None else dict(reference=value.reference.data.hex(),principal=value.principal,table=value.table,
            declaration=value.declaration.hex(),policy_revision=str(value.policy_revision),phase=value.phase.value,
            affected_rows=value.affected_rows,reason=value.reason.value,input=value.input,
            conflict=None if value.conflict is None else dict(key=str(value.conflict.key),row=value.conflict.row))}
    raise ValueError('Unsupported result')


def failed(action, error):
    if isinstance(error,UncertainOperation):
        assert 'submit' in action and error.recovery == action['submit'].encode()
    return dict(status=error.status,value={'err':error.code,'diagnostic':error.diagnostic,'diagnostic_invalid':error.diagnostic_invalid})


def run(mode, path):
    config = json.loads(Path(path).read_text())
    c = config['connection']
    connection = m.Connection(ProcessRef(c['realm'],c['writer']),ResourceRef(c['realm'],c['resource']),c['table'])
    args = (config['url'],c['principal'],Path(config['seed_file']),connection)
    if mode == 'sync':
        with m.Client(*args,timeout_ms=10000) as client:
            write({'ready':True})
            while action := read():
                if 'close' in action: break
                try: output = dict(status=0,value=result(action,translate(client,action)))
                except TransitError as error: output = failed(action,error)
                write(output)
        write({'closed':True})
    else:
        async def execute():
            async with m.AsyncClient(*args,timeout_ms=10000) as client:
                write({'ready':True})
                while action := read():
                    if 'close' in action: break
                    try:
                        pending = translate(client,action)
                        value = None if pending is None else await pending
                        output = dict(status=0,value=result(action,value))
                    except TransitError as error: output = failed(action,error)
                    write(output)
            write({'closed':True})
        asyncio.run(execute())


if __name__ == '__main__': run(*sys.argv[1:])
