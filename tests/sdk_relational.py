"""Installed language-native relational callers; shared real-authority schedule."""
import json
import os
from pathlib import Path
import shutil
import sys

from sdk_catalog import install
from sdk_unified import Consumer

ROOT = Path(__file__).resolve().parents[1]


def exercise(languages, url, root, catalogs, policy, typed, sql):
    installed = root / 'installed-relational'
    install(installed, languages)
    results = []
    for language in languages:
        target = installed / language
        config = target / 'relational.json'
        config.write_text(json.dumps(dict(url=url, catalogs=catalogs, seed_file=str(root / 'relational-caller.seed'), spill_directory=str(root))))
        environment = {k: v for k, v in os.environ.items() if k not in ('NODE_PATH', 'PYTHONPATH', 'PYTHONHOME', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
        if language == 'node':
            script = target / 'relational.mjs'
            shutil.copy2(ROOT / 'tests/node_relational_sdk.mjs', script)
            commands = [('node', ['node', str(script), str(config)])]
        elif language == 'python':
            script = target / 'relational.py'
            shutil.copy2(ROOT / 'tests/python_relational_sdk.py', script)
            commands = [(f'python-{mode}', [str(target / 'venv/bin/python'), '-B', str(script), mode, str(config)]) for mode in ('sync', 'async')]
        else:
            raise ValueError('No installed relational adapter for this language')
        for name, command in commands:
            client = Consumer(command, environment, target)
            def failure(action, expected):
                client.send(action)
                result = client.read()
                assert result['status'] and result['value']['err'] == expected, result
                return result['value']
            try:
                layouts = []
                for number, routes, expected in ((101, [0, 0], [[None,'1','0',None],['7','6','6','12'],['9','1','0',None]]), (102, [0, 1], [[None,'1','0',None],['7','2','2','16'],['9','1','0',None]])):
                    statement = dict(sql=sql, routes=routes)
                    explained = client.call(dict(explain=statement))
                    action = dict(open=dict(id=f'{number:032x}', statement=statement))
                    opened = client.call(action)
                    assert client.call(action) == opened
                    assert not explained['executed'] and not opened['completeCoverage']
                    assert explained['plan'] == opened['description']['plan'] == typed(routes)['plan']
                    assert explained['sources'][0]['catalog'] == str((1 << 64)-1)
                    ref = opened['reference']
                    assert json.loads(ref)['plan'] == explained['plan']
                    failure(dict(page=dict(reference=ref, ordinal='1')), 'InvalidQueryCursor')
                    rows = []
                    for ordinal in range(4):
                        request = dict(page=dict(reference=ref, ordinal=str(ordinal)))
                        page = client.call(request)
                        assert client.call(request) == page
                        if page['completeCoverage']:
                            assert page['row'] is None and ordinal == 3
                            break
                        rows.append(page['row'])
                    assert [row['cells'] for row in rows] == expected
                    assert len({json.dumps(row['identity'], sort_keys=True) for row in rows}) == 3
                    client.call(dict(close_query=ref))
                    client.call(dict(close_query=ref))
                    layouts.append(dict(routes=routes, rows=3, complete=True))
                statement = dict(sql=sql, routes=[0, 1])
                ref = client.call(dict(open=dict(id=f'{103:032x}', statement=statement)))['reference']
                client.call(dict(page=dict(reference=ref, ordinal='0')))
                policy(False)
                # SDKs expose the native authority rejection as their code;
                # the owned diagnostic preserves its catalog-level meaning.
                denied = failure(dict(page=dict(reference=ref, ordinal='0')), 'AccessDenied')
                assert denied['diagnostic']['category'] == 'access'
                assert denied['diagnostic']['cause'] == 'CatalogDenied'
                facts = {v['field']: v for v in denied['diagnostic']['facts'] if v}
                assert facts['native_cause']['value'] == dict(text='AccessDenied')
                client.call(dict(close_query=ref))
                policy(True)
                ref = client.call(dict(open=dict(id=f'{104:032x}', statement=statement)))['reference']
                client.call(dict(page=dict(reference=ref, ordinal='0')))
                client.call(dict(reconnect={}))
                failure(dict(page=dict(reference=ref, ordinal='0')), 'InvalidQueryCursor')
                ref = client.call(dict(open=dict(id=f'{105:032x}', statement=dict(sql='SELECT SUM(v) AS total FROM rel_overflow', routes=[0]))))['reference']
                request = dict(page=dict(reference=ref, ordinal='0'))
                failed = failure(request, 'Overflow')
                assert failure(request, 'Overflow') == failed
                facts = {v['field']: v for v in failed['diagnostic']['facts'] if v}
                assert facts['column']['value'] == dict(text='total') and facts['completion']['value'] == dict(boolean=False)
                assert facts['source_key']['value']['text'][-8:] == '00000001'
                client.call(dict(close_query=ref))
                results.append(dict(language=name, layouts=layouts, current_denial=True, lost_host=True, ordered_overflow=True, artifacts=json.loads((target / 'artifacts.json').read_text())))
            finally:
                client.close()
    return results
