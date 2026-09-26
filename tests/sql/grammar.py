"""Regenerate ANTLR, check complete statements, and compare covered Postgres ASTs."""
import hashlib
import json
from reference import ROOT, generate, tree, antlr_ast, pg_ast


def corpus():
    data = json.loads((ROOT / 'contracts/sql/corpus/statements.json').read_text())
    assert data['version'] == 1
    for source in data['upstream']:
        raw = (ROOT / 'contracts/sql/corpus' / source['path']).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == source['sha256']
    for case in data['select']:
        if 'upstream' in case:
            source = case['upstream']
            lines = (ROOT / 'contracts/sql/corpus' / source['path']).read_text().splitlines()
            assert case['sql'] == '\n'.join(lines[source['first_line'] - 1:source['last_line']])
    return data


def check():
    generate()
    data = corpus()
    for case in data['select']:
        actual = antlr_ast(case['sql'])
        assert actual == pg_ast(case['sql']), (case['id'], actual, pg_ast(case['sql']))
    for case in data['reject']:
        try:
            tree(case['sql'])
        except ValueError:
            pass
        else:
            raise AssertionError(f"invalid/out-of-profile syntax accepted: {case['id']}")
        if case.get('postgres'):
            from pglast.parser import parse_sql_json
            parse_sql_json(case['sql'])
    for sql in data['extensions']:
        tree(sql)
    tree('FOR SYSTEM_TIME AS OF 240', 'asOfFragment')
    print(f"SQL grammar: {len(data['select'])} SELECT ASTs agree with libpg_query; "
          f"{len(data['reject'])} syntax exclusions; {len(data['extensions'])} extensions; zero ANTLR diagnostics.")
    return data


if __name__ == '__main__':
    check()
