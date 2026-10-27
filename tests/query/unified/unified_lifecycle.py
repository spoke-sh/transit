"""Current public grants and explicit cancellation at real capture boundaries."""
import time
from query.unified.unified_abi import Failure, authorize_capture


def check(client, root, invoke, fault, kind):
    bundle = (root/'bundle.bin').read_bytes().hex()

    def observe(prepared):
        receipt = client.call({'submit': prepared})['receipt']
        until = time.monotonic()+60
        while True:
            value = client.call({'observe': receipt['position']})['observation']
            if 'committed' in value: return
            assert 'pending' in value and time.monotonic() < until, value
            time.sleep(.02)

    def upload(namespace):
        accepted = authorize_capture(client, root, namespace)
        for _ in range(132):
            prepared = client.call({'next': dict(namespace=namespace, bundle=accepted)})['prepared']
            if prepared is None: return
            observe(prepared)
        raise AssertionError('finite upload budget exceeded')

    def wait(namespace, phase, cleanup=False):
        until = time.monotonic()+180
        while True:
            status = client.call({'status': namespace})['status']
            if status['phase'] == phase:
                if not cleanup: return status
                job = invoke('job', namespace, direct=True)['job']
                if job['cleanup'] == 0:
                    assert job['phase'] in ({'cancelled', 'denied'} if phase == 'cancelled' else {phase}), job
                    return job
            assert time.monotonic() < until, status
            time.sleep(.1)

    invoke('revoke', direct=True)
    try:
        client.call({'next': dict(namespace='5', bundle=bundle)})
        raise AssertionError('revoked pre-submit access succeeded')
    except Failure as error:
        assert error.status == 4, error
    invoke('restore', direct=True)
    assert client.call({'status': '5'})['status'] is None

    # Request read authorization belongs to the source worker independently of
    # the caller's rights or optional association. Deny before source admission.
    invoke('request-read-revoke', direct=True)
    upload('5')
    wait('5', 'denied')
    assert invoke('job', '5', direct=True)['job'] is None
    invoke('request-read-restore', direct=True)

    for namespace, phase in (('6', 'denied'), ('7', 'cancelled')):
        fault['stage'].clear(); fault['resume'].clear()
        upload(namespace)
        assert fault['stage'].wait(timeout=120), 'capture never staged a result segment'
        staged = invoke('job', namespace, direct=True)
        assert staged['job']['phase'] == 'capturing'
        # The proxy holds the receipt for committed segment metadata, before
        # chunks are published or the completed-segment counter advances.
        assert staged['checkpoint']['progress']['segments'] == 0
        if phase == 'denied':
            invoke('request-read-revoke', direct=True)
        else:
            prepared = client.call({'prepare': {'cancel': namespace}})['prepared']
            observe(prepared)
        fault['resume'].set()
        closed = wait(namespace, phase, cleanup=True)
        if phase == 'cancelled':
            # Request retirement can reach the next source continuation before
            # the cancel frame. Both closures must release and clean the pin.
            assert closed['phase'] in ('cancelled', 'denied')
        if phase == 'denied': invoke('request-read-restore', direct=True)
        try:
            client.call({'page': dict(namespace=namespace)})
            raise AssertionError('closed query exposed staged rows')
        except Failure:
            pass
    assert invoke('released-read', direct=True) == {'released_read_denied': True}
    print(f'Unified {kind} lifecycle: caller denial before upload, independent source denial before admission '
          'and during capture, explicit cancellation, released-version refusal and bounded staged cleanup passed.', flush=True)
