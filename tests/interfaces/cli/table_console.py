"""Decode the console's native typed result stream for deployment assertions."""
from interfaces.cli.console import Console


def result(first, read):
    if first.get('profile') != 'sql_session_v1':
        return first
    assert not first['complete_coverage'], first
    rows = []
    while True:
        value = read()
        if 'row' in value:
            assert not value['complete_coverage'], value
            rows.append(value['row']['value']['structure'])
            continue
        assert value['complete_coverage'], value
        assert value['rows'] == len(rows), (rows, value)
        return dict(schema=first['schema'], rows=rows, complete=dict(rows=str(value['rows']), basis=value['basis']))


def results(envelopes):
    stream = iter(envelopes)
    return [result(value, lambda: next(stream)) for value in stream]


def atom(value, kind):
    return value['rows'][0][0]['value']['atom'][kind]


def records(value):
    """Named scalar rows used by settings and inspection assertions."""
    names = [column['name'] for column in value['schema']['type']['structure']]
    def cell(value):
        if 'null' in value:
            return None
        atom = value['value']['atom']
        assert len(atom) == 1, atom
        return next(iter(atom.values()))
    return [dict(zip(names, map(cell, row), strict=True)) for row in value['rows']]


class TableConsole(Console):
    def call(self, text):
        return result(super().call(text), self.read)
