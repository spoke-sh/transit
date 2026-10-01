"""Independent AST adapters: ANTLR parse tree and libpg_query's PostgreSQL tree.

No Zig parser or compiler code is used to derive either reference AST.
"""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / '.cache/verification/sql'


def generate():
    CACHE.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(['antlr4', '-Dlanguage=Python3', '-visitor', '-Werror',
                             '-o', str(CACHE), 'TransitExtensions.g4'],
                            cwd=ROOT / 'contracts/sql', capture_output=True, text=True)
    assert result.returncode == 0 and not result.stdout and not result.stderr, result.stderr
    sys.path.insert(0, str(CACHE))


def tree(sql, rule='statement'):
    from antlr4 import InputStream, CommonTokenStream
    from antlr4.error.ErrorListener import ErrorListener
    from antlr4.atn.PredictionMode import PredictionMode
    from TransitExtensionsLexer import TransitExtensionsLexer
    from TransitExtensionsParser import TransitExtensionsParser

    class Strict(ErrorListener):
        def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
            raise ValueError(f'{line}:{column}: {msg}')

        def reportAmbiguity(self, *args):
            raise AssertionError('ANTLR ambiguity in shared corpus')

    lexer = TransitExtensionsLexer(InputStream(sql))
    lexer.removeErrorListeners()
    lexer.addErrorListener(Strict())
    parser = TransitExtensionsParser(CommonTokenStream(lexer))
    parser.removeErrorListeners()
    parser.addErrorListener(Strict())
    parser._interp.predictionMode = PredictionMode.LL_EXACT_AMBIG_DETECTION
    return getattr(parser, rule)()


def identifier(ctx):
    text = ctx.getText()
    return text[1:-1].replace('""', '"') if text.startswith('"') else text.lower()


def column(ctx):
    names = [identifier(i) for i in ctx.identifier()]
    return [None, names[0]] if len(names) == 1 else names


def projection(ctx):
    return None if ctx.STAR() else [
        {'column': column(item.columnReference()),
         'alias': identifier(item.outputAlias().identifier()) if item.outputAlias() else None}
        for item in ctx.projectionItem()]


def literal(ctx):
    if ctx.signedInteger():
        return {'kind': 'int64', 'value': int(ctx.signedInteger().getText())}
    if ctx.TRUE() or ctx.FALSE():
        return {'kind': 'boolean', 'value': bool(ctx.TRUE())}
    if ctx.NULL_():
        return {'kind': 'null', 'value': None}
    value = ctx.STRING().getText()[1:-1].replace("''", "'")
    # AST keeps the bytea input string; compilation validates its hex encoding.
    return {'kind': 'uint64', 'value': int(value)} if ctx.UINT64() else ({'kind': 'float64', 'value': float(value)} if ctx.FLOAT64() else {'kind': 'binary' if ctx.BYTEA() else 'utf8', 'value': value})


def join_program(parts, op):
    result = list(parts[0])
    for part in parts[1:]:
        result.extend(part)
        result.append({'op': op})
    return result


def normalized_program(instructions):
    return instructions[0] if len(instructions) == 1 else {'op': 'program', 'instructions': instructions}


def antlr_ast(sql, *, template=False):
    ctx = tree(sql, 'parameterTemplate').templateSelect() if template else tree(sql).selectStatement()
    assert ctx
    selected = ctx.selection()
    aggregate = selected.aggregateSelection() if selected else ctx.aggregateSelection()
    if not aggregate:
        selection = {'kind': 'rows', 'columns': projection(selected.projection())}
    elif aggregate.COUNT() and aggregate.STAR():
        selection = {'kind': 'count'}
    else:
        selection = {'kind': 'count_values' if aggregate.COUNT() else 'sum', 'column': column(aggregate.columnReference())}
    where = ctx.templateWhereClause() if template else ctx.whereClause()
    def atom(pred):
        result = {'column': column(pred.columnReference()), 'op': 'is_' + pred.cellState().getText().lower() if pred.cellState() else None}
        if pred.comparison():
            result['op'] = {'=': 'eq', '<>': 'ne', '!=': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge'}[pred.comparison().getText()]
            result['literal'] = ({'kind': 'parameter', 'value': int(pred.PARAMETER().getText()[1:])} if template and pred.PARAMETER() else literal(pred.literal()))
        return result

    def negation(ctx):
        if ctx.NOT():
            return negation(ctx.negation()) + [{'op': 'not'}]
        if ctx.predicate():
            return disjunction(ctx.predicate().disjunction())
        return [atom(ctx.predicateAtom())]

    def conjunction(ctx):
        return join_program([negation(part) for part in ctx.negation()], 'and')

    def disjunction(ctx):
        return join_program([conjunction(part) for part in ctx.conjunction()], 'or')

    predicate = (atom(where.templatePredicate()) if template else normalized_program(disjunction(where.predicate().disjunction()))) if where else None
    limits = ctx.templateLimitClause() if template else ctx.limitClause()
    # Identify clauses by their position relative to the derived-table close.
    outer = inner = None
    for lim in limits:
        n = ({'parameter': int(lim.PARAMETER().getText()[1:])}
             if template and lim.PARAMETER() else int(lim.INTEGER().getText()))
        if ctx.RPAREN() and lim.start.tokenIndex < ctx.RPAREN().symbol.tokenIndex:
            inner = n
        else:
            outer = n
    names = ctx.identifier()
    return {'source': identifier(names[0]), 'source_alias': identifier(ctx.sourceAlias().identifier()) if ctx.sourceAlias() else None,
            'output_alias': identifier(aggregate.outputAlias().identifier()) if aggregate and aggregate.outputAlias() else None,
            'selection': selection, 'predicate': predicate,
            'limit': outer, 'input': None if selected else {
                'projection': projection(ctx.projection()), 'limit': inner, 'alias': identifier(names[1])}}


def pg_ast(sql):
    from pglast.parser import parse_sql_json
    parsed = json.loads(parse_sql_json(sql))['stmts']
    assert len(parsed) == 1
    node = parsed[0]['stmt']['SelectStmt']

    def col(node):
        fields = [x['String']['sval'] for x in node['ColumnRef']['fields']]
        return [None, fields[0]] if len(fields) == 1 else fields

    def project(node):
        targets = [x['ResTarget'] for x in node['targetList']]
        if len(targets) == 1 and targets[0]['val'].get('ColumnRef', {}).get('fields') == [{'A_Star': {}}]:
            return None
        return [{'column': col(x['val']), 'alias': x.get('name')} for x in targets]

    def const(node):
        if 'ParamRef' in node:
            return {'kind': 'parameter', 'value': node['ParamRef'].get('number', 0)}
        if 'TypeCast' in node:
            cast = node['TypeCast']
            kind = cast['typeName']['names'][-1]['String']['sval']
            value = cast['arg']['A_Const']['sval']['sval']
            assert kind in ('bytea', 'uint64', 'float64')
            return {'kind': 'uint64', 'value': int(value)} if kind == 'uint64' else ({'kind': 'float64', 'value': float(value)} if kind == 'float64' else {'kind': 'binary', 'value': value})
        if 'A_Expr' in node:
            expr = node['A_Expr']
            assert 'lexpr' not in expr and expr['name'][0]['String']['sval'] == '+'
            return const(expr['rexpr'])
        value = node['A_Const']
        if value.get('isnull'):
            return {'kind': 'null', 'value': None}
        for key, kind, default in [('ival', 'int64', 0), ('fval', 'int64', 0), ('boolval', 'boolean', False), ('sval', 'utf8', '')]:
            if key in value:
                raw = value[key].get(key, default)
                return {'kind': kind, 'value': int(raw) if kind == 'int64' else raw}
        raise AssertionError(value)

    def limit(node):
        if 'limitCount' not in node:
            return None
        value = const(node['limitCount'])
        return {'parameter': value['value']} if value['kind'] == 'parameter' else value['value']

    function = node['targetList'][0]['ResTarget']['val'].get('FuncCall')
    if function:
        name = function['funcname'][0]['String']['sval']
        selection = {'kind': name}
        if name == 'sum' or (name == 'count' and not function.get('agg_star')):
            selection['kind'] = 'sum' if name == 'sum' else 'count_values'
            selection['column'] = col(function['args'][0])
        else:
            assert name == 'count' and function['agg_star']
    else:
        selection = {'kind': 'rows', 'columns': project(node)}
    source_node = node['fromClause'][0]
    inner = None
    if 'RangeSubselect' in source_node:
        derived = source_node['RangeSubselect']
        source_query = derived['subquery']['SelectStmt']
        inner = {'projection': project(source_query), 'limit': limit(source_query), 'alias': derived['alias']['aliasname']}
        relation = source_query['fromClause'][0]['RangeVar']
    else:
        source_query = node
        relation = source_node['RangeVar']
    def predicate(where):
        if 'BoolExpr' in where:
            boolean = where['BoolExpr']
            args = [predicate(arg) for arg in boolean['args']]
            if boolean['boolop'] == 'NOT_EXPR':
                assert len(args) == 1
                return args[0] + [{'op': 'not'}]
            return join_program(args, {'AND_EXPR': 'and', 'OR_EXPR': 'or'}[boolean['boolop']])
        if 'NullTest' in where:
            assert where['NullTest'].get('nulltesttype', 'IS_NULL') == 'IS_NULL'
            return [{'column': col(where['NullTest']['arg']), 'op': 'is_null'}]
        expr = where['A_Expr']
        op = expr['name'][0]['String']['sval']
        return [{'column': col(expr['lexpr']), 'op': {'=': 'eq', '<>': 'ne', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge'}[op], 'literal': const(expr['rexpr'])}]

    pred = normalized_program(predicate(source_query['whereClause'])) if 'whereClause' in source_query else None
    return {'source': relation['relname'], 'source_alias': relation.get('alias', {}).get('aliasname'),
            'output_alias': node['targetList'][0]['ResTarget'].get('name') if function else None,
            'selection': selection, 'predicate': pred, 'limit': limit(node), 'input': inner}
