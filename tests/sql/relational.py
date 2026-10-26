"""Independent relational AST agreement; no runtime or authority claims.

ANTLR and PostgreSQL adapters derive trees independently of Zig. The fixed
corpus includes clause/alias boundaries, mixed aggregates and Boolean precedence.
"""
import json
import subprocess
import sys
from interfaces.deployment.reference import ROOT, CACHE, generate, tree, identifier, column


def instruction(op, column=None, value=None):
    return dict(op=op, column=column, value=value)


def combine(parts, op):
    result = list(parts[0])
    for part in parts[1:]:
        result += part + [instruction(op)]
    return result


def antlr(sql):
    ctx = tree(sql, 'relationalQuery').relationalSelect()

    def source(target):
        name = identifier(target.identifier())
        alias = target.relationalAlias()
        return dict(name=name, alias=identifier(alias.identifier() or alias.relationalImplicitAlias()) if alias else name)

    def selection(selected):
        ref = column(selected.columnReference()) if selected.columnReference() else None
        kind = 'sum' if selected.SUM() else 'count_all' if selected.STAR() else 'count' if selected.COUNT() else 'column'
        name = identifier(selected.outputAlias().identifier()) if selected.outputAlias() else ref[1] if kind == 'column' else 'sum' if kind == 'sum' else 'count'
        return dict(kind=kind, column=ref, name=name)

    def negate(ctx):
        if ctx.NOT():
            return negate(ctx.negation()) + [instruction('not')]
        if ctx.predicate():
            return predicate(ctx.predicate())
        atom = ctx.predicateAtom()
        ref = column(atom.columnReference())
        if atom.IS():
            assert atom.cellState().NULL_()
            return [instruction('is_null', ref)] + ([instruction('not')] if atom.NOT() else [])
        value = int(atom.literal().signedInteger().getText())
        return [instruction({'=': 'eq', '<>': 'ne', '!=': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge'}[atom.comparison().getText()], ref, value)]

    def predicate(ctx):
        return combine([combine([negate(n) for n in c.negation()], 'and') for c in ctx.disjunction().conjunction()], 'or')

    sources = [source(ctx.relationalTarget())]
    join = None
    if j := ctx.relationalJoin():
        sources.append(source(j.relationalTarget()))
        join = dict(kind='left' if j.LEFT() else 'inner', left=column(j.columnReference(0)), right=column(j.columnReference(1)))
    return dict(sources=sources, outputs=[selection(s) for s in ctx.relationalSelection()], join=join,
                groups=[column(c) for c in ctx.columnReference()],
                predicate=predicate(ctx.whereClause().predicate()) if ctx.whereClause() else [])


def postgres(sql):
    from pglast.parser import parse_sql_json
    node = json.loads(parse_sql_json(sql))['stmts'][0]['stmt']['SelectStmt']

    def col(value):
        names = [f['String']['sval'] for f in value['ColumnRef']['fields']]
        return [None, names[0]] if len(names) == 1 else names

    def source(value):
        var = value['RangeVar']
        return dict(name=var['relname'], alias=var.get('alias', {}).get('aliasname', var['relname']))

    def selection(value):
        target = value['ResTarget']
        expr = target['val']
        if 'ColumnRef' in expr:
            return dict(kind='column', column=col(expr), name=target.get('name', col(expr)[1]))
        call = expr['FuncCall']
        name = call['funcname'][0]['String']['sval']
        return dict(kind='count_all' if call.get('agg_star') else name,
                    column=None if call.get('agg_star') else col(call['args'][0]), name=target.get('name', name))

    def number(value):
        if 'A_Expr' in value:
            unary = value['A_Expr']
            assert 'lexpr' not in unary and unary['name'][0]['String']['sval'] == '+'
            return number(unary['rexpr'])
        constant = value['A_Const']
        return int(constant['fval']['fval']) if 'fval' in constant else constant['ival'].get('ival', 0)

    def predicate(value):
        if 'BoolExpr' in value:
            expr = value['BoolExpr']
            parts = [predicate(p) for p in expr['args']]
            return parts[0] + [instruction('not')] if expr['boolop'] == 'NOT_EXPR' else combine(parts, 'and' if expr['boolop'] == 'AND_EXPR' else 'or')
        if 'NullTest' in value:
            expr = value['NullTest']
            return [instruction('is_null', col(expr['arg']))] + ([instruction('not')] if expr['nulltesttype'] == 'IS_NOT_NULL' else [])
        expr = value['A_Expr']
        op = expr['name'][0]['String']['sval']
        return [instruction({'=': 'eq', '<>': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge'}[op], col(expr['lexpr']), number(expr['rexpr']))]

    target = node['fromClause'][0]
    join = None
    if 'JoinExpr' in target:
        expr = target['JoinExpr']
        sources = [source(expr['larg']), source(expr['rarg'])]
        condition = expr['quals']['A_Expr']
        assert condition['name'][0]['String']['sval'] == '='
        join = dict(kind='left' if expr['jointype'] == 'JOIN_LEFT' else 'inner', left=col(condition['lexpr']), right=col(condition['rexpr']))
    else:
        sources = [source(target)]
    return dict(sources=sources, outputs=[selection(s) for s in node['targetList']], join=join,
                groups=[col(c) for c in node.get('groupClause', [])],
                predicate=predicate(node['whereClause']) if 'whereClause' in node else [])


def corpus():
    return json.loads((ROOT / 'contracts/sql/corpus/relational.json').read_text())


def reference_check():
    data = corpus()
    for sql in data['accept']:
        assert antlr(sql) == postgres(sql), (sql, antlr(sql), postgres(sql))
    for sql in data['reject']:
        try:
            tree(sql, 'relationalQuery')
        except ValueError:
            continue
        raise AssertionError(f'Accepted excluded relational syntax: {sql}')
    print(f"Relational grammar: {len(data['accept'])} ASTs agree with PostgreSQL; {len(data['reject'])} syntax exclusions.")
    return data


def main(binary):
    generate()
    data = reference_check()
    path = CACHE / 'relational-cases.json'
    path.write_text(json.dumps(data['accept'] + data['reject']))
    rows = [json.loads(line) for line in subprocess.check_output([binary, str(path)], text=True).splitlines()]
    assert len(rows) == len(data['accept']) + len(data['reject'])
    for sql, actual in zip(data['accept'], rows):
        assert actual == antlr(sql), (sql, actual, antlr(sql))
    for sql, actual in zip(data['reject'], rows[len(data['accept']):]):
        assert 'err' in actual, (sql, actual)
    print('Relational production parser agrees with both independent trees and rejects every excluded case.')


if __name__ == '__main__':
    main(sys.argv[1])
