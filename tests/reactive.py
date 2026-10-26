"""Independent HTTP/SSE and RFC 6455 peers for the shared reactive owner."""
import base64
import hashlib
from http.client import HTTPConnection, HTTPSConnection
import json
import os
from pathlib import Path
import socket
import struct
import time
from serving_table import authorize, watch as table_watch

import serving
from serving import compact, frame, native_command, native_query, post, submit

TRACE = []


def cursor_bytes(cursor):
    value = cursor['position']
    scope = value['scope']
    return (b'SV1K' + bytes([value['version']]) + struct.pack('<8Q', *scope.values())
            + struct.pack('<QQ', value['watch_revision'], value['resource']) + bytes(value['schema'])
            + struct.pack('<QQ', int(value['data_revision']), value['outcome_position']) + bytes(cursor['signature']))


def signed_read(key, scope, kind='session', attachment=0, nonce=None, cursor=None):
    nonce = nonce or [0] * 16
    value = dict(scope=scope, kind=kind, attachment=attachment, nonce=nonce, cursor=cursor)
    encoded = (b'SV1U' + struct.pack('<8Q', *scope.values()) + bytes([{'session': 1, 'snapshot': 2, 'events': 3}[kind]])
               + struct.pack('<Q', attachment) + bytes(nonce) + bytes([cursor is not None]))
    if cursor: encoded += cursor_bytes(cursor)
    return dict(read=value, proof=serving.subject_proof(key, scope['principal'], scope['ingress'], hashlib.sha256(b'transit.reactive.read.v1\0' + encoded).digest()))


def reactive(tag, payload):
    return b'SV1c\x05' + bytes([tag]) + payload


class WebSocket:
    def __init__(self, port, host, tls, headers=None, expected=101, timeout=5):
        self.socket = socket.create_connection(('127.0.0.1', tls[port].port if port in tls else port), timeout=timeout)
        if port in tls: self.socket = tls[port].context.wrap_socket(self.socket, server_hostname='127.0.0.1')
        key = base64.b64encode(os.urandom(16)).decode()
        fields = dict(Host=host, Origin='https://' + host, Upgrade='websocket', Connection='Upgrade', **{'Sec-WebSocket-Key': key, 'Sec-WebSocket-Version': '13', 'Sec-WebSocket-Protocol': 'transit.reactive.v1', 'Sec-WebSocket-Extensions': 'permessage-deflate'})
        fields.update(headers or {})
        self.socket.sendall(('GET /reactive/v1/websocket HTTP/1.1\r\n' + ''.join(f'{k}: {v}\r\n' for k, v in fields.items()) + '\r\n').encode())
        head = bytearray()
        while not head.endswith(b'\r\n\r\n'):
            byte = self.socket.recv(1)
            if not byte: raise EOFError('upgrade interrupted')
            head += byte
        assert int(head.split()[1]) == expected, head
        if expected != 101: return
        response = dict((line.split(b': ', 1)[0].lower(), line.split(b': ', 1)[1]) for line in bytes(head).split(b'\r\n')[1:] if b':' in line)
        assert response[b'sec-websocket-protocol'] == b'transit.reactive.v1'
        assert response[b'sec-websocket-accept'] == base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
        assert b'sec-websocket-extensions' not in response

    def exact(self, length):
        data = bytearray()
        while len(data) < length:
            part = self.socket.recv(length - len(data))
            if not part: raise EOFError('interrupted WebSocket')
            data += part
        return bytes(data)

    def receive(self):
        h0, h1 = self.exact(2)
        assert h0 & 0xf0 == 0x80 and h1 & 0x80 == 0
        size = h1 & 127
        if size == 126: size = struct.unpack('>H', self.exact(2))[0]
        elif size == 127: size = struct.unpack('>Q', self.exact(8))[0]
        assert size <= 8192
        data = self.exact(size)
        value = json.loads(data) if h0 & 15 == 1 else data
        if h0 & 15 == 1: TRACE.append(dict(type='ServerMessage', value=value))
        return h0 & 15, value

    def until(self, kind):
        for _ in range(64):
            opcode, value = self.receive()
            if opcode == 1 and kind in value: return value[kind]
            assert opcode != 8, ('closed before', kind, value)
            assert opcode != 1 or 'terminal' not in value, value
        raise AssertionError(('message absent', kind))

    def send_frame(self, payload, opcode=1, fin=True, masked=True, rsv=0):
        mask = os.urandom(4)
        size = len(payload)
        prefix = bytes([(128 if fin else 0) | rsv | opcode, (128 if masked else 0) | (size if size < 126 else 126)])
        if size >= 126: prefix += struct.pack('>H', size)
        if masked: prefix += mask; payload = bytes(v ^ mask[i % 4] for i, v in enumerate(payload))
        self.socket.sendall(prefix + payload)

    def send(self, value):
        TRACE.append(dict(type='ClientMessage', value=value))
        self.send_frame(compact(value))

    def close(self):
        self.socket.close()


class SSE:
    def __init__(self, port, host, tls, bootstrap, origin=None, timeout=5):
        headers = {'Host': host, 'Origin': origin or 'https://' + host, 'Content-Type': 'application/json'}
        cursor = bootstrap['read']['read']['cursor']
        if cursor: headers['Last-Event-ID'] = cursor_bytes(cursor).hex()
        encoded = compact(bootstrap)
        deadline = time.monotonic() + 10
        while True:
            self.connection = HTTPSConnection('127.0.0.1', tls[port].port, context=tls[port].context, timeout=timeout) if port in tls else HTTPConnection('127.0.0.1', port, timeout=timeout)
            self.connection.request('POST', '/reactive/v1/events', encoded, headers)
            self.response = self.connection.getresponse()
            if self.response.status != 503 or time.monotonic() >= deadline: break
            self.response.read()
            self.connection.close()
            # Retry the identical signed attachment after bounded capacity loss.
            time.sleep(.05)
        assert self.response.status == 200, (self.response.status, self.response.read())
        assert self.response.headers['Content-Type'].startswith('text/event-stream')

    def receive(self):
        fields = {}
        while True:
            # Exercise an independent incremental line parser over one-byte reads.
            line = bytearray()
            while not line.endswith(b'\n'):
                byte = self.response.read(1)
                if not byte: raise EOFError('interrupted SSE')
                line += byte
                assert len(line) <= 9000
            if line == b'\n' and fields:
                message = json.loads(fields['data'])
                TRACE.append(dict(type='SseItem', value=fields))
                TRACE.append(dict(type='ServerMessage', value=message))
                assert fields['event'] in message
                if fields['event'] == 'event': assert fields['id'] == cursor_bytes(message['event']['cursor']).hex()
                return message
            if b':' in line:
                name, value = line[:-1].split(b':', 1)
                fields[name.decode()] = value.lstrip(b' ').decode('utf-8')

    def until(self, kind):
        for _ in range(64):
            value = self.receive()
            if kind in value: return value[kind]
            assert 'terminal' not in value, value
        raise AssertionError(('event absent', kind))

    def close(self):
        self.response.close()
        self.connection.close()


def run_trace(env, tls):
    serving.TLS = tls
    start = time.monotonic()
    TRACE.clear()
    keys, sequences = env['keys'], env['sequences']
    cast, drained = env['cast'], env['drained']
    ingress, application = env['ingress'], env['application']
    port, alternate = env['gateway_ports']
    host = env['public_host']
    principal = 65536
    key = keys[principal]
    cast(ingress, reactive(0, table_watch(env['counter_definition'], application)))
    now = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
    generation = cast(ingress, reactive(2, struct.pack('<QQQ', 7, 1, now + 28000)), principal)
    subscription_generation = cast(ingress, reactive(4, struct.pack('<QQQQQ', 7, generation, 0, 3, 1)), principal)
    drained(ingress)
    scope = dict(realm=49, principal=principal, service=1, ingress=ingress, session=7, generation=generation, subscription=3, subscription_generation=subscription_generation)
    state = post(port, '/reactive/v1/read', signed_read(key, scope), host)
    assert state['session']['phase'] == 'open', state

    def bootstrap(nonce, attachment, cursor=None):
        payload = reactive(3, struct.pack('<QQQ', 7, generation, attachment - 1) + bytes(nonce))
        signed = native_command(key, principal, sequences[principal] + 1, {'send': dict(pid=ingress, value=frame(payload))})
        sequences[principal] += 1
        return dict(version=1, attach=signed, read=signed_read(key, scope, 'events', attachment, nonce, cursor))

    peer = WebSocket(port, host, tls)
    try:
        challenge = peer.until('challenge')
        request = bootstrap(challenge['nonce'], 1)
        peer.send({'attach': request})
        assert peer.until('attached')['attachment'] == 1
        first = peer.until('event')
        snapshot = post(alternate, '/reactive/v1/read', signed_read(key, scope, 'snapshot', 1, challenge['nonce']), host)
        assert snapshot['snapshot']['observation']['data_revision'] == first['cursor']['position']['data_revision']
        TRACE.append(dict(type='ReactiveResponse', value=snapshot))
        assert all(row is None for row in snapshot['snapshot']['rows'])
        # Accepted bytes have one identity even if this socket disappears before
        # its receipt. HTTP fallback never generates a replacement operation.
        command = native_command(key, principal, sequences[principal] + 1, {'send': dict(pid=ingress, value=frame(submit(1, env['deadline_ms'])))})
        sequences[principal] += 1
        peer.send({'command': command})
    finally:
        peer.close()
    receipt = post(alternate, '/serving/v1/command', command, host, 202)
    assert post(port, '/serving/v1/command', command, host, 202) == receipt
    until = time.monotonic() + 10
    while True:
        status, response = post(port, '/serving/v1/read', serving.signed_read(key, principal, ingress, 'status', 1), host, None)
        if status == 200 and response['stage'] == 'completed': break
        assert status in (200, 404, 409, 503, 504), (status, response)
        assert time.monotonic() < until, response
        time.sleep(.05)
    assert struct.unpack('<q', bytes.fromhex(response['operation']['result']))[0] == 1
    challenge = post(alternate, '/reactive/v1/challenge', signed_read(key, scope), host)['challenge']
    replacement = bootstrap(challenge['nonce'], 2, first['cursor'])
    stream = SSE(alternate, host, tls, replacement)
    try:
        assert stream.until('attached')['attachment'] == 2
        changed = stream.until('event')
        assert changed['event']['source_changed'] and changed['event']['outcome']['operation'] == 1, changed
        outcome = changed['event']['outcome']
        assert outcome['diagnostic'] == response['diagnostic'], outcome
        assert outcome['diagnostic']['code'] == 'serving.reply_recorded' and outcome['diagnostic']['outcome'] == 'completed', outcome
        assert str(outcome['resource']) == outcome['diagnostic']['identity']['resource'], outcome
        assert int(changed['cursor']['position']['data_revision']) > int(first['cursor']['position']['data_revision'])
        post(port, '/reactive/v1/read', request['read'], host, 409)
        # Consume-once challenge cannot reattach a second live socket.
        post(alternate, '/reactive/v1/events', replacement, host, 403)
        snapshot = post(port, '/reactive/v1/read', signed_read(key, scope, 'snapshot', 2, challenge['nonce']), host)
        TRACE.append(dict(type='ReactiveResponse', value=snapshot))
        assert snapshot['snapshot']['rows'][0]['value'] == '1'
        assert stream.until('heartbeat') == {'version': 1}
    finally:
        stream.close()
    adversarial(env, tls, scope, bootstrap, 2, changed['cursor'], command, receipt)
    if env['reactive_browser']: scope = browser(env, tls, scope)
    if env['reactive_limits']:
        from reactive_limits import run
        run(env, tls, scope)
    target = Path(__file__).resolve().parents[1] / '.cache/verification/m20-reactive-trace.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(TRACE))
    print(f'Reactive initial trace: empty snapshot, Table progress/outcome, WebSocket-to-HTTP exact retry, SSE cursor resume and attachment fencing passed in {time.monotonic() - start:.2f}s', flush=True)


def adversarial(env, tls, scope, bootstrap, attachment, cursor, command, original_receipt):
    keys, sequences = env['keys'], env['sequences']
    cast, drained, send = env['cast'], env['drained'], env['send']
    port, alternate = env['gateway_ports']
    host, ingress = env['public_host'], env['ingress']
    principal, key = scope['principal'], keys[scope['principal']]
    # Bootstrap uses Origin and protocol negotiation but neither is a credential.
    for headers, status in (({'Origin': 'https://foreign.example.test'}, 403), ({'Sec-WebSocket-Version': '12'}, 400), ({'Sec-WebSocket-Protocol': 'unsupported'}, 400), ({'Sec-WebSocket-Key': 'not-a-nonce'}, 400)):
        peer = WebSocket(port, host, tls, headers, status)
        peer.close()
    peer = WebSocket(port, host, tls)
    peer.until('challenge')
    started = time.monotonic()
    terminal = peer.until('terminal')
    assert terminal['reason'] == 'interrupted', terminal
    diagnostic = terminal['diagnostic']
    assert diagnostic['code'] == 'reactive.challenge_timeout', diagnostic
    assert diagnostic['outcome'] == 'not_submitted', diagnostic
    assert diagnostic['evidence'] == 'local_before_dispatch', diagnostic
    assert diagnostic['identity'] is None, diagnostic
    assert peer.receive()[0] == 8
    assert time.monotonic() - started < 3
    peer.close()

    def renew():
        now = int(time.time() * 1000)
        cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
        drained(ingress)
        observed = post(alternate, '/reactive/v1/read', signed_read(key, scope), host)['session']
        renewal = native_command(key, principal, sequences[principal] + 1, {'send': dict(pid=ingress, value=frame(reactive(5, struct.pack('<QQQQ', scope['session'], scope['generation'], observed['lease_before_ms'], now + 28000))))})
        sequences[principal] += 1
        post(alternate, '/reactive/v1/control', renewal, host, 202)
        drained(ingress)

    renew()
    # Reconnect with an unchanged cursor: no manufactured invalidation. Upgrade
    # offers compression, but using RSV1 still fails because it was declined.
    peer = WebSocket(port, host, tls)
    challenge = peer.until('challenge')
    attachment += 1
    request = bootstrap(challenge['nonce'], attachment, cursor)
    encoded = compact({'attach': request})
    # Independent client fragmentation with a control frame interleaved.
    peer.send_frame(encoded[:17], fin=False)
    peer.send_frame(b'bootstrap-ping', opcode=9)
    peer.send_frame(encoded[17:], opcode=0)
    assert peer.until('attached')['attachment'] == attachment
    assert peer.until('heartbeat') == {'version': 1}
    peer.send_frame(b'{}', rsv=64)
    while True:
        opcode, value = peer.receive()
        if opcode == 8:
            assert struct.unpack('>H', value[:2])[0] == 1002
            break
    peer.close()

    # Idle native authority revocation fences a live attachment without a client
    # message. A TCP heartbeat or a pong cannot bypass the current check.
    peer = WebSocket(port, host, tls)
    challenge = peer.until('challenge')
    attachment += 1
    request = bootstrap(challenge['nonce'], attachment, cursor)
    peer.send({'attach': request})
    peer.until('attached')
    env['grant'](principal, 4, ingress)
    assert peer.until('terminal')['reason'] == 'denied'
    peer.close()
    env['grant'](principal, 20, ingress)
    # Native re-provisioning retires the old private role. Restoring process
    # permissions does not restore that role's database/schema/Table grants.
    post(alternate, '/reactive/v1/read', signed_read(key, scope, 'snapshot', attachment, challenge['nonce']), host, 403)
    role = env['query'](principal, {'authorization': dict(role=None, kind={'identity': {}})})['body']['authorization']['body']['identity']['login_role']
    catalog_authority = env['catalog_authority']['catalog']['authority']
    for target in (catalog_authority['database'], catalog_authority['initial_schema_authority'], int(env['counter_definition']['authorization'])):
        authorize(send, env['query'], {'grant': dict(object=dict(kind='domain', id=target), grantee=role, privileges=1, grant_options=0)})
    renew()

    # Losing every worker/gateway/node process preserves the logical session and
    # source position. The native node owns the local WAL and objects; its
    # replacement reopens the same directory and original command receipt.
    node_config = json.loads(env['configuration'].read_text())
    assert Path(node_config['local_directory']).is_dir()
    for process in (*env['gateways'], env['ingress_worker'], env['app_worker'], env['courier_worker'], env['authority']):
        process.kill(); process.wait(timeout=10)
    authority = env['start']('reactive-node-recovered', env['node'], node_config)
    serving.wait_ready(env['store'].http, authority, env['url'] + '/health')
    for config in (env['ingress_config'], env['application_config']):
        send({'own': dict(pid=config['pid'], expected_generation=2, worker=config['principal'])})
        config['generation'] = 3
    env['start']('reactive-ingress-recovered', env['example'], env['ingress_config'])
    env['start']('reactive-application-recovered', env['example'], env['application_config'])
    env['courier_worker'] = env['start']('reactive-courier-recovered', env['courier'], env['courier_config'])
    for index, gateway_port in enumerate(env['gateway_ports']):
        env['gateway_config']['role']['gateway']['port'] = gateway_port
        env['gateways'][index] = env['start'](f'reactive-gateway-recovered-{index}', env['example'], env['gateway_config'])
    time.sleep(.4)
    assert post(port, '/serving/v1/command', command, host, 202) == original_receipt
    assert post(port, '/reactive/v1/read', signed_read(key, scope), host)['session']['generation'] == scope['generation']
    challenge = post(port, '/reactive/v1/challenge', signed_read(key, scope), host)['challenge']
    attachment += 1
    request = bootstrap(challenge['nonce'], attachment, cursor)
    stream = SSE(port, host, tls, request)
    stream.until('attached')
    assert stream.until('heartbeat') == {'version': 1}
    cast(ingress, serving.policy(principal, revision=2, reads=False))
    drained(ingress)
    assert stream.until('terminal')['reason'] == 'denied'
    stream.close()
    cast(ingress, serving.policy(principal, revision=3))
    drained(ingress)
    # Scoped signed cursors still require signature integrity; future positions
    # and foreign subscriptions never become authority after gateway restart.
    forged = json.loads(json.dumps(cursor)); forged['position']['data_revision'] = str(int(forged['position']['data_revision']) + 1)
    post(alternate, '/reactive/v1/read', signed_read(key, scope, 'events', attachment, challenge['nonce'], forged), host, 403)
    print('Reactive adversarial trace: upgrade rejection, bounded unauthenticated bootstrap, fragmented authentication with ping, declined compression, idle native/service revocation and gateway/worker/native-local-node recovery passed', flush=True)


def browser(env, tls, old_scope):
    import subprocess
    key = env['keys'][65536]
    cast, drained = env['cast'], env['drained']
    ingress = env['ingress']
    cast(ingress, reactive(7, struct.pack('<QQ', old_scope['session'], old_scope['generation'])), 65536)
    now = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', now)), 34)
    generation = cast(ingress, reactive(2, struct.pack('<QQQ', 8, 1, now + 28000)), 65536)
    subscription = cast(ingress, reactive(4, struct.pack('<QQQQQ', 8, generation, 0, 4, 10)), 65536)
    drained(ingress)
    scope = dict(realm=49, principal=65536, service=1, ingress=ingress, session=8, generation=generation, subscription=4, subscription_generation=subscription)
    certificate = tls[env['gateway_ports'][0]].root / 'certificate.pem'
    public_pem = subprocess.check_output(['openssl', 'x509', '-in', str(certificate), '-pubkey', '-noout'])
    public_der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'DER'], input=public_pem)
    spki = base64.b64encode(hashlib.sha256(public_der).digest()).decode()
    config = env['store'].root / 'browser.json'
    definition = native_query(key, scope['principal'], {'identity': {}})['query']['definition']
    credential = env['query'](scope['principal'], {'authorization': dict(role=None, kind={'identity': {}})})['body']['authorization']['body']['identity']
    config.write_text(json.dumps(dict(origin='https://' + env['public_host'], definition=definition, scope=scope, credential_epoch=credential['credential_epoch'], sequence=env['sequences'][65536], private_key=str(key.path), deadline=env['deadline_ms'], spki=spki)))
    config.chmod(0o600)
    completed = subprocess.run(['vp', 'exec', '--filter', '@transit/board-web', 'node', 'browser/reactive.mjs', str(config)], capture_output=True, text=True, timeout=45)
    assert completed.returncode == 0, (completed.stdout, completed.stderr)
    result = json.loads(completed.stdout.strip().splitlines()[-1])
    env['sequences'][65536] = result['sequence']
    assert result['websocket'] and result['sse'] and result['fallback'] and result['discovery']
    print('Reactive browser: actual Chromium WebCrypto, same-origin TLS WebSocket bootstrap, exact HTTP fallback, fetch SSE resume, description digests and decimal snapshot values passed (fixture certificate SPKI pinned)', flush=True)
    return scope
