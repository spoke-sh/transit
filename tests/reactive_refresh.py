"""Real durable refresh owner with independent signed controls and query bytes."""
import hashlib
import json
from pathlib import Path
import struct
import time
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
        return client({'refresh_status': selection})['refresh_status']

    def mutate(operation):
        cast(ingress, submit(operation, env['deadline_ms']), principal)
        drained(ingress)
        wait(lambda: env['read']('status', operation)['stage'] == 'completed')

    schema = hashlib.sha256(b'\1\1\2id\5count').digest()
    cast(ingress, reactive(0, struct.pack('<QQQQIB', 0, 1, application, resource, 1, 13) + b'data-progress' + schema + b'\1'))
    now = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
    drained(ingress)
    # Independent Table declaration and FZP1 all-rows plan; no SQL recompile.
    table = b'TBL1\1\2id\5count'
    source = b'UQS1' + struct.pack('<QBI', resource, 2, 1) + bytes([len(table)]) + table
    limits = struct.pack('<QQQ', 100, 100, 1048576)
    declaration = hashlib.sha256(b'transit.query.source.v1\0' + source).digest()
    cast(application, b'UQA1' + struct.pack('<QQQ', ingress, requests, 1) + declaration + b'\1' + limits)
    drained(application)
    mutate(1)
    plan = b'FZP1\0\2\0\1\0' + struct.pack('<Q', 0) + b'\0'
    bundle = b'UQB1' + struct.pack('<HH', len(source), len(plan)) + limits + source + plan
    digest = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x31425155, len(bundle))).digest()
    for ordinal, offset in enumerate(range(0, len(bundle), 256)):
        part = bundle[offset:offset+256]
        digest = hashlib.sha256(b'\1' + digest + struct.pack('<IH', ordinal, len(part)) + part).digest()
    reference = b'SPF1' + struct.pack('<QIQQII', requests, 2, 1, 1, 0x31425155, len(bundle)) + digest
    cast(ingress, b'UQB1' + reference, principal)
    drained(ingress)
    for ordinal, offset in enumerate(range(0, len(bundle), 256)):
        part = bundle[offset:offset+256]
        for half in range(0, len(part), 128):
            cast(ingress, b'UQP1' + struct.pack('<QIB', 1, ordinal, int(half != 0)) + part[half:half+128], principal)
            drained(ingress)
    cast(ingress, b'UQS1' + struct.pack('<Q', 1), principal)
    drained(ingress)
    cast(ingress, b'UQX1' + struct.pack('<Q', 1), principal)
    wait(lambda: (current := status(1)) is not None and current[76] == 4)
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
    assert bytes.fromhex(rejected['rejected']) in (b'ServingDenied', b'AccessDenied'), rejected
    env['resource_grant'](resource, principal, 3)
    for selection in selections:
        assert view(selection)['starts'] == 1
        command({'pause': selection}, refresh=True, control=True)
        command({'close': selection['session']}, control=True)
    for namespace in ('1', frozen, ready_second['namespace']):
        assert status(namespace)[76] == 4
    Path('.cache/verification/m21-refresh-trace.json').write_text(json.dumps(trace))
    print(f'Reactive durable refresh: two shared-principal views, exact lost follow receipt, one admitted query, fair successor, worker replacement, full-width identities and current entry-read denial with metadata still permitted passed in {time.monotonic() - started:.2f}s', flush=True)
