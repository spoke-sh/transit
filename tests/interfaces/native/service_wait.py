"""Real authorized notification waits, with bounded admission and revocation."""
from concurrent.futures import ThreadPoolExecutor
import json
import socket
import time
from urllib.parse import urlsplit


def run(post, sign_query, query, command, pid, seed, public, url, prepare_command, set_request_deadline):
    read = sign_query({'process': pid})
    position = query({'process': pid})['position']

    def wait(envelope=read, after=position, milliseconds=1000, expected=200):
        return post('/v1/query', envelope, expected,
                    headers={'Content-Type': 'application/json',
                             'X-Transit-Wait': f'{after}:{milliseconds}'})

    started = time.monotonic()
    unchanged = wait(milliseconds=150)
    assert unchanged['position'] == position
    assert time.monotonic() - started >= .12, 'idle wait returned without waiting'
    for malformed in ('1:0', '1:1001', '01:1', '-1:1', '1:1:1'):
        post('/v1/query', read, 400, headers={'X-Transit-Wait': malformed})
    post('/v1/query', sign_query({'capabilities': {}}), 400,
         headers={'X-Transit-Wait': f'{position}:100'})
    wait(after=position + 100000, expected=400)

    grant = {'subject': 90, 'public_key': public, 'permissions': 16, 'pid': pid}
    # The authority lock and ordinary/control admission remain usable while all
    # four wait slots are occupied. One publication wakes the coalesced waiters.
    publish = prepare_command({'grant': grant})
    with ThreadPoolExecutor(max_workers=4) as pool:
        pending = [pool.submit(wait) for _ in range(4)]
        time.sleep(.1)
        wait(expected=503)
        query({'capabilities': {}})
        committed = publish()
        replies = [future.result(timeout=4) for future in pending]
        assert all(value['position'] > position for value in replies)
        assert all(value['position'] > committed for value in replies)
    # A notification arriving before registration must be visible immediately.
    assert wait()['position'] > position

    # An independent HTTP client publishes through the same exclusive owner.
    # Every waiter reconciles accepted authority before returning its result.
    publish = prepare_command({'grant': dict(grant, subject=91)})
    current = query({'process': pid})['position']
    with ThreadPoolExecutor(max_workers=1) as pool:
        pending = pool.submit(wait, read, current, 1000)
        time.sleep(.1)
        committed = publish()
        assert pending.result(timeout=4)['position'] > committed

    set_request_deadline(800)
    # The isolated 800 ms request deadline cancels a 1,000 ms idle wait.
    # Exercise all slots, then reuse all of them: cancellation must release
    # both the authority mutex and volatile/admission registrations.
    current = query({'process': pid})['position']
    endpoint = urlsplit(url)
    body = json.dumps(read).encode()
    def canceled():
        with socket.create_connection((endpoint.hostname, endpoint.port), timeout=3) as peer:
            peer.sendall((f'POST /v1/query HTTP/1.1\r\nHost: {endpoint.netloc}\r\n'
                          f'Content-Length: {len(body)}\r\nX-Transit-Wait: {current}:1000\r\n\r\n').encode() + body)
            try:
                response = peer.recv(4096)
                assert response == b'', ('deadline unexpectedly returned a response', response)
            except ConnectionResetError:
                pass
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda _: canceled(), range(4)))
        pending = [pool.submit(wait, read, current, 100) for _ in range(4)]
        assert all(future.result(timeout=4)['position'] == current for future in pending)

    set_request_deadline(10000)
    revoke = prepare_command({'grant': dict(grant, permissions=0)})
    subject = sign_query({'process': pid}, principal=90, seed=seed)
    current = query({'process': pid})['position']
    with ThreadPoolExecutor(max_workers=1) as pool:
        pending = pool.submit(wait, subject, current, 1000, 403)
        time.sleep(.1)
        revoke()
        assert pending.result(timeout=4)['err'] == 'AccessDenied'
    print('Native wait: timeout, registration races, coalescing, reserved admission, independent-client publication, cancellation cleanup and current revocation passed.', flush=True)
