"""Real authorized notification waits, with bounded admission and revocation."""
from concurrent.futures import ThreadPoolExecutor
import time


def run(post, sign_query, query, command, pid, seed, public):
    read = sign_query({'process': pid})
    position = query({'process': pid})['position']

    def wait(envelope=read, after=position, milliseconds=500, expected=200):
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
    with ThreadPoolExecutor(max_workers=4) as pool:
        pending = [pool.submit(wait) for _ in range(4)]
        time.sleep(.1)
        wait(expected=503)
        query({'capabilities': {}})
        committed = command({'grant': grant})
        replies = [future.result(timeout=4) for future in pending]
        assert all(value['position'] > position for value in replies)
        assert all(value['position'] > committed for value in replies)
    # A notification arriving before registration must be visible immediately.
    assert wait()['position'] > position

    subject = sign_query({'process': pid}, principal=90, seed=seed)
    current = query({'process': pid})['position']
    with ThreadPoolExecutor(max_workers=1) as pool:
        pending = pool.submit(wait, subject, current, 500, 403)
        time.sleep(.1)
        command({'grant': dict(grant, permissions=0)})
        assert pending.result(timeout=4)['err'] == 'AccessDenied'
    print('Native wait: bounded idle timeout, pre-registration publication, coalesced wakeup, reserved admission and current revocation passed.', flush=True)
