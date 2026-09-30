"""Actual Board and application browser consumers, with owned physical services."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import time
from reactive import reactive
from serving import policy, post, signed_read, submit


def run(env, tls):
    started = time.monotonic()
    root = env['store'].root
    cast, drained = env['cast'], env['drained']
    ingress, application = env['ingress'], env['application']
    requests, resource = env['ingress_resource'], env['application_resource']
    keys = env['keys']
    schema = hashlib.sha256(b'\1\1\2id\5count').digest()
    cast(ingress, reactive(0, struct.pack('<QQQQIB', 0, 1, application, resource, 1, 13) + b'data-progress' + schema + b'\1'))
    table = b'TBL1\1\2id\5count'
    source = b'UQS1' + struct.pack('<QBI', resource, 2, 1) + bytes([len(table)]) + table
    declaration = hashlib.sha256(b'transit.query.source.v1\0' + source).digest()
    cast(application, b'UQA1' + struct.pack('<QQQ', ingress, requests, 1) + declaration + b'\1' + struct.pack('<QQQ', 64, 64, 1048576))
    cast(ingress, policy(33))
    drained(application); drained(ingress)
    env['grant'](33, 20, ingress)
    env['grant'](34, 20, ingress)
    env['resource_grant'](requests, 34, 3)
    # Abandoned leases must release bounded live capacity without a browser
    # sending close. Use finite observed deadlines, not a fabricated expired clock.
    abandoned_at = int(time.time() * 1000)
    cast(ingress, reactive(1, struct.pack('<Q', abandoned_at)), 34)
    for principal in (65536, 65537):
        for session in (1, 2):
            cast(ingress, reactive(2, struct.pack('<QQQ', session, 1, abandoned_at + 5000)), principal)
    drained(ingress)
    observer = env['start']('clock-observer', env['example'], dict(url=env['worker_url'], realm=49, principal=34, seed_file=str(keys[34].seed), role={'clock_observer': dict(ingress=ingress, resource=requests, interval_ms=5000)}))
    active_key = (b'\0sv1L' + struct.pack('<QQ', 0, 0)).hex()
    until = time.monotonic() + 20
    while True:
        entry = env['query'](34, {'read_entries': dict(resource=requests, revision=None, keys=[active_key] + [None] * 7)})['body']['read_entries']['entries'][0]
        if entry and bytes.fromhex(entry['value']) == b'SV1L' + bytes(64): break
        assert time.monotonic() < until, 'observer failed to reclaim abandoned session slots'
        time.sleep(.25)
    session_keys = [(b'\0sv1S' + struct.pack('>QQ', principal, session)).hex()
                    for principal in (65536, 65537) for session in (1, 2)]
    history = env['query'](34, {'read_entries': dict(resource=requests, revision=None, keys=session_keys + [None] * 4)})['body']['read_entries']['entries']
    assert all(entry and bytes.fromhex(entry['value'])[76] == 3 for entry in history[:4]), history
    print('Observer reclaimed four abandoned sessions without deleting history.', flush=True)
    counter_host = f'127.0.0.1:{tls[env["gateway_ports"][1]].port}'
    operation = 100

    def mutate(row=1, delta=1):
        nonlocal operation
        operation += 1
        cast(ingress, submit(operation, env['deadline_ms'], row=row, delta=delta), 33)
        # Live renewals/clock observations can keep ingress nonempty. Wait for
        # this identified operation, never for global quiescence.
        until = time.monotonic() + 30
        while time.monotonic() < until:
            status, current = post(env['gateway_ports'][1], '/serving/v1/read', signed_read(keys[33], 33, ingress, 'status', operation), counter_host, None)
            assert status in (200, 404, 409, 429, 503, 504), (status, current)
            if status == 200 and current['stage'] == 'completed':
                return
            time.sleep(.25)
        raise AssertionError(('counter mutation incomplete', operation))

    mutate()
    # Board uses the existing read-only gateway principal; query/control sends
    # remain under the separately configured caller identity.
    if 'stop_gateway' in env: env['stop_gateway'](0)
    else:
        env['gateways'][0].terminate(); env['gateways'][0].wait(timeout=10)
    gateway = dict(service=1, ingress=ingress, resource=requests, port=env['gateway_ports'][0], host=env['public_host'], public_origin='https://' + env['public_host'],
        callers=[dict(principal=65536, public_key=keys[65536].public)], reactive=True, options=dict(requests=4, request_timeout_ms=30000), per_caller_requests=4,
        viewer=dict(principal=65536, seed_file=str(keys[65536].seed), refresh=True))
    board_config = dict(upstream=env['worker_url'], realm=49, principal=79, seed_file=str(keys[79].seed), profile='native_v1', public_origin=gateway['public_origin'], port=gateway['port'], request_timeout_ms=5000, upstream_timeout_ms=3500,
        query=dict(seed_file=str(keys[65536].seed), connection=dict(realm=49, principal=65536, source=application, resource=resource, requester=ingress, requests=requests),
            workspace=dict(name='counter', source=dict(resource=resource, source={'table': dict(id=1, names=['id', 'count'], value_type='int64')}), limits=dict(pages='64', segments='64', result_bytes='1048576'))),
        reactive=dict(principal=79, seed_file=str(keys[79].seed), gateway=gateway))
    board = env['start']('board-live', env['board'], board_config)
    pins = []
    certificates = []
    for gateway_port in env['gateway_ports']:
        certificate = tls[gateway_port].root / 'certificate.pem'
        certificates.append(certificate.read_bytes())
        public = subprocess.check_output(['openssl', 'x509', '-in', str(certificate), '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'DER'], input=public)
        pins.append(base64.b64encode(hashlib.sha256(der).digest()).decode())
    ca_bundle = root / 'view-ca.pem'
    ca_bundle.write_bytes(b'\n'.join(certificates))
    configuration = root / 'view-browser.json'
    configuration.write_text(json.dumps(dict(board=gateway['public_origin'], counter='https://' + counter_host, resource=resource, marker=str(root / 'view-stage'), spki=','.join(pins), recovery='recover' in env, screenshots=str(Path('.cache/verification').resolve()), profile=env.get('profile', 'native'))))
    log = (root / 'view-browser.log').open('w+')
    script = 'live-view-lifecycle.mjs' if env.get('reactive_views_lifecycle') else 'live-views.mjs'
    browser = subprocess.Popen(['vp', 'exec', '--filter', '@rey/transit-board-web', 'node', 'browser/' + script, str(configuration)], stdout=log, stderr=subprocess.STDOUT, env=env['store'].env | {'NODE_EXTRA_CA_CERTS': str(ca_bundle)})
    previous = None
    sessions_before = None

    def active_sessions():
        entry = env['query'](34, {'read_entries': dict(resource=requests, revision=None, keys=[active_key] + [None] * 7)})['body']['read_entries']['entries'][0]
        return bytes.fromhex(entry['value'])
    try:
        until = time.monotonic() + 900
        while browser.poll() is None:
            assert observer.poll() is None and (env['hosts_alive']() if 'hosts_alive' in env else board.poll() is None), 'view host exited'
            assert time.monotonic() < until, 'browser live view deadline'
            marker = root / 'view-stage'
            stage = marker.read_text() if marker.exists() else None
            if stage and stage != previous:
                previous = stage
                print(f"Reactive browser stage: {stage}", flush=True)
                if stage in ('mutate', 'mutate-again'): mutate()
                elif stage == 'deny': env['resource_grant'](resource, 65536, 1)
                elif stage == 'rows':
                    for row in range(2, 21): mutate(row)
                elif stage == 'restart': env['recover']()
                elif stage == 'sessions-before': sessions_before = active_sessions()
                elif stage == 'sessions-after': assert active_sessions() == sessions_before, 'reconnect replaced logical sessions'
                elif stage == 'peer-closed':
                    until_closed = time.monotonic() + 40
                    while sum(active_sessions()[4 + i * 16:20 + i * 16] != bytes(16) for i in range(4)) != 2:
                        assert time.monotonic() < until_closed, 'closed tab retained a live session'
                        time.sleep(.25)
                elif stage == 'reset':
                    cast(ingress, reactive(0, struct.pack('<QQQQIB', 1, 2, application, resource, 1, 13) + b'data-progress' + schema + b'\1'))
                elif stage == 'retire':
                    env['send']({'terminate': application})
                    env['send']({'retire_resource': resource})
                elif stage != 'ready': raise AssertionError(('unknown browser stage', stage))
                state = env['query'](0, {'process': ingress})['body']['process']
                print('Ingress at stage completion:', {k: state['process'][k] for k in ('admitted', 'consumed', 'revision')} | {'head': state['input']['position'] if state['input'] else None}, flush=True)
                (root / 'view-stage-ack').write_text(stage)
            time.sleep(.05)
        log.seek(0)
        text = log.read()
        print(text, flush=True)
        assert browser.returncode == 0, 'browser live-view proof failed'
        print(f'Reactive view {env.get("profile", "native")} proof passed in {time.monotonic() - started:.2f}s', flush=True)
    finally:
        if browser.poll() is None: browser.kill(); browser.wait(timeout=10)
        if browser.returncode:
            log.seek(0); print(log.read()[-10000:], flush=True)
        log.close()
