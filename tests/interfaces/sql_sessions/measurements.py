"""Small real-service observations; no latency or throughput acceptance target."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import platform
import subprocess
import time


def reads(first, second, hop, service_pid):
    samples = []
    def query(client, label):
        before = hop.counters() if hop else None
        batch = (client.concurrent_read() if label == 'two_sessions' else client.execute('SELECT id FROM native_sessions'))['batch']
        sample = dict(client.sample, path=label, rows=len(batch['rows']),
                      complete=batch['complete'], sql_requests=client.sample.get('sql_requests', 1))
        if hop:
            after = hop.counters()
            sample.update(native_requests=after[0]-before[0], native_response_bytes=after[1]-before[1])
        client.call(dict(close_result=batch['cursor']))
        return sample
    for _ in range(3):
        first.http.close()
        first.last = 0
        samples.append(query(first, 'new_tls'))
        samples.append(query(first, 'reused_tls'))
    start = time.perf_counter()
    with ThreadPoolExecutor(max_workers=2) as pool:
        concurrent = list(pool.map(lambda c: query(c, 'two_sessions'), (first, second)))
    elapsed = round((time.perf_counter()-start)*1000, 3)
    memory = {}
    if service_pid:
        for line in Path(f'/proc/{service_pid()}/status').read_text().splitlines():
            if line.startswith(('VmRSS:', 'VmHWM:')):
                key, value = line.split(':', 1)
                memory[key + '_kib'] = int(value.split()[0])
    print(json.dumps(dict(profile='native_sql_session_measurement',
                         revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                         tracked_changes=bool(subprocess.check_output(['git', 'diff', '--stat'])),
                         system=platform.system(), machine=platform.machine(),
                         samples=samples, concurrent=concurrent, concurrent_ms=elapsed, service_memory=memory,
                         limits='Three local samples per TLS path, no warmup or isolated load. First-batch SQL response includes authorization and snapshot acquisition; close is excluded from individual latency. Concurrent samples include explicitly repeated SELECTs after native capacity rejection before any batch; sql_requests records these attempts. Native counters include background recovery, and concurrent windows overlap. Bytes are HTTP bodies, not framing/TLS. RSS/HWM are one process observation, not aggregate deployment memory. No speedup or SLO claim.')), flush=True)


def local_batches(config, definition, sql, *, expected_rows=None, historical=False, slow_ms=0, representation=None):
    """Independent read-only measurement over an owned Unix peer session.

    Historical mode is only for the explicitly selected frozen baseline binary.
    No production caller accepts both result definitions. Rows are bounded by the
    experiment and only their count/digest is retained here.
    """
    import hashlib
    import http.client
    import socket
    from interfaces.sql_sessions.result_frame import Decoder
    decoder = Decoder()
    class Unix(http.client.HTTPConnection):
        def connect(self):
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.settimeout(60)
            self.sock.connect(config['endpoint'].removeprefix('unix:'))
    connection = Unix('localhost')
    instance = session = None
    metrics = dict(requests=0, request_bytes=0, response_bytes=0, canonical_cell_bytes=0)
    def call(action):
        nonlocal instance
        request = json.dumps(dict(version=1, definition=definition, instance=instance, session=session, action=action)).encode()
        control = next(iter(action)) in ('close', 'close_result')
        connection.request('POST', '/v1/sql/control' if control else '/v1/sql/session', request, {'Content-Type': 'application/json'})
        response = connection.getresponse()
        payload = response.read()
        assert response.status == 200, (response.status, payload[:256])
        value = json.loads(payload) if historical else decoder.response(payload, response.getheader('Content-Type'), definition)
        assert value['definition'] == definition, value
        if instance is None: instance = value['instance']
        assert value['instance'] == instance, value
        assert 'err' not in value['result'], value['result']
        metrics['requests'] += 1
        metrics['request_bytes'] += len(request)
        metrics['response_bytes'] += len(payload)
        return value['result']
    cursor = None
    try:
        call(dict(hello={}))
        session = call(dict(open=dict(account=config['account'], database=config['database'], authentication='peer')))['opened']['session']
        metrics.update(requests=0, request_bytes=0, response_bytes=0)
        started = time.perf_counter()
        batch = call(dict(execute=dict(sql=sql, token=None)))['batch']
        first_ms = (time.perf_counter() - started) * 1000
        cursor, schema = batch['cursor'], batch['schema']
        observation = batch['basis'] if historical else batch['observation']
        rows, batches, digest = 0, [], hashlib.sha256()
        row_digests, representation_samples = [], []
        while True:
            assert batch['cursor'] == cursor and batch['schema'] == schema
            assert batch['batch'] == len(batches), batch
            assert (batch['basis'] if historical else batch['observation']) == observation
            assert batch['rows'] or batch['complete']
            for row in batch['rows']:
                assert len(row_digests) < 512, 'measurement row budget exceeded'
                row_digest = hashlib.sha256()
                for cell in row:
                    raw = bytes.fromhex(cell)
                    metrics['canonical_cell_bytes'] += len(raw)
                    framed = len(raw).to_bytes(4, 'little') + raw
                    digest.update(framed); row_digest.update(framed)
                row_digests.append(row_digest.digest())
            rows += len(batch['rows'])
            batches.append(len(batch['rows']))
            if representation is not None:
                representation_samples.append(representation(batch, historical))
            if batch['complete']:
                if not historical: assert batch['completion'] == dict(rows=rows), batch
                break
            if not historical: assert batch['completion'] is None, batch
            if slow_ms: time.sleep(slow_ms / 1000)
            batch = call(dict(fetch=dict(cursor=cursor, batch=len(batches))))['batch']
        terminal_ms = (time.perf_counter() - started) * 1000
        if expected_rows is not None: assert rows == expected_rows, (rows, expected_rows)
        result = dict(profile='local_result_batches', sql=sql, rows=rows, batches=batches,
                    first_batch_ms=first_ms, terminal_ms=terminal_ms, slow_consumer_ms=slow_ms,
                    schema_sha256=hashlib.sha256(bytes.fromhex(schema)).hexdigest(),
                    row_multiset_sha256=hashlib.sha256(b''.join(sorted(row_digests))).hexdigest(),
                    ordered_cells_sha256=digest.hexdigest(), **metrics)
        if representation is not None:
            result.update(representation_samples=representation_samples,
                          timing_includes_codec_experiment=True)
        return result
    finally:
        if cursor is not None: call(dict(close_result=cursor))
        if session is not None: call(dict(close={}))
        connection.close()
