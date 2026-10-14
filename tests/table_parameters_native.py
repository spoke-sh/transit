"""Prepared Table callers against real signed ingress and the existing owner."""
import json
import select
import subprocess
import time


def qualify(proof, url, root, readers, call, execute, applied, finish, measurements):
    base = 960000
    applied(execute(base, 'CREATE TABLE prepared_rows (k BIGINT PRIMARY KEY, v UTF8, n UINT64 DEFAULT 7)', base))

    def prepare(sql, dml=False, dialect='transit'):
        before = measurements['sends']
        process = subprocess.Popen([proof, url, 'prepared-dml' if dml else 'prepared-select', str(root), sql, dialect],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        readers.append(process)
        assert select.select([process.stdout], [], [], 30)[0], 'Preparation timed out'
        line = process.stdout.readline()
        assert line and json.loads(line)['ready'], (line, process.poll())
        assert measurements['sends'] == before, 'Preparation dispatched native work'
        return process

    def bind(process, values, operation=0):
        process.stdin.write(json.dumps(dict(values=values, operation=operation)) + '\n')
        process.stdin.flush()
        assert select.select([process.stdout], [], [], 30)[0], 'Binding timed out'
        line = process.stdout.readline()
        assert line, process.stderr.read()
        return json.loads(line)

    def rows(process, values):
        result = bind(process, values)
        assert result.get('complete'), result
        return [[json.loads(cell)['cell'] for cell in row] for row in result['rows']]

    integer = lambda n: {'signed': n}
    text = lambda value: {'bytes': value}
    query = prepare('SELECT k, v, n FROM prepared_rows WHERE k = $1')
    insert = prepare('INSERT INTO prepared_rows (k, v, n) VALUES ($1, $2, $3)', True)
    mysql = prepare('UPDATE `prepared_rows` SET v = ? WHERE k = ?', True, 'mysql')
    name = "東京'; DELETE FROM prepared_rows; ? $1"
    before = measurements['sends']
    assert 'kind' in bind(insert, [integer(1), text(name), {'unsigned': 2**64-1}], base+1)
    assert measurements['sends'] == before, 'Binding dispatched native work'
    applied(finish())
    assert rows(query, [integer(1)]) == [[{'value': {'atom': {'signed': '1'}}}, {'value': {'atom': {'utf8': name}}}, {'value': {'atom': {'unsigned': str(2**64-1)}}}]]
    assert rows(query, [None]) == []
    assert bind(insert, [None, None, None], base+2) == {'err': 'NullNotAllowed'}
    assert bind(query, []) == {'err': 'ParameterCountMismatch'}
    assert 'kind' in bind(mysql, [None, integer(1)], base+3)
    result = finish()
    assert (result['matched'], result['changed']) == (1, 1), result
    assert rows(query, [integer(1)])[0][1] == {'null': {}}
    # The same template captures a new cut and sees a later durable mutation.
    applied(execute(base+4, "UPDATE prepared_rows SET v = 'fresh' WHERE k = 1"))
    assert rows(query, [integer(1)])[0][1] == {'value': {'atom': {'utf8': 'fresh'}}}
    null_query = prepare('SELECT k FROM prepared_rows WHERE NOT (k = $1) OR v = $2')
    assert rows(null_query, [None, text('other')]) == []
    assert len(rows(null_query, [None, text('fresh')])) == 1
    call('policy', 'deny')
    deadline = time.monotonic() + 30
    while True:
        denied = bind(query, [integer(1)])
        if 'err' in denied:
            assert denied['err'] in ('CatalogDenied', 'AccessDenied'), denied
            break
        assert time.monotonic() < deadline
        time.sleep(.01)
    call('policy', 'allow')
    deadline = time.monotonic() + 30
    while True:
        allowed = bind(query, [integer(1)])
        if 'err' not in allowed:
            assert allowed['complete'] and len(allowed['rows']) == 1, allowed
            break
        assert allowed['err'] in ('CatalogDenied', 'AccessDenied') and time.monotonic() < deadline, allowed
        time.sleep(.01)
    applied(execute(base+5, 'ALTER TABLE prepared_rows ADD COLUMN extra BIGINT'))
    assert bind(query, [integer(1)]) == {'err': 'CatalogDefinitionChanged'}
    assert bind(mysql, [None, integer(1)], base+6) == {'err': 'CatalogDefinitionChanged'}
    applied(execute(base+7, 'DROP TABLE prepared_rows'))
    applied(execute(base+8, 'CREATE TABLE prepared_rows (k BIGINT PRIMARY KEY, v UTF8, n UINT64 DEFAULT 7)', base+8))
    assert bind(query, [integer(1)]) == {'err': 'CatalogDefinitionChanged'}
    assert bind(insert, [integer(2), None, None], base+9) == {'err': 'CatalogDefinitionChanged'}
    for process in (query, insert, mysql, null_query):
        _, detail = process.communicate(timeout=30)
        assert process.returncode == 0, detail
    return dict(metadata_only=True, owned_dml=True, fresh_cuts=True, null_truth=True, full_width=True,
                mysql_parameters=True, current_denial=True, alter_invalidates=True, replacement_invalidates=True)
