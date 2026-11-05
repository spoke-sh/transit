"""Measure verified SQL on digest-pinned nightly containers, without building Transit."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import selectors
import subprocess
import threading
import time
import uuid

from interfaces.cli.table_console import TableConsole, records, results
from runner.capture import provenance, write_json
from runner.paths import ROOT

CASES = ('point_hot', 'point_disjoint', 'scan', 'write_hot', 'write_disjoint', 'mixed')
UNAVAILABLE = ('heap_allocations', 'physical_syncs', 'lock_wait_ns', 'replication_lag', 'network_sql_latency')
DRIVERS = ('performance/load/container_suite.py', 'interfaces/cli/table_console.py',
           'interfaces/cli/console.py', 'interfaces/cli/console_settings.py',
           'query/unified/unified_shell.py', 'runner/paths.py', 'runner/capture.py', 'runner/launch.py')


def docker(*args, timeout=60):
    process = subprocess.run(['docker', *map(str, args)], capture_output=True, text=True, timeout=timeout)
    if process.returncode:
        # Installation logs and console recovery files remain private. Docker
        # argv/error text can contain paths or configuration; publish only the phase.
        raise RuntimeError('docker ' + args[0] + ' failed')
    return process.stdout.strip()


def validate_selection(value):
    if value.get('version') != 1 or value.get('selection') not in ('promoted-nightly', 'explicit-unpromoted-candidate'):
        raise ValueError('missing selected nightly identity')
    if not re.fullmatch(r'ghcr\.io/[a-z0-9_.-]+/[a-z0-9_.-]+@sha256:[0-9a-f]{64}', value['image']):
        raise ValueError('an immutable nightly image digest is required')
    if not re.fullmatch('[0-9a-f]{40}', value['identity']['source_revision']):
        raise ValueError('missing binary source revision')
    for field in ('manifest_sha256', 'checksums_sha256', 'definition'):
        if not re.fullmatch('[0-9a-f]{64}', value[field]):
            raise ValueError('missing release evidence')
    if value['selection'] == 'promoted-nightly' and (not value.get('channel_commit') or not value.get('publication_run')):
        raise ValueError('missing promotion evidence')


def verify_image(selected, inspected, native_platform):
    validate_selection(selected)
    expected = selected['platforms'][native_platform]
    labels = inspected['Config']['Labels']
    if (inspected['Id'] != expected['config'] or
            inspected['Os'] + '/' + inspected['Architecture'] != native_platform or
            labels.get('org.opencontainers.image.revision') != selected['identity']['source_revision'] or
            labels.get('org.opencontainers.image.version') != selected['identity']['release']):
        raise ValueError('pulled image does not match the frozen release')


def command(value, changed=None):
    completion = value.get('completion', {})
    if completion.get('outcome') != 'applied':
        raise ValueError('statement lacks authoritative applied completion')
    if changed is not None and completion.get('counts') != dict(matched=str(changed), changed=str(changed)):
        raise ValueError('statement completion counts disagree')


def rows(value, expected):
    if value.get('complete', {}).get('rows') != str(len(expected)):
        raise ValueError('incomplete result')
    actual = sorted((int(row['id']), int(row['value'])) for row in records(value))
    if actual != sorted(expected.items()):
        raise ValueError('result disagrees with independent workload oracle')


class DockerConsole(TableConsole):
    """Reuse the public-console result reader over one persistent docker exec pipe."""
    def __init__(self, container):
        self.process = subprocess.Popen(['docker', 'exec', '-i', container, '/bin/transit',
                                         'console', '--no-rc', '--format', 'json'],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.buffer = b''
        self.stderr_bytes = 0
        self.diagnostic_codes = set()
        self.drain = threading.Thread(target=self._drain, daemon=True)
        self.drain.start()

    def _drain(self):
        pending = b''
        while block := self.process.stderr.read(4096):
            self.stderr_bytes += len(block)
            pending += block
            while b'\n' in pending:
                line, pending = pending.split(b'\n', 1)
                # Retain bounded typed identifiers, never messages, SQL or payloads.
                match = re.fullmatch(rb'(?:Code|Cause): ([A-Za-z][A-Za-z0-9_.]{0,95})\.', line)
                if match and len(self.diagnostic_codes) < 16:
                    self.diagnostic_codes.add(match[1].decode())
            pending = pending[-4096:]

    def call(self, sql):
        self.deadline = time.monotonic() + 60
        self.remaining_frames = 512
        self.remaining_bytes = 2 * 1024 * 1024
        return super().call(sql)

    def read(self, json_line=True):
        self.remaining_frames -= 1
        if self.remaining_frames < 0 or time.monotonic() >= self.deadline:
            raise TimeoutError('console result bound; original work remains unresolved')
        while b'\n' not in self.buffer:
            with selectors.DefaultSelector() as selector:
                selector.register(self.process.stdout, selectors.EVENT_READ)
                if not selector.select(max(0, self.deadline - time.monotonic())):
                    raise TimeoutError('console result deadline; original work remains unresolved')
            block = os.read(self.process.stdout.fileno(), 65536)
            if not block:
                raise EOFError('console ended before verified completion')
            self.buffer += block
            if len(self.buffer) > 1024 * 1024:
                raise ValueError('console response bound')
        line, self.buffer = self.buffer.split(b'\n', 1)
        self.remaining_bytes -= len(line) + 1
        if self.remaining_bytes < 0:
            raise ValueError('console result byte bound')
        return json.loads(line) if json_line else line

    def close(self, require_success=True):
        try:
            if self.process.poll() is None:
                self.process.stdin.write(b'.quit\n')
                self.process.stdin.flush()
                self.process.stdin.close()
            status = self.process.wait(timeout=10)
            if status != 0 and require_success:
                raise RuntimeError('console exited unsuccessfully')
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait(timeout=10)
            self.drain.join(timeout=10)
            for stream in (self.process.stdin, self.process.stdout, self.process.stderr):
                stream.close()


class Node:
    def __init__(self, name, image, cpus, memory):
        self.name, self.volume = name, name + '-data'
        self.image, self.cpus, self.memory = image, cpus, memory

    def create(self):
        docker('volume', 'create', '--label', 'transit.performance=true', self.volume)
        docker('create', '--name', self.name, '--label', 'transit.performance=true', '--init',
               '--network=none', '--read-only', '--tmpfs', '/tmp:rw,mode=1777,size=128m',
               '--mount', f'type=volume,source={self.volume},target=/data',
               '--cpus', self.cpus, '--memory', self.memory, '--memory-swap', self.memory,
               '--pids-limit', '4096', self.image, 'server', '--no-ui')

    def ready(self):
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            if docker('inspect', '--format', '{{.State.Running}}', self.name) != 'true':
                raise RuntimeError('nightly container stopped before readiness')
            process = subprocess.run(['docker', 'exec', self.name, '/bin/transit', 'console',
                                      '--no-rc', '--format', 'json', '-c', 'SELECT id, value FROM items;'],
                                     capture_output=True, text=True, timeout=30)
            if process.returncode == 0:
                values = results([json.loads(line) for line in process.stdout.splitlines()])
                if len(values) != 1:
                    raise ValueError('unexpected readiness result')
                rows(values[0], {})
                return
            time.sleep(1)
        raise TimeoutError('container readiness deadline')

    def start(self):
        docker('start', self.name)
        self.ready()

    def stop(self):
        docker('stop', '--timeout', '30', self.name, timeout=45)
        state = json.loads(docker('inspect', self.name))[0]['State']
        if state['Running'] or state['OOMKilled'] or state['ExitCode'] != 0:
            raise RuntimeError('container did not shut down cleanly')


class Recorder:
    def __init__(self, path):
        self.stream = path.open('x')
        self.lock = threading.Lock()

    def emit(self, **value):
        with self.lock:
            self.stream.write(json.dumps(value) + '\n')
            self.stream.flush()

    def sample(self, case, worker, index, operation, verify):
        started = time.perf_counter_ns()
        result = None
        try:
            result = operation()
            elapsed = time.perf_counter_ns() - started
            verify(result)
        except Exception as error:
            completion = result.get('completion', {}) if isinstance(result, dict) else {}
            outcome = completion.get('outcome')
            if outcome not in ('applied', 'rejected', 'cancelled', 'partial'):
                outcome = 'unresolved' if isinstance(result, dict) and 'unresolved' in result else 'missing'
            self.emit(phase='sample', case=case, worker=worker, index=index, outcome='failed',
                      elapsed_ns=time.perf_counter_ns() - started, error_type=type(error).__name__,
                      statement_outcome=outcome, verified=False)
            raise
        self.emit(phase='sample', case=case, worker=worker, index=index, outcome='complete',
                  elapsed_ns=elapsed, verified=True)


def plan(case, worker, index, expected):
    table = f'partition_{worker}' if case in ('point_disjoint', 'write_disjoint') else 'hot'
    if case == 'scan':
        return f'SELECT id, value FROM {table};', lambda value: rows(value, expected[table])
    if case.startswith('write') or (case == 'mixed' and index % 2 == 0):
        value = 100000 + worker * 10000 + index
        return f'UPDATE {table} SET value = {value} WHERE id = {worker};', lambda value: command(value, 1)
    value = (100000 + worker * 10000 + index - 1) if case == 'mixed' else expected[table][worker]
    return f'SELECT id, value FROM {table} WHERE id = {worker};', lambda result: rows(result, {worker: value})


def advance_oracle(case, worker, last, expected):
    if case.startswith('write') or case == 'mixed':
        table = f'partition_{worker}' if case == 'write_disjoint' else 'hot'
        final = last - last % 2 if case == 'mixed' else last
        expected[table][worker] = 100000 + worker * 10000 + final


def snapshot(nodes):
    return [json.loads(line) for line in docker('stats', '--no-stream', '--format', '{{json .}}',
                                               *(node.name for node in nodes)).splitlines()]


def inventory(clients, repeat, warmup):
    return {(case, worker, index) for case in CASES for worker in range(clients)
            for index in range(-warmup, repeat)}


def summarize(data):
    if not data or data[0] != dict(phase='campaign', outcome='started') or data[-1] != dict(phase='campaign', outcome='complete'):
        raise ValueError('incomplete container campaign')
    if sum(row['phase'] == 'campaign' for row in data) != 2 or any(
            row['phase'] not in ('campaign', 'manifest', 'sample', 'stage', 'window', 'resources', 'client') for row in data):
        raise ValueError('failed or unknown campaign record')
    manifests = [row for row in data if row['phase'] == 'manifest']
    if len(manifests) != 1:
        raise ValueError('missing or duplicate campaign identity')
    manifest, = manifests
    validate_selection(manifest['selected'])
    clients, repeat, warmup = (manifest[key] for key in ('clients', 'repeat', 'warmup'))
    if any(type(value) is not int or value < 1 for value in (clients, repeat, warmup)) or warmup % 2:
        raise ValueError('invalid workload size')
    if manifest['nodes'] not in (1, 3) or clients > 6 or manifest['rows'] < clients:
        raise ValueError('invalid topology')
    expected = inventory(clients, repeat, warmup)
    samples = {}
    for row in (value for value in data if value['phase'] == 'sample'):
        key = row['case'], row['worker'], row['index']
        if key not in expected or key in samples or row['outcome'] != 'complete' or row['verified'] is not True:
            raise ValueError('failed, unexpected or duplicate sample')
        if type(row['elapsed_ns']) is not int or row['elapsed_ns'] <= 0:
            raise ValueError('invalid timing')
        samples[key] = row
    if samples.keys() != expected:
        raise ValueError('missing workload samples')
    stages = [row for row in data if row['phase'] == 'stage']
    expected_stages = {'setup', 'verify', 'cleanup'} | {f'{kind}_{node}' for node in range(manifest['nodes'])
        for kind in ('startup', 'restart', 'restart_verify')}
    if len(stages) != len(expected_stages) or {row['case'] for row in stages} != expected_stages or any(
            row['outcome'] != 'complete' for row in stages):
        raise ValueError('missing or failed lifecycle evidence')
    windows = [row for row in data if row['phase'] == 'window']
    if len(windows) != len(CASES) or {row['case'] for row in windows} != set(CASES):
        raise ValueError('missing or duplicate workload window')
    summary = {}
    for window in windows:
        case = window['case']
        if type(window['elapsed_ns']) is not int or window['elapsed_ns'] <= 0:
            raise ValueError('invalid workload window')
        values = sorted(samples[case, worker, index]['elapsed_ns'] for worker in range(clients) for index in range(repeat))
        summary[case] = dict(samples=len(values), p50_ns=values[math.ceil(len(values) * .50) - 1],
                            p95_ns=values[math.ceil(len(values) * .95) - 1],
                            p99_ns=values[math.ceil(len(values) * .99) - 1], max_ns=values[-1],
                            verified_operations_per_second=len(values) * 1e9 / window['elapsed_ns'])
    resource_rows = [row for row in data if row['phase'] == 'resources']
    if len(resource_rows) != len(CASES) + 1 or {row['case'] for row in resource_rows} != {'setup', *CASES} or any(
            len(row['containers']) != manifest['nodes'] for row in resource_rows):
        raise ValueError('missing container resource observations')
    clients_closed = [row for row in data if row['phase'] == 'client']
    if (len(clients_closed) != clients + 2 * manifest['nodes'] or
            {row['ordinal'] for row in clients_closed} != set(range(len(clients_closed))) or
            any(row['exit_code'] != 0 for row in clients_closed)):
        raise ValueError('missing or unsuccessful client shutdown')
    return dict(status='complete', qualification='exploratory closed-loop container campaign; no performance budget',
                manifest=manifest, cases=summary)


def run(args):
    if args.nodes not in (1, 3) or not 1 <= args.clients <= 6 or args.clients < args.nodes or not args.clients % args.nodes == 0:
        raise ValueError('use one or three nodes and one to six evenly assigned clients')
    if not args.clients <= args.rows <= 256 or not 2 <= args.repeat <= 256 or not 2 <= args.warmup <= 16 or args.warmup % 2:
        raise ValueError('workload bounds exceeded')
    if not 1 <= args.total_cpus <= 16 or not 3 <= args.total_memory_gib <= 32:
        raise ValueError('resource bounds exceeded')
    args.output.mkdir(parents=True, exist_ok=False)
    recorder = Recorder(args.output / 'samples.jsonl')
    recorder.emit(phase='campaign', outcome='started')
    nodes, shells, controls, all_shells = [], [], [], []
    passed, cleanup_errors = False, []
    try:
        selected = json.loads(args.selection.read_text())
        validate_selection(selected)
        native_platform = 'linux/' + {'x86_64': 'amd64', 'aarch64': 'arm64'}[platform.machine()]
        docker('pull', '--platform', native_platform, selected['image'], timeout=300)
        inspected, = json.loads(docker('image', 'inspect', selected['image']))
        verify_image(selected, inspected, native_platform)
        identity = docker('run', '--rm', '--network=none', '--read-only', selected['image'], '--version')
        if identity != f'Transit {selected["identity"]["release"]} (git {selected["identity"]["source_revision"]}; CLI contract 1)':
            raise ValueError('container executable identity mismatch')
        recorder.emit(phase='manifest', version=1, selected=selected, source=provenance(ROOT),
                      drivers={name: hashlib.sha256((ROOT / 'tests' / name).read_bytes()).hexdigest() for name in DRIVERS},
                      nodes=args.nodes, clients=args.clients, rows=args.rows, repeat=args.repeat, warmup=args.warmup,
                      native_platform=native_platform, image_config=inspected['Id'],
                      topology='single-authority' if args.nodes == 1 else 'client-routed-independent-authorities',
                      placement='one physical Docker host; no cross-node SQL or replication',
                      total_cpus=args.total_cpus, total_memory_bytes=args.total_memory_gib * 1024**3,
                      host=dict(kernel=platform.release(), affinity=sorted(os.sched_getaffinity(0)),
                                docker=json.loads(docker('info', '--format', '{{json .}}'))['Driver']),
                      durability='synchronous local disk volumes', maintenance='default enabled',
                      cache='fresh installation then warm reads; no OS cache eviction',
                      transport='persistent console via docker exec pipes and local SQL; client overhead included',
                      unavailable=list(UNAVAILABLE))
        prefix = 'transit-perf-' + uuid.uuid4().hex[:12]
        expected = []
        for ordinal in range(args.nodes):
            node = Node(f'{prefix}-{ordinal}', selected['image'], f'{args.total_cpus / args.nodes:.6f}',
                        args.total_memory_gib * 1024**3 // args.nodes)
            nodes.append(node)
            node.create()
            started = time.perf_counter_ns()
            node.start()
            recorder.emit(phase='stage', case=f'startup_{ordinal}', outcome='complete', elapsed_ns=time.perf_counter_ns() - started)
            control = DockerConsole(node.name)
            controls.append(control)
            all_shells.append(control)
            tables = {'hot', *(f'partition_{worker}' for worker in range(args.clients) if worker % args.nodes == ordinal)}
            oracle = {table: {row: row * 10 for row in range(args.rows)} for table in tables}
            expected.append(oracle)
            for table in sorted(tables):
                command(control.call(f'CREATE TABLE {table} (id BIGINT PRIMARY KEY, value BIGINT);'))
                # Bounded deterministic setup; excluded from operation samples.
                values = ','.join(f'({key},{value})' for key, value in oracle[table].items())
                command(control.call(f'INSERT INTO {table} VALUES {values};'), args.rows)
                rows(control.call(f'SELECT id, value FROM {table};'), oracle[table])
        for worker in range(args.clients):
            shell = DockerConsole(nodes[worker % args.nodes].name)
            shells.append(shell)
            all_shells.append(shell)
            rows(shell.call('SELECT id, value FROM items;'), {})
        recorder.emit(phase='stage', case='setup', outcome='complete')
        recorder.emit(phase='resources', case='setup', containers=snapshot(nodes))
        with ThreadPoolExecutor(max_workers=args.clients) as pool:
            for case in CASES:
                def work(worker, indices, barrier=None):
                    if barrier is not None:
                        barrier.wait(timeout=30)
                    oracle = expected[worker % args.nodes]
                    for index in indices:
                        sql, verify = plan(case, worker, index, oracle)
                        recorder.sample(case, worker, index, lambda: shells[worker].call(sql), verify)
                futures = [pool.submit(work, worker, range(-args.warmup, 0)) for worker in range(args.clients)]
                for future in futures:
                    future.result()
                barrier = threading.Barrier(args.clients + 1)
                futures = [pool.submit(work, worker, range(args.repeat), barrier) for worker in range(args.clients)]
                started = time.perf_counter_ns()
                barrier.wait(timeout=30)
                for future in futures:
                    future.result()
                recorder.emit(phase='window', case=case, elapsed_ns=time.perf_counter_ns() - started)
                for worker in range(args.clients):
                    advance_oracle(case, worker, args.repeat - 1, expected[worker % args.nodes])
                recorder.emit(phase='resources', case=case, containers=snapshot(nodes))
        for ordinal, control in enumerate(controls):
            for table, oracle in expected[ordinal].items():
                rows(control.call(f'SELECT id, value FROM {table};'), oracle)
        recorder.emit(phase='stage', case='verify', outcome='complete')
        for shell in [*shells, *controls]:
            shell.close()
        shells.clear()
        controls.clear()
        for ordinal, node in enumerate(nodes):
            node.stop()
            started = time.perf_counter_ns()
            node.start()
            recorder.emit(phase='stage', case=f'restart_{ordinal}', outcome='complete', elapsed_ns=time.perf_counter_ns() - started)
            control = DockerConsole(node.name)
            controls.append(control)
            all_shells.append(control)
            for table, oracle in expected[ordinal].items():
                rows(control.call(f'SELECT id, value FROM {table};'), oracle)
            recorder.emit(phase='stage', case=f'restart_verify_{ordinal}', outcome='complete')
        passed = True
    except Exception as error:
        recorder.emit(phase='failure', outcome='failed', error_type=type(error).__name__)
        raise
    finally:
        for shell in [*shells, *controls]:
            try:
                shell.close(require_success=passed)
            except Exception as error:
                cleanup_errors.append(type(error).__name__)
        for node in reversed(nodes):
            try:
                node.stop()
                docker('rm', node.name)
                if passed and not cleanup_errors:
                    docker('volume', 'rm', node.volume)
            except Exception as error:
                cleanup_errors.append(type(error).__name__)
        for ordinal, shell in enumerate(all_shells):
            recorder.emit(phase='client', ordinal=ordinal, exit_code=shell.process.poll(),
                          stderr_bytes=shell.stderr_bytes, diagnostic_codes=sorted(shell.diagnostic_codes))
        recorder.emit(phase='stage', case='cleanup', outcome='complete' if not cleanup_errors else 'failed', errors=cleanup_errors)
        recorder.emit(phase='campaign', outcome='complete' if passed and not cleanup_errors else 'failed')
        recorder.stream.close()
        if not passed or cleanup_errors:
            write_json(args.output / 'failure.json', dict(status='failed', cleanup_errors=cleanup_errors,
                       private_volumes=[node.volume for node in nodes]))
    if cleanup_errors:
        raise RuntimeError('container cleanup failed')
    summary = summarize([json.loads(line) for line in (args.output / 'samples.jsonl').read_text().splitlines()])
    write_json(args.output / 'summary.json', summary)
    lines = ['| Workload | Samples | p50 ms | p95 ms | p99 ms | Verified ops/s |',
             '| --- | ---: | ---: | ---: | ---: | ---: |']
    for case, result in summary['cases'].items():
        lines.append(f'| {case} | {result["samples"]} | {result["p50_ns"]/1e6:.3f} | {result["p95_ns"]/1e6:.3f} | '
                     f'{result["p99_ns"]/1e6:.3f} | {result["verified_operations_per_second"]:.2f} |')
    (args.output / 'summary.md').write_text(f'{summary["manifest"]["topology"]}; {selected["image"]}\n\n' +
        '\n'.join(lines) + '\n\nEmpirical closed-loop samples on one Docker host; no SLO, replication or multi-host claim.\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--selection', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--nodes', type=int, choices=(1, 3), required=True)
    parser.add_argument('--clients', type=int, default=6)
    parser.add_argument('--rows', type=int, default=64)
    parser.add_argument('--repeat', type=int, default=32)
    parser.add_argument('--warmup', type=int, default=2)
    parser.add_argument('--total-cpus', type=int, default=4)
    parser.add_argument('--total-memory-gib', type=int, default=6)
    run(parser.parse_args())


if __name__ == '__main__':
    main()
