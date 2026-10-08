"""Read the Table console's typed streaming result contract in native proofs."""
from console import Console


def result(first, read):
    if first.get('profile') != 'table_snapshot_v1':
        return first
    assert not first['complete_coverage'], first
    rows = []
    while True:
        value = read()
        if 'row' in value:
            assert not value['complete_coverage'], value
            rows.append(value['row']['value']['structure'])
            continue
        assert value['complete_coverage'] and 'complete' in value, value
        complete = value['complete']
        assert complete['basis'] == first['basis'] and complete['plan'] == first['plan'], (first, value)
        assert int(complete['rows']) == len(rows), (rows, value)
        return dict(schema=first['schema'], rows=rows, complete=complete)


def results(envelopes):
    stream = iter(envelopes)
    return [result(value, lambda: next(stream)) for value in stream]


def atom(value, kind):
    return value['rows'][0][0]['value']['atom'][kind]


class TableConsole(Console):
    def call(self, text):
        return result(super().call(text), self.read)
