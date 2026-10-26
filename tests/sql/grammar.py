"""Regenerate ANTLR, check complete statements, and compare covered Postgres ASTs."""
import hashlib
import json
import re
from interfaces.deployment.reference import ROOT, generate, tree, antlr_ast, pg_ast


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


def documentation_examples():
    from antlr4 import InputStream
    from TransitExtensionsLexer import TransitExtensionsLexer
    from TransitExtensionsParser import TransitExtensionsParser

    grammar = (ROOT / 'contracts/sql/TransitExtensions.g4').read_text()
    extensions = re.search(r'extensionStatement\s*:(.*?);', grammar, re.S).group(1)
    required = set(re.findall(r'\b[a-z]\w*\b', extensions)) | {'selectStatement', 'mutationStatement', 'asOfClause'}
    covered = set()
    count = 0

    def visit(node):
        if hasattr(node, 'getRuleIndex'):
            covered.add(TransitExtensionsParser.ruleNames[node.getRuleIndex()])
            for child in node.getChildren():
                visit(child)

    directory = ROOT / 'docs/handbook/reference/sql'
    for path in [directory.with_suffix('.md'), *sorted(directory.glob('*.md'))]:
        if path.name == 'application.md':
            continue  # Its complete program uses the separate application grammar proof.
        for block in re.findall(r'^```sql\n(.*?)^```', path.read_text(), re.M | re.S):
            # Split on lexer terminators, preserving semicolons inside strings/comments.
            start = 0
            ends = [token.stop + 1 for token in TransitExtensionsLexer(InputStream(block)).getAllTokens()
                    if token.type == TransitExtensionsLexer.SEMI] + [len(block)]
            for end in ends:
                statement = block[start:end].strip()
                start = end
                if statement:
                    rule = {'as-of': 'asOfFragment', 'parameters': 'parameterTemplate', 'relational': 'relationalQuery', 'authorization': 'authorizationStatement'}.get(path.stem, 'statement')
                    visit(tree(statement, rule))
                    count += 1
    assert required <= covered, f'Missing SQL reference examples: {sorted(required - covered)}'
    print(f'SQL documentation: {count} examples parse; every statement and historical fragment covered (syntax only).')


def check():
    import pglast
    from pglast.parser import get_postgresql_version
    assert pglast.__version__ == 'v7.13' and get_postgresql_version() == (17, 7)
    generate()
    data = corpus()
    for case in data['select']:
        actual = antlr_ast(case['sql'])
        assert actual == pg_ast(case['sql']), (case['id'], actual, pg_ast(case['sql']))
    for case in data.get('table_select', []):
        assert antlr_ast(case['sql']) == pg_ast(case['sql']), case
    for case in data['reject']:
        try:
            tree(case['sql'])
        except ValueError:
            pass
        else:
            raise AssertionError(f"invalid/out-of-profile syntax accepted: {case['id']}")
        from pglast.parser import parse_sql_json, ParseError
        try:
            parse_sql_json(case['sql'])
            accepted = True
        except ParseError:
            accepted = False
        assert accepted == case['postgres'], case['id']
    for sql in data['extensions']:
        tree(sql)
    tree('FOR SYSTEM_TIME AS OF 240', 'asOfFragment')
    from relational import reference_check
    reference_check()
    documentation_examples()
    print(f"SQL grammar: {len(data['select'])} SELECT ASTs agree with libpg_query; "
          f"{len(data['reject'])} syntax exclusions; {len(data['extensions'])} extensions; zero ANTLR diagnostics.")
    return data


if __name__ == '__main__':
    check()
