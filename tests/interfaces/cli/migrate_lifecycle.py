#!/usr/bin/env python3
"""End-to-end qualification of transit migrate lifecycle, drift detection, claim fencing and resume."""
import base64
import ctypes
import hashlib
import json
from pathlib import Path
import select
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time

from harness import phases, processes
from interfaces.cli.table_console import records, results as table_results
from interfaces.http.serving import compact
from interfaces.installation.server_application_faults import ExistingKey, native, post

VERSION_FORMAT = 0x544d5631  # "TMV1"


def run_cli(root, env, cli, label, *args, input_text=None):
    stdout, stderr = root / f'{label}.stdout', root / f'{label}.stderr'
    with phases.phase('cli', label), stdout.open('wb') as output, stderr.open('wb') as errors:
        result = subprocess.run([str(cli), *args], input=input_text, text=True,
                                cwd=root, env=env, stdout=output, stderr=errors, timeout=90)
    result.stdout, result.stderr = stdout.read_text(), stderr.read_text()
    return result


def sql_query_records(root, env, cli, label, sql):
    result = run_cli(root, env, cli, label, 'console', '--no-rc', '--format', 'json', '-c', sql)
    assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
    batches = table_results(json.loads(line) for line in result.stdout.splitlines() if line.strip())
    assert batches, result.stdout
    return records(batches[-1])


def update_ledger_version(root, ports, version_id, mutator):
    record = json.loads((root / '.transit/installation.json').read_text())
    gw = json.loads((root / '.transit/sql/gateway.json').read_text())
    exec_cfg = gw['accounts'][0]['execution']
    binding = exec_cfg['bindings'][0]
    key = ExistingKey(root, Path(gw['accounts'][0]['keys']['table']))
    principal = exec_cfg['table_principal']
    realm = exec_cfg['realm']
    port = ports['gateway']

    identity = post(port, '/v1/query', native(key, realm, principal,
        dict(authorization=dict(role=binding['role'], kind=dict(identity={})))))['body']['authorization']['body']['identity']

    connection = dict(
        scope=dict(realm=realm, resource=binding['resource'], catalog=binding['catalog']),
        branch=1,
        audience=binding['owner'],
        principal=principal,
        role=binding['role'],
    )
    namespace = binding['namespace']
    account = list(hashlib.sha256(
        b'transit.migration.ledger-account.v1\x00'
        + struct.pack('<5Q', realm, binding['resource'], binding['catalog'], 1, namespace)
    ).digest())

    token_bytes = hashlib.sha256(
        b'transit.migration.version.v1\x00'
        + struct.pack('<5Q', realm, binding['resource'], binding['catalog'], 1, namespace)
        + version_id.encode('utf-8')
    ).digest()[:16]
    token_key = dict(
        definition=record['definition'],
        connection=connection,
        account=account,
        token=list(token_bytes),
    )

    def call_table(action, nonce_seed):
        body = dict(definition=record['definition'], connection=connection, nonce=[nonce_seed] * 16,
                    action=action, delegation=None, closure=None, borrow=None, lease=None, transaction=None)
        ctx = hashlib.sha256(b'transit.table.direct.request.v1\x00' + compact(body)).digest()
        claim = dict(definition=record['definition'], realm=realm, principal=principal,
                     credential_epoch=identity['credential_epoch'], role=binding['role'],
                     audience=connection['audience'], context=list(ctx))
        sig = key.sign(hashlib.sha256(b'transit.authorization.subject.v1\x00' + compact(claim)).digest())
        return post(port, '/table/v1', dict(body, proof=dict(claim=claim, signature=sig)))

    state = call_table(dict(client_progress=dict(inspect=token_key)), 81)['result']['client_progress']['state']
    assert state is not None, f'Missing ledger version {version_id}'
    ref = state['record'] or state['receipt']['binding']['intent']['external']['record']
    raw_b64 = call_table(dict(record=dict(read=ref)), 82)['result']['record']['bytes']['base64']
    entry = json.loads(base64.b64decode(raw_b64).decode('utf-8'))
    mutator(entry)
    new_bytes = compact(entry)
    scope = dict(definition=record['definition'], connection=connection, account=account)
    staged_ref = call_table(dict(record=dict(stage=dict(
        scope=scope,
        format=VERSION_FORMAT,
        bytes=dict(base64=base64.b64encode(new_bytes).decode('ascii')),
    ))), 83)['result']['record']['reference']
    call_table(dict(client_progress=dict(update=dict(
        key=token_key,
        expected=state['revision'],
        pending=False,
        cancel=False,
        record=staged_ref,
    ))), 84)


def run(binary):
    binary = Path(binary).resolve()
    if binary.is_dir():
        binary = binary / 'bin/transit'
    root = Path(tempfile.mkdtemp(prefix='transit-migrate-', dir='/var/tmp'))
    success = False
    print(f'Migration lifecycle qualification: {root}', flush=True)
    try:
        env = {'PATH': '/unavailable', 'HOME': str(root), 'LANG': 'C'}
        listeners = [socket.socket() for _ in range(5)]
        for listener in listeners:
            listener.bind(('127.0.0.1', 0))
        selected = [listener.getsockname()[1] for listener in listeners]
        for listener in listeners:
            listener.close()
        ports = dict(zip(('node', 'gateway'), selected[:2]))
        env.update({f'TRANSIT_PORTS__{k.upper()}': str(v) for k, v in ports.items()})
        env.update(
            TRANSIT_APPLICATIONS__PORT=str(selected[2]),
            TRANSIT_BOARD__PORT=str(selected[3]),
            TRANSIT_SQL__HEALTH_PORT=str(selected[4]),
        )
        tools = root / 'bin'
        tools.mkdir()
        cli = tools / 'transit'
        shutil.copy2(binary, cli)

        log_path = root / 'server.stderr'
        with log_path.open('wb') as log:
            process = subprocess.Popen([str(cli), 'server', '--no-ui'],
                                       cwd=root, env=env, stdout=subprocess.PIPE, stderr=log)
            try:
                deadline = time.monotonic() + 120
                while not select.select([process.stdout], [], [], 0.1)[0]:
                    assert process.poll() is None and time.monotonic() < deadline, log_path.read_text()
                line = process.stdout.readline()
                assert line, log_path.read_text()
                ready_report = json.loads(line)
                assert ready_report['ready'] is True, ready_report
                while 'server.ready Server is ready' not in log_path.read_text():
                    assert process.poll() is None and time.monotonic() < deadline, log_path.read_text()
                    time.sleep(0.05)

                # 1. Immediate readiness after server.ready & ORDER BY diagnostic (#274)
                initial_status = run_cli(root, env, cli, '01-immediate-status',
                                         'migrate', 'status', '--format', 'json')
                assert initial_status.returncode == 0, (initial_status.returncode, initial_status.stdout, initial_status.stderr)
                initial_json = json.loads(initial_status.stdout)
                assert initial_json['outcome'] == 'inspected' and initial_json['versions'] == [], initial_json

                order_by_probe = run_cli(
                    root, env, cli, '02-order-by-diagnostic',
                    'console', '--no-rc', '--format', 'json',
                    input_text=(
                        "CREATE TABLE platform_migrations (version TEXT PRIMARY KEY);\n"
                        "SELECT version FROM platform_migrations ORDER BY version;\n"
                    ),
                )
                assert order_by_probe.returncode != 0, order_by_probe.stdout
                assert 'InvalidColumnName' not in order_by_probe.stdout and 'InvalidColumnName' not in order_by_probe.stderr, (
                    order_by_probe.stdout, order_by_probe.stderr)
                assert 'sql.unsupported_construct' in order_by_probe.stderr and 'UnsupportedConstruct' in order_by_probe.stderr, (
                    order_by_probe.stdout, order_by_probe.stderr)
                drop_probe = run_cli(root, env, cli, '02b-drop-platform-migrations',
                                     'console', '--no-rc', '-c', 'DROP TABLE platform_migrations;')
                assert drop_probe.returncode == 0, drop_probe.stderr

                # 2. Clean initialization (plan, inspect, apply, status, verify, console .migrations)
                migrations_dir = root / 'migrations'
                migrations_dir.mkdir()
                m1_path = migrations_dir / '0001-create-accounts.sql'
                m1_sql = (
                    "-- Create accounts and seed initial row\n"
                    "CREATE TABLE accounts (id BIGINT PRIMARY KEY, name TEXT, balance BIGINT);\n"
                    "INSERT INTO accounts (id, name, balance) VALUES (1, 'Ada', 100);\n"
                    "SELECT id, name, balance FROM accounts WHERE id = 1;\n"
                )
                m1_path.write_text(m1_sql)

                m2_path = migrations_dir / '0002-alter-accounts.sql'
                m2_sql = (
                    "ALTER TABLE accounts ADD COLUMN tier TEXT DEFAULT 'standard';\n"
                    "UPDATE accounts SET balance = 150 WHERE id = 1;\n"
                )
                m2_path.write_text(m2_sql)

                plan_file = root / 'plan.json'
                plan_res = run_cli(root, env, cli, '03-plan',
                                   'migrate', 'plan', '--dir', str(migrations_dir),
                                   '--out', str(plan_file), '--format', 'json')
                assert plan_res.returncode == 0, (plan_res.returncode, plan_res.stdout, plan_res.stderr)
                assert plan_file.exists()
                plan_report = json.loads(plan_res.stdout)
                assert plan_report['outcome'] == 'planned', plan_report
                assert len(plan_report['versions']) == 2, plan_report
                assert [v['version_id'] for v in plan_report['versions']] == ['0001', '0002']
                assert [v['state'] for v in plan_report['versions']] == ['will_apply', 'will_apply']
                assert len(plan_report['versions'][0]['steps']) == 3
                assert len(plan_report['versions'][1]['steps']) == 2

                inspect_res = run_cli(root, env, cli, '04-inspect-plan',
                                      'migrate', 'inspect', '--plan', str(plan_file), '--format', 'json')
                assert inspect_res.returncode == 0, inspect_res.stderr
                inspect_report = json.loads(inspect_res.stdout)
                assert inspect_report['outcome'] == 'inspected', inspect_report
                assert inspect_report['plan_digest'] == plan_report['plan_digest']

                apply_res = run_cli(root, env, cli, '05-apply-plan',
                                    'migrate', 'apply', '--plan', str(plan_file), '--format', 'json')
                assert apply_res.returncode == 0, (apply_res.returncode, apply_res.stdout, apply_res.stderr)
                apply_report = json.loads(apply_res.stdout)
                assert apply_report['outcome'] == 'applied', apply_report
                assert apply_report['versions'][0]['state'] == 'verified'
                assert apply_report['versions'][0]['steps'][1]['affected_rows'] == 1
                assert apply_report['versions'][1]['state'] == 'verified'
                assert apply_report['versions'][1]['steps'][1]['affected_rows'] == 1

                rows = sql_query_records(root, env, cli, '06-select-accounts',
                                         'SELECT id, name, balance, tier FROM accounts;')
                assert rows == [dict(id='1', name='Ada', balance='150', tier='standard')], rows

                status_table = run_cli(root, env, cli, '07-status-table',
                                       'migrate', 'status', '--format', 'table')
                assert status_table.returncode == 0, status_table.stderr
                assert 'create-accounts' in status_table.stdout and 'alter-accounts' in status_table.stdout, status_table.stdout

                console_migrations = run_cli(root, env, cli, '08-console-migrations',
                                             'console', '--no-rc', input_text='.migrations\n')
                assert console_migrations.returncode == 0, console_migrations.stderr
                assert 'create-accounts' in console_migrations.stdout and 'alter-accounts' in console_migrations.stdout, console_migrations.stdout

                verify_dir = run_cli(root, env, cli, '09-verify-dir',
                                     'migrate', 'verify', '--dir', str(migrations_dir), '--format', 'json')
                assert verify_dir.returncode == 0, (verify_dir.returncode, verify_dir.stdout, verify_dir.stderr)
                assert json.loads(verify_dir.stdout)['outcome'] == 'verified'

                verify_live = run_cli(root, env, cli, '10-verify-live',
                                      'migrate', 'verify', '--format', 'json')
                assert verify_live.returncode == 0, (verify_live.returncode, verify_live.stdout, verify_live.stderr)
                assert json.loads(verify_live.stdout)['outcome'] == 'verified'

                # 3. Idempotent re-run
                rerun_res = run_cli(root, env, cli, '11-apply-idempotent',
                                    'migrate', 'apply', '--dir', str(migrations_dir), '--format', 'json')
                assert rerun_res.returncode == 0, (rerun_res.returncode, rerun_res.stdout, rerun_res.stderr)
                rerun_report = json.loads(rerun_res.stdout)
                assert rerun_report['outcome'] == 'already_satisfied', rerun_report
                assert [v['state'] for v in rerun_report['versions']] == ['verified', 'verified'], rerun_report
                assert sql_query_records(root, env, cli, '11b-select-accounts',
                                         'SELECT id, name, balance, tier FROM accounts;') == [
                    dict(id='1', name='Ada', balance='150', tier='standard')
                ]

                # 4. Target identity mismatch
                mismatch_res = run_cli(root, env, cli, '12-target-mismatch',
                                       'migrate', 'plan', '--dir', str(migrations_dir),
                                       '--database', 'wrong_db', '--format', 'json')
                assert mismatch_res.returncode == 2, (mismatch_res.returncode, mismatch_res.stdout, mismatch_res.stderr)
                mismatch_report = json.loads(mismatch_res.stdout)
                assert mismatch_report['outcome'] == 'target_mismatch', mismatch_report
                assert mismatch_report['diagnostic_code'] == 'migration.target_mismatch', mismatch_report

                # 5. Modified migration file rejection (checksum_mismatch)
                m1_path.write_text(m1_sql + "-- tampered comment\n")
                for idx, action in enumerate(('plan', 'apply', 'verify')):
                    tampered = run_cli(root, env, cli, f'13-checksum-{idx}-{action}',
                                       'migrate', action, '--dir', str(migrations_dir), '--format', 'json')
                    assert tampered.returncode == 3, (action, tampered.returncode, tampered.stdout, tampered.stderr)
                    tampered_report = json.loads(tampered.stdout)
                    assert tampered_report['outcome'] == 'checksum_mismatch', tampered_report
                    assert tampered_report['diagnostic_code'] == 'migration.checksum_mismatch', tampered_report
                m1_path.write_text(m1_sql)

                # 6. CREATE TABLE IF NOT EXISTS schema drift & post-apply live drift detection
                precreate = run_cli(root, env, cli, '14-precreate-widgets',
                                    'console', '--no-rc', '-c',
                                    'CREATE TABLE widgets (id BIGINT PRIMARY KEY, legacy_col TEXT);')
                assert precreate.returncode == 0, precreate.stderr
                m3_drift_path = migrations_dir / '0003-widgets.sql'
                m3_drift_path.write_text(
                    'CREATE TABLE IF NOT EXISTS widgets (id BIGINT PRIMARY KEY, different_col BIGINT);\n'
                )
                for action in ('plan', 'apply'):
                    drift_res = run_cli(root, env, cli, f'15-if-not-exists-drift-{action}',
                                        'migrate', action, '--dir', str(migrations_dir), '--format', 'json')
                    assert drift_res.returncode == 3, (action, drift_res.returncode, drift_res.stdout, drift_res.stderr)
                    drift_report = json.loads(drift_res.stdout)
                    assert drift_report['outcome'] == 'drift_detected', drift_report
                    assert drift_report['versions'][2]['state'] == 'already_diverged', drift_report
                    step0 = drift_report['versions'][2]['steps'][0]
                    assert step0['state'] == 'already_diverged', step0
                    assert step0['drift']['aspect'] in ('missing_column', 'extra_column', 'column_type'), step0
                    assert step0['expected_schema_sha256'] != step0['observed_schema_sha256'], step0
                m3_drift_path.unlink()
                drop_widgets = run_cli(root, env, cli, '15b-drop-widgets',
                                       'console', '--no-rc', '-c', 'DROP TABLE widgets;')
                assert drop_widgets.returncode == 0, drop_widgets.stderr

                # Live catalog drift on already-applied table
                alter_oob = run_cli(root, env, cli, '16-alter-oob',
                                    'console', '--no-rc', '-c',
                                    'ALTER TABLE accounts ADD COLUMN oob_col BIGINT DEFAULT 0;')
                assert alter_oob.returncode == 0, alter_oob.stderr
                live_drift = run_cli(root, env, cli, '16b-verify-live-drift',
                                     'migrate', 'verify', '--format', 'json')
                assert live_drift.returncode == 3, (live_drift.returncode, live_drift.stdout, live_drift.stderr)
                assert json.loads(live_drift.stdout)['outcome'] == 'drift_detected'
                fix_oob = run_cli(root, env, cli, '16c-drop-oob',
                                  'console', '--no-rc', '-c',
                                  'ALTER TABLE accounts DROP COLUMN oob_col;')
                assert fix_oob.returncode == 0, fix_oob.stderr
                verify_restored = run_cli(root, env, cli, '16d-verify-restored',
                                          'migrate', 'verify', '--format', 'json')
                assert verify_restored.returncode == 0, verify_restored.stdout

                # 7. Multi-statement partial failure on step k > 1
                seed_conflict = run_cli(root, env, cli, '17-seed-conflict',
                                        'console', '--no-rc', '-c',
                                        "INSERT INTO accounts (id, name, balance) VALUES (2, 'Conflict', 0);")
                assert seed_conflict.returncode == 0, seed_conflict.stderr

                m3_audit_path = migrations_dir / '0003-audit.sql'
                m3_audit_path.write_text(
                    "CREATE TABLE account_audit (id BIGINT PRIMARY KEY, note TEXT);\n"
                    "INSERT INTO account_audit (id, note) VALUES (10, 'step-1-ok');\n"
                    "INSERT INTO accounts (id, name, balance) VALUES (2, 'Grace', 200);\n"
                )
                partial_res = run_cli(root, env, cli, '18-partial-failure',
                                      'migrate', 'apply', '--dir', str(migrations_dir), '--format', 'json')
                assert partial_res.returncode == 1, (partial_res.returncode, partial_res.stdout, partial_res.stderr)
                partial_report = json.loads(partial_res.stdout)
                assert partial_report['outcome'] == 'step_failed', partial_report
                v3 = partial_report['versions'][2]
                assert v3['state'] == 'failed', v3
                assert [s['state'] for s in v3['steps']] == ['applied', 'applied', 'failed'], v3['steps']
                assert sql_query_records(root, env, cli, '18b-select-audit',
                                         'SELECT id, note FROM account_audit;') == [
                    dict(id='10', note='step-1-ok')
                ]

                # Re-running apply while version 0003 is in failed state refuses until resumed
                blocked_apply = run_cli(root, env, cli, '19-blocked-apply',
                                        'migrate', 'apply', '--dir', str(migrations_dir), '--format', 'json')
                assert blocked_apply.returncode == 1, (blocked_apply.returncode, blocked_apply.stdout)
                assert json.loads(blocked_apply.stdout)['outcome'] == 'step_failed'

                # 8. Concurrent runner claim conflict (claim_conflict) and interrupted-attempt resume
                # Simulate an active foreign claim on version 0003 with step 2 in-flight ('applying')
                def set_claimed(entry):
                    entry['state'] = 'claimed'
                    entry['active_attempt_id'] = [0xbb] * 16
                    entry['steps'][1]['state'] = 'applying'

                update_ledger_version(root, ports, '0003', set_claimed)

                claim_conflict = run_cli(root, env, cli, '20-claim-conflict',
                                         'migrate', 'apply', '--dir', str(migrations_dir), '--format', 'json')
                assert claim_conflict.returncode == 3, (claim_conflict.returncode, claim_conflict.stdout, claim_conflict.stderr)
                conflict_report = json.loads(claim_conflict.stdout)
                assert conflict_report['outcome'] == 'claim_conflict', conflict_report
                assert conflict_report['diagnostic_code'] == 'migration.claim_conflict', conflict_report

                unknown_status = run_cli(root, env, cli, '21-status-unknown',
                                         'migrate', 'status', '--format', 'json')
                assert unknown_status.returncode == 4, (unknown_status.returncode, unknown_status.stdout)
                unknown_report = json.loads(unknown_status.stdout)
                assert unknown_report['outcome'] == 'outcome_unknown', unknown_report
                assert unknown_report['recovery_command'] == 'transit migrate resume', unknown_report

                # Remove the conflicting row and run 'transit migrate resume --dir migrations'
                clear_conflict = run_cli(root, env, cli, '22-clear-conflict',
                                         'console', '--no-rc', '-c',
                                         'DELETE FROM accounts WHERE id = 2;')
                assert clear_conflict.returncode == 0, clear_conflict.stderr

                resume_res = run_cli(root, env, cli, '23-resume',
                                     'migrate', 'resume', '--dir', str(migrations_dir), '--format', 'json')
                assert resume_res.returncode == 0, (resume_res.returncode, resume_res.stdout, resume_res.stderr)
                resume_report = json.loads(resume_res.stdout)
                assert resume_report['outcome'] == 'applied', resume_report
                assert resume_report['versions'][2]['state'] == 'verified', resume_report['versions'][2]

                # Step 2 ('INSERT INTO account_audit') was reconciled from its durable token without re-executing,
                # and Step 3 ('INSERT INTO accounts') completed cleanly.
                assert sql_query_records(root, env, cli, '24-select-audit-after-resume',
                                         'SELECT id, note FROM account_audit;') == [
                    dict(id='10', note='step-1-ok')
                ]
                account_rows = sorted(
                    sql_query_records(root, env, cli, '25-select-accounts-after-resume',
                                      'SELECT id, name, balance, tier FROM accounts;'),
                    key=lambda r: int(r['id']),
                )
                assert account_rows == [
                    dict(id='1', name='Ada', balance='150', tier='standard'),
                    dict(id='2', name='Grace', balance='200', tier='standard'),
                ], account_rows

                final_verify = run_cli(root, env, cli, '26-final-verify',
                                       'migrate', 'verify', '--dir', str(migrations_dir), '--format', 'json')
                assert final_verify.returncode == 0, final_verify.stdout
                assert json.loads(final_verify.stdout)['outcome'] == 'verified'

            finally:
                owned = processes.children(process.pid)
                process.terminate()
                process.wait(timeout=30)
                processes.joined(owned)
                process.stdout.close()
            assert process.returncode == 0, log_path.read_text()

        success = True
        print('Migration lifecycle: immediate SQL readiness, ORDER BY diagnostic, plan/inspect/apply/status/verify, idempotent re-run, target mismatch, checksum immutability, IF NOT EXISTS & live schema drift, partial step failure, claim conflict and token-reconciled resume passed.', flush=True)
    finally:
        if success:
            shutil.rmtree(root)
        else:
            print(f'Migration lifecycle failure evidence retained: {root}', file=sys.stderr)


if __name__ == '__main__':
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    run(sys.argv[1])
