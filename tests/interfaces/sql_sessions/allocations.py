"""Independent finite-relation peer for client allocation checks, not SQL execution."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
from pathlib import Path
import re
import shutil
import socket
from socketserver import ThreadingMixIn, UnixStreamServer
import ssl
import struct
import subprocess
import sys
import tempfile
import threading

from runner.paths import ROOT
from runner import capture
from interfaces.sql_sessions.result_frame import encode_fixture, CONTENT_TYPE, ENCODING
from query.logical.fuze_types import DEFINITION, descriptor


def schema(wide):
    fields = [(b'id', 2)] + ([(b'text', 5)] if wide else [])
    value = b'FTY1' + bytes([len(DEFINITION)]) + DEFINITION + bytes([22, len(fields)])
    for name, kind in fields:
        value += bytes([len(name)]) + name + bytes([0, kind])
    return value.hex()


@contextmanager
def peer(mode, root):
    definition = re.search(r'\b([a-f0-9]{64})\b', (ROOT / 'packages/zig/transit-protocol/src/Growth.zig').read_text()).group(1)
    state = dict(requests=0, queries=0, retries=0, turnovers=0, prepares=0, releases=0, commands=0, timeouts=0, cancellations=0)
    active = {}
    dropped = set()
    lock = threading.Lock()
    partial = threading.Event()
    observation = dict(metadata=dict(kind='probe', consistency='session', namespace=None, definitions=[], configuration_revision=None, session_settings=None, source=None))

    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *_):
            pass

        def setup(self):
            super().setup()
            self.requests = 0

        def do_POST(self):
            request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            assert request['definition'] == definition and request['version'] == 1
            action, value = next(iter(request['action'].items()))
            with lock:
                state['requests'] += 1
            self.requests += 1
            binary = False
            if action == 'hello':
                result = dict(hello=dict(encoding=ENCODING, session_lease_ms=30000, maximum_message=4194304, maximum_batch=1048576, maximum_rows=32, capabilities=[]))
            elif action == 'open':
                result = dict(opened=dict(session=[3] * 32, account=[4] * 32, database='transit', proof=''))
            elif action == 'assist':
                assert value['text'] in ('allocation_probe_timeout', 'allocation_probe_cancel', 'allocation_probe_barrier')
                if value['text'] == 'allocation_probe_barrier':
                    assert partial.wait(10), 'cancellation never reached the partial response'
                    result = dict(closed={})
                else:
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', '128')
                    self.end_headers()
                    self.wfile.write(b'{')
                    self.wfile.flush()
                    if value['text'] == 'allocation_probe_cancel':
                        state['cancellations'] += 1
                        partial.set()
                    else:
                        state['timeouts'] += 1
                    self.connection.settimeout(10)
                    try:
                        assert self.connection.recv(1) == b'', 'cancelled connection was reused'
                    except (ConnectionResetError, ssl.SSLError):
                        pass
                    self.close_connection = True
                    return
            elif action in ('close', 'close_result', 'touch'):
                result = dict(closed={})
                if action == 'close_result':
                    active.pop(bytes(value), None)
            elif action == 'prepare':
                state['prepares'] += 1
                result = dict(described=dict(statement=[7] * 32, schema=schema('wide' in value['sql']),
                                             parameters=[descriptor('uint64').hex()], mutation=False))
            elif action == 'release':
                assert value == [7] * 32
                state['releases'] += 1
                result = dict(closed={})
            elif action == 'execute' and value['sql'] == 'SET allocation_probe':
                state['commands'] += 1
                result = dict(completion=dict(kind='set', outcome='applied', counts=None,
                                              operation=None, pending_restart=False, diagnostic=None))
            else:
                if action == 'execute':
                    match = re.fullmatch(r'SELECT (\d+) (wide|narrow) (retry|once)', value['sql'])
                    assert match
                    if value['parameters']:
                        desc = descriptor('uint64')
                        assert value['parameters'] == [(b'FVL1' + struct.pack('<H', len(desc)) + desc + b'\1\3' + struct.pack('<Q', 7)).hex()]
                    with lock:
                        state['queries'] += 1
                        cursor = state['queries'].to_bytes(32, 'little')
                    active[cursor] = int(match[1]), match[2] == 'wide', match[3] == 'retry'
                    ordinal = 0
                else:
                    assert action == 'fetch', action
                    cursor, ordinal = bytes(value['cursor']), value['batch']
                length, wide, retry = active[cursor]
                if retry and ordinal == 1 and cursor not in dropped:
                    dropped.add(cursor)
                    with lock:
                        state['retries'] += 1
                    self.close_connection = True
                    self.connection.shutdown(socket.SHUT_RDWR)
                    return
                start = ordinal * 32
                end = min(length, start + 32)
                assert start <= length
                rows = []
                for row in range(start, end):
                    cells = [(b'\x03' + struct.pack('<Q', row)).hex()]
                    if wide:
                        cells += [(b'\x03' + struct.pack('<I', 24000) + bytes([ord('a') + row % 26]) * 24000).hex()]
                    rows.append(cells)
                payload = encode_fixture(definition, [2] * 16, dict(cursor=list(cursor), batch=ordinal, schema=schema(wide), observation=observation, rows=rows, complete=end == length, completion=dict(rows=length) if end == length else None))
                binary = True
            if not binary:
                payload = json.dumps(dict(version=1, definition=definition, instance=[2] * 16, result=result)).encode()
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE if binary else 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            if self.requests == 256:
                with lock:
                    state['turnovers'] += 1
                self.send_header('Connection', 'close')
                self.close_connection = True
            self.end_headers()
            self.wfile.write(payload)

    class UnixServer(ThreadingMixIn, UnixStreamServer):
        daemon_threads = True

    ca = ''
    if mode == 'unix':
        path = root / 'peer.sock'
        server = UnixServer(str(path), Handler)
        endpoint = f'unix:{path}'
    else:
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        endpoint = f'{mode}://127.0.0.1:{server.server_port}'
        if mode == 'https':
            ca = str(root / 'certificate.pem')
            key = str(root / 'key.pem')
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', ca, '-days', '1', '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1'], check=True, capture_output=True)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(ca, key)
            server.socket = context.wrap_socket(server.socket, server_side=True)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        yield endpoint, ca, state
    finally:
        server.shutdown()
        server.server_close()
        worker.join()


def mappings(text):
    """Retain attempted mappings/thread creation, including failed syscalls.

    brk(NULL) queries are not growth. Shrinkage is distinguished from growth
    using each process's preceding observation, including pre-interval calls.
    An unknown starting break or incomplete trace fails rather than certifying.
    """
    active = False
    markers = []
    pending, breaks = {}, {}
    events = []
    for line in text.splitlines():
        match = re.fullmatch(r'(\d+)\s+(\d+\.\d+)\s+(.*)', line)
        if not match:
            raise AssertionError(f'unparsed trace: {line}')
        pid, timestamp, call = match.groups()
        measured = active
        if '<unfinished ...>' in call:
            assert pid not in pending
            pending[pid] = (call.split('<unfinished ...>')[0], measured, timestamp)
            continue
        if call.startswith('<... '):
            resume = re.match(r'<\.\.\. (\w+) resumed>(.*)', call)
            assert resume and pid in pending
            prefix, measured, timestamp = pending.pop(pid)
            assert prefix.startswith(resume[1] + '(')
            call = prefix + resume[2]
        if call.startswith(('+++ ', '--- ')):
            continue
        syscall = re.match(r'(\w+)\((.*)\)\s+= (.*)', call)
        assert syscall, call
        name, args, result = syscall.groups()
        if name == 'prctl':
            if 'PR_SET_NAME, "alloc_begin"' in args:
                assert not markers and result == '0'
                active = True
                markers.append('begin')
            elif 'PR_SET_NAME, "alloc_end"' in args:
                assert markers == ['begin'] and result == '0'
                active = False
                markers.append('end')
            continue
        assert name in ('mmap', 'mmap2', 'mremap', 'brk', 'clone', 'clone3'), name
        if name == 'brk':
            previous = breaks.get(pid)
            observed = int(result.split()[0], 16)
            breaks[pid] = observed
            if args in ('NULL', '0'):
                continue
            if measured:
                assert previous is not None, 'unknown starting heap break'
            if previous is not None and observed <= previous:
                continue
        if measured:
            events.append(dict(thread=int(pid), timestamp=timestamp, syscall=name,
                               arguments=args, result=result))
    assert not pending and markers == ['begin', 'end'], 'incomplete allocation interval'
    return events


def trace_controls():
    begin = '1 1.000 prctl(PR_SET_NAME, "alloc_begin") = 0\n'
    end = '1 3.000 prctl(PR_SET_NAME, "alloc_end") = 0\n'
    assert mappings(begin + end) == []
    trace = ('1 0.500 brk(NULL) = 0x1000\n' + begin +
             '2 2.000 mmap(NULL, 4096, PROT_READ, MAP_PRIVATE, -1, 0 <unfinished ...>\n'
             '1 2.100 brk(0x2000) = 0x2000\n'
             '2 2.200 <... mmap resumed>) = 0x3000\n' + end)
    assert {event['syscall'] for event in mappings(trace)} == {'brk', 'mmap'}
    for malformed in (begin, end, begin + begin + end, begin + 'unparsed\n' + end,
                      begin + '1 2.000 mmap(NULL <unfinished ...>\n' + end):
        try:
            mappings(malformed)
        except AssertionError:
            continue
        raise AssertionError('incomplete/malformed trace accepted')


def main():
    binary = str(Path(sys.argv[1]).resolve())
    if sys.platform != 'linux' or not shutil.which('strace'):
        raise SystemExit('Linux allocation observer requires the pinned strace; no OS-level pass recorded')
    destination = capture.directory(ROOT / '.cache/allocations/sql-client.json')
    evidence = capture.provenance(ROOT) | dict(status='inconclusive', profiles=[],
        binary_sha256=capture.identity(Path(binary))['sha256'],
        strace=str(Path(shutil.which('strace')).resolve()),
        observation='Zig backing attempts; interposable glibc attempts; traced mapping, brk growth and worker attempts in all child threads. Not hidden allocator calls that neither cross these boundaries nor grow the heap.')
    sources = [ROOT / 'tests/interfaces/sql/allocation_probe.c', Path(__file__),
               ROOT / 'tests/interfaces/sql/sql_result_allocations.zig']
    for package in ('transit-memory', 'transit-io', 'transit-sql-client', 'transit-sql-results', 'transit-sql-protocol'):
        sources.extend((ROOT / 'packages/zig' / package / 'src').rglob('*.zig'))
    evidence['source_sha256'] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    report_path = destination / 'evidence.json'
    capture.write_json(report_path, evidence)
    try:
        trace_controls()
        for mode, negative in (('unix', True), ('unix', False), ('http', False), ('https', False)):
            name = mode + ('-negative' if negative else '')
            trace = destination / (name + '.trace')
            profile = dict(name=name, completed=False)
            evidence['profiles'].append(profile)
            capture.write_json(report_path, evidence)
            with tempfile.TemporaryDirectory(prefix='transit-result-allocations-') as directory:
                with peer(mode, Path(directory)) as (endpoint, ca, state):
                    command = ['strace', '-f', '-ttt', '-o', str(trace), '-e',
                               'trace=mmap,mremap,brk,clone,clone3,prctl', binary, endpoint, ca]
                    if negative:
                        command.append('negative')
                    cancelled = threading.Event()
                    timer = threading.Timer(120, cancelled.set)
                    timer.start()
                    try:
                        result = capture.run(command, cwd=ROOT, log=destination / (name + '.log'),
                                             result=profile, capture_stdout=True, cancelled=cancelled)
                    finally:
                        timer.cancel()
                        timer.join()
                    report = json.loads(result.stdout.splitlines()[-1])
                    profile.update(client=report, peer=dict(state), trace=capture.identity(trace))
                    events = mappings(trace.read_text())
                    profile['memory_events'] = events
                    assert result.returncode == 0, profile
                    assert report['backing']['alloc_attempts'] == report['backing']['growing_resize_attempts'] == report['backing']['remap_attempts'] == 0
                    if negative:
                        assert all(count > 0 for count in report['libc_attempts']), report
                        calls = {event['syscall'] for event in events}
                        assert 'mmap' in calls and calls & {'clone', 'clone3'}, events
                        assert report['statements'] == 0 and state['queries'] == 1
                    else:
                        assert report['statements'] == 300 and state['queries'] == 302
                        assert state['timeouts'] == state['cancellations'] == 1, state
                        assert state['prepares'] == state['releases'] == 30 and state['commands'] == 1, state
                        assert state['requests'] > 256 and state['retries'] > 0 and state['turnovers'] > 0, state
                        assert report['libc_attempts'] == [0, 0, 0, 0] and events == [], profile
                    profile['status'] = 'passed'
                    print(f'{name}: {state}; memory events={len(events)}, libc attempts={report["libc_attempts"]}', flush=True)
            capture.write_json(report_path, evidence)
        evidence['status'] = 'passed'
    except BaseException as failure:
        evidence['failure'] = str(failure)
        raise
    finally:
        capture.write_json(report_path, evidence)
        print(f'Allocation evidence: {destination}', flush=True)


if __name__ == '__main__':
    main()
