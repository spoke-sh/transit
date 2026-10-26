"""Independent peer of the Zig private caller adapter; no browser signing code."""
import hashlib
import json
from pathlib import Path
import struct
import time
from interfaces.http.serving_table import watch as table_watch
from interfaces.reactive.reactive import reactive, SSE
from interfaces.http.serving import post, policy, submit


def run(env, tls):
    start = time.monotonic()
    port, host = env['gateway_ports'][0], env['public_host']
    ingress, application = env['ingress'], env['application']
    cast, drained = env['cast'], env['drained']
    principal = 65536
    trace = []
    def client(operation, expected=200, control=False):
        value = post(port, '/reactive/v1/client' + ('/control' if control else ''), operation, host, expected, {'Origin': 'https://' + host})
        if expected == 200:
            trace.extend([dict(type='HostRequest', value=operation), dict(type='HostResponse', value=value)])
        return value
    cast(ingress, reactive(0, table_watch(env['counter_definition'], application)))
    now = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
    drained(ingress)
    description = client({'describe': {}})['description']
    assert description['connection'] == dict(realm=49, principal=principal, service=1, ingress=ingress, role=None)
    assert client({'clock': {}}, control=True)['clock']['observed_ms'] == now
    post(port, '/reactive/v1/client', {'describe': {}}, host, 403)
    client({'prepare': {'observe_clock': now}}, 400)
    client({'describe': {}}, 400, True)
    def command(value, lost=False, control=False):
        prepared = client({'prepare': value}, control=control)['prepared']
        env['sequences'][principal] = prepared['request']['sequence']
        if lost:
            env['fault']['armed'] = True
            lost_response = client({'submit': prepared}, 503, control)
            detail = lost_response['diagnostic']
            assert detail['code'] == 'serving.send_unknown' and detail['outcome'] == 'unknown', detail
            assert detail['evidence'] == 'saved_intent', detail
            assert detail['identity']['id'] == str(prepared['request']['sequence']), detail
            assert detail['identity']['sequence'] == str(prepared['request']['sequence']), detail
            assert env['fault']['lost']
        receipt = client({'submit': prepared}, control=control)['receipt']['receipt']
        assert client({'submit': prepared}, control=control)['receipt']['receipt'] == receipt
        drained(ingress)
        assert client({'observe': prepared}, control=True)['observation'] == {'committed': {}}
        return receipt['position']
    generation = command({'open': dict(session=11, source_revision=1, lease_before_ms=now + 28000)}, lost=True)
    subscription = command({'subscribe': dict(identity=dict(session=11, generation=generation), expected=0, subscription=3, operation=0)})
    scope = description['connection'] | dict(session=11, generation=generation, subscription=3, subscription_generation=subscription)
    request = dict(scope=scope, kind='session', attachment=0, nonce=[0] * 16, cursor=None)
    signed = client({'sign_read': request})['signed_read']
    challenge = post(port, '/reactive/v1/challenge', signed, host)['challenge']['nonce']
    attach = client({'prepare': {'attach': dict(identity=dict(session=11, generation=generation), expected=0, nonce=challenge)}})['prepared']
    env['sequences'][principal] = attach['request']['sequence']
    request.update(kind='events', attachment=1, nonce=challenge)
    signed = client({'sign_read': request})['signed_read']
    with_stream = SSE(port, host, tls, dict(version=1, attach=attach, read=signed))
    try:
        with_stream.until('attached')
        first = with_stream.until('event')
        request['cursor'] = first['cursor']
        result = client({'inspect': request})['inspection']
        assert result['response']['snapshot'] is None
        assert result['observation']['basis']['cut']['resource'] == env['application_resource']
        assert client({'covered': dict(observation=result['observation'], captured=result['observation']['basis'])}) == {'covered': True}
        foreign = result['observation']['basis'] | dict(cut=result['observation']['basis']['cut'] | dict(resource=1))
        assert client({'covered': dict(observation=result['observation'], captured=foreign)}) == {'covered': False}
        client({'sign_read': request | dict(kind='snapshot', cursor=None)}, 403)
        client({'sign_read': request | dict(scope=scope | dict(principal=65537))}, 403)
        cast(ingress, submit(77, env['deadline_ms']), principal)
        drained(ingress); drained(application)
        changed = with_stream.until('event')
        assert changed['cursor']['position']['data_revision'] > first['cursor']['position']['data_revision']
        # Pausing has its own exact control and does not cancel the application.
        command({'close': dict(session=11, generation=generation)}, control=True)
        terminal = with_stream.until('terminal')
        assert terminal['reason'] == 'closed', terminal
        assert terminal['diagnostic']['code'] == 'reactive.session_closed', terminal
        assert terminal['diagnostic']['outcome'] == 'not_applicable', terminal
        assert terminal['diagnostic']['stage'] == 'read', terminal
    finally:
        with_stream.close()
    prepared = client({'prepare': {'renew': dict(identity=dict(session=11, generation=generation), expected=now + 28000, lease_before_ms=now + 29000)}}, control=True)['prepared']
    env['sequences'][principal] = prepared['request']['sequence']
    rejected_input = client({'submit': prepared}, control=True)['receipt']['receipt']['position']
    drained(ingress)
    rejected = client({'observe': prepared}, control=True)['observation']['rejected']
    assert rejected['record']['reason'] == 'ReactiveSessionClosed', rejected
    assert rejected['record']['payload'] == list(hashlib.sha256(b'transit.serving.input.v1\0' + bytes.fromhex(prepared['request']['command']['send']['value'])).digest()), rejected
    detail = rejected['diagnostic']
    assert detail['code'] == 'reactive.session_closed' and detail['outcome'] == 'input_rejected', detail
    facts = {fact['field']: fact for fact in detail['facts'] if fact}
    assert facts['operation']['value'] == {'text': 'closed'}, facts
    assert facts['observed_clock']['availability'] == 'unrecorded', facts
    assert client({'observe': prepared}, control=True)['observation']['rejected'] == rejected
    cast(ingress, policy(principal, revision=2, reads=False))
    drained(ingress)
    client({'describe': {}}, 403)
    client({'clock': {}}, 403, True)
    Path('.cache/verification/m21-client-trace.json').write_text(json.dumps(trace))
    print(f'Reactive shared client: Zig preparation, exact lost-reply retry, committed controls, private Origin, metadata-only watch/coverage, reserved close and denial passed in {time.monotonic() - start:.2f}s', flush=True)
