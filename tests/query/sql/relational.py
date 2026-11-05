"""Independent relational AST agreement; no runtime or authority claims.

ANTLR and PostgreSQL adapters derive trees independently of Zig. The fixed
corpus includes clause/alias boundaries, mixed aggregates and Boolean precedence.
"""
import json
import subprocess
import sys
from query.sql.reference import ROOT, CACHE, generate, tree, identifier, column


def instruction(op, column=None, value=None):
    return dict(op=op, column=column, value=value)


def having_instruction(op, expression=None, value=None):
    return dict(op=op, expression=expression, value=value)


def combine(parts, op, make=instruction):
    result = list(parts[0])
    for part in parts[1:]:
        result += part + [make(op)]
    return result


def antlr(sql):
    ctx = tree(sql, 'relationalQuery').relationalSelect()

    def source(target):
        name = identifier(target.identifier())
        alias = target.relationalAlias()
        return dict(name=name, alias=identifier(alias.identifier() or alias.relationalImplicitAlias()) if alias else name)

    def expr(e):
        ref = column(e.columnReference()) if e.columnReference() else None
        kind = 'sum' if e.SUM() else 'count_all' if e.STAR() else 'count' if e.COUNT() else 'column'
        return dict(kind=kind, column=ref)

    def selection(selected):
        item = expr(selected.relationalExpression())
        name = identifier(selected.outputAlias().identifier()) if selected.outputAlias() else item['column'][1] if item['kind'] == 'column' else 'sum' if item['kind'] == 'sum' else 'count'
        return dict(kind=item['kind'], column=item['column'], name=name)

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

    def having_negate(ctx):
        if ctx.NOT():
            return having_negate(ctx.havingNegation()) + [having_instruction('not')]
        if ctx.havingDisjunction():
            return having_predicate(ctx.havingDisjunction())
        atom = ctx.havingAtom()
        lhs = expr(atom.relationalExpression())
        if atom.IS():
            assert atom.NULL_()
            return [having_instruction('is_null', lhs)] + ([having_instruction('not')] if atom.NOT() else [])
        value = int(atom.literal().signedInteger().getText())
        return [having_instruction({'=': 'eq', '<>': 'ne', '!=': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge'}[atom.comparison().getText()], lhs, value)]

    def having_predicate(ctx):
        return combine([combine([having_negate(n) for n in c.havingNegation()], 'and', having_instruction) for c in ctx.havingConjunction()], 'or', having_instruction)

    def order_item(item):
        direction = 'desc' if item.DESC() else 'asc'
        nulls = 'first' if item.FIRST() else 'last' if item.LAST() else ('last' if direction == 'desc' else 'first')
        return dict(expression=expr(item.relationalExpression()), direction=direction, nulls=nulls)

    sources = [source(ctx.relationalTarget())]
    join = None
    if j := ctx.relationalJoin():
        sources.append(source(j.relationalTarget()))
        join = dict(kind='left' if j.LEFT() else 'inner', left=column(j.columnReference(0)), right=column(j.columnReference(1)))
    return dict(sources=sources, outputs=[selection(s) for s in ctx.relationalSelection()], join=join,
                groups=[column(c) for c in ctx.columnReference()],
                predicate=predicate(ctx.whereClause().predicate()) if ctx.whereClause() else [],
                having=having_predicate(ctx.havingClause().havingDisjunction()) if ctx.havingClause() else [],
                order_by=[order_item(o) for o in ctx.orderByClause().relationalOrderItem()] if ctx.orderByClause() else [],
                limit=int(ctx.limitClause().INTEGER().getText()) if ctx.limitClause() else None)


def postgres(sql):
    from pglast.parser import parse_sql_json
    node = json.loads(parse_sql_json(sql))['stmts'][0]['stmt']['SelectStmt']

    def col(value):
        names = [f['String']['sval'] for f in value['ColumnRef']['fields']]
        return [None, names[0]] if len(names) == 1 else names

    def source(value):
        var = value['RangeVar']
        return dict(name=var['relname'], alias=var.get('alias', {}).get('aliasname', var['relname']))

    def expr(value):
        if 'ColumnRef' in value:
            return dict(kind='column', column=col(value))
        call = value['FuncCall']
        name = call['funcname'][0]['String']['sval']
        return dict(kind='count_all' if call.get('agg_star') else name,
                    column=None if call.get('agg_star') else col(call['args'][0]))

    def selection(value):
        target = value['ResTarget']
        item = expr(target['val'])
        default_name = item['column'][1] if item['kind'] == 'column' else 'sum' if item['kind'] == 'sum' else 'count'
        return dict(kind=item['kind'], column=item['column'], name=target.get('name', default_name))

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

    def having(value):
        if 'BoolExpr' in value:
            node_expr = value['BoolExpr']
            parts = [having(p) for p in node_expr['args']]
            return parts[0] + [having_instruction('not')] if node_expr['boolop'] == 'NOT_EXPR' else combine(parts, 'and' if node_expr['boolop'] == 'AND_EXPR' else 'or', having_instruction)
        if 'NullTest' in value:
            node_expr = value['NullTest']
            return [having_instruction('is_null', expr(node_expr['arg']))] + ([having_instruction('not')] if node_expr['nulltesttype'] == 'IS_NOT_NULL' else [])
        node_expr = value['A_Expr']
        op = node_expr['name'][0]['String']['sval']
        return [having_instruction({'=': 'eq', '<>': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge'}[op], expr(node_expr['lexpr']), number(node_expr['rexpr']))]

    def order_item(value):
        sortby = value['SortBy']
        direction = 'desc' if sortby.get('sortby_dir') == 'SORTBY_DESC' else 'asc'
        nulls_mode = sortby.get('sortby_nulls', 'SORTBY_NULLS_DEFAULT')
        nulls = 'first' if nulls_mode == 'SORTBY_NULLS_FIRST' else 'last' if nulls_mode == 'SORTBY_NULLS_LAST' else ('last' if direction == 'desc' else 'first')
        return dict(expression=expr(sortby['node']), direction=direction, nulls=nulls)

    target = node['fromClause'][0]
    join = None
    if 'JoinExpr' in target:
        join_expr = target['JoinExpr']
        sources = [source(join_expr['larg']), source(join_expr['rarg'])]
        condition = join_expr['quals']['A_Expr']
        assert condition['name'][0]['String']['sval'] == '='
        join = dict(kind='left' if join_expr['jointype'] == 'JOIN_LEFT' else 'inner', left=col(condition['lexpr']), right=col(condition['rexpr']))
    else:
        sources = [source(target)]
    return dict(sources=sources, outputs=[selection(s) for s in node['targetList']], join=join,
                groups=[col(c) for c in node.get('groupClause', [])],
                predicate=predicate(node['whereClause']) if 'whereClause' in node else [],
                having=having(node['havingClause']) if 'havingClause' in node else [],
                order_by=[order_item(o) for o in node.get('sortClause', [])],
                limit=number(node['limitCount']) if 'limitCount' in node else None)


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
