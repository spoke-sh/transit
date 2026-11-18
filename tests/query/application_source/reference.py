"""Independent source AST from the ANTLR tree; never reads production output."""
import re


class Refusal(ValueError):
    def __init__(self, offset, message):
        super().__init__(message)
        self.offset = offset


def parse(source):
    from antlr4 import InputStream, CommonTokenStream
    from antlr4.error.ErrorListener import ErrorListener
    from antlr4.atn.PredictionMode import PredictionMode
    from TransitSourceLexer import TransitSourceLexer
    from TransitSourceParser import TransitSourceParser

    offsets = [0]
    for char in source:
        offsets.append(offsets[-1] + len(char.encode('utf8')))
    if offsets[-1] > 1024 * 1024 or '\0' in source or '\1' in source:
        raise Refusal(0, 'encoding/bound')

    class Strict(ErrorListener):
        def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
            pos = offendingSymbol.start if offendingSymbol else recognizer._tokenStartCharIndex
            raise Refusal(offsets[max(0, min(pos, len(source)))], msg)

        def reportAmbiguity(self, recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs):
            raise AssertionError(f'ANTLR ambiguity at tokens {startIndex}:{stopIndex}')

    lexer = TransitSourceLexer(InputStream(source))
    lexer.removeErrorListeners()
    lexer.addErrorListener(Strict())
    tokens = CommonTokenStream(lexer)
    parser = TransitSourceParser(tokens)
    parser.removeErrorListeners()
    parser.addErrorListener(Strict())
    parser._interp.predictionMode = PredictionMode.LL_EXACT_AMBIG_DETECTION
    root = parser.sourceFile()

    def span(ctx):
        return {'start': offsets[ctx.start.start], 'end': offsets[ctx.stop.stop + 1]}

    def bounds(node, atomic=False, helper_mode=None):
        if not hasattr(node, 'getRuleIndex'):
            return
        rule = parser.ruleNames[node.getRuleIndex()]
        if rule == 'definition' and (node.FUNCTION() or node.GUARD() or node.PROCEDURE()):
            bounds(node.sourceName(), False, None)
            bounds(node.parameters(), False, None)
            if node.sourceType():
                bounds(node.sourceType(), False, None)
            if node.PROCEDURE():
                if not node.ATOMIC():
                    following = tokens.tokens[node.BEGIN().symbol.tokenIndex + 1]
                    raise Refusal(offsets[following.start], 'procedure requires BEGIN ATOMIC')
                if bool(node.RETURNS()) != bool(node.procedureBody().RETURN()):
                    raise Refusal(span(node.procedureBody())['end'], 'procedure return coverage')
                bounds(node.procedureBody(), True, 'procedure')
            elif node.GUARD():
                if node.ATOMIC():
                    raise Refusal(offsets[node.ATOMIC().symbol.start], 'atomic guard')
                bounds(node.programBlock(), False, 'guard')
            else:
                if node.ATOMIC():
                    raise Refusal(offsets[node.ATOMIC().symbol.start], 'atomic function')
                bounds(node.functionBody(), False, 'function')
            return
        if helper_mode and rule in ('identifierHole', 'typeHole', 'valueHole', 'checkHole', 'scalarHole', 'tableHole', 'streamHole', 'queueHole'):
            raise Refusal(span(node)['start'], 'hole inside helper')
        if rule == 'functionBody' and node.programInstruction():
            for child in node.children or []:
                bounds(child, atomic, 'function')
            raise Refusal(span(node.programInstruction(0))['start'], 'impure source function')
        if rule == 'programInstruction':
            if node.LET() and node.programExpression() and node.programExpression().start.text.upper() == 'SELECT':
                following = tokens.tokens[node.programExpression().start.tokenIndex + 1]
                raise Refusal(offsets[following.start], 'LET SELECT requires a complete read')
            if helper_mode == 'guard' and (node.BEGIN() or node.INSERT() or node.PRODUCE() or node.ENQUEUE() or node.CALL()):
                raise Refusal(span(node)['start'], 'mutation inside guard')
            if helper_mode != 'function':
                if node.BEGIN():
                    if atomic:
                        raise Refusal(span(node)['start'], 'nested atomic program')
                    atomic = True
                elif (node.INSERT() or node.PRODUCE() or node.ENQUEUE() or node.CALL()) and not atomic:
                    raise Refusal(span(node)['start'], 'mutation outside atomic program')
        if rule in ('sourceName', 'sourceNameWithoutModule', 'referenceHead', 'plainReferenceHead') and len(node.getText().encode()) > 63:
            raise Refusal(span(node)['start'], 'name bound')
        if rule in ('parameters', 'rowParameters'):
            names = [p.sourceName().getText().lower() for p in node.parameter()]
            if len(names) > 64 or len(set(names)) != len(names):
                raise Refusal(span(node)['start'], 'parameter bound/duplicate')
        if rule == 'callArguments':
            if node.namedArgument():
                names = [na.sourceName().getText().lower() for na in node.namedArgument()]
                if len(names) > 64 or len(set(names)) != len(names):
                    raise Refusal(span(node)['start'], 'named argument bound/duplicate')
            elif len(node.expression()) > 64:
                raise Refusal(span(node)['start'], 'argument bound')
        if rule == 'sourceAtom' and node.ROW() and node.namedArgument():
            names = [na.sourceName().getText().lower() for na in node.namedArgument()]
            if len(names) > 64 or len(set(names)) != len(names):
                raise Refusal(span(node)['start'], 'row field bound/duplicate')
        if rule == 'exportTargetBody':
            if len(node.suiteRef()) > 64:
                raise Refusal(span(node)['start'], 'suite bound')
            opt_names = [opt.sourceName().getText().lower() for opt in node.targetOption()]
            if len(opt_names) > 64 or len(set(opt_names)) != len(opt_names):
                raise Refusal(span(node)['start'], 'option bound/duplicate')
        if rule == 'sourceStatement' and len(node.caseModule()) > 64:
            raise Refusal(span(node)['start'], 'setup bound')
        if rule == 'sourceStatement' and node.REFERENCE():
            col_nodes = node.sourceName()[:-1] if node.AS() else node.sourceName()
            cols = [c.getText().lower() for c in col_nodes]
            if len(cols) > 64 or len(set(cols)) != len(cols):
                raise Refusal(span(node)['start'], 'reference column bound/duplicate')
        if rule == 'matchArm':
            names = [n.getText().lower() for n in node.sourceName()]
            if len(names) > 64 or len(set(names)) != len(names):
                raise Refusal(span(node)['start'], 'binder bound/duplicate')
        if rule == 'sourceStatement' and len(node.matchArm()) > 64:
            raise Refusal(span(node)['start'], 'arm bound')
        for child in node.children or []:
            bounds(child, atomic, helper_mode)
    bounds(root)

    def string(token):
        return token.getText()[1:-1].replace("''", "'")

    def name(ctx):
        parts = ctx.getText().split('(')[0].lower().split('.')
        return {'qualifier': parts[0] if len(parts) >= 2 else None,
                'member': parts[1] if len(parts) >= 2 else parts[0],
                'constructor': parts[2] if len(parts) == 3 else None}

    def template(ctx, rows=False, helper=None):
        result = []
        if ctx and ctx.stop and ctx.stop.tokenIndex >= ctx.start.tokenIndex:
            # ANTLR's SQL lexer combines numbers/operators. Project their constituent
            # source scanner tokens independently; never split quoted bytes.
            for token in tokens.tokens[ctx.start.tokenIndex:ctx.stop.tokenIndex + 1]:
                raw = token.text
                if raw[0] in "'\"":
                    parts = [(raw, 0)]
                else:
                    parts = [(m.group(), m.start()) for m in re.finditer(r'[A-Za-z_][A-Za-z_0-9]*|[0-9]+|.', raw)]
                for text, start in parts:
                    kind = ('string' if text[0] == "'" else 'quoted' if text[0] == '"' else
                            'word' if re.fullmatch('[A-Za-z_][A-Za-z_0-9]*', text) else
                            'number' if text.isascii() and text.isdigit() else 'symbol')
                    result.append({'kind': kind, 'text': text.upper() if kind == 'word' and token.type != TransitSourceLexer.NUMBER else text,
                                   'start': offsets[token.start + start], 'end': offsets[token.start + start + len(text)]})
        holes = []
        def visit(node):
            if not hasattr(node, 'getRuleIndex'):
                return
            rule = parser.ruleNames[node.getRuleIndex()]
            role = {'identifierHole': 'identifier', 'typeHole': 'type', 'valueHole': 'value', 'checkHole': 'operand', 'scalarHole': 'operand', 'tableHole': 'table', 'streamHole': 'stream', 'queueHole': 'queue'}.get(rule)
            if role:
                holes.append({'name': node.sourceName().getText().lower(), 'role': role, **span(node)})
            else:
                for child in node.children or []:
                    visit(child)
        if ctx:
            visit(ctx)
        if helper:
            kind = helper
        else:
            kind = 'rows' if rows else result[0]['text'].lower()
            if kind == 'create' and result[2]['text'] in ('STREAM', 'QUEUE'):
                kind += '_' + result[2]['text'].lower()
            elif kind == 'create' and result[2]['text'] == 'DATAFLOW':
                kind = 'program'
            elif kind in ('authorize', 'activate', 'suspend', 'resume', 'retire'):
                kind = 'control'
        return {'kind': kind, 'tokens': result, 'holes': holes}

    binary = {'+': 'add', '-': 'subtract', '*': 'multiply', '=': 'equal', '<>': 'not_equal',
              '<': 'less', '<=': 'less_equal', '>': 'greater', '>=': 'greater_equal', 'AND': 'and_', 'OR': 'or_'}

    def expr(ctx):
        rule = parser.ruleNames[ctx.getRuleIndex()]
        if rule == 'expression':
            return expr(ctx.sourceOr())
        if rule in ('sourceOr', 'sourceAnd', 'sourceComparison', 'sourceAdd', 'sourceMultiply'):
            value = expr(ctx.children[0])
            for index in range(1, len(ctx.children), 2):
                op = ctx.children[index].getText().upper()
                right = expr(ctx.children[index + 1])
                value = {'span': {'start': value['span']['start'], 'end': right['span']['end']},
                         'value': {'binary': {'op': binary[op], 'left': value, 'right': right}}}
            return value
        if rule == 'sourceUnary':
            if ctx.sourceAtom():
                return expr(ctx.sourceAtom())
            child = ctx.sourceUnary()
            if ctx.MINUS() and child.sourceAtom() and child.sourceAtom().INTEGER():
                value = {'integer': -int(child.getText())}
            else:
                value = {'unary': {'negative': bool(ctx.MINUS()), 'operand': expr(child)}}
        elif ctx.INTEGER():
            value = {'integer': int(ctx.INTEGER().getText())}
        elif ctx.NAME() and ctx.STRING():
            value = {'identifier': string(ctx.STRING())}
        elif ctx.SCHEMA_BINDING() and ctx.STRING():
            value = {'schema_binding': string(ctx.STRING())}
        elif ctx.ROW() and ctx.namedArgument():
            value = {'row': [{'name': na.sourceName().getText().lower(), 'value': expr(na.expression())} for na in ctx.namedArgument()]}
        elif ctx.TYPE():
            kind = ctx.sourceType()
            value = {'type': kind.getText().lower()} if kind.sourceBaseType() else {'named_type': name(kind)}
        elif ctx.TRUE() or ctx.FALSE():
            value = {'boolean': bool(ctx.TRUE())}
        elif ctx.STRING():
            value = {'text': string(ctx.STRING())}
        elif ctx.plainReferenceHead() or ctx.SCHEMA_BINDING() or ctx.ROW():
            value = {'construct': call_parts(ctx, ctx.callArguments())} if ctx.LPAREN() else {'reference': name(ctx)}
        else:
            value = expr(ctx.expression())['value']
        if 'integer' in value and not -(2 ** 63) <= value['integer'] < 2 ** 63:
            raise Refusal(span(ctx)['start'], 'integer bound')
        return {'span': span(ctx), 'value': value}

    def call_parts(name_ctx, args_ctx, result=None, let_binding=False):
        if args_ctx is None:
            arguments, names = [], []
        elif args_ctx.namedArgument():
            names = [na.sourceName().getText().lower() for na in args_ctx.namedArgument()]
            arguments = [expr(na.expression()) for na in args_ctx.namedArgument()]
        else:
            names = []
            arguments = [expr(arg) for arg in args_ctx.expression()]
        return {'name': name(name_ctx), 'arguments': arguments, 'names': names, 'result': result, 'let_binding': let_binding}

    def statement_node(stmt):
        if stmt.LET():
            sc = stmt.sourceCall()
            value = {'use': call_parts(sc.sourceQualifiedName(), sc.callArguments(),
                                       result=stmt.sourceName(0).getText().lower(), let_binding=True)}
        elif stmt.USE():
            if stmt.sourceCall():
                sc = stmt.sourceCall()
                value = {'use': call_parts(sc.sourceQualifiedName(), sc.callArguments(),
                                           result=stmt.sourceName(0).getText().lower() if stmt.AS() else None)}
            elif stmt.LPAREN():
                value = {'use': call_parts(stmt.sourceQualifiedName(), stmt.callArguments(),
                                           result=stmt.sourceName(0).getText().lower() if stmt.AS() else None)}
            else:
                value = {'use_module': name(stmt.sourceQualifiedName())}
        elif stmt.DECLARE():
            value = {'declare_from': string(stmt.STRING())}
        elif stmt.BIND():
            value = {'bind_schema': {'name': stmt.sourceName(0).getText().lower(), 'target': expr(stmt.expression())}}
        elif stmt.EXPORT():
            if stmt.REFERENCE():
                src = name(stmt.helperName())
                col_nodes = stmt.sourceName()[:-1] if stmt.AS() else stmt.sourceName()
                alias = stmt.sourceName()[-1].getText().lower() if stmt.AS() else src['member']
                value = {'reference_export': {'source': src, 'columns': [c.getText().lower() for c in col_nodes], 'alias': alias}}
            elif stmt.TABLE() or stmt.STREAM() or stmt.QUEUE():
                src = name(stmt.helperName())
                alias = stmt.sourceName(0).getText().lower() if stmt.sourceName() else src['member']
                exported = {'source': src, 'operand': bool(stmt.DOLLAR()), 'alias': alias}
                if stmt.TABLE():
                    value = {'table_export': exported}
                else:
                    value = {'log_export': {'kind': 'stream' if stmt.STREAM() else 'queue', **exported}}
            else:
                src = name(stmt.helperName())
                alias = stmt.sourceName(0).getText().lower() if stmt.AS() else src['member']
                sym_kind = ('function' if stmt.FUNCTION() else 'guard' if stmt.GUARD() else
                            'procedure' if stmt.PROCEDURE() else 'view' if stmt.VIEW() else
                            'dataflow' if stmt.DATAFLOW() else 'profile')
                value = {'symbol_export': {'kind': sym_kind, 'source': src, 'alias': alias}}
        elif stmt.MATCH():
            arms = [{'constructor': name(arm.sourceQualifiedName()), 'names': [n.getText().lower() for n in arm.sourceName()],
                     'body': body(arm.body()), 'span': span(arm)} for arm in stmt.matchArm()]
            value = {'match': {'value': expr(stmt.expression()), 'arms': arms}}
        elif stmt.IF():
            value = {'conditional': {'condition': expr(stmt.expression()), 'yes': body(stmt.body(0)),
                                     'no': body(stmt.body(1)) if stmt.ELSE() else []}}
        elif stmt.TEST():
            label = string(stmt.STRING())
            if not 1 <= len(label.encode()) <= 128 or any(ord(c) < 32 or ord(c) == 127 for c in label):
                raise Refusal(span(stmt)['start'], 'case label')
            setup = [{'call': call_parts(cm.sourceQualifiedName(), cm.callArguments())} if cm.LPAREN()
                     else {'reference': name(cm.sourceQualifiedName())} for cm in stmt.caseModule()]
            value = {'test_case': {'name': label, 'setup': setup, 'body': body(stmt.body(0))}}
        elif stmt.WORKFLOW():
            counts = [int(c.getText()) for c in stmt.INTEGER()]
            if any(c >= 2 ** 64 for c in counts):
                raise Refusal(span(stmt)['start'], 'count bound')
            value = {'workflow': {'name': expr(stmt.expression()), **dict(zip(('completed', 'refused', 'observations'), counts))}}
        elif stmt.ASSERT():
            assertion = stmt.assertion()
            if assertion.ROWS():
                expected = {'rows': template(assertion.expectedRows(), True)}
            elif assertion.COMMAND():
                counts = [int(c.getText()) for c in assertion.INTEGER()]
                if any(c >= 2 ** 64 for c in counts):
                    raise Refusal(span(assertion)['start'], 'count bound')
                expected = {'command': dict(zip(('matched', 'changed'), counts))}
            else:
                reason = string(assertion.STRING())
                if reason not in ('duplicate_key', 'check_violation'):
                    raise Refusal(span(assertion)['start'], 'refusal kind')
                expected = {'refusal': reason}
            value = {'assertion': {'sql': template(assertion.simpleTemplate()), 'expected': expected}}
        else:
            value = {'sql': template(stmt.tableTemplate())}
        return {'span': span(stmt), 'value': value}

    def body(ctx):
        return [statement_node(stmt) for stmt in ctx.sourceStatement()]

    def parameters(ctx):
        result = []
        for param in ctx.parameter() if ctx else []:
            kind = param.parameterKind()
            if kind.SCHEMA_BINDING():
                value = {'schema_binding': None}
            elif kind.MODULE():
                value = {'module_of' if kind.OF() else 'module': name(kind.sourceQualifiedName())}
            elif kind.rowParameters():
                value = {'row': parameters(kind.rowParameters())}
            elif kind.TABLE() or kind.STREAM() or kind.QUEUE():
                columns = []
                for col in kind.signatureColumn():
                    raw_type = col.sourceType()
                    ty = {'scalar': raw_type.getText().lower()} if raw_type.sourceBaseType() else {'named': name(raw_type)}
                    nullable = not col.PRIMARY() and (not col.nullability() or not col.nullability().NOT())
                    if col.PRIMARY() and col.nullability() and not col.nullability().NOT():
                        raise Refusal(span(col)['start'], 'nullable primary key')
                    columns.append({'name': col.sourceName(0).getText().lower(), 'type': ty, 'nullable': nullable,
                                    'primary': bool(col.PRIMARY()), 'collation': col.sourceName(1).getText().lower() if col.COLLATE() else 'none'})
                names = [col['name'] for col in columns]
                if len(columns) > 128 or len(set(names)) != len(names):
                    raise Refusal(span(kind)['start'], 'column bound/duplicate')
                value = {'table' if kind.TABLE() else 'stream' if kind.STREAM() else 'queue': columns}
            elif kind.sourceParameterName():
                value = {'named': name(kind.sourceParameterName())}
            else:
                value = {{'BIGINT': 'integer', 'IDENTIFIER': 'identifier'}.get(kind.getText().upper(), kind.getText().lower()): None}
            result.append({'name': param.sourceName().getText().lower(), 'kind': value})
        return result

    def migration_clause(mc):
        if mc is None:
            return None
        strings = [string(token) for token in mc.STRING()]
        basis = None if mc.EMPTY() else strings.pop(0)
        return dict(zip(('basis', 'database', 'schema', 'version', 'name'), [basis, *strings]))

    definitions = []
    for definition in root.definition():
        domain = None
        constructors = []
        return_type = None
        program = None
        mig = None
        target_of = None
        target_ref = None
        output_path = None
        suite_path = None
        suites = []
        target_options = []
        if definition.EXPORT():
            def_name = definition.sourceName().getText().lower()
            if definition.MODULE():
                def_kind = 'module'
                params = parameters(definition.parameters())
                def_body = body(definition.body())
            elif definition.SUITE():
                def_kind = 'test_suite'
                params = []
                def_body = []
                suite_path = string(definition.STRING())
            else:
                etb = definition.exportTargetBody()
                params = []
                def_body = []
                if etb.EQ() and not etb.AS():
                    def_kind = 'target_alias'
                    target_ref = {'qualifier': etb.sourceName(0).getText().lower(),
                                  'member': etb.sourceName(1).getText().lower(), 'constructor': None}
                elif etb.SQL():
                    def_kind = 'target'
                    target_of = etb.sourceName(0).getText().lower()
                    output_path = string(etb.STRING()) if etb.INTO() else None
                elif etb.MIGRATIONS():
                    def_kind = 'migration_target'
                    target_of = etb.sourceName(0).getText().lower()
                    mig = migration_clause(etb.migrationClause())
                    output_path = string(etb.STRING()) if etb.INTO() else None
                else:
                    def_kind = 'test_target'
                    target_of = etb.sourceName(0).getText().lower()
                    suites = [{'path': string(sr.STRING())} if sr.STRING() else {'symbol': name(sr.helperName())} for sr in etb.suiteRef()]
                    target_options = [{'name': to.sourceName().getText().lower(), 'value': expr(to.expression())} for to in etb.targetOption()]
        else:
            def_name = definition.sourceName().getText().lower()
            if definition.DOMAIN():
                domain = {'base': definition.sourceBaseType().getText().lower(), 'identity': string(definition.STRING())}
                if not 1 <= len(domain['identity'].encode()) <= 128:
                    raise Refusal(span(definition)['start'], 'domain identity bound')
            if definition.VARIANT():
                constructors = [{'name': ctor.sourceName().getText().lower(), 'fields': parameters(ctor.parameters())} for ctor in definition.variantConstructor()]
                names = [ctor['name'] for ctor in constructors]
                if len(constructors) > 64 or len(set(names)) != len(names):
                    raise Refusal(span(definition)['start'], 'constructor bound/duplicate')
            if definition.sourceType():
                raw_ret = definition.sourceType()
                return_type = {'scalar': raw_ret.getText().lower()} if raw_ret.sourceBaseType() else {'named': name(raw_ret)}
            program = (template(definition.functionBody(), helper='function_body') if definition.FUNCTION() else
                       template(definition.programBlock(), helper='guard_body') if definition.GUARD() else
                       template(definition.procedureBody(), helper='procedure_body') if definition.PROCEDURE() else None)
            mig = migration_clause(definition.migrationClause()) if definition.MIGRATION() else None
            def_kind = ('domain' if domain else 'variant' if constructors else
                        'function' if definition.FUNCTION() else 'guard' if definition.GUARD() else
                        'procedure' if definition.PROCEDURE() else 'migration_target' if definition.MIGRATION() else
                        'module' if definition.MODULE() else 'interface' if definition.INTERFACE() else
                        'test_target' if definition.TEST() else 'target')
            params = parameters(definition.parameters())
            def_body = body(definition.body()) if definition.body() else []
        definitions.append({'name': def_name, 'public': bool(definition.PUBLIC() or definition.EXPORT()),
                            'kind': def_kind, 'parameters': params, 'body': def_body,
                            'span': span(definition), 'domain': domain, 'constructors': constructors,
                            'return_type': return_type, 'program': program, 'migration': mig,
                            'target_of': target_of, 'target_ref': target_ref, 'output_path': output_path,
                            'suite_path': suite_path, 'suites': suites, 'target_options': target_options})

    def import_node(item):
        if item.sourceNameWithoutModule():
            alias = item.sourceNameWithoutModule().getText().lower()
            pkg = item.sourceName(0).getText().lower() if item.PACKAGE() else None
        elif len(item.sourceName()) == 2 or (len(item.sourceName()) == 1 and not item.PACKAGE()):
            alias = item.sourceName(0).getText().lower()
            pkg = item.sourceName(1).getText().lower() if item.PACKAGE() else None
        else:
            alias = 'module'
            pkg = item.sourceName(0).getText().lower() if item.PACKAGE() else None
        return {'alias': alias, 'package': pkg, 'path': string(item.STRING()), 'span': span(item)}

    imports = [import_node(item) for item in root.sourceImport()]
    dependencies = [{'name': item.sourceName().getText().lower(), 'repository': string(item.STRING(0)), 'revision': string(item.STRING(1)),
                     'subdirectory': string(item.STRING(2)) if item.SUBDIRECTORY() else '', 'span': span(item)} for item in root.dependency()]
    defaults = [{'name': item.sourceName().getText().lower(), 'span': span(item)} for item in root.defaultTarget()]
    statements = [statement_node(stmt) for stmt in root.sourceStatement()]
    return {'definitions': definitions, 'imports': imports, 'dependencies': dependencies,
            'defaults': defaults, 'statements': statements}
