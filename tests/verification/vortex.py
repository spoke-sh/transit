"""External fault supervisor for real Transit binaries and an owned disk Ursula.

A seed reproduces workload/fault intent, not OS scheduling. Only public signed
operations observe authority. No storage files or private checkpoints are edited.
"""
import argparse
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from harness.ursula import Fixture
from harness.services import free_port, wait_ready

ROOT = Path(__file__).resolve().parents[2]


class Peer(ThreadingHTTPServer):
    daemon_threads = False

    def __init__(self, port, record):
        super().__init__(('127.0.0.1', 0), Handler)
        self.upstream = port
        self.record = record
        self.mutex = threading.Lock()
        self.rule = None
        self.seen = threading.Event()
        self.finished = threading.Event()
        self.accepted = {}
        self.attempts = {}
        self.last_fault_identity = None
        self.errors = []

    def arm(self, principal, command, fault, delay):
        with self.mutex:
            assert self.rule is None, 'previous fault never fired'
            self.seen.clear()
            self.finished.clear()
            self.rule = dict(principal=principal, command=command, fault=fault, delay=delay)
            self.record('fault_requested', **self.rule)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        peer = self.server
        rule = None
        connection = None
        try:
            self.connection.settimeout(10)
            size = int(self.headers['Content-Length'])
            if not 0 < size <= 1024 * 1024:
                raise ValueError('unbounded proxy request')
            body = self.rfile.read(size)
            envelope = json.loads(body)
            request = envelope.get('request', envelope.get('query'))
            command = next(iter(request.get('command', {})), None)
            digest = hashlib.sha256(body).hexdigest()
            with peer.mutex:
                if command:
                    identity = (request['principal'], request['sequence'])
                    attempt = peer.attempts.setdefault(identity, [digest, 0])
                    assert attempt[0] == digest, 'uncertain request changed signed bytes'
                    attempt[1] += 1
                if peer.rule and request['principal'] == peer.rule['principal'] and command == peer.rule['command']:
                    rule, peer.rule = peer.rule, None
                    peer.last_fault_identity = identity
            event = dict(principal=request['principal'], sequence=request.get('sequence'), command=command, sha256=digest)
            peer.record('request', **event, signed=envelope)
            if rule and rule['fault'] in ('drop_request', 'delay_request'):
                peer.record('fault_observed', **rule)
                peer.seen.set()
                if rule['fault'] == 'drop_request':
                    self.close_connection = True
                    return
                time.sleep(rule['delay'])
            connection = HTTPConnection('127.0.0.1', peer.upstream, timeout=8)
            connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
            response = connection.getresponse()
            data = response.read(1024 * 1024 + 1)
            if len(data) > 1024 * 1024:
                raise ValueError('unbounded proxy response')
            peer.record('response', **event, status=response.status, body=json.loads(data))
            if command and response.status == 200:
                identity = (request['principal'], request['sequence'])
                with peer.mutex:
                    previous = peer.accepted.setdefault(identity, (digest, data))
                    if previous != (digest, data):
                        raise AssertionError('accepted identity or receipt changed')
            if rule and rule['fault'] in ('drop_response', 'delay_response'):
                if response.status != 200:
                    # These schedules kill/recover after a lost acceptance
                    # receipt. A timeout or rejection is not that premise.
                    # Forward it normally and keep the fault armed for an
                    # accepted attempt within the existing supervisor budget.
                    with peer.mutex:
                        assert peer.rule is None, 'response fault replaced while in flight'
                        peer.rule = rule
                    peer.record('fault_deferred', **rule, status=response.status)
                    rule = None
                else:
                    peer.record('fault_observed', **rule)
                    peer.seen.set()
                    if rule['fault'] == 'drop_response':
                        self.close_connection = True
                        return
                    time.sleep(rule['delay'])
            self.send_response(response.status)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except (ConnectionError, TimeoutError, OSError) as error:
            peer.record('connection_interrupted', error=type(error).__name__)
            self.close_connection = True
        except BaseException as error:
            with peer.mutex:
                peer.errors.append(repr(error))
            self.close_connection = True
        finally:
            if connection:
                connection.close()
            if rule:
                peer.finished.set()


def verify(state, expected, pid, sink):
    process, resource, outputs, destination = (state[k] for k in ('process', 'resource', 'outputs', 'destination'))
    assert process['admitted'] == process['consumed'] == len(expected), 'lost/duplicate source admission'
    assert resource == (expected[-1] if expected else 0), 'partial resource/input publication'
    assert len(outputs) == len(expected), 'partial output publication'
    for output, value in zip(outputs, expected):
        assert output['source'] == pid and output['destination'] == sink, 'original route changed'
        assert int(bytes.fromhex(output['value'])) == value, 'output value changed'
    assert destination['admitted'] == destination['consumed'] == len(expected), 'lost/duplicate destination admission'
    assert all(o['phase'] == 'delivered' for o in outputs), 'eligible output stalled'


def scenario(args, destination, record, report):
    rng = random.Random(args.seed)
    binaries = dict(zip(('node', 'cli', 'worker', 'courier'), args.binaries))
    children, handles = [], []
    peer = thread = None
    # Keep disk tests off Nix's potentially memory-backed TMPDIR.
    disk = ROOT / '.cache/verification/storage'
    disk.mkdir(parents=True, exist_ok=True)
    previous_tempdir = tempfile.tempdir
    tempfile.tempdir = str(disk)
    store = Fixture()
    tempfile.tempdir = previous_tempdir

    def start(name, argv):
        handle = (store.root / f'{name}-{len(handles)}.log').open('w')
        handles.append(handle)
        child = subprocess.Popen([str(x) for x in argv], stdout=handle, stderr=subprocess.STDOUT,
                                 start_new_session=True, env=store.env)
        children.append(child)
        record('process_started', actor=name, pid=child.pid)
        return child

    def stop(child, actor):
        record('kill_requested', actor=actor, pid=child.pid)
        if child.poll() is None:
            os.killpg(child.pid, signal.SIGKILL)
        child.wait(timeout=10)
        record('process_exited', actor=actor, pid=child.pid, code=child.returncode)

    def invoke(argv):
        result = subprocess.run([str(x) for x in argv], capture_output=True, text=True, timeout=20, env=store.env)
        if result.returncode:
            raise RuntimeError(f'public client failed: {result.stderr[-2000:]}')
        return json.loads(result.stdout)

    try:
        with store:
            try:
                port = free_port()
                url = f'http://127.0.0.1:{port}'

                def key(name):
                    path = store.root / f'{name}.key'
                    path.write_text(os.urandom(32).hex())
                    path.chmod(0o600)
                    return path, invoke([binaries['cli'], 'public-key', path])

                root_key, public = key('root')
                worker_key, worker_public = key('worker')
                courier_key, courier_public = key('courier')
                config = store.root / 'node.json'
                config.write_text(json.dumps(dict(genesis=dict(realm=61, root_key=public, max_clock_error_ms=10000),
                    ursula_url=store.url, bucket='vortex', journal='authority', port=port)))
                subprocess.run([str(binaries['node']), str(config), '--initialize'], check=True, capture_output=True, timeout=20, env=store.env)

                def node():
                    child = start('node', [binaries['node'], config])
                    wait_ready(store.http, child, url + '/health')
                    return child

                authority = node()
                sequence = 0

                def command(value):
                    nonlocal sequence
                    sequence += 1
                    path = store.root / 'command.json'
                    path.write_text(json.dumps(dict(realm=61, principal=0, sequence=sequence, command=value)))
                    receipt = invoke([binaries['cli'], 'submit', root_key, path, url])
                    record('control', sequence=sequence, command=value, receipt=receipt)
                    return receipt['position']

                def query(kind, principal=0, credential=None, full=False):
                    path = store.root / 'query.json'
                    path.write_text(json.dumps(dict(realm=61, principal=principal, kind=kind)))
                    response = invoke([binaries['cli'], 'query', credential or root_key, path, url])
                    return response if full else response['body']

                pid = command(dict(spawn={}))
                sink = command(dict(spawn={}))
                command(dict(grant=dict(subject=1, public_key=worker_public, permissions=88, pid=pid)))
                command(dict(grant=dict(subject=2, public_key=courier_public, permissions=132)))
                resource = command(dict(create_resource=dict(writer=pid)))
                for subject in (0, 1):
                    command(dict(grant_resource=dict(resource=resource, subject=subject, permissions=7)))
                command(dict(associate=dict(pid=pid, name=b'counter'.hex(), resource=resource)))
                command(dict(own=dict(pid=pid, expected_generation=1, worker=1)))
                command(dict(own=dict(pid=sink, expected_generation=0, worker=0)))
                peer = Peer(port, record)
                thread = threading.Thread(target=peer.serve_forever, name='vortex-proxy')
                thread.start()
                proxy_url = f'http://127.0.0.1:{peer.server_port}'
                worker_config = store.root / 'worker.json'
                worker_options = dict(url=proxy_url, realm=61, principal=1, pid=pid, generation=2,
                                      state_association='counter', publish_to=sink, seed_file=str(worker_key))
                worker_config.write_text(json.dumps(worker_options))
                courier_config = store.root / 'courier.json'
                courier_config.write_text(json.dumps(dict(url=proxy_url, realm=61, principal=2, seed_file=str(courier_key), interval_ms=20)))
                report['topology'] = dict(realm=61, pid=pid, sink=sink, resource=resource, authority=url,
                    proxy=proxy_url, store=store.url, wal='disk', filesystem=subprocess.check_output(['stat', '-f', '-c', '%T', store.root], text=True).strip())
                expected = []

                def until(predicate, label):
                    deadline = time.monotonic() + 30
                    while not predicate():
                        if peer.errors:
                            raise AssertionError(peer.errors)
                        if time.monotonic() >= deadline:
                            raise TimeoutError(label)
                        time.sleep(.03)

                def fault_done():
                    assert peer.seen.wait(20), 'requested fault did not execute'
                    assert peer.finished.wait(10), 'proxy fault did not finish'
                    assert not peer.errors, peer.errors

                for index in range(args.rounds):
                    value = rng.randrange(1, 10)
                    expected.append(value + (expected[-1] if expected else 0))
                    command(dict(send=dict(pid=pid, value=str(value).encode().hex())))
                    fault = ('drop_request', 'delay_request', 'drop_response', 'delay_response')[index % 4]
                    peer.arm(1, 'turn', fault, rng.randrange(20, 81) / 1000)
                    worker = start('worker', [binaries['worker'], worker_config])
                    fault_done()
                    retry_identity = peer.last_fault_identity
                    if index % 4 == 2:
                        stop(worker, 'worker')
                        stop(authority, 'node')
                        record('store_kill_requested', pid=store.server.pid)
                        store.stop()
                        record('store_stopped')
                        store.start()
                        record('store_restarted', pid=store.server.pid)
                        authority = node()
                        # Accepted turn recovery needs no handler or resend.
                    else:
                        until(lambda: query(dict(process=pid))['process']['process']['consumed'] == len(expected), 'worker progress')
                        if fault == 'drop_request':
                            assert peer.attempts[retry_identity][1] >= 2, 'worker never retried lost request'
                        stop(worker, 'worker')
                    assert query(dict(process=pid))['process']['process']['consumed'] == len(expected)
                    peer.arm(2, 'deliver', 'drop_response', .03)
                    courier = start('courier', [binaries['courier'], courier_config])
                    fault_done()
                    retry_identity = peer.last_fault_identity
                    record('pause_requested', actor='courier', pid=courier.pid)
                    os.kill(courier.pid, signal.SIGSTOP)
                    def paused():
                        observed, status = os.waitpid(courier.pid, os.WUNTRACED | os.WNOHANG)
                        if not observed:
                            return False
                        assert os.WIFSTOPPED(status), 'courier exited before pause observation'
                        return True
                    until(paused, 'courier pause observation')
                    record('pause_observed', actor='courier', pid=courier.pid)
                    os.kill(courier.pid, signal.SIGCONT)
                    record('resume_requested', actor='courier', pid=courier.pid)
                    until(lambda: peer.attempts[retry_identity][1] >= 2, 'courier exact retry')
                    until(lambda: query(dict(delivery={}), 2, courier_key)['delivery']['next'] is None, 'courier progress')
                    stop(courier, 'courier')
                    # Recover/replay the courier against current history.
                    subprocess.run([str(binaries['courier']), str(courier_config), '--once'], check=True, capture_output=True, timeout=20, env=store.env)
                    source = query(dict(process=sink))['process']
                    item = source['input']
                    assert item is not None and int(bytes.fromhex(item['value'])) == expected[-1]
                    outputs, after, position = [], None, None
                    while True:
                        response = query(dict(outputs=dict(after=after, position=position)), full=True)
                        position = response['position']
                        page = response['body']['outputs']
                        outputs += [o for o in page['entries'] if o is not None]
                        after = page['next']
                        if after is None:
                            break
                    output = outputs[-1]
                    assert item['origin']['process'] == dict(pid=pid, turn=output['turn'], output=output['id']), 'changed admission provenance'
                    command(dict(turn=dict(pid=sink, generation=1, expected_revision=source['process']['revision'], input=item['position'])))
                    current = query(dict(process=pid))['process']['process']
                    revision = query(dict(resource=resource))['resource']['revision']
                    entries = query(dict(entries=dict(resource=resource, revision=revision, key=b'value'.hex())))['entries']['page']['entries']
                    state = dict(process=current, resource=int(bytes.fromhex(entries[0]['value'])), outputs=outputs,
                                 destination=query(dict(process=sink))['process']['process'])
                    verify(state, expected, pid, sink)
                    record('checked', round=index, state=state, expected=expected.copy())
                    report['rounds_completed'] = index + 1
                # Real current policy and stale ownership refusals, after progress.
                command(dict(grant=dict(subject=1, public_key=worker_public, permissions=0, pid=pid)))
                denied = subprocess.run([str(binaries['worker']), '--once', str(worker_config)], capture_output=True, text=True, timeout=20, env=store.env)
                assert denied.returncode and 'AccessDenied' in denied.stderr, 'revoked disclosure accepted'
                command(dict(grant=dict(subject=1, public_key=worker_public, permissions=88, pid=pid)))
                command(dict(own=dict(pid=pid, expected_generation=2, worker=1)))
                stale = subprocess.run([str(binaries['worker']), '--once', str(worker_config)], capture_output=True, text=True, timeout=20, env=store.env)
                assert stale.returncode and 'StaleActivation' in stale.stderr, 'stale activation accepted'
                record('fences_checked', denial=True, stale_activation=True)
                assert not peer.errors and peer.rule is None, (peer.errors, peer.rule)
                # Challenge each independent final-state invariant.
                for field in ('resource', 'outputs', 'destination'):
                    changed = json.loads(json.dumps(state))
                    if field == 'resource': changed[field] += 1
                    elif field == 'outputs': changed[field][0]['destination'] = pid
                    else: changed[field]['admitted'] += 1
                    try:
                        verify(changed, expected, pid, sink)
                    except AssertionError:
                        pass
                    else:
                        raise AssertionError(f'negative control survived: {field}')
                report['negative_controls'] = ['resource', 'original_destination', 'duplicate_admission']
            finally:
                for child in children:
                    if child.poll() is None:
                        stop(child, 'cleanup')
                if peer:
                    peer.shutdown()
                    peer.server_close()
                    thread.join(timeout=10)
                for handle in handles:
                    handle.close()
                store.log.flush()
                for path in store.root.glob('*.log'):
                    shutil.copyfile(path, destination / path.name)
    finally:
        report['cleanup'] = all(c.poll() is not None for c in children) and store.server is None and (thread is None or not thread.is_alive())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binaries', type=Path, nargs=4)
    parser.add_argument('--seed', type=int, default=1)
    parser.add_argument('--rounds', type=int, default=4)
    args = parser.parse_args()
    if not 4 <= args.rounds <= 32 or not 1 <= args.seed < 2**32:
        parser.error('use 4..32 rounds and a nonzero u32 seed')
    args.binaries = [p.resolve(strict=True) for p in args.binaries]
    destination = ROOT / '.cache/verification/vortex' / f'{time.time_ns()}-seed-{args.seed}'
    destination.mkdir(parents=True)
    started = time.monotonic()
    report = dict(completed=False, cleanup=False, seed=args.seed, rounds=args.rounds, generator='python-mt19937-vortex-v1',
        revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
        compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
        python=sys.version,
        ursula=subprocess.check_output(['ursula', '--version'], text=True).strip(),
        provider_sha256=hashlib.sha256(Path(shutil.which('ursula')).read_bytes()).hexdigest(),
        binaries={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in args.binaries},
        supervisor_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    report_file = destination / 'report.json'
    report_file.write_text(json.dumps(report, indent=2) + '\n')
    mutex = threading.Lock()
    try:
        with (destination / 'history.jsonl').open('w') as history:
            def record(event, **fields):
                with mutex:
                    history.write(json.dumps(dict(event=event, elapsed=time.monotonic()-started, **fields)) + '\n')
                    history.flush()
            scenario(args, destination, record, report)
        assert report['cleanup'], 'owned resources did not join'
        report['completed'] = True
    finally:
        report['seconds'] = round(time.monotonic() - started, 3)
        report_file.write_text(json.dumps(report, indent=2) + '\n')
        print(f'Vortex evidence: {destination}', flush=True)
    print(f'Vortex: {args.rounds} rounds passed; {report["seconds"]}s; cleanup joined')


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    main()
