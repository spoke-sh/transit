"""Real durable refresh owner with independent signed controls and query bytes."""
import hashlib
import json
from pathlib import Path
import struct
import time
from serving_table import watch as table_watch, query_bytes, query_policy
from reactive import reactive
from serving import post, submit


def run(env, _tls):
    started = time.monotonic()
    principal = 65536
    ingress, application = env['ingress'], env['application']
    requests, resource = env['ingress_resource'], env['application_resource']
    cast, drained, query = env['cast'], env['drained'], env['query']
    port, host = env['gateway_ports'][0], env['public_host']
    trace = []
    leases = {}
    last_clock = 0

    def client(operation, expected=200, control=False):
        value = post(port, '/reactive/v1/client' + ('/control' if control else ''), operation, host, expected, {'Origin': 'https://' + host})
        if expected == 200:
            trace.extend([dict(type='HostRequest', value=operation), dict(type='HostResponse', value=value)])
        return value

    def command(value, refresh=False, control=False, lost=False):
        if not control:
            maintain()
        prepared = client({'refresh_prepare' if refresh else 'prepare': value}, control=control)['prepared']
        env['sequences'][principal] = prepared['request']['sequence']
        if lost:
            env['fault']['armed'] = True
            client({'submit': prepared}, 503, control)
            assert env['fault']['lost']
        receipt = client({'submit': prepared}, control=control)['receipt']['receipt']
        drained(ingress)
        observation = client({'observe': receipt['position']}, control=True)['observation']
        assert observation == {'committed': {}}, (value, observation)
        if 'close' in value:
            leases.pop(value['close']['session'], None)
        return receipt['position']

    def maintain():
        nonlocal last_clock
        now_ms = int(time.time() * 1000)
        if leases and now_ms - last_clock >= 2000:
            cast(ingress, reactive(1, struct.pack('<Q', now_ms)), 34)
            drained(ingress)
            last_clock = now_ms
        for identifier, (identity, previous) in list(leases.items()):
            now_ms = int(time.time() * 1000)
            if previous - now_ms < 18000:
                cast(ingress, reactive(1, struct.pack('<Q', now_ms)), 34)
                drained(ingress)
                last_clock = now_ms
                renewed = now_ms + 28000
                command({'renew': dict(identity=identity, expected=previous, lease_before_ms=renewed)}, control=True)
                leases[identifier] = identity, renewed

    def status(namespace):
        key = (b'\0Uu' + struct.pack('>QQ', int(namespace), 0)).hex()
        for _ in range(3):
            current = query(0, {'resource': requests})['body']['resource']
            try:
                entries = query(0, {'entries': dict(view=None, resource=requests, revision=current['revision'], key=key, after=None)})['body']['entries']['page']['entries']
                return bytes.fromhex(entries[0]['value']) if entries[0] else None
            except AssertionError as error:
                if 'StaleStateResource' not in str(error):
                    raise
        return None

    def wait(predicate, timeout=120):
        until = time.monotonic() + timeout
        while time.monotonic() < until:
            maintain()
            result = predicate()
            if result:
                return result
            time.sleep(.03)
        raise AssertionError('Refresh condition timed out')

    def view(selection):
        return client({'refresh_status': selection})['refresh_status']['view']

    def mutate(operation):
        cast(ingress, submit(operation, env['deadline_ms']), principal)
        drained(ingress)
        wait(lambda: env['read']('status', operation)['stage'] == 'completed')

    cast(ingress, reactive(0, table_watch(env['counter_definition'], application)))
    now = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
    drained(ingress)
    # Independent schema-bound Table declaration and FQP1 plan.
    limits = struct.pack('<QQQ', 100, 100, 1048576)
    source, declaration, bundle = query_bytes(env['counter_definition'], application, limits)
    cast(application, query_policy(env['counter_definition'], application, ingress, requests, principal, limits, revision=1, allow=True))
    drained(application)
    mutate(1)
    digest = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x31425155, len(bundle))).digest()
    for ordinal, offset in enumerate(range(0, len(bundle), 256)):
        part = bundle[offset:offset+256]
        digest = hashlib.sha256(b'\1' + digest + struct.pack('<IH', ordinal, len(part)) + part).digest()
    def complete_template(namespace):
        reference = b'SPF1' + struct.pack('<QIQQII', requests, 2, namespace, 1, 0x31425155, len(bundle)) + digest
        cast(ingress, b'UQB1' + reference, principal)
        drained(ingress)
        for ordinal, offset in enumerate(range(0, len(bundle), 256)):
            part = bundle[offset:offset+256]
            for half in range(0, len(part), 128):
                cast(ingress, b'UQP1' + struct.pack('<QIB', namespace, ordinal, int(half != 0)) + part[half:half+128], principal)
                drained(ingress)
        cast(ingress, b'UQS1' + struct.pack('<Q', namespace), principal)
        drained(ingress)
        cast(ingress, b'UQX1' + struct.pack('<Q', namespace), principal)
        def completed():
            current = status(namespace)
            if current is None: return False
            assert current[76] < 5, ('template terminal failure', current[76], current[85:].hex())
            return current[76] == 4
        wait(completed)

    complete_template(1)
    now = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
    drained(ingress)
    selections = []
    for identifier in (1, 2):
        now = int(time.time() * 1000)
        cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
        drained(ingress)
        generation = command({'open': dict(session=identifier, source_revision=1, lease_before_ms=now + 28000)})
        identity = dict(session=identifier, generation=generation)
        leases[identifier] = identity, now + 28000
        command({'subscribe': dict(identity=identity, expected=0, subscription=1, operation=0)})
        followed = command({'follow': dict(session=identity, expected=0, template='1', limit=2)}, refresh=True, lost=identifier == 1)
        selections.append(dict(session=identity, generation=followed))
        assert view(selections[-1])['starts'] == 0
    mutate(2)
    # Hold source processing while both views become dirty. The durable owner
    # admits only one query; the other remains one coalesced invalidation.
    env['app_worker'].terminate()
    env['app_worker'].wait(timeout=10)
    for selection in selections:
        command({'invalidate': selection}, refresh=True)
    first, second = [view(selection) for selection in selections]
    assert first['phase'] == 'admitted' and second['phase'] == 'idle', (first, second)
    assert int(first['namespace']) >= 2**63
    frozen = first['namespace']
    env['ingress_worker'].terminate()
    env['ingress_worker'].wait(timeout=10)
    for name in ('ingress_config', 'application_config'):
        config = env[name]
        env['send']({'own': dict(pid=config['pid'], expected_generation=config['generation'], worker=config['principal'])})
        config['generation'] += 1
        env['start']('refresh-recovered-' + name, env['example'], config)
    ready_first = wait(lambda: (current if (current := view(selections[0]))['phase'] == 'ready' else None))
    assert ready_first['namespace'] == frozen and ready_first['starts'] == 1
    ready_second = wait(lambda: (current if (current := view(selections[1]))['phase'] == 'ready' else None))
    assert ready_second['starts'] == 1 and ready_second['namespace'] != frozen
    for selection, ready in zip(selections, (ready_first, ready_second)):
        command({'acknowledged': dict(selection=selection, namespace=ready['namespace'])}, refresh=True)
        current = view(selection)
        assert current['covered'] >= current['dirty'] and current['starts'] == 1
    # New data under revoked resource permission must not turn retained proofs
    # into authority. Recovery controls can still release the accepted view.
    mutate(3)
    env['resource_grant'](resource, principal, 1)
    assert query(principal, {'resource': resource})['body']['resource']['id'] == resource
    client({'refresh_status': selections[0]}, 403)
    prepared = client({'refresh_prepare': {'invalidate': selections[0]}})['prepared']
    env['sequences'][principal] = prepared['request']['sequence']
    receipt = client({'submit': prepared})['receipt']['receipt']
    drained(ingress)
    rejected = client({'observe': receipt['position']}, control=True)['observation']
    assert rejected['rejected']['record']['reason'] in ('ServingDenied', 'AccessDenied'), rejected
    assert rejected['rejected']['record']['reason'] == 'AccessDenied', rejected
    denial = rejected['rejected']['diagnostic']
    assert denial['cause'] == 'AccessDenied', denial
    original_facts = {fact['field']: fact['value'] for fact in denial['facts'] if fact}
    assert original_facts['operation'] == {'text': 'source'}, denial
    assert original_facts['actual_resource'] == {'unsigned': str(resource)}, denial
    assert original_facts['principal'] == {'unsigned': str(principal)}, denial
    assert original_facts['native_cause'] == {'text': 'AccessDenied'}, denial
    env['resource_grant'](resource, principal, 3)
    assert client({'observe': receipt['position']}, control=True)['observation'] == rejected
    for selection in selections:
        assert view(selection)['starts'] == 1
        paused_input = command({'pause': selection}, refresh=True, control=True)
        original = client({'refresh_status': selection})['refresh_status']
        assert original['view']['failure']['stopped']['reason'] == 'paused', original
        assert original['view']['failure']['stopped']['input'] == paused_input, original
        assert original['diagnostic']['code'] == 'refresh.paused', original
        assert original['diagnostic']['outcome'] == 'not_applicable', original
        assert original['query_diagnostic'] is None, original
        command({'close': selection['session']}, control=True)
        retained = client({'refresh_status': selection})['refresh_status']
        assert retained['view']['failure'] == original['view']['failure'], retained
        assert retained['diagnostic'] == original['diagnostic'], retained
    for namespace in ('1', frozen, ready_second['namespace']):
        assert status(namespace)[76] == 4
    complete_template(2) # A current template makes the new Follow initially idle.
    # A source-policy rejection is a query outcome, independently retained from
    # the scheduler stop. Restoring policy cannot rewrite either original cause.
    now = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
    drained(ingress)
    generation = command({'open': dict(session=3, source_revision=1, lease_before_ms=now + 28000)})
    identity = dict(session=3, generation=generation)
    leases[3] = identity, now + 28000
    selected = dict(session=identity, generation=command({'follow': dict(session=identity, expected=0, template='2', limit=1)}, refresh=True))
    assert view(selected)['starts'] == 0
    cast(application, query_policy(env['counter_definition'], application, ingress, requests, principal, limits, revision=2, allow=False))
    drained(application)
    mutate(4)
    command({'invalidate': selected}, refresh=True)
    failed = wait(lambda: (value if (value := client({'refresh_status': selected})['refresh_status'])['view']['phase'] == 'denied' else None))
    assert failed['view']['failure']['stopped']['reason'] == 'query_rejected', failed
    assert failed['diagnostic']['code'] == 'refresh.query_rejected', failed
    assert failed['diagnostic']['outcome'] == 'not_applicable', failed
    assert failed['query_diagnostic']['code'] == 'query.policy_denied', failed
    assert failed['query_diagnostic']['outcome'] == 'rejected', failed
    assert failed['query_diagnostic']['identity']['id'] == failed['view']['namespace'], failed
    cast(application, query_policy(env['counter_definition'], application, ingress, requests, principal, limits, revision=3, allow=True))
    drained(application)
    restored = client({'refresh_status': selected})['refresh_status']
    assert restored['diagnostic'] == failed['diagnostic'], restored
    assert restored['query_diagnostic'] == failed['query_diagnostic'], restored
    command({'close': identity}, control=True)
    Path('.cache/verification/m21-refresh-trace.json').write_text(json.dumps(trace))
    print(f'Reactive durable refresh: two shared-principal views, exact lost follow receipt, one admitted query, fair successor, worker replacement, full-width identities and current entry-read denial with metadata still permitted passed in {time.monotonic() - started:.2f}s', flush=True)
