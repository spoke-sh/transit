"""Shared neutral relational pages over real catalog routes and disk Ursula."""
import json
from pathlib import Path
import select
import subprocess
import sys
import time

from storage import Fixture, free_port, wait_ready

SQL = 'SELECT l.k, COUNT(*) AS rows, COUNT(r.v) AS present, SUM(r.v) AS total FROM rel_left l LEFT JOIN rel_right r ON l.k = r.k GROUP BY l.k'


def exercise(host, url, root, readers, policy, typed):
    catalogs = []
    for directory in (root, root / 'secondary'):
        owner = json.loads((directory / 'catalog.json').read_text())['writer']
        catalogs.append(dict(scope=dict(realm=46, resource=owner['resource'], catalog=str((1 << 64)-1)), owner=owner['pid'], principal=1234))
    seed = root / 'relational-caller.seed'
    seed.write_text('0a' * 32)
    seed.chmod(0o600)
    options = dict(consistency='per_resource_snapshot_vector', resident_bytes='16777216', spill_bytes='16777216', result_bytes='8388608', output_rows='1000', work_steps='100000', source_pins=2, requests='100000', spill_work='100000')
    config = dict(url=url, seed_file=str(seed), query_client=dict(relational=dict(catalogs=catalogs, options=options, spill_directory=str(root)), timeout_ms=5000))
    config_path = root / 'relational-caller.json'
    process = None
    calls = 0
    max_response_bytes = 0

    def start():
        config_path.write_text(json.dumps(config))
        child = subprocess.Popen([host, str(config_path)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        readers.append(child)
        return child

    def stop():
        if process.poll() is None:
            process.stdin.close()
            process.wait(timeout=15)
        assert process.returncode == 0, process.stderr.read()

    def call(action, error=None):
        nonlocal calls, max_response_bytes
        process.stdin.write(json.dumps({'unified_query': {'relational': action}}, separators=(',', ':')) + '\n')
        process.stdin.flush()
        assert select.select([process.stdout], [], [], 30)[0], 'Relational page exceeded its request deadline'
        line = process.stdout.readline()
        assert line, (process.poll(), process.stderr.read() if process.poll() is not None else '')
        calls += 1
        max_response_bytes = max(max_response_bytes, len(line.encode()))
        envelope = json.loads(line)
        value = envelope['value']
        if error:
            assert envelope['status'] != 0 and value['err'] == error, envelope
            assert value['diagnostic']['outcome'] in ('not_applicable', 'not_submitted'), value
            return value
        assert envelope['status'] == 0, envelope
        return value['relational']

    def open_query(number, routes):
        action = dict(id=f'{number:032x}', statement=dict(sql=SQL, routes=routes))
        explanation = call({'explain': action['statement']})['explained']
        opened = call({'open': action})['opened']
        assert call({'open': action})['opened'] == opened
        assert explanation == opened['description'] and not explanation['executed']
        assert not opened['complete_coverage']
        assert explanation['sources'][0]['catalog'] == str((1 << 64)-1)
        return action, opened

    def page(reference, ordinal, error=None):
        return call({'page': dict(reference=reference, ordinal=str(ordinal))}, error)

    def values(rows):
        return [[None if 'null' in cell else int(next(iter(cell['value']['atom'].values()))) for cell in row['cells']] for row in rows]

    process = start()
    capabilities = call({'capabilities': {}})['capabilities']
    assert capabilities['interactive'] and not capabilities['captured'] and not capabilities['maintained']
    call({'explain': dict(sql='SELECT k FROM rel_left l JOIN rel_right r ON l.k = r.k', routes=[0, 1])}, 'AmbiguousRelationalColumn')
    layouts = []
    for number, routes, expected in ((1, [0, 0], [[None,1,0,None],[7,6,6,12],[9,1,0,None]]), (2, [0, 1], [[None,1,0,None],[7,2,2,16],[9,1,0,None]])):
        action, opened = open_query(number, routes)
        reference = opened['reference']
        native = typed(routes)
        assert reference['plan'] == native['plan'], (reference, native)
        cuts = [{key: cut[key] for key in ('resource', 'revision', 'commitment')} for cut in opened['cuts']]
        assert (cuts[0] == cuts[1]) == (routes == [0, 0]), cuts
        call({'open': {**action, 'statement': {**action['statement'], 'sql': 'SELECT COUNT(*) FROM rel_left'}}}, 'QueryIdentityMismatch')
        page(reference, 1, 'InvalidQueryCursor')
        page(reference, '01', 'InvalidQueryCursor')
        page({**reference, 'plan': 'bad'}, 0, 'QueryIdentityMismatch')
        page({**reference, 'basis': '0'*64}, 0, 'QueryIdentityMismatch')
        rows = []
        for ordinal in range(10):
            result = page(reference, ordinal)['page']
            assert page(reference, ordinal)['page'] == result, 'Lost page response changed exact result'
            if ordinal:
                page(reference, ordinal-1, 'InvalidQueryCursor')
            if result['complete_coverage']:
                assert result['row'] is None
                page(reference, ordinal+1, 'InvalidQueryCursor')
                break
            assert result['row'] is not None
            rows.append(result['row'])
        else:
            raise AssertionError('No complete-coverage page')
        assert values(rows) == expected, rows
        assert len({json.dumps(row['identity'], sort_keys=True) for row in rows}) == len(rows)
        assert call({'close': reference}) == {'closed': {}}
        assert call({'close': reference}) == {'closed': {}}
        page(reference, 0, 'InvalidQueryCursor')
        call({'open': action}, 'QueryIdentityMismatch')
        layouts.append(dict(routes=routes, rows=len(rows), complete=True))

    # Re-reading an already serialized prefix rechecks even the other catalog.
    action, opened = open_query(3, [0, 1])
    reference = opened['reference']
    first = page(reference, 0)['page']
    assert not first['complete_coverage']
    policy(False)
    denial = page(reference, 0, 'CatalogDenied')
    assert denial['diagnostic']['category'] == 'access', denial
    assert call({'close': reference}) == {'closed': {}}
    policy(True)
    action, opened = open_query(4, [0, 1])
    reference = opened['reference']
    page(reference, 0)
    stop()
    process = start()
    page(reference, 0, 'InvalidQueryCursor')
    stop()

    # A budget failure retains an incomplete prefix and the original cause.
    config['query_client']['relational']['options']['output_rows'] = '1'
    process = start()
    _, opened = open_query(5, [0, 1])
    reference = opened['reference']
    assert not page(reference, 0)['page']['complete_coverage']
    first_error = page(reference, 1, 'RelationalResultBudget')
    assert page(reference, 1, 'RelationalResultBudget') == first_error
    call({'close': reference})
    stop()
    config['query_client']['relational']['options']['output_rows'] = '1000'
    process = start()
    overflow = call({'open': dict(id=f'{6:032x}', statement=dict(sql='SELECT SUM(v) AS total FROM rel_overflow', routes=[0]))})['opened']['reference']
    failure = page(overflow, 0, 'Overflow')
    assert page(overflow, 0, 'Overflow') == failure
    facts = {fact['field']: fact for fact in failure['diagnostic']['facts'] if fact}
    assert facts['completion']['value'] == {'boolean': False}, facts
    assert facts['column']['value'] == {'text': 'total'}, facts
    assert facts['expression']['value'] == {'unsigned': '0'}, facts
    assert 'source_key' in facts and 'source_basis' in facts
    assert facts['source_key']['value']['text'][-8:] == '00000001', facts
    call({'close': overflow})
    stop()
    return dict(ordered_overflow_witness=True, layouts=layouts, calls=calls, max_response_bytes=max_response_bytes, repeat_open=True, repeat_page=True, repeat_close=True, source_denial_after_prefix=True, host_loss_expires_handle=True, budget_preserves_failure=True)


def run(node, proof, host, languages=()):
    node, proof, host = [str(Path(path).resolve()) for path in (node, proof, host)]
    started = time.monotonic()
    with Fixture() as fixture:
        root = fixture.root
        secondary = root / 'secondary'
        secondary.mkdir()
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        config = root / 'node.json'
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000), ursula_url=fixture.url, bucket='relational-callers', journal='authority', port=port, resident_pages=8, request_timeout_ms=10000)))
        log = (root / 'node.log').open('w+')
        authority = None
        readers = []
        try:
            subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)
            authority = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
            wait_ready(fixture.http, authority, url + '/health')

            def call(mode, *args, directory=root):
                result = subprocess.run([proof, url, mode, str(directory), *map(str, args)], capture_output=True, text=True, timeout=60)
                assert result.returncode == 0, (mode, result.stderr[-12000:])
                return json.loads(result.stdout)

            def execute(operation, sql, object_id='-', directory=root):
                call('compile', operation, object_id, sql, directory=directory)
                for _ in range(100):
                    result = call('next', directory=directory)
                    if result['state'] == 'terminal':
                        assert result['outcome'] == 'applied' or result.get('table_outcome') == 'applied', result
                        return
                    call('pump', directory=directory)
                raise AssertionError('Catalog setup did not finish')

            for directory, worker in ((root, 65536), (secondary, 65538)):
                call('provision', worker, directory=directory)
                call('initialize', directory=directory)
                call('pump', directory=directory)
            execute(1, 'CREATE TABLE rel_left (k BIGINT, v BIGINT)', 1)
            execute(2, 'CREATE TABLE rel_right (k BIGINT, v BIGINT)', 2)
            execute(3, 'INSERT INTO rel_left VALUES (7,10),(7,20),(9,30),(NULL,40)')
            execute(4, 'INSERT INTO rel_right VALUES (7,1),(7,2),(7,3),(NULL,4)')
            execute(5, 'CREATE TABLE rel_overflow (v BIGINT)', 5)
            execute(6, 'INSERT INTO rel_overflow VALUES (9223372036854775807),(1),(-1)')
            execute(1, 'CREATE TABLE rel_right (k BIGINT, v BIGINT)', 1, directory=secondary)
            execute(2, 'INSERT INTO rel_right VALUES (7,8)', directory=secondary)

            def policy(allow):
                call('policy', 'allow' if allow else 'deny', directory=secondary)
                call('pump', directory=secondary)

            result = exercise(host, url, root, readers, policy, lambda routes: call('relational', SQL, *([secondary] if routes == [0, 1] else [])))
            if languages:
                from sdk_relational import exercise as sdk_exercise
                catalogs = json.loads((root / 'relational-caller.json').read_text())['query_client']['relational']['catalogs']
                result['installed'] = sdk_exercise(languages, url, root, catalogs, policy, lambda routes: call('relational', SQL, *([secondary] if routes == [0, 1] else [])), SQL)
            print(json.dumps(dict(profile='relational-callers-native', seconds=round(time.monotonic()-started, 3), **result)))
        finally:
            for child in readers:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=15)
            if authority is not None:
                authority.terminate()
                authority.wait(timeout=15)
            log.close()


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('node')
    parser.add_argument('proof')
    parser.add_argument('host')
    parser.add_argument('--sdk', action='append', choices=('node', 'python'), default=[])
    args = parser.parse_args()
    run(args.node, args.proof, args.host, args.sdk)
