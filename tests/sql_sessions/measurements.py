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
        batch = client.execute('SELECT id FROM native_sessions')['batch']
        sample = dict(client.sample, path=label, rows=len(batch['rows']),
                      complete=batch['complete'], sql_requests=1)
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
                         limits='Three local samples per TLS path, no warmup or isolated load. First-batch SQL response includes authorization and snapshot acquisition; close is excluded from individual latency. Native counters include background recovery, and concurrent windows overlap. Bytes are HTTP bodies, not framing/TLS. RSS/HWM are one process observation, not aggregate deployment memory. No speedup or SLO claim.')), flush=True)
