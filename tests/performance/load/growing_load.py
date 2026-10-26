"""Finite offered-load experiment through the public growing service.

The producer schedules every request independently of completion. Its 48-item
test queue and worker count are explicit; queueing time is included in latency.
Protocol signing and the drain oracle live in the Zig public-client driver.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from http.client import HTTPConnection
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import resource
import subprocess
import threading
import time
import tempfile
from cold_storage import ColdStore
from pages import metrics, sample_process
from harness.ursula import Fixture
from harness.services import free_port, wait_ready


def distribution(samples):
    ordered = sorted(samples)
    return {f'p{p}': ordered[max(0, (len(ordered) * p + 99) // 100 - 1)]
            if len(ordered) >= minimum else None for p, minimum in ((50, 1), (95, 20), (99, 100))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('node')
    parser.add_argument('caller')
    parser.add_argument('--rows', type=int, default=64)
    parser.add_argument('--cache', type=int, default=1)
    parser.add_argument('--payload', type=int, default=256)
    parser.add_argument('--hot-percent', type=int, default=90)
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--interval-ms', type=float, default=1)
    parser.add_argument('--cold-s3', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if not 1 <= args.workers <= 16 or not 0 <= args.interval_ms <= 1000:
        parser.error('workers must be 1..16 and interval-ms 0..1000')
    from runner.paths import ROOT as root
    disk = root / '.cache/verification/storage'
    disk.mkdir(parents=True, exist_ok=True)
    tempfile.tempdir = str(disk)  # Nix's TMPDIR may be tmpfs; measure the checkout filesystem.
    node, caller = (str(Path(path).resolve(strict=True)) for path in (args.node, args.caller))
    artifact = args.output or root / '.cache/verification/growing-load.json'
    artifact.parent.mkdir(parents=True, exist_ok=True)
    evidence = dict(version=1, status='inconclusive', profile='serialized v1 authority, public Zig client, finite offered load',
                    revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                    dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'])),
                    binaries={Path(p).name: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in (node, caller)},
                    platform=platform.platform(), logical_cpus=os.cpu_count(), affinity=sorted(os.sched_getaffinity(0)),
                    stack_limit_bytes=resource.getrlimit(resource.RLIMIT_STACK)[0],
                    zig=subprocess.check_output(['zig', 'version'], text=True).strip(),
                    ursula=subprocess.check_output(['ursula', '--version'], text=True).strip(),
                    workload={k: getattr(args, k) for k in ('rows', 'cache', 'payload', 'hot_percent', 'workers', 'interval_ms', 'cold_s3')})
    try:
        with ExitStack() as resources:
            cold = resources.enter_context(ColdStore()) if args.cold_s3 else None
            fixture = resources.enter_context(Fixture(cold.config() if cold else None))
            evidence['filesystem'] = subprocess.check_output(['stat', '-f', '-c', '%T', fixture.root], text=True).strip()
            public = json.loads(subprocess.check_output([caller, 'public'], timeout=10))
            port = free_port()
            url = f'http://127.0.0.1:{port}'
            config = fixture.root / 'node.json'
            config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000),
                ursula_url=fixture.url, bucket='growing-load', journal='authority', port=port,
                resident_pages=args.cache, request_timeout_ms=15000, request_metrics=True)))
            manifest = fixture.root / 'expected.json'
            log = resources.enter_context((fixture.root / 'node.log').open('w+'))
            authority = None
            stop = threading.Event()
            peaks = {name: metrics() for name in ('node', 'ursula', 'cold_store', 'generator')}

            def sample():
                while not stop.wait(.02):
                    if authority:
                        sample_process(authority.pid, peaks['node'])
                    if fixture.server:
                        sample_process(fixture.server.pid, peaks['ursula'])
                    if cold:
                        sample_process(cold.pid, peaks['cold_store'])
                    sample_process(os.getpid(), peaks['generator'])

            sampler = threading.Thread(target=sample)
            sampler.start()

            def start():
                nonlocal authority
                started = time.monotonic()
                authority = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(fixture.http, authority, url + '/health')
                return time.monotonic() - started

            def driver(phase):
                result = subprocess.run([caller, url, phase, str(manifest), str(args.rows), str(args.payload), str(args.hot_percent)],
                                        capture_output=True, text=True, timeout=600, check=True)
                return json.loads(result.stdout)

            def request(body, offered):
                started = time.monotonic()
                connection = HTTPConnection('127.0.0.1', port, timeout=20)
                try:
                    connection.request('POST', '/v1/command', json.dumps(body), {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = json.loads(response.read())
                    finished = time.monotonic()
                    return dict(status=response.status, receipt=data, offered=offered, finished=finished,
                                queue_ms=(started - offered) * 1000, latency_ms=(finished - offered) * 1000,
                                work=json.loads(response.getheader('x-transit-work', 'null')))
                finally:
                    connection.close()

            try:
                subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)
                evidence['node_start_seconds'] = start()
                started = time.monotonic()
                prepared = driver('setup')
                evidence['setup_seconds'] = time.monotonic() - started
                assert len(prepared['requests']) == 48
                offered_at = time.monotonic()
                scheduling = []
                with ThreadPoolExecutor(max_workers=args.workers) as pool, ThreadPoolExecutor(max_workers=1) as control_pool:
                    futures = []
                    control = None
                    for i, body in enumerate(prepared['requests']):
                        due = offered_at + i * args.interval_ms / 1000
                        time.sleep(max(0, due - time.monotonic()))
                        scheduling.append((time.monotonic() - due) * 1000)
                        futures.append(pool.submit(request, body, due))
                        if i == 24:
                            control = control_pool.submit(request, prepared['control'], time.monotonic())
                    results = [f.result(timeout=60) for f in futures]
                    controlled = control.result(timeout=60)
                # Refusal at the listener is known pre-admission. Never classify
                # arbitrary 503s or failed exchanges as a safe rejection.
                def capacity(result):
                    return result['status'] == 503 and result['receipt'] == {'err': 'HttpCapacity'}
                assert all(r['status'] == 200 or capacity(r) for r in results), results
                accepted = [(body, r) for body, r in zip(prepared['requests'], results) if r['status'] == 200]
                assert all(r['receipt']['position'] > 0 for _, r in accepted)
                assert len({r['receipt']['position'] for _, r in accepted}) == len(accepted)
                assert controlled['status'] == 200 or capacity(controlled), controlled
                # Qualify revocation after the measured burst if its initial
                # attempt was refused. Keep this outside admission throughput.
                evidence['control_initial_status'] = controlled['status']
                if capacity(controlled):
                    retried_control = request(prepared['control'], time.monotonic())
                    assert retried_control['status'] == 200, retried_control
                    evidence['control_after_burst_ms'] = retried_control['latency_ms']
                expected = json.loads(manifest.read_text())
                expected['accepted'] = [r['status'] == 200 for r in results]
                manifest.write_text(json.dumps(expected))
                denied = request(prepared['denied'], time.monotonic())
                assert denied['status'] == 403, denied
                evidence.update(offered=48, admitted=len(accepted), rejected=48-len(accepted), uncertain=0,
                                latency_ms=distribution([r['latency_ms'] for r in results]),
                                admitted_latency_ms=distribution([r['latency_ms'] for _, r in accepted]),
                                rejected_latency_ms=distribution([r['latency_ms'] for r in results if capacity(r)]),
                                generator_queue_ms=distribution([r['queue_ms'] for r in results]),
                                generator_schedule_lag_ms=distribution(scheduling),
                                control_latency_ms=controlled['latency_ms'],
                                admitted_per_second=len(accepted) / (max(r['finished'] for r in results) - offered_at),
                                attempts=[{k: r[k] for k in ('status', 'queue_ms', 'latency_ms', 'work')} for r in results])
                # Duplicate all receipts while the accepted backlog is retained.
                for body, original in accepted:
                    retried = request(body, time.monotonic())
                    assert retried['status'] == 200 and retried['receipt'] == original['receipt']
                evidence['oldest_accepted_queue_age_lower_bound_ms'] = (
                    (time.monotonic() - min(r['finished'] for _, r in accepted)) * 1000 if accepted else None)
                started = time.monotonic()
                evidence['drain'] = driver('drain')
                evidence['drain_seconds'] = time.monotonic() - started
                authority.kill()
                authority.wait(timeout=10)
                authority = None
                fixture.stop()
                started = time.monotonic()
                fixture.start()
                evidence['provider_restart_seconds'] = time.monotonic() - started
                evidence['node_restart_seconds'] = start()
                evidence['recovered'] = driver('recover')
                # Historical receipts and revocation survive node/provider loss.
                for body, original in accepted:
                    retried = request(body, time.monotonic())
                    assert retried['status'] == 200 and retried['receipt'] == original['receipt']
                assert request(prepared['denied'], time.monotonic())['status'] == 403
                evidence['wal_file_bytes'] = sum(p.stat().st_size for p in (fixture.root / 'wal').rglob('*') if p.is_file())
                if cold:
                    evidence.update(cold_provider=cold.identity, cold_file_bytes=cold.file_bytes(), cold_data_objects=cold.data_objects())
                    assert evidence['cold_data_objects'] > 0
            except subprocess.CalledProcessError as error:
                raise RuntimeError((error.stderr or '')[-12000:]) from error
            finally:
                if authority:
                    authority.kill()
                    authority.wait(timeout=10)
                stop.set()
                sampler.join(timeout=5)
                assert not sampler.is_alive()
                evidence['sampled_peak'] = peaks
        evidence['status'] = 'passed'
        print('Growing offered load: ' + json.dumps(evidence), flush=True)
    finally:
        artifact.write_text(json.dumps(evidence, indent=2) + '\n')


if __name__ == '__main__':
    main()
