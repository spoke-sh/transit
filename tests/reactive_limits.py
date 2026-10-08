"""Bounded independent peers: capacity, malformed frames, cursors and hard expiry."""
import copy
import hashlib
from http.client import HTTPSConnection
from pathlib import Path
import struct
import time

import serving
from reactive import SSE, WebSocket, cursor_bytes, reactive, signed_read
from serving_table import bootstrap as bootstrap_counter, watch as table_watch


def run(env, tls, previous):
    start = time.monotonic()
    port, alternate = env['gateway_ports']
    host, ingress = env['public_host'], env['ingress']
    keys, sequences = env['keys'], env['sequences']
    cast, drained = env['cast'], env['drained']

    def command(payload, principal=65536):
        result = cast(ingress, payload, principal)
        drained(ingress)
        return result

    def close(scope):
        command(reactive(7, struct.pack('<QQ', scope['session'], scope['generation'])), scope['principal'])

    close(previous)

    def observe():
        now = int(time.time() * 1000)
        command(reactive(1, struct.pack('<Q', now)), 34)
        return now

    def open_session(principal, session, revision=1, duration=28000):
        now = observe()
        generation = command(reactive(2, struct.pack('<QQQ', session, revision, now + duration)), principal)
        subscription = command(reactive(4, struct.pack('<QQQQQ', session, generation, 0, 1, 0)), principal)
        scope = dict(realm=49, principal=principal, service=1, ingress=ingress, session=session, generation=generation, subscription=1, subscription_generation=subscription)
        return dict(scope=scope, attachment=0, nonce=None)

    def read(state, kind='session', cursor=None, expected=200):
        scope = state['scope']
        return serving.post(alternate, '/reactive/v1/read', signed_read(keys[scope['principal']], scope, kind, state['attachment'], state['nonce'], cursor), host, expected)

    def signed_command(state, payload):
        principal = state['scope']['principal']
        sequences[principal] += 1
        return serving.native_command(keys[principal], principal, sequences[principal], {'send': dict(pid=ingress, value=serving.frame(payload))})

    def bootstrap(state, nonce, cursor=None):
        scope = state['scope']
        payload = reactive(3, struct.pack('<QQQ', scope['session'], scope['generation'], state['attachment']) + bytes(nonce))
        state['attachment'] += 1
        state['nonce'] = nonce
        return dict(version=1, attach=signed_command(state, payload), read=signed_read(keys[scope['principal']], scope, 'events', state['attachment'], nonce, cursor))

    def attach_sse(state):
        scope = state['scope']
        challenge = serving.post(port, '/reactive/v1/challenge', signed_read(keys[scope['principal']], scope), host)['challenge']
        stream = SSE(port, host, tls, bootstrap(state, challenge['nonce']))
        stream.until('attached')
        return stream

    def attach_ws(state):
        peer = WebSocket(port, host, tls)
        challenge = peer.until('challenge')
        peer.send({'attach': bootstrap(state, challenge['nonce'])})
        peer.until('attached')
        return peer

    def renew(state):
        now = observe()
        old = read(state)['session']['lease_before_ms']
        scope = state['scope']
        payload = reactive(5, struct.pack('<QQQQ', scope['session'], scope['generation'], old, now + 29000))
        message = signed_command(state, payload)
        serving.post(port, '/reactive/v1/control', message, host, 202)
        drained(ingress)
        assert read(state)['session']['lease_before_ms'] == now + 29000

    states = [open_session(principal, session) for principal, session in ((65536, 20), (65536, 21), (65537, 20), (65537, 21))]
    refused = command(reactive(2, struct.pack('<QQQ', 22, 1, int(time.time() * 1000) + 20000)))
    disposition = serving.post(alternate, '/serving/v1/read', serving.signed_read(keys[65536], 65536, ingress, 'disposition', refused), host)
    assert disposition['disposition']['record']['reason'] == 'ReactiveCapacity'
    detail = disposition['disposition']['diagnostic']
    assert detail['code'] == 'reactive.active_limit' and detail['outcome'] == 'input_rejected', detail
    facts = {fact['field']: fact['value'] for fact in detail['facts'] if fact}
    assert facts['actual_count'] == {'unsigned': '4'} and facts['limit'] == {'unsigned': '4'}, facts
    streams = [attach_sse(state) for state in states]
    for stream in streams: stream.until('event')
    serving.post(port, '/reactive/v1/read', signed_read(keys[65536], states[0]['scope']), host, 503)
    started = time.monotonic()
    health = HTTPSConnection('127.0.0.1', tls[port].port, context=tls[port].context, timeout=3)
    health.request('GET', '/health', headers={'Host': host})
    response = health.getresponse()
    assert response.status == 200
    response.read(); health.close()
    latency = time.monotonic() - started
    assert latency < 2
    renew(states[0])  # All four data handlers remain occupied.
    env['grant'](65537, 4, ingress)
    for stream in streams[2:]:
        assert stream.until('terminal')['reason'] == 'denied'
        stream.close()
    env['grant'](65537, 20, ingress)
    for stream in streams[:2]: stream.close()
    for state in states[1:]: close(state['scope'])
    state = states[0]
    time.sleep(.6)

    # Correct gateway signatures do not authorize future, foreign or incompatible positions.
    peer = attach_ws(state)
    cursor = peer.until('event')['cursor']
    peer.close()
    for field, value, expected in (('data_revision', cursor['position']['data_revision'] + 1, 400), ('outcome_position', 900, 400), ('watch_revision', 2, 409), ('schema', [17] * 32, 409), ('scope', dict(state['scope'], subscription=99), 400)):
        altered = copy.deepcopy(cursor)
        altered['position'][field] = value
        encoded = b'SV1E' + cursor_bytes(altered)[4:-64]
        altered['signature'] = keys[79].sign(hashlib.sha256(b'transit.reactive.cursor.v1\0' + encoded).digest())
        read(state, 'events', altered, expected)

    renew(state)
    peer = attach_ws(state)
    message = {'read': signed_read(keys[65536], state['scope'], 'snapshot', state['attachment'], state['nonce'])}
    # Escaped member names have the same decoded meaning; signature semantics
    # stay in the shared canonical owner, rather than raw JSON spelling.
    encoded = serving.compact(message).replace(b'"read":', b'"r\\u0065ad":', 1)
    peer.send_frame(encoded[:13], fin=False)
    peer.send_frame(encoded[13:], opcode=0)
    assert peer.until('observation')['snapshot'] is not None
    peer.send_frame(b'\x03\xe8', opcode=8)
    while peer.receive()[0] != 8: pass
    peer.close()

    # Actual wire failures, beyond the deterministic RFC frame tests.
    cases = [(dict(payload=b'{}', masked=False), 1002), (dict(payload=b'\xff'), 1007), (dict(payload=b'\x00', opcode=2), 1003), (dict(oversized=True), 1009), (dict(payload=b'\x03', opcode=8), 1002)]
    for args, expected in cases:
        peer = attach_ws(state)
        if args.get('oversized'):
            # Reject the declared length before waiting for/allocating payload.
            peer.socket.sendall(b'\x81\xfe' + struct.pack('>H', 8193) + b'abcd')
        else:
            peer.send_frame(**args)
        while True:
            opcode, value = peer.receive()
            if opcode == 8:
                assert struct.unpack('>H', value[:2])[0] == expected, (expected, value)
                break
        peer.close()
    renew(state)
    # Bounded reconnect churn and slow/non-reading peers. A second principal's
    # health/control work was already proved under the full data pool above.
    for _ in range(12):
        peer = attach_ws(state)
        peer.close()
    rss = sum(int(next(line.split()[1] for line in Path(f'/proc/{process.pid}/status').read_text().splitlines() if line.startswith('VmRSS:'))) * 1024 for process in env['gateways'])
    assert rss <= 256 * 1024 * 1024, rss
    close(state['scope'])
    time.sleep(.6)

    # An unavailable timer observer cannot extend an idle attachment's lease.
    finite = open_session(65536, 30, duration=10000)
    stream = attach_sse(finite)
    stream.until('event')
    assert stream.until('terminal')['reason'] == 'expired'
    stream.close()
    read(finite, 'snapshot', expected=410)
    assert read(finite)['session']['phase'] == 'open'  # No observer changed history.
    close(finite['scope'])

    # The current source grant is checked even for an idle, already attached peer.
    state = open_session(65536, 31)
    stream = attach_sse(state)
    stream.until('event')
    env['resource_grant'](env['application_resource'], 79, 0)
    assert stream.until('terminal')['reason'] == 'denied'
    stream.close()
    env['resource_grant'](env['application_resource'], 79, 3)
    close(state['scope'])

    # A separately owned finite source expires without any observer notification.
    expires = int(time.time() * 1000) + 18000
    application, resource = env['provision'](78, expires)
    config = dict(env['application_config'], pid=application, generation=2)
    worker = env['start']('reactive-finite-source', env['example'], config)
    cast(application, b''); drained(application)
    env['resource_grant'](resource, 33, 3)
    env['resource_grant'](resource, 79, 3)
    env['courier_worker'].kill(); env['courier_worker'].wait(timeout=10)
    courier_config = copy.deepcopy(env['courier_config'])
    courier_config['role']['courier']['destinations'].append(application)
    env['courier_worker'] = env['start']('reactive-finite-courier', env['courier'], courier_config)
    root = env['store'].root / 'finite-source'
    root.mkdir()
    definition = bootstrap_counter(env['cli'], root, env['url'], serving.REALM, application, resource, keys[33], cast, drained, env['query'], sequences, readers=(65536,))
    worker.kill(); worker.wait(timeout=10)
    command(serving.publication(2, application, env['deadline_ms']), 33)
    command(reactive(0, table_watch(definition, application, expected=1, revision=2)), 33)
    finite = open_session(65536, 32, revision=2)
    stream = attach_sse(finite)
    stream.until('event')
    terminal = stream.until('terminal')['reason']
    assert terminal in ('expired', 'interrupted'), terminal
    stream.close()
    until = time.monotonic() + 12
    while True:
        status, value = read(finite, 'snapshot', expected=None)
        if status == 410: break
        assert status == 503 and time.monotonic() < until, (status, value)
        time.sleep(.1)
    session = read(finite)['session']
    assert session['phase'] == 'open' and session['lease_before_ms'] > int(time.time() * 1000) + 1000, session
    print(f'Reactive limits: four durable sessions/four held streams, reserved renewal and health {latency:.3f}s, idle revocation, signed cursor rejection, malformed frames, 12 reconnects, absent observer lease/source expiry; two-gateway RSS {rss} bytes <= 268435456; {time.monotonic() - start:.2f}s', flush=True)
