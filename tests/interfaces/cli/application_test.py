#!/usr/bin/env python3
"""Execute real Table/Queue tests under network and executable denial."""
import ctypes
import errno
import platform
import signal
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from runner.paths import ROOT
from interfaces.cli.application_build import offline, cli_build, repository, source, source_diagnostics
from interfaces.cli.table_console import records
from interfaces.installation.server import Fixture


def invoke(cli, root, *args, expected=0, timeout=60):
    temporary = root / '.test-tmp'
    temporary.mkdir(exist_ok=True)
    result = subprocess.run([str(cli), 'test', '--format', 'json', *map(str, args)],
                            cwd=root, capture_output=True, text=True, timeout=timeout,
                            env={'PATH': '/unavailable', 'TRANSIT_CONSOLE_CONFIG': '/private/unreadable', 'TMPDIR': str(temporary)},
                            preexec_fn=offline)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    assert not result.stderr, result.stderr
    assert not list(temporary.iterdir()), "Case storage survived normal cleanup"
    report = json.loads(result.stdout)
    assert report.get('ok', False) == (expected == 0), report
    if 'cases' in report:
        assert len(result.stdout.encode()) <= 1024 * 1024
        assert not any(value in result.stdout for value in ('root.seed', 'registrar.seed', 'credential.json', '.pending-'))
    return report


def fault_filter(mode):
    offline()
    numbers = {'x86_64': {'sync': 74, 'unlink': 263}, 'aarch64': {'sync': 82, 'unlink': 35}}[platform.machine()]
    number = numbers['unlink' if mode == 'cleanup' else 'sync']
    result = 0x80000000 if mode == 'killed' else 0x00050000 | (errno.EACCES if mode == 'cleanup' else errno.ENOSPC)
    code = [(0x20, 0, 0, 0), (0x15, 0, 1, number), (0x06, 0, 0, result), (0x06, 0, 0, 0x7fff0000)]
    class Filter(ctypes.Structure):
        _fields_ = [('code', ctypes.c_ushort), ('jt', ctypes.c_ubyte), ('jf', ctypes.c_ubyte), ('k', ctypes.c_uint)]
    class Program(ctypes.Structure):
        _fields_ = [('length', ctypes.c_ushort), ('filter', ctypes.POINTER(Filter))]
    filters = (Filter * len(code))(*(Filter(*item) for item in code))
    program = Program(len(code), filters)
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(22, 2, ctypes.byref(program), 0, 0):
        raise OSError(ctypes.get_errno(), 'Cannot install failure proof filter')


def failure_lifecycle(cli, project, root):
    for mode in ('initialization', 'cleanup', 'killed'):
        directory = root / mode
        directory.mkdir()
        result = subprocess.run([str(cli), 'test', '--format', 'json'], cwd=project,
                                capture_output=True, text=True, timeout=60,
                                env={'PATH': '/unavailable', 'TMPDIR': str(directory)},
                                preexec_fn=lambda: fault_filter(mode))
        if mode == 'killed':
            assert result.returncode == -signal.SIGSYS and not result.stdout, result
            assert list(directory.iterdir()), 'Process death did not reach private host storage'
        else:
            assert result.returncode == 1 and not result.stderr, result
            report = json.loads(result.stdout)
            assert not report['ok'] and not report['complete'], report
            assert report['cases'][0]['status'] == 'failed'
            assert report['cases'][1]['status'] == 'not_run'
            if mode == 'initialization':
                assert not list(directory.iterdir()), 'Failed initialization leaked storage'
            else:
                assert list(directory.iterdir()), 'Deletion refusal was not exercised'
        # The proof owns this entire directory. Never discover/sweep others.
        shutil.rmtree(directory)


def suite(body, name='case'):
    return f"CREATE TEST TARGET tests AS BEGIN TEST '{name}' USING MODULES () AS BEGIN {body} END; END;"


def installed_oracle(cli, sql):
    """The same independently written SQL through an ordinary installed caller."""
    fixture = Fixture(cli)
    fixture.use_private_runtime()
    passed = False
    try:
        fixture.start()
        fixture.ready()
        fixture.console('DROP TABLE items;')
        rows = []
        counts = []
        for index, statement in enumerate(sql.splitlines()):
            outcomes = fixture.console(statement, expected=1 if index == 4 else 0)
            if index == 4:
                continue
            for value in outcomes:
                if 'schema' in value:
                    rows.append(sorted(records(value), key=lambda row: int(row['id'])))
                    assert value['complete']['rows'] == '2'
                elif value.get('completion', {}).get('kind') == 'insert':
                    counts.append(value['completion']['counts'])
        assert counts == [{'matched': '1', 'changed': '1'}] * 2, counts
        expected = [{'id': '7', 'value': 'initial'}, {'id': '9', 'value': None}]
        assert rows == [expected, expected], rows
        passed = True
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed Table test oracle: {fixture.root}', file=sys.stderr)


def workspace_test_journey(cli, parent):
    ws = parent / 'workspace-tests'
    source(ws, 'build.transit', (
        "IMPORT MODULE apps FROM './apps/build.transit';\n"
        "EXPORT TARGET app_sql = apps.app_sql;\n"
        "EXPORT TARGET app_tests = apps.app_tests;\n"
        "EXPORT DEFAULT TARGET app_sql;\n"
    ))
    source(ws, 'apps/build.transit', (
        "IMPORT MODULE app FROM './app/build.transit';\n"
        "EXPORT TARGET app_sql = app.sql;\n"
        "EXPORT TARGET app_tests = app.tests;\n"
    ))
    source(ws, 'apps/app/shared/helpers.transit', (
        "CREATE PUBLIC FUNCTION normalize_label(raw TEXT) RETURNS TEXT AS BEGIN\n"
        "  RETURN CASE WHEN raw = '' THEN 'unnamed' ELSE raw END;\n"
        "END;\n"
    ))
    source(ws, 'apps/app/tenancy/state.transit', (
        "CREATE PUBLIC TABLE tenants (id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL);\n"
    ))
    source(ws, 'apps/app/tenancy/guards.transit', (
        "CREATE GUARD require_tenant(tenants_tbl TABLE(id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL), tenant_id BIGINT) AS BEGIN\n"
        "  LET found = SELECT active FROM tenants_tbl WHERE id = tenant_id;\n"
        "  REQUIRE found IS NOT NULL ELSE 'MissingTenant';\n"
        "  REQUIRE found.active ELSE 'InactiveTenant';\n"
        "END;\n"
    ))
    source(ws, 'apps/app/tenancy/build.transit', (
        "EXPORT MODULE application(schema SCHEMA_BINDING) AS BEGIN\n"
        "  BIND SCHEMA tenancy TO schema;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './guards.transit';\n"
        "  EXPORT TABLE tenants;\n"
        "  EXPORT GUARD require_tenant;\n"
        "END;\n"
        "EXPORT TEST SUITE tests FROM './tenancy.test.transit';\n"
    ))
    source(ws, 'apps/app/tenancy/tenancy.test.transit', (
        "TEST 'tenancy table accepts active tenant' USING MODULES (platform) AS BEGIN\n"
        "  ASSERT COMMAND (INSERT INTO tenants VALUES (1, TRUE, 'acme')) MATCHED 1 CHANGED 1;\n"
        "  ASSERT ROWS (SELECT id, label FROM tenants) EQUAL ((1, 'acme'));\n"
        "END;\n"
    ))
    source(ws, 'apps/app/networking/state.transit', (
        "CREATE PUBLIC TABLE networks (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL);\n"
    ))
    source(ws, 'apps/app/networking/procedures.transit', (
        "CREATE PROCEDURE attach_network(\n"
        "  tenants_tbl TABLE(id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL),\n"
        "  networks_tbl TABLE(id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL),\n"
        "  net_id BIGINT,\n"
        "  tenant_id BIGINT,\n"
        "  label TEXT\n"
        ") RETURNS BIGINT AS BEGIN ATOMIC\n"
        "  CHECK GUARD tenancy.require_tenant(tenants_tbl, tenant_id);\n"
        "  INSERT INTO networks_tbl VALUES (net_id, tenant_id, normalize_label(label)) ON CONFLICT (id) DO ASSERT SAME ROW;\n"
        "  RETURN net_id;\n"
        "END;\n"
    ))
    source(ws, 'apps/app/networking/build.transit', (
        "IMPORT MODULE helpers FROM '../shared/helpers.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, tenancy MODULE OF tenancy_build.application) AS BEGIN\n"
        "  BIND SCHEMA networking TO schema;\n"
        "  USE MODULE helpers;\n"
        "  USE MODULE tenancy;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './procedures.transit';\n"
        "  EXPORT TABLE networks;\n"
        "  EXPORT PROCEDURE attach_network;\n"
        "END;\n"
    ))
    source(ws, 'apps/app/ingress/flow.transit', (
        "CREATE PUBLIC QUEUE ingress_requests (id BIGINT NOT NULL, tenant_id BIGINT NOT NULL, label TEXT NOT NULL);\n"
        "CREATE PUBLIC STREAM ingress_events (id BIGINT NOT NULL, tenant_id BIGINT NOT NULL);\n"
        "CREATE PUBLIC DATAFLOW process_ingress FROM QUEUE ingress_requests AS req AS BEGIN\n"
        "  CHECK GUARD require_tenant(tenants, req.tenant_id);\n"
        "  BEGIN ATOMIC\n"
        "    LET attached = CALL networking.attach_network(tenancy.tenants, networking.networks, req.id, req.tenant_id, req.label);\n"
        "    PRODUCE INTO ingress_events VALUES (attached, req.tenant_id);\n"
        "  END;\n"
        "END;\n"
        "AUTHORIZE DATAFLOW process_ingress AS ROLE CURRENT_ROLE;\n"
        "ACTIVATE DATAFLOW process_ingress;\n"
    ))
    source(ws, 'apps/app/ingress/build.transit', (
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "IMPORT MODULE networking_build FROM '../networking/build.transit';\n"
        "EXPORT MODULE application(\n"
        "  schema SCHEMA_BINDING,\n"
        "  tenancy MODULE OF tenancy_build.application,\n"
        "  networking MODULE OF networking_build.application\n"
        ") AS BEGIN\n"
        "  BIND SCHEMA ingress TO schema;\n"
        "  USE MODULE tenancy;\n"
        "  USE MODULE networking;\n"
        "  DECLARE FROM './flow.transit';\n"
        "END;\n"
    ))
    composition_suite = (
        "TEST 'diamond composition executes guard and returning procedure once' USING MODULES (platform) AS BEGIN\n"
        "  ASSERT COMMAND (INSERT INTO tenants VALUES (10, TRUE, 'core')) MATCHED 1 CHANGED 1;\n"
        "  ENQUEUE INTO ingress_requests VALUES (99, 10, '');\n"
        "  ASSERT WORKFLOW NAME 'process_ingress' COMPLETED 1 REFUSED 0 WITHIN 1000 OBSERVATIONS;\n"
        "  ASSERT ROWS (SELECT id, tenant_id, label FROM networks) EQUAL ((99, 10, 'unnamed'));\n"
        "  ASSERT ROWS (CONSUME id, tenant_id FROM ingress_events) EQUAL ((99, 10));\n"
        "END;\n"
    )
    source(ws, 'apps/app/tests/composition.test.transit', composition_suite)
    source(ws, 'apps/app/build.transit', (
        "IMPORT MODULE tenancy FROM './tenancy/build.transit';\n"
        "IMPORT MODULE networking FROM './networking/build.transit';\n"
        "IMPORT MODULE ingress FROM './ingress/build.transit';\n"
        "EXPORT MODULE application(bindings ROW(tenancy SCHEMA_BINDING, networking SCHEMA_BINDING)) AS BEGIN\n"
        "  LET tenancy_mod = USE MODULE tenancy.application(schema => bindings.tenancy);\n"
        "  LET net_mod = USE MODULE networking.application(schema => bindings.networking, tenancy => tenancy_mod);\n"
        "  LET ingress_mod = USE MODULE ingress.application(schema => bindings.networking, tenancy => tenancy_mod, networking => net_mod);\n"
        "END;\n"
        "LET control = USE MODULE application(bindings => ROW(tenancy => SCHEMA_BINDING('tenancy'), networking => SCHEMA_BINDING('networking')));\n"
        "EXPORT TARGET sql AS SQL OF control;\n"
        "EXPORT TARGET tests AS TESTS OF control USING SUITES (tenancy.tests, './tests/composition.test.transit');\n"
    ))
    # Unique test target is selected automatically when --target is omitted.
    report = invoke(cli, ws, timeout=120)
    assert report['target'] == 'app_tests' and report['complete'], report
    assert [case['status'] for case in report['cases']] == ['passed', 'passed'], report
    assert not (ws / '.transit').exists()

    # Multiple entry test targets refuse implicit selection until --target disambiguates.
    root_text = (ws / 'build.transit').read_text()
    source(ws, 'build.transit', root_text + "EXPORT TARGET second_tests = apps.app_tests;\n")
    ambiguous = invoke(cli, ws, expected=1)
    assert ambiguous['code'] == 'application.source.target' and ambiguous['outcome'] == 'not_submitted', ambiguous
    explicit = invoke(cli, ws, '--target', 'app_tests', timeout=120)
    assert explicit['target'] == 'app_tests' and explicit['complete'], explicit
    source(ws, 'build.transit', root_text)

    # Unsupported WITH (...) test options fail compilation rather than being ignored.
    app_build_text = (ws / 'apps/app/build.transit').read_text()
    source(ws, 'apps/app/build.transit',
           app_build_text.replace("USING SUITES (tenancy.tests, './tests/composition.test.transit');",
                                  "USING SUITES (tenancy.tests, './tests/composition.test.transit') WITH (verify_replay = TRUE);"))
    unsupported = invoke(cli, ws, expected=1)
    assert unsupported['code'] == 'application.source.unsupported' and unsupported['outcome'] == 'not_submitted', unsupported
    shutil.rmtree(ws)


def multi_schema_test_journey(cli, parent):
    ws = parent / 'multi-schema-tests'
    source(ws, 'build.transit', (
        "IMPORT MODULE app FROM './app/build.transit';\n"
        "EXPORT TARGET tests = app.tests;\n"
    ))
    source(ws, 'app/types.transit', (
        "CREATE PUBLIC DOMAIN EnvId AS UUID IDENTITY 'ms.env-id';\n"
        "CREATE PUBLIC FUNCTION format_tag(meta ROW(region TEXT, active BOOLEAN)) RETURNS TEXT AS BEGIN\n"
        "  RETURN CASE WHEN meta.active THEN meta.region ELSE 'disabled' END;\n"
        "END;\n"
    ))
    source(ws, 'app/tenancy/state.transit', (
        "CREATE SCHEMA tenancy;\n"
        "CREATE PUBLIC TABLE tenancy.environments (\n"
        "  id $env_ty PRIMARY KEY,\n"
        "  tenant_code TEXT NOT NULL,\n"
        "  active BOOLEAN NOT NULL,\n"
        "  secret_note TEXT NOT NULL\n"
        ");\n"
        "INSERT INTO tenancy.environments VALUES ($seed_env, 'acme', TRUE, 'sealed');\n"
    ))
    source(ws, 'app/tenancy/guards.transit', (
        "IMPORT types FROM '../types.transit';\n"
        "CREATE GUARD tenancy.require_scope(scope ROW(expected_tenant TEXT, actual_tenant TEXT, active BOOLEAN)) AS\n"
        "  REQUIRE scope.active ELSE 'InactiveEnvironment',\n"
        "  REQUIRE scope.actual_tenant = scope.expected_tenant ELSE 'TenantMismatch';\n"
        "CREATE GUARD tenancy.require_environment(env_id types.EnvId, expected_tenant TEXT) AS BEGIN\n"
        "  LET found = SELECT tenant_code, active FROM tenancy.environments WHERE id = env_id;\n"
        "  REQUIRE found IS NOT NULL ELSE 'MissingEnvironment';\n"
        "  CHECK GUARD tenancy.require_scope(ROW(expected_tenant, found.tenant_code, found.active));\n"
        "END;\n"
    ))
    source(ws, 'app/tenancy/build.transit', (
        "IMPORT MODULE types FROM '../types.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, env_ty TYPE, seed_env types.EnvId) AS BEGIN\n"
        "  BIND SCHEMA tenancy TO schema;\n"
        "  USE MODULE types;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './guards.transit';\n"
        "  EXPORT REFERENCE TABLE tenancy.environments(id, tenant_code);\n"
        "  EXPORT GUARD tenancy.require_environment;\n"
        "END;\n"
    ))
    source(ws, 'app/networking/state.transit', (
        "CREATE SCHEMA networking;\n"
        "CREATE PUBLIC TABLE networking.networks (\n"
        "  id BIGINT PRIMARY KEY,\n"
        "  env_id $env_ty NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  cidr TEXT NOT NULL\n"
        ");\n"
        "CREATE PUBLIC TABLE networking.attachments (\n"
        "  net_id BIGINT PRIMARY KEY,\n"
        "  env_id $env_ty NOT NULL,\n"
        "  tag TEXT NOT NULL\n"
        ");\n"
    ))
    source(ws, 'app/networking/procedures.transit', (
        "IMPORT types FROM '../types.transit';\n"
        "CREATE PROCEDURE networking.attach_consumer(net_id BIGINT, env_id types.EnvId, meta ROW(region TEXT, active BOOLEAN)) RETURNS TEXT AS BEGIN ATOMIC\n"
        "  LET net = SELECT cidr FROM networking.networks WHERE id = net_id;\n"
        "  REQUIRE net IS NOT NULL ELSE 'MissingNetwork';\n"
        "  LET tag = types.format_tag(meta);\n"
        "  INSERT INTO networking.attachments VALUES (net_id, env_id, tag) ON CONFLICT (net_id) DO ASSERT SAME ROW;\n"
        "  RETURN tag;\n"
        "END;\n"
    ))
    source(ws, 'app/networking/build.transit', (
        "IMPORT MODULE types FROM '../types.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "EXPORT MODULE application(schema SCHEMA_BINDING, env_ty TYPE, tenancy MODULE OF tenancy_build.application) AS BEGIN\n"
        "  BIND SCHEMA networking TO schema;\n"
        "  USE MODULE types;\n"
        "  USE MODULE tenancy;\n"
        "  DECLARE FROM './state.transit';\n"
        "  DECLARE FROM './procedures.transit';\n"
        "  EXPORT TABLE networking.networks;\n"
        "  EXPORT PROCEDURE networking.attach_consumer;\n"
        "END;\n"
    ))
    source(ws, 'app/deployments/flow.transit', (
        "CREATE SCHEMA deployments;\n"
        "CREATE PUBLIC TABLE deployments.releases (\n"
        "  id BIGINT PRIMARY KEY,\n"
        "  env_id $env_ty NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  net_id BIGINT NOT NULL REFERENCES networking.networks(id) ON DELETE RESTRICT NOT ENFORCED,\n"
        "  deployed_at TIMESTAMPTZ NOT NULL,\n"
        "  digest BINARY NOT NULL,\n"
        "  tag TEXT NOT NULL\n"
        ");\n"
        "CREATE PUBLIC QUEUE deployments.requests (\n"
        "  id BIGINT NOT NULL,\n"
        "  env_id $env_ty NOT NULL,\n"
        "  tenant_code TEXT NOT NULL,\n"
        "  net_id BIGINT NOT NULL,\n"
        "  region TEXT NOT NULL,\n"
        "  deployed_at TIMESTAMPTZ NOT NULL,\n"
        "  digest BINARY NOT NULL\n"
        ");\n"
        "CREATE PUBLIC STREAM deployments.events (id BIGINT NOT NULL, tag TEXT NOT NULL);\n"
        "CREATE PUBLIC DATAFLOW deployments.provision FROM QUEUE deployments.requests AS req AS BEGIN\n"
        "  CHECK GUARD tenancy.require_environment(req.env_id, req.tenant_code);\n"
        "  BEGIN ATOMIC\n"
        "    LET tag = CALL networking.attach_consumer(req.net_id, req.env_id, ROW(req.region, TRUE));\n"
        "    INSERT INTO deployments.releases VALUES (req.id, req.env_id, req.net_id, req.deployed_at, req.digest, tag) ON CONFLICT (id) DO ASSERT SAME ROW;\n"
        "    PRODUCE INTO deployments.events VALUES (req.id, tag);\n"
        "  END;\n"
        "END;\n"
        "AUTHORIZE DATAFLOW deployments.provision AS ROLE CURRENT_ROLE;\n"
        "ACTIVATE DATAFLOW deployments.provision;\n"
    ))
    source(ws, 'app/deployments/build.transit', (
        "IMPORT MODULE types FROM '../types.transit';\n"
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';\n"
        "IMPORT MODULE networking_build FROM '../networking/build.transit';\n"
        "EXPORT MODULE application(\n"
        "  schema SCHEMA_BINDING,\n"
        "  env_ty TYPE,\n"
        "  tenancy MODULE OF tenancy_build.application,\n"
        "  networking MODULE OF networking_build.application\n"
        ") AS BEGIN\n"
        "  BIND SCHEMA deployments TO schema;\n"
        "  USE MODULE types;\n"
        "  USE MODULE tenancy;\n"
        "  USE MODULE networking;\n"
        "  DECLARE FROM './flow.transit';\n"
        "  EXPORT TABLE deployments.releases;\n"
        "  EXPORT QUEUE deployments.requests;\n"
        "  EXPORT STREAM deployments.events;\n"
        "END;\n"
    ))
    env_uuid = '550e8400-e29b-41d4-a716-446655440000'
    suite_text = (
        "IMPORT MODULE types FROM './types.transit';\n"
        "CREATE MODULE AddNetwork(tbl TABLE(id BIGINT PRIMARY KEY, env_id types.EnvId NOT NULL, cidr TEXT NOT NULL), id BIGINT, env_id types.EnvId, cidr TEXT) AS BEGIN\n"
        "  ASSERT COMMAND (INSERT INTO $tbl VALUES ($id, $env_id, $cidr)) MATCHED 1 CHANGED 1;\n"
        "END;\n"
        "CREATE MODULE SendDeploy(q QUEUE(id BIGINT NOT NULL, env_id types.EnvId NOT NULL, tenant_code TEXT NOT NULL, net_id BIGINT NOT NULL, region TEXT NOT NULL, deployed_at TIMESTAMPTZ NOT NULL, digest BINARY NOT NULL), id BIGINT, env_id types.EnvId, tenant_code TEXT, net_id BIGINT, region TEXT) AS BEGIN\n"
        "  ENQUEUE INTO $q VALUES ($id, $env_id, $tenant_code, $net_id, $region, TIMESTAMP '2026-07-04T09:30:00Z', X'DEADBEEF');\n"
        "END;\n"
        "TEST 'multi-schema reference exports and typed domains execute in isolated host' USING MODULES (platform) AS BEGIN\n"
        f"  USE AddNetwork(networks, 7, types.EnvId(UUID '{env_uuid}'), '10.1.0.0/16');\n"
        f"  USE SendDeploy(requests, 901, types.EnvId(UUID '{env_uuid}'), 'acme', 7, 'eu-central-1');\n"
        f"  USE SendDeploy(requests, 902, types.EnvId(UUID '{env_uuid}'), 'wrong-tenant', 7, 'eu-central-1');\n"
        "  ASSERT WORKFLOW NAME 'deployments.provision' COMPLETED 1 REFUSED 1 WITHIN 1000 OBSERVATIONS;\n"
        "  ASSERT ROWS (SELECT id, env_id, net_id, deployed_at, digest, tag FROM deployments.releases) EQUAL (\n"
        f"    (901, UUID '{env_uuid}', 7, TIMESTAMP '2026-07-04T09:30:00Z', X'DEADBEEF', 'eu-central-1')\n"
        "  );\n"
        "  ASSERT ROWS (CONSUME id, tag FROM deployments.events) EQUAL ((901, 'eu-central-1'));\n"
        "END;\n"
    )
    source(ws, 'app/multi_schema.test.transit', suite_text)
    source(ws, 'app/build.transit', (
        "IMPORT MODULE types FROM './types.transit';\n"
        "IMPORT MODULE tenancy FROM './tenancy/build.transit';\n"
        "IMPORT MODULE networking FROM './networking/build.transit';\n"
        "IMPORT MODULE deployments FROM './deployments/build.transit';\n"
        "EXPORT MODULE application() AS BEGIN\n"
        f"  LET t = USE MODULE tenancy.application(schema => SCHEMA_BINDING('tenancy'), env_ty => TYPE types.EnvId, seed_env => types.EnvId(UUID '{env_uuid}'));\n"
        "  LET n = USE MODULE networking.application(schema => SCHEMA_BINDING('networking'), env_ty => TYPE types.EnvId, tenancy => t);\n"
        "  LET d = USE MODULE deployments.application(schema => SCHEMA_BINDING('deployments'), env_ty => TYPE types.EnvId, tenancy => t, networking => n);\n"
        "  EXPORT REFERENCE TABLE t.environments(id) AS environments;\n"
        "  EXPORT TABLE n.networks AS networks;\n"
        "  EXPORT TABLE d.releases AS releases;\n"
        "  EXPORT QUEUE d.requests AS requests;\n"
        "  EXPORT STREAM d.events AS events;\n"
        "END;\n"
        "LET control = USE MODULE application();\n"
        "EXPORT TARGET tests AS TESTS OF control USING SUITES ('./multi_schema.test.transit');\n"
    ))
    report = invoke(cli, ws, timeout=180)
    assert report['target'] == 'tests' and report['complete'], report
    assert [case['status'] for case in report['cases']] == ['passed'], report

    # Test cases also respect EXPORT REFERENCE TABLE encapsulation and cannot read tenancy.environments directly.
    source(ws, 'app/multi_schema.test.transit',
           suite_text.replace("END;\n", "  SELECT id FROM tenancy.environments;\nEND;\n"))
    refused = invoke(cli, ws, expected=1)
    assert refused['code'] == 'application.source.import' and refused['outcome'] == 'not_submitted', refused
    shutil.rmtree(ws)


def main():
    cli = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix='transit-application-test-') as temporary:
        root = Path(temporary)
        source_diagnostics(cli, root, 'test')
        programs = root / 'queue-programs'
        shutil.copytree(ROOT / 'tests/fixtures/application-queue-programs', programs)
        program_report = invoke(cli, programs)
        assert program_report['complete'] and [case['status'] for case in program_report['cases']] == ['passed', 'passed'], program_report
        assert [case['observation']['rows'] for case in program_report['cases']] == [2, 0], program_report
        program_source = (programs / 'build.transit').read_text()
        source(programs, 'build.transit', program_source.replace("EQUAL ((7, 'accepted:ready'))", "EQUAL ((8, 'accepted:ready'))", 1))
        wrong = invoke(cli, programs, expected=1)
        assert wrong['cases'][0]['status'] == 'failed' and wrong['cases'][0]['observation']['failure'] == 'rows', wrong
        human = subprocess.run([str(cli), 'test'], cwd=programs, capture_output=True, text=True,
                               timeout=60, env={'PATH': '/unavailable'}, preexec_fn=offline)
        at = wrong['cases'][0]['action_location']
        shown = at['source'].removeprefix('root/')
        assert human.returncode == 1 and not human.stdout, human
        assert f"{shown}:{at['line']}:{at['byte_column']}: error: row assertion failed:" in human.stderr, human.stderr
        assert '^~' in human.stderr and 'note: in test ' in human.stderr, human.stderr
        assert 'Test Summary: 1/2 tests passed; 1 failed' in human.stderr, human.stderr
        assert 'no sql submitted' not in human.stderr.lower() and 'root/' not in human.stderr and '\x1b' not in human.stderr, human.stderr
        colored = subprocess.run([str(cli), 'test', '--color', 'on'], cwd=programs, capture_output=True, text=True,
                                 timeout=60, env={'PATH': '/unavailable'}, preexec_fn=offline)
        assert colored.returncode == 1 and not colored.stdout, colored
        assert '\x1b[1;31merror:\x1b[0m' in colored.stderr and '\x1b[1;32m^~' in colored.stderr and '\x1b[1;36mnote:\x1b[0m' in colored.stderr, colored.stderr
        source(programs, 'build.transit', program_source.replace('COMPLETED 1 REFUSED 2 WITHIN 1000', 'COMPLETED 2 REFUSED 2 WITHIN 1'))
        incomplete = invoke(cli, programs, expected=1)
        assert incomplete['cases'][0]['status'] == 'failed' and incomplete['cases'][0]['observation']['failure'] == 'workflow_progress', incomplete
        source(programs, 'build.transit', program_source)
        typed_queue = root / 'typed-queue'
        shutil.copytree(ROOT / 'tests/fixtures/application-typed-queue', typed_queue)
        # Five isolated cases retain the CLI's 30-second per-case budget. The
        # process watchdog covers their aggregate execution and joined cleanup.
        report = invoke(cli, typed_queue, timeout=180)
        assert report['complete'] and [case['status'] for case in report['cases']] == ['passed'] * 5, report
        assert [case['observation']['rows'] for case in report['cases']] == [2, 0, 0, 0, 2], report
        workflow = (typed_queue / 'workflow.transit').read_text()
        source(typed_queue, 'workflow.transit', workflow.replace('found.id = request.machine_id', 'found.id = request.id'))
        refused = invoke(cli, typed_queue, expected=1)
        assert refused['code'] == 'application.source.domain' and refused['outcome'] == 'not_submitted' and 'cases' not in refused, refused
        assert not (typed_queue / '.transit').exists()
        modular = root / 'modular-programs'
        shutil.copytree(ROOT / 'tests/fixtures/application-modular-programs', modular)
        modular_report = invoke(cli, modular, timeout=240)
        assert modular_report['complete'] and [case['status'] for case in modular_report['cases']] == ['passed'] * 6, modular_report
        assert [case['observation']['rows'] for case in modular_report['cases']] == [2, 0, 0, 0, 0, 1], modular_report
        assert 0 < modular_report['compiler_peak_bytes'] <= 64 * 1024 * 1024, modular_report
        for case in modular_report['cases']:
            resources = case['observation']['resources']
            assert 0 < resources['memory_peak_bytes'] <= modular_report['limits']['host_bytes'], case
            assert 0 < resources['storage_reserved_bytes'] <= modular_report['limits']['storage_bytes'], case
        modular_workflow = (modular / 'workflow.transit').read_text()
        modular_helpers = (modular / 'helpers.transit').read_text()
        for filename, original_text, mutated_text, expected_code in (
                ('workflow.transit', modular_workflow,
                 modular_workflow.replace("LET summary = 'caller-local-shadow-sentinel';", "LET summary = helpers.clean_note(order_item.note);"),
                 'application.source.import'),
                ('workflow.transit', modular_workflow,
                 modular_workflow.replace('helpers.verify_account($accounts, order_item.account_id, order_item.amount)',
                                          'helpers.verify_account($accounts, order_item.id, order_item.amount)'),
                 'application.source.domain'),
                ('helpers.transit', modular_helpers,
                 modular_helpers.replace("RETURN token = token;", "RETURN token = RANDOM_TOKEN(16);"),
                 'application.source.unsupported'),
                ('helpers.transit', modular_helpers,
                 modular_helpers.replace("RETURN order_id;", "RETURN preserve_order(order_id);"),
                 'application.source.unsupported')):
            source(modular, filename, mutated_text)
            refused = invoke(cli, modular, expected=1)
            assert refused['code'] == expected_code and refused['outcome'] == 'not_submitted' and 'cases' not in refused, (filename, expected_code, refused)
            assert not (modular / '.transit').exists()
            source(modular, filename, original_text)
        shutil.rmtree(modular)
        typed = root / 'typed-targets'
        shutil.copytree(ROOT / 'tests/fixtures/application-typed-targets', typed)
        typed_report = invoke(cli, typed)
        assert typed_report['complete'] and [case['status'] for case in typed_report['cases']] == ['passed', 'passed']
        assert [case['observation']['rows'] for case in typed_report['cases']] == [2, 1]
        routing = (typed / 'routing.transit').read_text()
        source(typed, 'routing.transit', routing.replace('INSERT INTO $sites VALUES ($id)', 'INSERT INTO $machines VALUES ($id)'))
        refused = invoke(cli, typed, expected=1)
        assert refused['outcome'] == 'not_submitted' and 'cases' not in refused
        assert not (typed / '.transit').exists()
        project = root / 'project'
        shutil.copytree(ROOT / 'tests/fixtures/application-tests', project)
        oracle = (project / 'expected.sql').read_text()
        first = invoke(cli, project)
        repeat = invoke(cli, project)
        assert first['complete'] and len(first['cases']) == 2, first
        assert all(case['status'] == 'passed' for case in first['cases'])
        for key in ('input_digest', 'sql_digest'):
            assert first[key] == repeat[key]
        assert first['cases'][0]['sql_digest'] == hashlib.sha256((project / 'expected.sql').read_bytes()).hexdigest()
        assert first['cases'][0]['observation']['rows'] == 4
        assert first['cases'][1]['observation']['rows'] == 1
        assert 0 < first['compiler_peak_bytes'] <= 64 * 1024 * 1024
        for case in first['cases']:
            resources = case['observation']['resources']
            assert 0 < resources['memory_peak_bytes'] <= first['limits']['host_bytes']
            assert 0 < resources['storage_reserved_bytes'] <= first['limits']['storage_bytes']
        assert not (project / '.transit').exists()
        for args in (['--verify-replay'], ['--fetch'], ['--out', 'result'], ['--config', '/private'], ['--target', '../escape']):
            failure = invoke(cli, project, *args, expected=2)
            assert failure['outcome'] == 'not_submitted'
        invoke(cli, project, '--target', 'default', expected=1)
        # Ordinary build target coexists with test declarations without running them.
        cli_build(cli, project, '--check')
        failure_lifecycle(cli, project, root)
        original = (project / 'build.transit').read_text()
        for before, after, failure in (
                ('MATCHED 1 CHANGED 1', 'MATCHED 2 CHANGED 1', 'counts'),
                ("(9, NULL), (7, 'initial')", "(9, NULL), (8, 'initial')", 'rows'),
                ("'duplicate_key'", "'check_violation'", 'refusal_reason')):
            source(project, 'build.transit', original.replace(before, after, 1))
            report = invoke(cli, project, expected=1)
            assert report['complete'] and not report['ok']
            assert [case['status'] for case in report['cases']] == ['failed', 'passed']
            assert report['cases'][0]['observation']['failure'] == failure
        source(project, 'build.transit', original.replace("(7, 'duplicate')", "(8, 'duplicate')"))
        report = invoke(cli, project, expected=1)
        assert report['cases'][0]['observation']['failure'] == 'expected_refusal'
        # An unexpected real refusal stops execution and identifies the suffix.
        source(project, 'build.transit', original.replace('(9, NULL)', '(7, NULL)', 1))
        report = invoke(cli, project, expected=1)
        assert not report['complete'] and [case['status'] for case in report['cases']] == ['failed', 'not_run']
        assert report['cases'][0]['error_code'] == 'GatewayMutationRejected'
        source(project, 'build.transit', original + '\nCREATE TEST TARGET empty AS BEGIN END;')
        invoke(cli, project, '--target', 'empty', expected=1)
        # Three batches, nulls, duplicate projected values, full-width integers,
        # authoritative updates/deletes and genuinely empty final results.
        inserts = ''.join(f'INSERT INTO data VALUES ({i}, NULL);' for i in range(70))
        expected = ','.join(f'({i}, NULL)' for i in range(70))
        body = ('CREATE PUBLIC TABLE data (id BIGINT PRIMARY KEY, value TEXT);' + inserts +
                f'ASSERT ROWS (SELECT * FROM data) EQUAL ({expected});' +
                'ASSERT ROWS (SELECT value FROM data) EQUAL (' + ','.join('(NULL)' for _ in range(70)) + ');' +
                'ASSERT COMMAND (UPDATE data SET id = 9223372036854775807 WHERE id = 0) MATCHED 1 CHANGED 1;' +
                'ASSERT ROWS (SELECT id FROM data WHERE id = 9223372036854775807) EQUAL ((9223372036854775807));' +
                'ASSERT COMMAND (DELETE FROM data) MATCHED 70 CHANGED 70;' +
                'ASSERT ROWS (SELECT * FROM data) EQUAL ();')
        source(project, 'build.transit', suite(body))
        report = invoke(cli, project)
        assert report['cases'][0]['observation']['rows'] == 141
        # Runtime constraint evidence and unchanged state use the same owners.
        source(project, 'build.transit', suite("CREATE PUBLIC TABLE items(id BIGINT PRIMARY KEY, CHECK (id > 0)); INSERT INTO items VALUES (1); ASSERT STATEMENT (UPDATE items SET id = -1) FAILS WITH 'check_violation'; ASSERT ROWS (SELECT * FROM items) EQUAL ((1));"))
        invoke(cli, project)
        # Case row accounting includes every statement, including plain SELECT.
        seed = 'CREATE PUBLIC TABLE items(id BIGINT); INSERT INTO items VALUES ' + ','.join(f'({i})' for i in range(100)) + ';'
        source(project, 'build.transit', suite(seed + 'SELECT * FROM items;' * 100))
        limit = invoke(cli, project)
        assert limit['cases'][0]['observation']['rows'] == 10000
        source(project, 'build.transit', suite(seed + 'SELECT * FROM items;' * 101))
        limit = invoke(cli, project, expected=1)
        assert not limit['complete'] and limit['cases'][0]['error_code'] == 'TestRowsLimit'
        columns = ','.join(f'c{i} TEXT' for i in range(32))
        values = ','.join('NULL' for _ in range(32))
        seed_wide = ('INSERT INTO items VALUES ' + ','.join(f'({values})' for _ in range(10)) + ';') * 16
        assignments = ','.join(f"c{i} = '" + 'x' * 90 + "'" for i in range(32))
        body = f'CREATE PUBLIC TABLE items({columns});' + seed_wide + f'UPDATE items SET {assignments};' + 'SELECT * FROM items;' * 40
        source(project, 'build.transit', suite(body))
        limit = invoke(cli, project, expected=1)
        assert not limit['complete'] and limit['cases'][0]['error_code'] == 'TestResultBytesLimit', limit
        # Bad expected types and shapes never reach native execution.
        for expected_rows in ("(('seven'))", '((1, 2))', '((NULL))'):
            source(project, 'build.transit', suite('CREATE PUBLIC TABLE items(id BIGINT PRIMARY KEY); ASSERT ROWS (SELECT * FROM items) EQUAL ' + expected_rows + ';'))
            failure = invoke(cli, project, expected=1)
            assert failure['outcome'] == 'not_submitted' and 'cases' not in failure
        # Independent child roots use the same resolver and default test target.
        child = project / 'child'
        child.mkdir()
        source(child, 'build.transit', suite('CREATE PUBLIC TABLE items(id BIGINT); ASSERT ROWS (SELECT * FROM items) EQUAL ();'))
        invoke(cli, project, '-f', 'child/build.transit')
        # All cases compile first: a valid first case cannot conceal a later error.
        source(project, 'build.transit', original.replace('SELECT id FROM items', 'SELECT missing FROM items'))
        report = invoke(cli, project, expected=1)
        assert 'cases' not in report and report['outcome'] == 'not_submitted'
        # Frozen repository test composition and override remain offline, including
        # with the original repository and git absent at execution time.
        remote = root / 'remote'
        remote.mkdir()
        revision = repository(root / 'origin', {'pkg/build.transit': "CREATE PUBLIC MODULE Cases() AS BEGIN TEST 'remote' USING MODULES () AS BEGIN CREATE PUBLIC TABLE items (id BIGINT); INSERT INTO items VALUES (7); ASSERT ROWS (SELECT * FROM items) EQUAL ((7)); END; END;"})
        text = f"DEPENDENCY checks FROM '{root / 'origin'}' REVISION '{revision}' SUBDIRECTORY 'pkg'; IMPORT checks FROM PACKAGE checks FILE 'build.transit'; CREATE TEST TARGET tests AS BEGIN USE checks.Cases(); END;"
        source(remote, 'build.transit', text)
        invoke(cli, remote, expected=1)
        cli_build(cli, remote, '--fetch', fetch=True)
        (root / 'origin').rename(root / 'hidden-origin')
        locked = invoke(cli, remote)
        override = root / 'override'
        override.mkdir()
        source(override, 'build.transit', (root / 'hidden-origin/pkg/build.transit').read_text().replace('7', '8'))
        overridden = invoke(cli, remote, '--override', f'checks={override}')
        assert locked['input_digest'] != overridden['input_digest']
        assert locked['sql_digest'] != overridden['sql_digest']
        lock = (remote / 'transit.lock').read_text()
        changed = json.loads(lock)
        changed['definition'] = 'foreign'
        (remote / 'transit.lock').write_text(json.dumps(changed))
        invoke(cli, remote, expected=1)
        (remote / 'transit.lock').write_text(lock)
        pin = json.loads(lock)['dependencies'][0]
        cached = remote / '.transit/packages' / pin['digest'] / 'tree/build.transit'
        cached.write_text(cached.read_text() + '\n')
        invoke(cli, remote, expected=1)
        shutil.rmtree(project)
        shutil.rmtree(remote)
        workspace_test_journey(cli, root)
        multi_schema_test_journey(cli, root)
        installed_oracle(cli, oracle)
    print('Application tests: offline isolation, typed rows, counts, refusals, child/remote targets and failure coverage passed')


if __name__ == '__main__':
    main()
