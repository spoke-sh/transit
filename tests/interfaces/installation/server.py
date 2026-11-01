#!/usr/bin/env python3
"""Actual local CLI commands, disk providers and owned Linux child failure proofs."""
import ctypes
import json
import os
from pathlib import Path
import select
import shutil
import signal
import socket
import struct
import subprocess
import sys
import time
import urllib.error

from harness.local_installation import LocalInstallation
from harness.phases import phase
from harness.processes import children, command
from interfaces.cli.table_console import TableConsole, atom, records, results as table_results


class Fixture(LocalInstallation):
    def __init__(self, cli, node, host, parent="/var/tmp"):
        super().__init__(cli, node, host, parent=parent)
        self.activation = None
        self.markers = set()

    @phase("readiness", "local-installation")
    def ready(self, timeout=180):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise AssertionError(f"Manager exit {self.process.returncode}: {Path(self.logs[-1].name).read_text()}")
            if select.select([self.process.stdout], [], [], 0.1)[0]:
                line = self.process.stdout.readline()
                if not line:
                    raise AssertionError(Path(self.logs[-1].name).read_text())
                report = json.loads(line)
                assert report["ready"] and report["profile"] == "local_applications_v1", report
                port = self.config["ports"]["gateway"]
                assert report["gateway_url"] == self.url, report
                assert report["allowed_hosts"] == [f"127.0.0.1:{port}", f"localhost:{port}"] + self.config.get("gateway_allowed_hosts", []), report
                assert report["ui"] == ('disabled' if self.no_ui else 'ready'), report
                board_url = None if self.no_ui else f"http://127.0.0.1:{self.config['board']['port']}"
                assert report["board_url"] == board_url, report
                activation = self.record()["registration"]
                markers = {path.name for path in (self.installation / "activations").glob("*.activation")}
                if self.activation is not None:
                    assert activation["pid"] == self.activation["pid"]
                    assert activation["generation"] > self.activation["generation"]
                    assert activation["public_key"] != self.activation["public_key"]
                    assert self.markers < markers, (self.markers, markers)
                self.activation, self.markers = activation, markers
                self.ready_sql(deadline)
                # SQL activation can reopen the physical owner after the core
                # receipt. Observe all admission gates within the original
                # deadline; a transient 503 is not completed startup.
                self.health_attempts = 0
                while True:
                    assert self.process.poll() is None, Path(self.logs[-1].name).read_text()
                    remaining = deadline - time.monotonic()
                    assert remaining > 0, 'Gateway did not become ready'
                    self.health_attempts += 1
                    try:
                        with self.http.open(self.url + "/health", timeout=min(5, remaining)) as response:
                            assert response.status == 200
                        break
                    except urllib.error.HTTPError as error:
                        if error.code != 503:
                            raise
                        error.close()
                        time.sleep(min(.05, max(0, deadline - time.monotonic())))
                self.board_attempts = 0
                if board_url:
                    self.ready_board(board_url, deadline)
                return report
        raise TimeoutError(f"Server readiness at {self.root}")

    def ready_board(self, board_url, deadline):
        # The supervisor has just read this same route. Respect Board's finite
        # read interval; neither a 429 nor a transient 503 establishes readiness.
        while True:
            assert self.process.poll() is None, 'Manager exited before Board readiness'
            remaining = deadline - time.monotonic()
            assert remaining > 0, 'Board did not become ready'
            self.board_attempts += 1
            try:
                with self.http.open(board_url + '/api/v1/atlas', timeout=min(5, remaining)) as response:
                    atlas = json.load(response)
                    assert atlas['realm'] == self.config['realm'], atlas
                    assert atlas['identity']['principal'] == 25, atlas
                    return
            except urllib.error.HTTPError as error:
                if error.code not in (429, 503):
                    raise
                error.close()
                time.sleep(min(.1, max(0, deadline - time.monotonic())))

    def ready_sql(self, deadline):
        # The core ready record precedes SQL admission. Fault schedules must
        # finish the current startup before deliberately killing another role.
        if not self.config.get('sql', {}).get('native', {}).get('local', True):
            return
        status_file = self.installation / 'sql/status.json'
        while True:
            assert self.process.poll() is None, Path(self.logs[-1].name).read_text()
            if status_file.exists():
                status = json.loads(status_file.read_text())
                if status.get('service', {}).get('state') == 'accepting':
                    return
            assert time.monotonic() < deadline, 'Local SQL did not become ready'
            time.sleep(.05)

    def refusal(self, message):
        args = [self.cli, "server", "--config", str(self.path)]
        if self.no_ui:
            args.append("--no-ui")
        result = subprocess.run(args, capture_output=True, text=True, timeout=30, env={"PATH": "/unavailable"})
        assert result.returncode != 0 and message in result.stderr, result
        assert not result.stdout, result
    def console_config(self):
        # Public rendezvous is sufficient; never read a client signing key.
        import hashlib
        uid = os.geteuid()
        runtime = Path(f'/tmp/transit-{uid}')
        digest = hashlib.sha256(str(self.installation).encode()).hexdigest()
        rendezvous = json.loads((runtime / (digest[:32] + '.json')).read_text())
        return dict(version=1, endpoint='unix:'+rendezvous['socket'],
                    account=rendezvous['account'], database=rendezvous['database'], authentication='peer')
    def console(self, text, expected=0, *, request_timeout_ms=None, timeout=80):
        args = [self.cli, "console", "--no-rc", "--format", "json"]
        if request_timeout_ms is not None:
            connection = self.console_config()
            connection['request_timeout_ms'] = request_timeout_ms
            path = self.root / 'console-connection.json'
            path.write_text(json.dumps(connection))
            args.extend(['--config', str(path)])
        result = subprocess.run(args,
            input=text, text=True, capture_output=True, timeout=timeout, cwd=self.root, env={"PATH": "/unavailable"})
        assert result.returncode == expected, result
        if expected:
            return result
        return table_results(json.loads(line) for line in result.stdout.splitlines())
    def sql_session(self, action, **kwargs):
        from interfaces.sql_sessions.local import Client
        client = Client(self.console_config(), self.record()['definition']).open()
        try:
            return client.call(action, **kwargs)
        finally:
            client.close()
    def sql_operations(self):
        after, entries = 0, []
        while True:
            page = self.sql_session(dict(operations=dict(after=after)))['operations']
            entries.extend(page['entries'])
            if page['next'] is None:
                return entries
            after = page['next']
    def sql_progress(self, identity):
        from interfaces.installation.server_sql import call
        configured = self.config.get('executables', {}).get('sql_gateway')
        gateway = [configured] if configured else [self.cli, '__transit_role_v1', 'sql_gateway']
        profile = self.installation / 'sql/accounts' / self.console_config()['account'] / 'control.json'
        observed = json.loads(call([*gateway, 'control', profile, 'status', identity['id']], retry_observation=True))
        receipt = observed['operation']['receipt']
        assert str(receipt['position']['next_lsn']) == str(identity['id']), observed
        assert receipt['binding']['key']['account'] == identity['account'], observed
        return observed
    def revoke_table_writes(self):
        # Current native domain grants own Table permissions. The old catalog
        # policy record is no longer an authorization source.
        import hashlib
        from interfaces.installation.server_application_faults import ExistingKey, native, post
        key = ExistingKey(self.root, self.installation / 'root.seed')
        port, realm = self.config['ports']['node'], self.config['realm']
        record = self.record()
        done = record['provision']

        def query(kind):
            return post(port, '/v1/query', native(key, realm, 0, kind), retry_unavailable=True)

        def authority(kind):
            return query(dict(authorization=dict(role=None, kind=kind)))['body']['authorization']

        def command(value):
            sequence = query({'capabilities': {}})['principal_sequence'] + 1
            # Retain the exact signature and sequence through unavailable replies;
            # retry never constructs a second authorization action.
            signed = native(key, realm, 0, dict(authorization=value), sequence)
            return post(port, '/v1/command', signed, retry_unavailable=True)['position']

        binding = hashlib.sha256(b'transit.catalog.authorization.binding.v1\0' + bytes.fromhex(record['definition']) + struct.pack('<QQQBQ', realm, done[5], 1, 3, 1)).digest()
        table = authority(dict(binding=dict(domain=record['authorization_steps'][5], key=list(binding))))['body']['binding']
        assert table is not None and table['owner'] == record['authorization_steps'][0]
        action = dict(revoke_privileges=dict(object=table['reference'], grantee=table['owner'], privileges=14, grant_option_only=False, behavior='cascade'))
        change = command(dict(begin=dict(expected_revision=authority(dict(identity={}))['revision'], role=None, action=action)))
        deadline = time.monotonic() + 30
        while True:
            status = authority(dict(change=change))['body']['change']
            if status['status'] == 'ready':
                command(dict(publish=change))
                assert authority(dict(change=change))['body']['change']['status'] == 'published'
                return
            assert status['status'] == 'preparing' and time.monotonic() < deadline, status
            command(dict(advance=change))
    def kill_role(self, match):
        candidates = [pid for pid in children(self.process.pid) if match in command(pid) and (match != "/transit-node " or "--maintain" not in command(pid))]
        assert len(candidates) == 1, [(pid, command(pid)) for pid in children(self.process.pid)]
        os.kill(candidates[0], signal.SIGKILL)


def run(cli, node, host):
    # Own/reap grandchildren when deliberately killing the manager. Runtime
    # supervision uses PDEATHSIG and does not depend on this fixture facility.
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    from interfaces.installation.server_direct_boundary import FaultFixture
    fixture = FaultFixture(cli, node, host)
    start = time.monotonic()
    success = False
    print(f"Transit server proof: {fixture.root}", flush=True)
    try:
        from interfaces.installation.server_startup import admission
        admission(fixture)
        fixture.start()
        fixture.ready()
        assert 'creating installation' in Path(fixture.logs[-1].name).read_text()
        node_config = json.loads((fixture.installation / 'node.json').read_text())
        assert node_config['local_directory'] == str(fixture.installation / 'data/native')
        assert 'ursula_url' not in node_config
        assert list((fixture.installation / 'data/native/wal').glob('*.twal'))
        assert list((fixture.installation / 'data/native/objects').glob('*.data'))
        owned_commands = [command(pid) for pid in children(fixture.process.pid)]
        assert not any('minio server' in value or 'ursula server' in value or '--maintain' in value for value in owned_commands)
        from interfaces.installation.server_configuration import run as configuration_proof
        configuration_proof(fixture)
        from interfaces.installation.server_faults import gateway_hosts, reusable_connections
        gateway_hosts(fixture)
        reusable_connections(fixture)
        from interfaces.cli.console_terminal import local_transcript
        local_transcript(fixture.cli, fixture.root)
        from interfaces.cli.console_edit import local_edit
        local_edit(fixture.cli, fixture.root)
        original = fixture.record()
        fixture.refusal("another server manages this installation")
        shell = TableConsole(fixture.cli, cwd=fixture.root)
        try:
            assert [row['table'] for row in records(shell.call('.schema'))] == ['items']
            page = shell.call('SELECT COUNT(*) FROM items;')
            assert page['complete']['rows'] == '1' and atom(page, 'unsigned') == '0', page
            # Reuse protocol support, but retire idle transport sockets and open
            # an independent snapshot after the listener's idle deadline.
            time.sleep(1.2)
            again = shell.call('SELECT COUNT(*) FROM items;')
            assert atom(again, 'unsigned') == '0', again
            values = shell.call('SELECT COUNT(value) AS present FROM items;')
            assert values['schema']['type']['structure'] == [{'name': 'present', 'type': {'uint64': {}}, 'nullable': False, 'optional': False}], values
            assert atom(values, 'unsigned') == '0', values
            shell.close()
        finally:
            if shell.process.poll() is None:
                shell.process.kill(); shell.process.wait(timeout=10)
        print("Transit server independent console: verified empty Table row/value counts and independent snapshots", flush=True)
        results = fixture.console('INSERT INTO items (id, value) VALUES (1, 100), (2, NULL);\n'
                                  'SELECT COUNT(value) AS present FROM items;\n'
                                  'SELECT COUNT(*) AS present FROM items;\n'
                                  'SELECT COUNT(value) AS present FROM items WHERE value IS NULL;\n'
                                  'SELECT COUNT(chosen.amount) AS present FROM (SELECT value AS amount FROM items WHERE id = 2 LIMIT 1) AS chosen;\n'
                                  'SELECT COUNT(chosen.amount) AS present FROM (SELECT value AS amount FROM items LIMIT 0) AS chosen;\n'
                                  'UPDATE items SET value = 101 WHERE id = 1;\n'
                                  'DELETE FROM items WHERE id = 2;\nSELECT value FROM items WHERE id = 1;\n')
        assert [(row['completion']['counts']['matched'], row['completion']['counts']['changed']) for row in results if 'completion' in row] == [('2', '2'), ('1', '1'), ('1', '1')], results
        assert len(results) == 9, results
        for page, count in zip(results[1:6], ('1', '2', '0', '0', '0'), strict=True):
            assert page['complete']['rows'] == '1', page
            assert page['schema']['type']['structure'] == [{'name': 'present', 'type': {'uint64': {}}, 'nullable': False, 'optional': False}], page
            assert atom(page, 'unsigned') == count, page
        assert atom(results[-1], 'signed') == '101', results
        print("Transit server independent console: nullable value/row counts, aliases and derived LIMIT/zero counts passed", flush=True)
        assert not list(fixture.installation.glob('console-*')), 'Console created private recovery state'
        # Two independent local sessions work concurrently without shared locks.
        first = TableConsole(fixture.cli, cwd=fixture.root)
        second = TableConsole(fixture.cli, cwd=fixture.root)
        try:
            assert atom(first.call('SELECT COUNT(*) FROM items;'), 'unsigned') == '1'
            assert atom(second.call('SELECT COUNT(*) FROM items;'), 'unsigned') == '1'
        finally:
            first.close(); second.close()
        explicit = fixture.root / 'connection.json'
        explicit.write_text(json.dumps(fixture.console_config()))
        read = subprocess.run([fixture.cli, 'console', '--no-rc', '--config', str(explicit), '--format', 'json',
                               '-c', 'SELECT * FROM items'], capture_output=True, text=True, timeout=30)
        assert read.returncode == 0 and table_results(map(json.loads, read.stdout.splitlines()))[0]['rows'], read
        info = subprocess.run([fixture.cli, 'console', '--no-rc', '--config', str(explicit), '--format', 'json'],
                              input='.info\n', capture_output=True, text=True, timeout=30)
        assert info.returncode == 0 and json.loads(info.stdout)['database'] == 'transit', info
        # Kill a console after its exact direct binding is dispatched while
        # Table execution is refused. Database recovery controls remain available.
        prior_operations = {entry['identity']['id'] for entry in fixture.sql_operations()}
        fixture.boundary.pause()
        pending = subprocess.Popen([fixture.cli, 'console', '--no-rc', '-c',
                                    'INSERT INTO items (id, value) VALUES (3, 300)'],
                                   cwd=fixture.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   env={'PATH': '/unavailable', 'LANG': 'C'})
        try:
            deadline = time.monotonic() + 60
            while True:
                if not fixture.boundary.observed.exists():
                    assert pending.poll() is None and time.monotonic() < deadline, 'direct work was not dispatched'
                    time.sleep(.05)
                    continue
                binding = json.loads(fixture.boundary.observed.read_text())
                inventory = fixture.sql_operations()
                unfinished = [entry for entry in inventory
                              if entry['identity']['id'] not in prior_operations
                              and entry['phase'] not in ('terminal', 'abandoned')]
                if unfinished:
                    assert len(unfinished) == 1, unfinished
                    saved_write = unfinished[-1]
                    operation = saved_write['identity']['id']
                    progress = fixture.sql_progress(saved_write['identity'])
                    assert progress['operation']['receipt']['binding']['intent']['table']['binding'] == binding
                    break
                assert pending.poll() is None and time.monotonic() < deadline, 'write was not admitted'
                time.sleep(.05)
        finally:
            pending.kill()
            pending.communicate(timeout=10)
        fixture.stop()
        # Same public v1 label cannot reinterpret another contract definition.
        record_path = fixture.installation / "installation.json"
        saved = record_path.read_bytes()
        try:
            for incompatible in (None, "previous-v1-definition", "a836b4860f5817b78c936b1ff8ee2e13c973b7e9f73dfc5003a0820ef8194262", "2577b1247a78a2f8a3eae59b3b36a286fedf9836759d19325edd9b3318b5bad5"):
                record = json.loads(saved)
                if incompatible is None:
                    del record['definition']
                else:
                    record['definition'] = incompatible
                encoded = json.dumps(record).encode()
                record_path.write_bytes(encoded)
                fixture.refusal("cannot read the retained installation record")
                # The console has no authority to read installation.json. A stopped
                # service is reported through local discovery/transport instead.
                rejected = fixture.console('SELECT COUNT(*) FROM items;\n', expected=1)
                assert rejected.stderr and not rejected.stdout, rejected
                assert record_path.read_bytes() == encoded
            for missing in ('default_table', 'table_registrar_receipt', 'workers'):
                record = json.loads(saved)
                del record[missing]
                encoded = json.dumps(record).encode()
                record_path.write_bytes(encoded)
                fixture.refusal('cannot read the retained installation record')
                assert record_path.read_bytes() == encoded
        finally:
            record_path.write_bytes(saved)
        fixture.start()
        fixture.ready()
        assert fixture.record()["provision"] == original["provision"]
        observed = fixture.sql_session(dict(status=dict(operation=saved_write['identity'])))['operation']
        assert observed['identity'] == saved_write['identity']
        fixture.boundary.resume()
        resumed = fixture.sql_session(dict(resume=saved_write['identity']))['operation']
        deadline = time.monotonic() + 90
        while resumed['phase'] != 'terminal':
            assert resumed['identity'] == saved_write['identity'] and time.monotonic() < deadline, resumed
            time.sleep(.1)
            resumed = fixture.sql_session(dict(status=dict(operation=saved_write['identity'])))['operation']
        assert resumed['phase'] == 'terminal' and resumed['outcome'] == 'applied' and resumed['matched'] == resumed['changed'] == 1, resumed
        assert atom(fixture.console("SELECT COUNT(*) FROM items;\n.quit\n")[-1], 'unsigned') == "2"
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        assert fixture.record()["provision"] == original["provision"]
        for role in ('"unified_source":', "/direct-node ", '"unified_requester":'):
            fixture.kill_role(role)
            fixture.ready()
            assert fixture.record()["provision"] == original["provision"]
            fixture.console(".schema\n.quit\n")
            assert atom(fixture.console("SELECT COUNT(*) FROM items;\n.quit\n")[-1], 'unsigned') == "2"
            assert fixture.console('UPDATE items SET value = 101 WHERE id = 1;\n')[-1]['completion']['counts']['changed'] == '0'
        fixture.kill_role("/courier.json")
        assert fixture.process.wait(timeout=30) == 1
        failure = Path(fixture.logs[-1].name).read_text().rsplit("server.failed ", 1)[-1]
        assert "restart budget exhausted" in failure and "ChildExited" in failure, failure
        assert 'role="courier"' in failure and "retrying" not in failure, failure
        fixture.stop()
        for name in ("data",):
            old = fixture.installation / name
            backup = fixture.installation / (name + "-absent")
            old.rename(backup)
            try:
                fixture.refusal("file not found")
            finally:
                backup.rename(old)
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(("127.0.0.1", fixture.config["ports"]["gateway"]))
            listener.listen()
            fixture.refusal("address already in use")
        fixture.start()
        fixture.ready()
        fixture.console(".schema\n.quit\n")
        fixture.revoke_table_writes()
        for restart in (False, True):
            if restart:
                fixture.stop()
                fixture.start()
                fixture.ready()
            denied = fixture.console('INSERT INTO items (id, value) VALUES (4, 400);\n', expected=1)
            assert 'AccessDenied (42501)' in denied.stderr and not denied.stdout, denied
            assert not list(fixture.installation.glob('console-*'))
            assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '2'
        # The initialized default is a real catalog object. Startup must not
        # manufacture it again after an intentional DROP/name reuse.
        fixture.console('CREATE TABLE ddl_probe (id INT64);\n')
        fixture.console('ALTER TABLE ddl_probe ADD COLUMN active BOOLEAN DEFAULT TRUE;\n')
        fixture.console('ALTER TABLE ddl_probe RENAME TO ddl_renamed;\n')
        assert [column['name'] for column in records(fixture.console('DESCRIBE ddl_renamed;\n')[-1])] == ['id', 'active']
        fixture.console('DROP TABLE ddl_renamed;\n')
        fixture.console('DROP TABLE IF EXISTS ddl_renamed;\n')
        fixture.console('DROP TABLE items;\n')
        fixture.stop()
        fixture.start()
        fixture.ready()
        assert all(row['table'] != 'items' for page in fixture.console('SHOW TABLES;\n') for row in records(page))
        fixture.console('CREATE TABLE items (name TEXT);\n')
        schema = records(fixture.console('DESCRIBE items;\n')[-1])
        assert [column['name'] for column in schema] == ['name'], schema
        fixture.stop()
        fixture.start()
        fixture.ready()
        assert records(fixture.console('DESCRIBE items;\n')[-1]) == schema
        # A stopped child cannot process SIGTERM. Force the supervisor's timed
        # SIGKILL path and join its pipe drainers before closing their handles.
        source = next(pid for pid in children(fixture.process.pid) if '"unified_source":' in command(pid))
        os.kill(source, signal.SIGSTOP)
        fixture.stop()
        success = True
        print(f"Transit server core lifecycle: passed in {time.monotonic() - start:.2f}s", flush=True)
    finally:
        fixture.boundary.resume()
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f"Failed server evidence retained at {fixture.root}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    faults = sys.argv[-1] == "--faults"
    args = sys.argv[1:-1] if faults else sys.argv[1:]
    if len(args) == 5:
        os.environ["TEST_TRANSIT_SQL_GATEWAY_BINARY"] = str(Path(args.pop()).resolve())
    if len(args) == 4:
        os.environ["TEST_TRANSIT_BOARD_BINARY"] = str(Path(args.pop()).resolve())
    run(*args)
    if faults:
        from interfaces.installation.server_faults import run as fault_proof
        fault_proof(*args)
