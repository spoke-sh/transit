#!/usr/bin/env python3
"""Measure owned local queries, with optional instrumented transport counts."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import time

from server import Fixture, children, command
from storage import free_port
from latency_probe import Probe


def digest(path):
    with open(path, 'rb') as binary:
        return hashlib.file_digest(binary, 'sha256').hexdigest()


def override(fixture, role, fields, probe_gate=None):
    """Change only this owned fixture's generated child configuration."""
    fields = {key: value for key, value in fields.items() if value is not None}
    if not fields:
        return
    executable = fixture.config['executables'][role]
    wrapper = fixture.root / (role + '-control')
    wrapper.write_text(f'''#!{sys.executable}
import json, os, sys, time
from pathlib import Path
bootstrap = sys.argv[1] == '--bootstrap-json'
config = json.loads(sys.argv[2] if bootstrap else Path(sys.argv[1]).read_text())
config.update({fields!r})
if bootstrap:
    sys.argv[2] = json.dumps(config)
else:
    Path(sys.argv[1]).write_text(json.dumps(config))
gate = {str(probe_gate) if probe_gate else None!r}
if gate:
    Path(gate).touch()
    deadline = time.monotonic() + 30
    while not Path(gate + '.ready').exists():
        if time.monotonic() > deadline: raise TimeoutError('measurement proxy not ready')
        time.sleep(0.01)
os.execv({executable!r}, [{executable!r}] + sys.argv[1:])
''')
    wrapper.chmod(0o700)
    fixture.config['executables'][role] = str(wrapper)


def measured_run(args, cwd, timeout=420):
    """Drain both pipes, sample resident memory, and time the first output byte.

    First output is observable presentation latency, not an inferred server
    execution time. Memory is sampled every 20 ms and can miss shorter peaks.
    """
    started = time.monotonic()
    process = subprocess.Popen(args, cwd=cwd, stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               env={'PATH': '/unavailable'})
    first = None
    peak = 0
    buffers = [bytearray(), bytearray()]
    try:
        with selectors.DefaultSelector() as selector:
            for index, pipe in enumerate((process.stdout, process.stderr)):
                selector.register(pipe, selectors.EVENT_READ, index)
            while selector.get_map():
                if time.monotonic() - started > timeout:
                    raise TimeoutError('console measurement exceeded deadline')
                try:
                    resident = int(Path(f'/proc/{process.pid}/statm').read_text().split()[1])
                    peak = max(peak, resident * os.sysconf('SC_PAGE_SIZE'))
                except FileNotFoundError:
                    pass
                for key, _ in selector.select(timeout=0.02):
                    data = os.read(key.fileobj.fileno(), 65536)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    if key.data == 0 and first is None:
                        first = time.monotonic() - started
                    buffers[key.data].extend(data)
                    if len(buffers[key.data]) > 16 * 1024 * 1024:
                        raise ValueError('console output exceeds measurement bound')
        code = process.wait(timeout=10)
        return code, *(buffer.decode() for buffer in buffers), {
            'seconds': time.monotonic() - started,
            'first_stdout_seconds': first, 'sampled_peak_rss_bytes': peak}
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=10)
        process.stdout.close()
        process.stderr.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for role in ('cli', 'node', 'host'):
        parser.add_argument(role)
    parser.add_argument('--resident-pages', type=int, choices=range(1025), metavar='0..1024')
    parser.add_argument('--worker-interval-ms', type=int, choices=range(1, 60001), metavar='1..60000')
    parser.add_argument('--single', action='store_true', help='measure only the first empty SELECT')
    parser.add_argument('--repeat', type=int, default=1, choices=range(1, 101), metavar='1..100')
    parser.add_argument('--age-queries', type=int, default=0, choices=range(1001), metavar='0..1000',
                        help='execute this many unmeasured SELECTs before measurements')
    parser.add_argument('--instrument', action='store_true',
                        help='count native/provider attempts through loopback proxies; adds overhead')
    args = parser.parse_args()
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Fixture(args.cli, args.node, args.host)
    success = False
    probes = {}
    try:
        # Freeze all selected executables for the measurement and retained identity.
        for role in ('node', 'query_host'):
            frozen = fixture.root / role
            shutil.copy2(fixture.config['executables'][role], frozen)
            fixture.config['executables'][role] = str(frozen)
        binaries = {'cli': fixture.cli, **fixture.config['executables']}
        node = binaries['node']
        node_fields = {'resident_pages': args.resident_pages}
        if args.instrument:
            real_port = free_port()
            probes['provider'] = Probe(f"http://127.0.0.1:{fixture.config['ports']['store']}")
            node_fields.update(port=real_port, ursula_url=probes['provider'].url)
        gate = fixture.root / 'probe-gate' if args.instrument else None
        override(fixture, 'node', node_fields, gate)
        override(fixture, 'query_host', {'interval_ms': args.worker_interval_ms})
        fixture.path.write_text(json.dumps(fixture.config))
        print(json.dumps({'executables': {role: digest(path) for role, path in
              binaries.items()}, 'source_rows': 0, 'instrumented': args.instrument,
              'age_queries': args.age_queries, 'repeat': args.repeat,
              'cache_condition': 'post-bootstrap; later queries share the node cache',
              'overrides': {'resident_pages': args.resident_pages,
                            'worker_interval_ms': args.worker_interval_ms}}), flush=True)
        fixture.start(initialize=True)
        if gate:
            deadline = time.monotonic() + 90
            while not gate.exists():
                assert fixture.process.poll() is None, Path(fixture.logs[-1].name).read_text()
                assert time.monotonic() < deadline, 'node did not reach measurement gate'
                time.sleep(0.02)
            probes['native'] = Probe(f'http://127.0.0.1:{real_port}',
                                     fixture.config['ports']['node'], native=True)
            Path(str(gate) + '.ready').touch()
        fixture.ready()
        invalid = subprocess.run([fixture.cli, 'console', '--no-rc'],
                                 input='.timing on\nCREATE KV items (UTF8);', cwd=fixture.root,
                                 capture_output=True, text=True, timeout=30,
                                 env={'PATH': '/unavailable'})
        assert invalid.returncode == 1 and not invalid.stdout, invalid
        assert 'Time: ' in invalid.stderr and 'error: ' in invalid.stderr, invalid.stderr
        authority = [pid for pid in children(fixture.process.pid)
                     if command(pid).startswith(node + ' ') and '--maintain' not in command(pid)]
        assert len(authority) == 1, authority

        def cpu():
            fields = Path(f'/proc/{authority[0]}/stat').read_text().split()
            return sum(map(int, fields[13:15])) / os.sysconf('SC_CLK_TCK')

        before_cpu, before = cpu(), time.monotonic()
        counters = {name: probe.snapshot() for name, probe in probes.items()}
        time.sleep(3)
        print(json.dumps({'phase': 'idle', 'seconds': time.monotonic() - before,
                          'node_cpu_seconds': cpu() - before_cpu,
                          'attempts': {name: dict(probe.snapshot() - counters[name])
                                       for name, probe in probes.items()}}), flush=True)

        script = fixture.root / 'measurement.sql'
        def execute(mode, sql):
            script.write_text('.timing on\n' + sql + '\n')
            return measured_run([fixture.cli, 'console', '--no-rc', '--format', mode,
                                 '-f', str(script)], fixture.root)

        for _ in range(args.age_queries):
            code, _, stderr, _ = execute('table', 'SELECT * FROM items;')
            assert code == 0, stderr

        # Sequential queries expose warm/history behavior as well as presentation.
        queries = [('table', 'SELECT * FROM items;'),
                   ('table', 'SELECT * FROM items;'),
                   ('json', 'SELECT * FROM items;'),
                   ('table', 'SELECT COUNT(*) FROM items;')]
        selected = queries[:1] if args.single else queries
        for index, (mode, sql) in enumerate(selected * args.repeat):
            before_cpu = cpu()
            counters = {name: probe.snapshot() for name, probe in probes.items()}
            code, stdout, stderr, measurements = execute(mode, sql)
            assert code == 0, stderr
            assert re.fullmatch(r'Time: \d+ ms \((?:[a-z]+ \d+ ms, )*[a-z]+ \d+ ms\)\n', stderr), stderr
            if mode == 'json':
                assert json.loads(stdout)['complete_coverage']
            else:
                assert stdout.startswith('┌') and stdout.endswith(('0 rows\n', '1 row\n'))
            print(json.dumps({'phase': 'query', 'index': index, 'mode': mode, 'sql': sql, **measurements,
                              'node_cpu_seconds': cpu() - before_cpu,
                              'stdout_bytes': len(stdout.encode()), 'timing': stderr.strip(),
                              'attempts': {name: dict(probe.snapshot() - counters[name])
                                           for name, probe in probes.items()}}), flush=True)
        success = True
    finally:
        fixture.cleanup()
        for probe in probes.values():
            probe.close()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Latency fixture retained at {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    main()
