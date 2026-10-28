"""Exact local SQL setup recovery at native commit/response boundaries."""
import ctypes
import json
from harness.operation_helpers import operations
import os
from pathlib import Path
import shutil
import socket
import sys

from harness.processes import joined
from interfaces.installation.server import Fixture
from interfaces.installation.server_application_faults import arm, descendants, install_peer, wait_file
from interfaces.installation.server_sql import account, apply, call, freeze, wait_status
from harness.services import free_port


def run(cli, node, host, board, gateway):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = Fixture(cli, node, host)
    freeze(fixture)
    install_peer(fixture)
    fixture.config['sql'] = {'native': {'local': False}}
    fixture.config['applications'] = {'port': free_port()}
    fixture.config['board'] = {'port': free_port()}
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    print(f'Local SQL fault proof: {fixture.root}', flush=True)
    def kill():
        owned = descendants(fixture.process.pid)
        fixture.stop(kill=True)
        joined(owned)
    try:
        fixture.start(); fixture.ready(); fixture.stop()
        password = fixture.root / 'owner.password'
        password.write_text('local-sql-isolated-fault-proof'); password.chmod(0o600)
        fixture.config['sql'] = dict(native={'local': False}, postgres={'port': free_port()}, health_port=free_port(),
            drain_ms=1000, accounts=[dict(name='owner', role='local_owner', password_file=str(password))])
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: account(s, 'owner')['state'] == 'awaiting_binding')
        path = fixture.installation / 'sql/accounts/owner/account.json'
        frozen = json.loads(path.read_text())
        fixture.stop(); fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: account(s, 'owner')['state'] == 'awaiting_binding')
        recovered = json.loads(path.read_text())
        assert recovered['identity'] == frozen['identity'] and recovered['principals'] == frozen['principals']
        assert set(recovered['principals']) == {'table'}
        (fixture.root / 'drop-table-next').write_text(json.dumps(dict(label='sql-activation', principal=recovered['principals']['table'], format=0x53514131)))
        apply(fixture, fixture.installation / 'sql/accounts/owner/bind-credential.json', 'binding')
        wait_file(fixture.root / 'dropped-sql-activation.json', timeout=120)
        accepted = json.loads((fixture.root / 'dropped-sql-activation.json').read_text())
        receipt = json.loads(bytes.fromhex(accepted['receipt']))['result']['client_progress']['state']
        frozen_init = json.loads(path.read_text())
        kill()
        (fixture.root / 'release-sql-activation').touch()
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        retained = json.loads(path.read_text())
        assert retained['identity'] == frozen['identity'] and retained['principals'] == frozen['principals']
        assert retained['initialized'] and retained['generation'] > frozen_init['generation']
        assert receipt['record']['format'] == 0x53514131
        print('Local SQL: Catalog activation reply loss preserves account identity and fences the original generation after manager SIGKILL.', flush=True)

        # A foreign process owns the configured port. The shared preflight
        # rejects before starting children or changing the enrolled identity.
        fixture.stop()
        checkpoint = path.read_bytes()
        query = fixture.root / 'identity.json'; query.write_text('{"identity":{}}')
        with socket.socket() as occupied:
            occupied.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            occupied.bind(('127.0.0.1', fixture.config['sql']['postgres']['port']))
            occupied.listen(1)
            fixture.refusal('sql.postgres.port')
            assert path.read_bytes() == checkpoint
        fixture.start(); fixture.ready(timeout=300)
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting')
        assert json.loads(path.read_text())['identity'] == retained['identity']
        print('Local SQL: occupied port rejects in preflight without enrollment changes; restart succeeds after release.', flush=True)

        # Disable the database caller using public authorization. Replacement
        # must reject without restoring its credential or blocking core access.
        control = json.loads((fixture.installation / 'sql/accounts/owner/control.json').read_text())
        worker_profile = fixture.root / 'worker-auth.json'
        worker_profile.write_text(json.dumps(dict(version=1, url=control['native_url'],
            seed_file=str(fixture.installation / 'sql/accounts/owner/table.seed'),
            connection=dict(definition=control['definition'], realm=control['execution']['realm'], principal=control['execution']['table_principal']))))
        observed = json.loads(call([operations(), 'auth', 'read', '--config', worker_profile, '--file', query], retry_observation=True))['observation']['body']['authorization']
        change = fixture.root / 'disable-worker.json'
        change.write_text(json.dumps(dict(expected_revision=observed['revision'], action=dict(disable_credential=dict(
            principal=control['execution']['table_principal'], expected_epoch=observed['body']['identity']['credential_epoch'])))))
        apply(fixture, change, 'disable-worker')
        fixture.stop()
        fixture.start(); fixture.ready(timeout=300)
        status = wait_status(fixture, lambda s: s['service']['state'] == 'unavailable')
        assert status['service']['postgres_port'] is None
        denied = json.loads(path.read_text())['journal']
        assert denied['pending'] is None
        assert json.loads(path.read_text())['principals'] == retained['principals']
        call([operations(), 'auth', 'read', '--config', fixture.installation / 'sql/authorization.yaml', '--file', query], retry_observation=True)
        print('Local SQL: revoked database caller remains revoked; no replacement credential is created and core administration stays available.', flush=True)
        success = True
    finally:
        fixture.cleanup()
        if success: shutil.rmtree(fixture.root)
        else: print(f'Local SQL fault evidence retained at {fixture.root}', file=sys.stderr, flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])
