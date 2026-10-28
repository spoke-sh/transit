#!/usr/bin/env python3
"""One copied executable, default server/console and no runtime PATH tools."""
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

from harness import phases, processes
from interfaces.cli.table_console import results as table_results, atom, records
from interfaces.installation.server_board import Board


def console(root, env, cli, label, *args, input=None):
    # Keep partial output when the existing deadline kills a console wait.
    # A timeout leaves accepted work uncertain; these files are diagnostic
    # evidence, never instructions to submit the statements again.
    stdout, stderr = root / f'{label}.stdout', root / f'{label}.stderr'
    with phases.phase('console', label), stdout.open('wb') as output, stderr.open('wb') as errors:
        result = subprocess.run([str(cli), 'console', *args], input=input, text=True,
                                cwd=root, env=env, stdout=output, stderr=errors, timeout=90)
    result.stdout, result.stderr = stdout.read_text(), stderr.read_text()
    return result


def defaults(binary):
    """No config file or PATH tools; isolated ports and stable defaults on restart."""
    root = Path(tempfile.mkdtemp(prefix='transit-defaults-', dir='/var/tmp'))
    directory = str(root)
    success = False
    print(f'Single executable default workflow: {root}', flush=True)
    try:
        env = {'PATH': '/unavailable', 'HOME': directory, 'LANG': 'C'}
        # Keep this proof independent of an operator's running default server.
        listeners = [socket.socket() for _ in range(5)]
        for listener in listeners: listener.bind(('127.0.0.1', 0))
        selected = [listener.getsockname()[1] for listener in listeners]
        for listener in listeners: listener.close()
        ports = dict(zip(('node', 'gateway'), selected[:2]))
        env.update({f'TRANSIT_PORTS__{key.upper()}': str(value) for key, value in ports.items()})
        env.update(TRANSIT_APPLICATIONS__PORT=str(selected[2]), TRANSIT_BOARD__PORT=str(selected[3]),
                   TRANSIT_SQL__HEALTH_PORT=str(selected[4]))
        tools = root/'bin'; tools.mkdir()
        cli = tools/'transit'
        shutil.copy2(binary, cli)
        assert list(tools.iterdir()) == [cli]
        assert not (root/'share/transit/local-executables.json').exists()
        prior = None
        for variant in ('first-start', 'defaults', 'yaml', 'environment'):
            if variant == 'yaml':
                (root/'transit.yaml').write_text('realm: 1\nports:\n'+''.join(f'  {key}: {value}\n' for key, value in ports.items()))
                for key in ports: env.pop(f'TRANSIT_PORTS__{key.upper()}')
            if variant == 'environment':
                env.update(TRANSIT_PORTS='{"gateway":10000}', TRANSIT_PORTS__GATEWAY=str(ports['gateway']))
            log_path = root / f'{variant}.server.stderr'
            with log_path.open('wb') as log:
                process = subprocess.Popen([str(cli), 'server'],
                                           cwd=root, env=env, stdout=subprocess.PIPE, stderr=log)
                try:
                    deadline = time.monotonic()+120
                    while not select.select([process.stdout], [], [], .1)[0]:
                        assert process.poll() is None and time.monotonic() < deadline, log_path.read_text()
                    line = process.stdout.readline()
                    assert line, log_path.read_text()
                    report = json.loads(line)
                    assert report['ready'] and report['ui'] == 'ready'
                    # The machine record describes core readiness. The human
                    # ready announcement also waits for local console discovery,
                    # within the same startup budget (no additional wait window).
                    while 'server.ready Server is ready' not in log_path.read_text():
                        assert process.poll() is None and time.monotonic() < deadline, log_path.read_text()
                        time.sleep(.1)
                    assert report['installation'] == str(root/'.transit') and 'console_config' not in report
                    assert not (root/'.transit/console.json').exists() and not (root/'.transit/console.yaml').exists()
                    assert report['gateway_url'] == f"http://127.0.0.1:{ports['gateway']}"
                    node = json.loads((root/'.transit/node.json').read_text())
                    assert node['table'] is not None and node['storage']['maintenance']['flush']['enabled']
                    owned = processes.children(process.pid)
                    assert owned and all(Path(f'/proc/{pid}/exe').resolve() == cli for pid in owned), owned
                    record = json.loads((root/'.transit/installation.json').read_text())
                    if prior is not None: assert record['installation'] == prior['installation'] and record['provision'] == prior['provision']
                    prior = record
                    if variant == 'first-start':
                        # Exactly the human-facing invocation, with SQL supplied
                        # on stdin. No role, connection or engine-selection flags.
                        human = console(root, env, cli, 'first-start-statements', input=(
                            "CREATE TABLE packaging_probe (id BIGINT PRIMARY KEY, title TEXT);\n"
                            "INSERT INTO packaging_probe (id, title) VALUES (9001, 'retained');\n"
                            "ALTER TABLE packaging_probe ADD COLUMN score BIGINT DEFAULT 7;\n"
                            "ALTER TABLE packaging_probe ALTER COLUMN score SET DEFAULT 9;\n"
                            "SELECT id, title, score FROM packaging_probe;\n"))
                        assert human.returncode == 0 and 'retained' in human.stdout, human
                        deadline = time.monotonic()+30
                        while not list((root/'.transit/data/native').rglob('*.tseg')):
                            assert process.poll() is None and time.monotonic() < deadline, 'Default automatic Table flush did not publish a segment'
                            time.sleep(.1)
                    result = console(root, env, cli, f'{variant}-items', '--no-rc',
                                     '--format', 'json', '-c', 'SELECT COUNT(*) FROM items')
                    assert result.returncode == 0, result
                    queries = table_results(json.loads(line) for line in result.stdout.splitlines())
                    assert len(queries) == 1, queries
                    assert atom(queries[0], 'unsigned') == '0', queries
                    persisted = console(root, env, cli, f'{variant}-retained', '--no-rc', '--format', 'json',
                                        input='SELECT id, title, score FROM packaging_probe;\n')
                    assert persisted.returncode == 0, persisted
                    assert records(table_results(json.loads(line) for line in persisted.stdout.splitlines())[0]) == [
                        dict(id='9001', title='retained', score='7')]
                finally:
                    owned = processes.children(process.pid)
                    process.terminate()
                    process.wait(timeout=30)
                    processes.joined(owned)
                    process.stdout.close()
                assert process.returncode == 0, log_path.read_text()
        success = True
        print('Single executable: no-file server startup, default Board, bare console DDL/DML/lazy ALTER, exact values across restart and identical defaults/YAML/environment identity passed with no sibling executables or runtime PATH tools.', flush=True)

    finally:
        if success:
            shutil.rmtree(root)
        else:
            print(f'Default workflow evidence retained: {root}', file=sys.stderr)


def run(package):
    package = Path(package).resolve()
    binary = package / 'bin/transit' if package.is_dir() else package
    defaults(binary)
    if package.is_dir():
        assert {path.name for path in (package / 'bin').iterdir()} == {'transit'}
        assert not (package / 'share/transit/local-executables.json').exists()
    fixture = Board(binary, binary, binary, binary)
    del fixture.config['executables']
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    try:
        fixture.start()
        report = fixture.ready()
        assert report['board_url'] == fixture.board_url
        assert b'<script' in fixture.request('/')
        assert len([entry for entry in fixture.atlas()['resources']['entries'] if entry]) == 2
        record = fixture.record()
        for role in ('/board.json', '__transit_role_v1 node ', '"unified_requester":'):
            fixture.kill_role(role)
            fixture.ready()
            assert fixture.record()['board_receipts'] == record['board_receipts']
            assert b'<script' in fixture.request('/')
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        assert fixture.record()['installation'] == record['installation']
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
        fixture.stop()
        checkpoint = (fixture.installation/'installation.json').read_bytes()
        fixture.config['executables'] = {'board': fixture.cli}
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.refusal('configuration or executable differs from the recorded installation')
        assert (fixture.installation/'installation.json').read_bytes() == checkpoint
        del fixture.config['executables']
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready()
        success = True
        print('Single executable Board: embedded assets, role/manager death, --no-ui, re-enable, retained identity and changed invocation-mode refusal passed without runtime PATH tools.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Packaged failure evidence retained: {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    run(sys.argv[1])
