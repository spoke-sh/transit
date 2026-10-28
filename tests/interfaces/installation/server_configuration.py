"""Installed console configuration lifecycle on the server proof's disposable data."""
import json
import hashlib
import os
import subprocess
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from interfaces.cli.table_console import results, records


def yaml_config(value, indent=0):
    lines = []
    for key, item in value.items():
        if isinstance(item, dict):
            lines.append(' ' * indent + key + ':\n' + yaml_config(item, indent + 2))
        else:
            lines.append(' ' * indent + key + ': ' + json.dumps(item) + '\n')
    return ''.join(lines)


def run(fixture):
    original = json.loads(json.dumps(fixture.config))
    def write():
        temporary = fixture.path.with_suffix('.new')
        temporary.write_text(yaml_config(fixture.config))
        temporary.replace(fixture.path)
    explicit = False
    restarted = False
    connection_path = fixture.root / 'configuration-console.yaml'
    connection = fixture.console_config()
    record = fixture.record()
    binding = dict(realm=record['realm'], installation=record['installation'], object=dict(kind='domain', id=record['authorization_steps'][9]))
    connection_path.write_text(json.dumps(connection))
    def sql(statement, ok=True):
        result = subprocess.run([fixture.cli, 'console', '--format', 'json', '-c', statement] + (['--config', str(connection_path)] if explicit else []), cwd=fixture.root,
                                env={'PATH': '/unavailable'}, text=True, capture_output=True, timeout=30)
        assert (result.returncode == 0) == ok, (statement, result)
        output = []
        completion = None
        for value in results(map(json.loads, result.stdout.splitlines())):
            if 'schema' in value:
                output.extend(records(value))
            elif 'completion' in value and 'outcome' in value['completion']:
                assert completion is None, value
                completion = value['completion']
                assert completion['outcome'] in (('applied', 'unchanged') if ok else ('rejected',)), completion
        if statement == 'SELECT transit_reload_conf()':
            assert completion is not None and completion['kind'] == 'reload', completion
            assert completion['operation'] is not None and completion['counts'] is None, completion
            row = sql("SELECT * FROM transit_config_reloads() ORDER BY ordinal DESC LIMIT 1")[0]
            assert completion['pending_restart'] == (row['phase'] == 'pending_restart'), (completion, row)
            output.append(dict(outcome=row))
        return output
    def setting(name):
        return sql(f"SELECT name, value, configured_value, pending_restart, source_line FROM transit_settings() WHERE name = '{name}'")[0]
    try:
        assert sql('SHOW realm')[0]['value'] == str(original['realm'])
        assert sql('SHOW startup.require_existing')[0]['value'] == 'false'
        assert sql('SHOW DATABASES')[0]['database'] == 'transit'
        assert sql('SHOW SCHEMAS')[0]['schema'] == 'public'
        assert len(sql('SHOW ALL')) > 20
        from interfaces.installation.server_application_faults import ExistingKey, native, post
        from interfaces.http.serving import subject_proof, compact
        key = ExistingKey(fixture.root, fixture.installation / 'caller.seed')
        port = fixture.config['ports']['gateway']
        realm = record['realm']
        identity = post(port, '/v1/query', native(key, realm, 10, dict(authorization=dict(role=None, kind=dict(identity={})))) )['body']['authorization']['body']['identity']
        def signed(action, privilege, operation=None):
            request = dict(definition=record['definition'],binding=binding,operation=operation or list(os.urandom(16)),action=action)
            proof = subject_proof(key,10,binding['object']['id'],hashlib.sha256(b'transit.configuration.request.v1\0'+compact(request)).digest(),credential_epoch=identity['credential_epoch'],realm=realm)
            guard = dict(subject=dict(signed=proof),requirements=[dict(object=binding['object'],privileges=privilege,access='all')]+[None]*15,selectable=None)
            return dict(configuration=request,authority=native(key,realm,10,dict(authorization=dict(role=None,kind=dict(check=guard)))))
        observed = post(port,'/configuration/v1',signed(dict(settings=dict(name='version',cursor=None,origins=False)),1))
        generation = observed['result']['settings']['generation']
        request = signed(dict(reload=dict(expected_generation=generation)),4)
        accepted = post(port,'/configuration/v1',request)
        fixture.path.write_text('unknown: changed-after-acceptance\n')
        assert post(port,'/configuration/v1',request)['result']==accepted['result'], 'Exact retry re-read the file'
        write()
        changed = json.loads(json.dumps(request))
        changed['configuration']['action']['reload']['expected_generation'] += 1
        post(port,'/configuration/v1',changed,expected=403)
        conflict = signed(dict(reload=dict(expected_generation=generation+1)),4,request['configuration']['operation'])
        post(port,'/configuration/v1',conflict,expected=409)
        # Model a crash after checkpoint publication but before either history
        # index is complete, using this proof's private installation only.
        checkpoint = fixture.installation / 'configuration.json'
        state = json.loads(checkpoint.read_text())
        outcome = accepted['result']['reload']
        state['pending'] = dict(request=request['configuration'],principal=10,role=None,outcome=outcome)
        temporary = checkpoint.with_suffix('.recovery-test')
        temporary.write_text(json.dumps(state)); temporary.replace(checkpoint)
        history_dir = fixture.installation / 'configuration-history'
        (history_dir / ('operation-'+bytes(outcome['operation']).hex()+'.json')).unlink()
        (history_dir / ('ordinal-'+str(outcome['ordinal'])+'.json')).unlink()
        assert post(port,'/configuration/v1',request)['result']==accepted['result']
        assert json.loads(checkpoint.read_text())['pending'] is None
        operation_id = bytes(outcome['operation']).hex()
        assert sql(f"SELECT phase FROM transit_config_reloads() WHERE operation='{operation_id}'")[0]['phase']==outcome['phase']
        first_page = post(port,'/configuration/v1',signed(dict(settings=dict(name=None,cursor=None,origins=False)),1))
        assert len(first_page['result']['settings']['rows'])==8 and first_page['result']['settings']['next'] is not None
        assert all(row['source_name'] is None for row in first_page['result']['settings']['rows'])

        assert sql("SELECT name FROM transit_settings() WHERE owner = 'gateway' ORDER BY name LIMIT 1")[0]['name'] == 'gateway_allowed_hosts'
        fixture.config['gateway_allowed_hosts'] = ['configuration-proof.example:18080']
        fixture.config['query'] = dict(statement_timeout='5s', statement_timeout_ceiling='10s')
        write()
        competing = [signed(dict(reload=dict(expected_generation=generation)),4) for _ in range(2)]
        with ThreadPoolExecutor(2) as pool:
            outcomes = list(pool.map(lambda body: post(port,'/configuration/v1',body)['result']['reload'], competing))
        assert sorted(item['phase'] for item in outcomes)==['applied','rejected'],outcomes
        assert next(item for item in outcomes if item['phase']=='rejected')['error_code']=='ConfigurationGenerationConflict'
        post(port,'/configuration/v1',signed(dict(settings=dict(name=None,cursor=first_page['result']['settings']['next'],origins=False)),1),expected=409)
        assert setting('query.statement_timeout')['value'] == '5000'
        assert setting('query.statement_timeout')['source_line'] is not None
        with fixture.http.open(urllib.request.Request(fixture.url + '/health', headers={'Host': 'configuration-proof.example:18080'})) as response:
            assert response.status == 200
        settings = subprocess.run([fixture.cli, 'console', '--format', 'json'], input="SET query.statement_timeout = '2s';\nSHOW query.statement_timeout;\nRESET ALL;\nSHOW query.statement_timeout;\n", cwd=fixture.root, env={'PATH': '/unavailable'}, text=True, capture_output=True, timeout=30)
        assert settings.returncode == 0, settings
        assert [row['value'] for value in results(map(json.loads, settings.stdout.splitlines())) if 'schema' in value for row in records(value) if 'value' in row] == ['2000', '5000'], settings
        sql("SET query.statement_timeout = '11s'", ok=False)
        from harness.services import free_port
        fixture.config['ports']['gateway'] = free_port()
        fixture.config['startup'] = {'require_existing': True}
        write()
        pending = sql('SELECT transit_reload_conf()')[0]
        assert pending['outcome']['phase'] == 'pending_restart', pending
        row = setting('ports.gateway')
        assert row['value'] == str(original['ports']['gateway']) and row['configured_value'] == str(fixture.config['ports']['gateway']) and row['pending_restart'], row
        startup = setting('startup.require_existing')
        assert startup['value'] == 'false' and startup['configured_value'] == 'true' and startup['pending_restart'], startup
        explicit = True
        fixture.path.write_text('private_unknown_setting: private-must-not-leak\n')
        rejected = sql('SELECT transit_reload_conf()', ok=False)[0]
        assert rejected['outcome']['phase'] == 'rejected', rejected
        assert 'private' not in json.dumps(rejected)
        assert sql('SHOW query.statement_timeout')[0]['value'] == '5000'
        explicit = False
        fixture.config['admission_ceiling'] = 129
        write()
        assert sql('SELECT transit_reload_conf()', ok=False)[0]['outcome']['error_code'] == 'InitializationSettingChanged'
        history = sql('SELECT phase FROM transit_config_reloads() ORDER BY ordinal DESC LIMIT 2')
        assert [row['phase'] for row in history if 'phase' in row] == ['rejected', 'rejected'], history
        sql('SELECT transit_reload_conf() FROM items', ok=False)
        sql('SELECT * FROM transit_config_check()', ok=False)
        fixture.config['admission_ceiling'] = original.get('admission_ceiling',65536)
        foreign = fixture.root/'foreign-executable'
        foreign.write_text('#!/bin/false\n'); foreign.chmod(0o700)
        fixture.config['executables']['node'] = str(foreign)
        write()
        assert sql('SELECT transit_reload_conf()',ok=False)[0]['outcome']['error_code']=='ConfigurationArtifactMismatch'
        fixture.config['executables']['node'] = original['executables']['node']
        write()
        fixture.stop()
        fixture.url = f"http://127.0.0.1:{fixture.config['ports']['gateway']}"
        restarted = True
        fixture.start(); fixture.ready()
        row = setting('ports.gateway')
        assert row['value']==str(fixture.config['ports']['gateway']) and not row['pending_restart'],row
        startup = setting('startup.require_existing')
        assert startup['value'] == 'true' and not startup['pending_restart'], startup
        assert fixture.record()['installation']==record['installation']
        assert sql('SELECT phase FROM transit_config_reloads() ORDER BY ordinal DESC LIMIT 1')[0]['phase']=='rejected'
        fixture.stop()
        retained = checkpoint.read_bytes()
        installation_before = (fixture.installation / 'installation.json').read_bytes()
        history_before = {path.name: path.read_bytes() for path in history_dir.iterdir()}
        checkpoint.unlink()
        try:
            fixture.refusal('cannot read the retained configuration checkpoint')
            assert not checkpoint.exists(), 'Restart recreated missing accepted settings'
            assert (fixture.installation / 'installation.json').read_bytes() == installation_before
            assert {path.name: path.read_bytes() for path in history_dir.iterdir()} == history_before
        finally:
            checkpoint.write_bytes(retained)
        incomplete_record = json.loads(installation_before)
        del incomplete_record['complete']
        (fixture.installation / 'installation.json').write_text(json.dumps(incomplete_record))
        try:
            fixture.refusal('cannot read the retained installation record')
            assert checkpoint.read_bytes() == retained
        finally:
            (fixture.installation / 'installation.json').write_bytes(installation_before)
        fixture.start(); fixture.ready()
        assert sql('SELECT phase FROM transit_config_reloads() ORDER BY ordinal DESC LIMIT 1')[0]['phase']=='rejected'
    finally:
        fixture.config = original
        explicit = False
        write()
        if restarted:
            fixture.stop()
            fixture.url = f"http://127.0.0.1:{fixture.config['ports']['gateway']}"
            fixture.start(); fixture.ready()
        sql('SELECT transit_reload_conf()')
    print('Configuration: SQL inspection, YAML coordinates, live Host policy, session limits, restart application, invalid/immutable rejection, concurrent reloads, exact retries, history-index recovery and missing-checkpoint refusal passed.', flush=True)
