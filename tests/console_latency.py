#!/usr/bin/env python3
"""Measure the real local empty-table path without imposing a latency target."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from server import Fixture, children, command


def digest(path):
    with open(path, 'rb') as binary:
        return hashlib.file_digest(binary, 'sha256').hexdigest()


def override(fixture, role, field, value):
    """Change only this owned fixture's generated child configuration."""
    if value is None:
        return
    executable = fixture.config['executables'][role]
    wrapper = fixture.root / (role + '-control')
    wrapper.write_text(f'''#!{sys.executable}
import json, os, sys
from pathlib import Path
bootstrap = sys.argv[1] == '--bootstrap-json'
config = json.loads(sys.argv[2] if bootstrap else Path(sys.argv[1]).read_text())
config[{field!r}] = {value!r}
if bootstrap:
    sys.argv[2] = json.dumps(config)
else:
    Path(sys.argv[1]).write_text(json.dumps(config))
os.execv({executable!r}, [{executable!r}] + sys.argv[1:])
''')
    wrapper.chmod(0o700)
    fixture.config['executables'][role] = str(wrapper)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for role in ('cli', 'node', 'host'):
        parser.add_argument(role)
    parser.add_argument('--resident-pages', type=int, choices=range(1025), metavar='0..1024')
    parser.add_argument('--worker-interval-ms', type=int, choices=range(1, 60001), metavar='1..60000')
    parser.add_argument('--single', action='store_true', help='measure only the first empty SELECT')
    args = parser.parse_args()
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Fixture(args.cli, args.node, args.host)
    success = False
    try:
        # Freeze all selected executables for the measurement and retained identity.
        for role in ('node', 'query_host'):
            frozen = fixture.root / role
            shutil.copy2(fixture.config['executables'][role], frozen)
            fixture.config['executables'][role] = str(frozen)
        binaries = {'cli': fixture.cli, **fixture.config['executables']}
        node = binaries['node']
        override(fixture, 'node', 'resident_pages', args.resident_pages)
        override(fixture, 'query_host', 'interval_ms', args.worker_interval_ms)
        fixture.path.write_text(json.dumps(fixture.config))
        print(json.dumps({'executables': {role: digest(path) for role, path in
              binaries.items()}, 'source_rows': 0,
              'overrides': {'resident_pages': args.resident_pages,
                            'worker_interval_ms': args.worker_interval_ms}}), flush=True)
        fixture.start(initialize=True)
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
        time.sleep(3)
        print(json.dumps({'phase': 'idle', 'seconds': time.monotonic() - before,
                          'node_cpu_seconds': cpu() - before_cpu}), flush=True)

        # Sequential queries expose warm/history behavior as well as presentation.
        queries = [('table', 'SELECT * FROM items;'),
                   ('table', 'SELECT * FROM items;'),
                   ('json', 'SELECT * FROM items;'),
                   ('table', 'SELECT COUNT(*) FROM items;')]
        for mode, sql in queries[:1] if args.single else queries:
            before_cpu, before = cpu(), time.monotonic()
            result = subprocess.run([fixture.cli, 'console', '--no-rc', '--format', mode],
                                    input='.timing on\n' + sql + '\n', cwd=fixture.root,
                                    capture_output=True, text=True, timeout=420,
                                    env={'PATH': '/unavailable'})
            assert result.returncode == 0, result.stderr
            assert re.fullmatch(r'Time: \d+ ms \((?:[a-z]+ \d+ ms, )*[a-z]+ \d+ ms\)\n', result.stderr), result.stderr
            if mode == 'json':
                assert json.loads(result.stdout)['complete_coverage']
            else:
                assert result.stdout.startswith('┌') and result.stdout.endswith(('0 rows\n', '1 row\n'))
            print(json.dumps({'mode': mode, 'sql': sql, 'seconds': time.monotonic() - before,
                              'node_cpu_seconds': cpu() - before_cpu,
                              'stdout_bytes': len(result.stdout.encode()),
                              'timing': result.stderr.strip()}), flush=True)
        success = True
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Latency fixture retained at {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    main()
