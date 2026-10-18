#!/usr/bin/env python3
"""Downstream consumer of the Nix manifest; runtime has an unavailable PATH."""
import ctypes
import json
import os
from pathlib import Path
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import time

import server
from server_board import Board


def defaults(package):
    """No config file or PATH tools; isolated ports and stable defaults on restart."""
    with tempfile.TemporaryDirectory(prefix='transit-defaults-') as directory:
        root = Path(directory)
        env = {'PATH': '/unavailable', 'HOME': directory, 'LANG': 'C'}
        # Keep this proof independent of an operator's running default server.
        listeners = [socket.socket() for _ in range(7)]
        for listener in listeners: listener.bind(('127.0.0.1', 0))
        selected = [listener.getsockname()[1] for listener in listeners]
        for listener in listeners: listener.close()
        ports = dict(zip(('cold', 'cold_console', 'store', 'node', 'gateway'), selected[:5]))
        env.update({f'TRANSIT_PORTS__{key.upper()}': str(value) for key, value in ports.items()})
        env.update(TRANSIT_APPLICATIONS__PORT=str(selected[5]), TRANSIT_BOARD__PORT=str(selected[6]))
        tools = root/'bin'; tools.mkdir()
        cli = tools/'transit'
        shutil.copy2(package/'bin/transit', cli)
        for name in ('minio', 'ursula', 'transit-node', 'transit-query-host', 'transit-board', 'transit-sql-gateway'):
            (tools/name).symlink_to(package/'bin'/name)
        assert not (root/'share/transit/local-executables.json').exists()
        prior = None
        for variant in ('initialize', 'defaults', 'yaml', 'environment'):
            initialize = variant == 'initialize'
            if variant == 'yaml':
                (root/'transit.yaml').write_text('realm: 1\nports:\n'+''.join(f'  {key}: {value}\n' for key, value in ports.items()))
                for key in ports: env.pop(f'TRANSIT_PORTS__{key.upper()}')
            if variant == 'environment':
                env.update(TRANSIT_PORTS='{"gateway":10000}', TRANSIT_PORTS__GATEWAY=str(ports['gateway']))
            with (root/'stderr').open('wb') as log:
                process = subprocess.Popen([str(cli), 'server', *(['--initialize'] if initialize else [])],
                                           cwd=root, env=env, stdout=subprocess.PIPE, stderr=log)
                try:
                    deadline = time.monotonic()+120
                    while not select.select([process.stdout], [], [], .1)[0]:
                        assert process.poll() is None and time.monotonic() < deadline, (root/'stderr').read_text()
                    line = process.stdout.readline()
                    assert line, (root/'stderr').read_text()
                    report = json.loads(line)
                    assert report['ready'] and report['ui'] == 'ready'
                    assert report['installation'] == str(root/'.transit') and 'console_config' not in report
                    assert not (root/'.transit/console.json').exists() and not (root/'.transit/console.yaml').exists()
                    assert report['gateway_url'] == f"http://127.0.0.1:{ports['gateway']}"
                    record = json.loads((root/'.transit/installation.json').read_text())
                    if prior is not None: assert record['installation'] == prior['installation'] and record['provision'] == prior['provision']
                    prior = record
                    result = subprocess.run([str(cli), 'console', '--no-rc',
                                             '--format', 'json', '-c', 'SELECT COUNT(*) FROM items'], cwd=root, env=env, capture_output=True, timeout=90)
                    assert result.returncode == 0, result
                    queries = server.table_results(json.loads(line) for line in result.stdout.splitlines())
                    assert len(queries) == 1, queries
                    assert server.atom(queries[0], 'unsigned') == '0', queries
                finally:
                    owned = server.children(process.pid)
                    process.terminate()
                    process.wait(timeout=30)
                    server.joined(owned)
                    process.stdout.close()
                assert process.returncode == 0, (root/'stderr').read_text()
        print('Packaged defaults: adjacent executables without a manifest, no-file initialization/restart on isolated ports, default Board, bare-console automatic SQL and identical effective defaults/YAML/environment identity passed with no runtime PATH tools.', flush=True)


def run(package):
    package = Path(package).resolve()
    defaults(package)
    executables = json.loads((package / 'share/transit/local-executables.json').read_text())
    assert set(executables) == {'minio', 'ursula', 'node', 'query_host', 'board', 'sql_gateway'}
    assert all(Path(path).is_file() for path in executables.values())
    # Select the packaged provider before constructing the shared fixture:
    # the source proof's Docker-based MinIO extraction is never invoked here.
    server.minio_binary = lambda: Path(executables['minio'])
    fixture = Board(package / 'bin/transit', executables['node'], executables['query_host'], executables['board'])
    fixture.config['executables'] = executables
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    try:
        fixture.alias = 'serve'
        fixture.start(initialize=True)
        report = fixture.ready()
        assert report['board_url'] == fixture.board_url
        assert b'<script' in fixture.get('/')
        assert len([entry for entry in fixture.atlas()['resources']['entries'] if entry]) == 2
        record = fixture.record()
        fixture.stop()
        fixture.no_ui = True
        fixture.start()
        fixture.ready()
        fixture.stop()
        fixture.no_ui = False
        fixture.start()
        fixture.ready()
        assert fixture.record()['installation'] == record['installation']
        assert fixture.record()['board_receipts'] == record['board_receipts']
        success = True
        print('Packaged downstream manifest: default embedded Board, --no-ui, re-enable and retained identity passed without runtime PATH tools.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Packaged failure evidence retained: {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    run(sys.argv[1])
