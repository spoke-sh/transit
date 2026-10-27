"""Installed language-native retained relational callers on the direct owner."""
from runner.paths import ROOT
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

from sdk.sdk_unified import Consumer
from query.execution.relational_callers_native import SQL, EXPECTED, SELF_SQL, SELF_EXPECTED



def install(target, language, environment):
    target.mkdir()
    packages = target / 'packages'
    packages.mkdir()
    artifacts = {}
    if language == 'python':
        for path in (ROOT / '.cache/bindings/Debug/wheels').glob('*.whl'):
            if path.name.split('-')[1] != '0.2.0' or path.name.split('-')[0] not in ('transit_client', 'transit_native_client', 'transit_station', 'transit_native_station'): continue
            shutil.copy2(path, packages / path.name)
            artifacts[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            if path.name.startswith('transit_station-'):
                with zipfile.ZipFile(path) as archive:
                    for name in ('catalog.py', 'catalog_values.py', 'relational.py', 'station-abi.json'):
                        assert archive.read('transit_station/' + name) == (ROOT / 'sdks/python/transit-station/transit_station' / name).read_bytes(), 'Rebuild matching Python wheels'
        assert len(artifacts) == 4
        venv = target / 'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', str(venv)], env=environment, check=True)
        python = str(venv / 'bin/python')
        subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index', '--find-links', str(packages), 'transit-station==0.2.0'], env=environment, check=True, stdout=subprocess.DEVNULL)
        script = target / 'consumer.py'
        shutil.copy2(ROOT / 'tests/sdk/consumers/python/python_relational_sdk.py', script)
        commands = [(f'python-{mode}', [python, '-B', str(script), mode]) for mode in ('sync', 'async')]
    elif language == 'node':
        dependencies = {}
        for name in ('client', 'native-client', 'station', 'native-station'):
            path = ROOT / '.cache/bindings/Debug/node' / f'transit-{name}-0.2.0.tgz'
            copy = packages / path.name
            shutil.copy2(path, copy)
            artifacts[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            dependencies['@transit/' + name] = 'file:' + str(copy)
            if name == 'station':
                with tarfile.open(path) as archive:
                    for filename in ('catalog.js', 'relational.js', 'contract.json'):
                        assert archive.extractfile('package/dist/' + filename).read() == (ROOT / 'sdks/ts/transit-station-sdk/dist' / filename).read_bytes(), 'Rebuild matching Node packages'
        manager = json.loads((ROOT / 'package.json').read_text())['packageManager']
        (target / 'package.json').write_text(json.dumps(dict(private=True, type='module', packageManager=manager, dependencies=dependencies, pnpm=dict(overrides=dependencies))))
        subprocess.run(['vp', 'env', 'exec', '--package-manager', manager, 'pnpm', 'install', '--prefer-offline', '--ignore-scripts'], cwd=target, env=environment, check=True, stdout=subprocess.DEVNULL)
        script = target / 'consumer.mjs'
        shutil.copy2(ROOT / 'tests/sdk/consumers/node/node_relational_sdk.mjs', script)
        commands = [('node', ['node', str(script)])]
    else:
        raise ValueError('No installed relational adapter for this language')
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    return commands


def exercise(languages, authority, service, root, fixture, policy):
    installed = root / 'installed-relational'
    installed.mkdir()
    results = []
    for language in languages:
        target = installed / language
        environment = {k: v for k, v in os.environ.items() if k not in ('NODE_PATH', 'PYTHONPATH', 'PYTHONHOME', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
        commands = install(target, language, environment)
        config = target / 'relational.json'
        config.write_text(json.dumps(dict(url=authority, service_url=service, catalogs=fixture.configuration['catalogs'], seed_file=str(root / 'caller.seed'), spill_directory=str(target))))
        for name, command in commands:
            client = Consumer([*command, str(config)], environment, target, read_timeout=180)
            def failure(action, expected):
                client.send(action)
                result = client.read()
                assert result['status'] and result['value']['err'] == expected, result
                return result['value']
            def prepare(number, sql=SQL, routes=(0, 1)):
                statement = dict(namespace=1, sql=sql, routes=list(routes))
                explained = client.call(dict(explain=statement))
                snapshots = fixture.retain(explained['sources'])
                sources = [dict(basis=json.dumps(source['binding']), snapshot=json.dumps(snapshot)) for source, snapshot in zip(explained['sources'], snapshots, strict=True)]
                action = dict(open=dict(id=f'{number:032x}', statement=statement, sources=sources))
                opened = client.call(action)
                assert client.call(action) == opened
                assert opened['description'] == explained and not opened['completeCoverage']
                assert json.loads(opened['reference'])['plan'] == explained['plan']
                return action, opened, snapshots
            def finish(ref, snapshots):
                client.call(dict(close_query=ref))
                client.call(dict(close_query=ref))
                for snapshot in snapshots:
                    assert not fixture.catalog.call(dict(retention=dict(status=snapshot['owner'])))['retention']['status']['released']
                fixture.release(snapshots)
            try:
                for number, sql, routes, expected in ((101, SQL, (0, 0), EXPECTED), (102, SQL, (0, 1), EXPECTED), (103, SELF_SQL, (0, 0), SELF_EXPECTED)):
                    action, opened, snapshots = prepare(number, sql, routes)
                    assert (opened['cuts'][0] == opened['cuts'][1]) == (sql == SELF_SQL)
                    ref = opened['reference']
                    failure(dict(page=dict(reference=ref, ordinal='1')), 'InvalidQueryCursor')
                    rows = []
                    for ordinal in range(4):
                        request = dict(page=dict(reference=ref, ordinal=str(ordinal)))
                        page = client.call(request)
                        assert client.call(request) == page
                        if page['completeCoverage']:
                            assert page['row'] is None and ordinal == 3
                        else: rows.append(page['row'])
                    assert [[None if value is None else int(value) for value in row['cells']] for row in rows] == expected
                    assert len({json.dumps(row['identity'], sort_keys=True) for row in rows}) == 3
                    finish(ref, snapshots)
                action, opened, snapshots = prepare(104)
                ref = opened['reference']
                first = client.call(dict(page=dict(reference=ref, ordinal='0')))
                policy(False)
                try:
                    denied = failure(dict(page=dict(reference=ref, ordinal='0')), 'AccessDenied')
                    assert denied['diagnostic']['category'] == 'access'
                finally: policy(True)
                assert client.call(dict(page=dict(reference=ref, ordinal='0'))) == first
                client.call(dict(reconnect={}))
                failure(dict(page=dict(reference=ref, ordinal='0')), 'InvalidQueryCursor')
                assert client.call(action) == opened
                finish(ref, snapshots)
                _, opened, snapshots = prepare(105, 'SELECT SUM(v) AS total FROM rel_overflow', (0,))
                ref = opened['reference']
                request = dict(page=dict(reference=ref, ordinal='0'))
                failed = failure(request, 'Overflow')
                assert failure(request, 'Overflow') == failed
                facts = {v['field']: v for v in failed['diagnostic']['facts'] if v}
                assert facts['column']['value'] == dict(text='total') and facts['completion']['value'] == dict(boolean=False)
                assert facts['source_key']['value']['text'][-8:] == '00000001'
                finish(ref, snapshots)
                results.append(dict(language=name, join_layouts=3, current_denial=True, lost_host=True, ordered_overflow=True, original_retention=True, artifacts=json.loads((target / 'artifacts.json').read_text())))
            finally:
                client.close()
    return results
