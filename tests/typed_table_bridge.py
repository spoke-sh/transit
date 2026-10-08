"""Exercise the shared general Table boundary over an actual native owner.

This fixture uses the public Station port and C ABI. Installed SDK qualification
has its own boundary; no Python implementation of Table semantics is used.
"""
import json
import os
import select
import subprocess
import time


def run(host, url, root, readers, query):
    source_config = json.loads((root / "console.json").read_text())
    connection = source_config["catalog"]
    connection["scope"]["catalog"] = str(connection["scope"]["catalog"])
    config = root / "bridge-host.json"
    config.write_text(json.dumps(dict(url=url, seed_file=str(root / "caller.seed"),
                                     catalog_client=dict(connection=connection, timeout_ms=5000))))
    def open_bridge():
        child = subprocess.Popen([host, str(config)], stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        readers.append(child)
        return child

    process = open_bridge()
    max_step_bytes = 0

    def call(action, error=None):
        nonlocal max_step_bytes
        wire = json.dumps({'catalog': action}, separators=(',', ':'))
        if next(iter(action)) in ('next', 'status', 'progress', 'wait_progress'):
            max_step_bytes = max(max_step_bytes, len(wire.encode()))
        process.stdin.write(wire + '\n')
        process.stdin.flush()
        assert select.select([process.stdout], [], [], 30)[0], 'Neutral Table call exceeded its budget'
        line = process.stdout.readline()
        assert line, (process.poll(), process.stderr.read() if process.poll() is not None else '')
        envelope = json.loads(line)
        result = envelope['value']
        if error:
            assert envelope['status'] != 0 and result['err'] == error, envelope
            assert result['diagnostic']['outcome'] in ('not_submitted', 'not_applicable'), result
        else:
            assert envelope['status'] == 0 and 'err' not in result, envelope
        return result

    definition = call({'capabilities': {}})['capabilities']['definition']

    def persist(name, value):
        with (root / name).open('w') as output:
            json.dump(value, output, separators=(',', ':'))
            output.flush()
            os.fsync(output.fileno())

    def identity(operation):
        return dict(operation=str(operation), namespace=str(operation + 10000))

    def finish(compiled):
        persist('bridge-intent.json', compiled['saved'])
        reference = compiled['intent']['reference']
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            step = call({'next': reference})['next']
            if 'terminal' in step:
                return step['terminal']
            if 'running' in step:
                time.sleep(.01)
                continue
            assert 'send' in step, step
            prepared = step['send']
            persist('bridge-step.json', prepared)
            receipt = call({'submit': prepared})['receipt']
            persist('bridge-input.json', receipt)
            while time.monotonic() < deadline:
                progress = call({'wait_progress': dict(intent=reference, prepared=prepared, input=receipt['position'])})['progress']
                if 'pending' in progress:
                    continue
                processed = progress['processed']
                assert processed['disposition'] is None, processed
                if processed['outcome'] and processed['outcome']['terminal']:
                    return processed['outcome']
                break
        raise AssertionError('Neutral Table operation did not finish')

    def sql(operation, text, object_id=None):
        compiled = call({'compile': dict(identity=identity(operation), create_object=object_id, sql=text)})['compiled']
        return compiled, finish(compiled)

    def lookup(name='bridge_people'):
        return call({'lookup': name})['definition']

    def basis(value):
        return {name: value['metadata'][name] for name in ('object', 'revision', 'schema_fingerprint')}

    def prepare(operation, action, name='bridge_people'):
        return call({'prepare': dict(definition=definition, identity=identity(operation), name=name, action=action)})['compiled']

    def dependency_control(dependency, present):
        prepared = call({'prepare_dependency': dict(**dependency, present=present)})['prepared']
        persist('bridge-control.json', prepared)
        receipt = call({'submit': prepared})['receipt']
        selected = dict(prepared=prepared, input=receipt['position'])
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if call({'wait_observe': selected})['observation'] == 'processed':
                disposition = call({'input_disposition': selected})['disposition']
                assert disposition['outcome'] == 'dependency_applied', disposition
                return
        raise AssertionError('Dependency control did not process')

    _, created = sql(900, 'CREATE TABLE bridge_people (tenant INTEGER, id INTEGER, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2), PRIMARY KEY(tenant,id))', '9001')
    assert created['phase'] == 'applied' and created['object'] == '9001', created
    source = lookup()
    assert len(source['schema']['columns']) == 4 and source['schema']['primary_key'] == ['1', '2'], source
    assert source['head']['rows'] == '0', source
    cell = lambda atom: {'cell': {'value': {'atom': atom}}}
    nested = {'value': {'structure': [cell({'binary': 'ab' * 256})['cell'], cell({'utf8': '東京'})['cell']]}}
    row = [dict(column='3', value={'cell': nested}), dict(column='1', value=cell({'signed': '7'})),
           dict(column='4', value=cell({'decimal': '123456789012345678901234567890'})),
           dict(column='2', value=cell({'signed': '1'}))]
    mutation = dict(basis=basis(source), mutation=dict(action={'insert': [row]}, predicate=None))
    # Exercise both directions above the old raw-client framing bound without
    # dispatching thousands of unrelated upload parts in this framing proof.
    large_row = json.loads(json.dumps(row))
    large_row[0]['value']['cell']['value']['structure'][0]['value']['atom']['binary'] = 'ab' * (300 * 1024)
    large = prepare(899, {'mutate': dict(basis=basis(source), mutation=dict(action={'insert': [large_row]}, predicate=None))})
    assert len(json.dumps(large)) > 540672
    assert call({'load': large['saved']})['loaded'] == large['intent']

    inserted = prepare(901, {'mutate': mutation})
    applied = finish(inserted)
    assert applied['counts'] == {'matched': '1', 'changed': '1'}, applied
    result = query('SELECT payload,amount FROM bridge_people')['rows'][0]
    assert result[0]['cell'] == nested and result[1]['cell']['value']['atom']['decimal'] == '123456789012345678901234567890', result
    duplicate = finish(prepare(902, {'mutate': mutation}))
    assert duplicate['phase'] == 'rejected' and duplicate['counts'] is None, duplicate
    assert duplicate['diagnostic']['code'] == 'table.primary_key_conflict', duplicate
    controls = dict(basis=basis(source), change={'add': dict(name='enabled', type={'boolean': {}}, nullable=False,
                        default={'value': {'atom': {'boolean': True}}}, max_characters=None)})
    changed = finish(prepare(903, {'alter': controls}))
    assert changed['phase'] == 'applied', changed
    stale = dict(definition=definition, identity=identity(904), name='bridge_people', action={'mutate': mutation})
    call({'prepare': stale}, error='CatalogDefinitionChanged')
    source = lookup()
    renamed = finish(prepare(905, {'rename': dict(basis=basis(source), name='bridge_renamed')}))
    assert renamed['phase'] == 'applied' and lookup() is None, renamed
    assert query('SELECT enabled FROM bridge_renamed')['rows'][0][0]['cell']['value']['atom']['boolean'] is True
    source = lookup('bridge_renamed')
    blocker = dict(scope=connection['scope'], object='9001', identity=str((1 << 64) - 1), owner=connection['owner'], kind='writer')
    dependency_control(blocker, True)
    blocked = prepare(908, {'drop': dict(basis=basis(source), if_exists=False)}, name='bridge_renamed')
    rejected = finish(blocked)
    assert rejected['phase'] == 'rejected' and rejected['diagnostic']['code'] == 'table.drop_restricted', rejected
    facts = {fact['field']: fact for fact in rejected['diagnostic']['facts'] if fact is not None}
    assert facts['dependency']['value'] == {'unsigned': blocker['identity']}, facts
    assert facts['dependency_kind']['value'] == {'text': 'writer'}, facts
    assert facts['dependency_owner']['value'] == {'unsigned': str(blocker['owner'])}, facts
    assert all(facts[key]['origin'] == 'owner' and facts[key]['availability'] == 'provided' for key in ('dependency', 'dependency_kind', 'dependency_owner'))
    dependency_control(blocker, False)
    dropped = finish(prepare(906, {'drop': dict(basis=basis(source), if_exists=False)}, name='bridge_renamed'))
    assert dropped['phase'] == 'applied' and lookup('bridge_renamed') is None, dropped
    sql(907, 'CREATE TABLE bridge_people (replacement TEXT)', '9002')
    sql(909, 'CREATE TABLE bridge_renamed (replacement BOOLEAN)', '9003')
    assert lookup()['metadata']['object'] == '9002'
    # Restarting the local handle does not imply cancellation or recompile.
    process.stdin.close()
    process.stdin = None
    assert process.wait(timeout=10) == 0
    process = open_bridge()
    call({'status': inserted['intent']['reference']}, error='TableIntentNotLoaded')
    loaded = call({'load': inserted['saved']})['loaded']
    assert loaded == inserted['intent']
    original = call({'status': loaded['reference']})['state']['outcome']
    assert original == applied and original['object'] == '9001', original
    retained = call({'definition': dict(object='9001', revision='1')})['historical']
    assert set(retained) == {'metadata', 'schema'} and retained['metadata']['name'] == 'bridge_people'
    assert len(retained['schema']['columns']) == 4 and retained['schema']['primary_key'] == ['1', '2']
    altered = call({'definition': dict(object='9001', revision='2')})['historical']
    assert altered['schema']['columns'][-1]['name'] == 'enabled'
    renamed = call({'definition': dict(object='9001', revision='3')})['historical']
    assert renamed['metadata']['name'] == 'bridge_renamed'
    assert call({'definition': dict(object='9001', revision='999')}) == {'historical': None}
    call({'load': blocked['saved']})
    retained_rejection = call({'status': blocked['intent']['reference']})['state']['outcome']
    assert retained_rejection == rejected, retained_rejection
    assert lookup('bridge_renamed')['metadata']['object'] == '9003'
    assert max_step_bytes < 8192, max_step_bytes
    process.stdin.close()
    process.stdin = None
    assert process.wait(timeout=10) == 0
    return dict(max_step_bytes=max_step_bytes, original_object=original['object'], replacement_object='9002')
