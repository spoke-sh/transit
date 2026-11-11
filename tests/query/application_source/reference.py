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

    def bounds(node):
        if not hasattr(node, 'getRuleIndex'):
            return
        rule = parser.ruleNames[node.getRuleIndex()]
        if rule in ('sourceName', 'referenceHead') and len(node.getText().encode()) > 63:
            raise Refusal(span(node)['start'], 'name bound')
        if rule == 'parameters':
            names = [p.sourceName().getText().lower() for p in node.parameter()]
            if len(names) > 64 or len(set(names)) != len(names):
                raise Refusal(span(node)['start'], 'parameter bound/duplicate')
        if rule in ('sourceCall', 'sourceAtom') and len(node.expression()) > 64:
            raise Refusal(span(node)['start'], 'argument bound')
        if rule == 'sourceStatement' and len(node.sourceCall()) > 64:
            raise Refusal(span(node)['start'], 'setup bound')
        if rule == 'matchArm':
            names = [n.getText().lower() for n in node.sourceName()]
            if len(names) > 64 or len(set(names)) != len(names):
                raise Refusal(span(node)['start'], 'binder bound/duplicate')
        if rule == 'sourceStatement' and len(node.matchArm()) > 64:
            raise Refusal(span(node)['start'], 'arm bound')
        for child in node.children or []:
            bounds(child)
    bounds(root)

    def string(token):
        return token.getText()[1:-1].replace("''", "'")

    def name(ctx):
        parts = ctx.getText().split('(')[0].lower().split('.')
        return {'qualifier': parts[0] if len(parts) >= 2 else None,
                'member': parts[1] if len(parts) >= 2 else parts[0],
                'constructor': parts[2] if len(parts) == 3 else None}

    def template(ctx, rows=False):
        result = []
        if ctx:
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
            role = {'identifierHole': 'identifier', 'typeHole': 'type', 'valueHole': 'value', 'checkHole': 'operand', 'scalarHole': 'operand', 'streamHole': 'stream', 'queueHole': 'queue'}.get(rule)
            if role:
                holes.append({'name': node.sourceName().getText().lower(), 'role': role, **span(node)})
            else:
                for child in node.children or []:
                    visit(child)
        if ctx:
            visit(ctx)
        kind = 'rows' if rows else result[0]['text'].lower()
        if kind == 'create' and result[2]['text'] in ('STREAM', 'QUEUE'):
            kind += '_' + result[2]['text'].lower()
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
        elif ctx.TYPE():
            kind = ctx.sourceType()
            value = {'type': kind.getText().lower()} if kind.sourceBaseType() else {'named_type': name(kind)}
        elif ctx.TRUE() or ctx.FALSE():
            value = {'boolean': bool(ctx.TRUE())}
        elif ctx.STRING():
            value = {'text': string(ctx.STRING())}
        elif ctx.referenceHead():
            value = {'construct': {'name': name(ctx), 'arguments': [expr(arg) for arg in ctx.expression()], 'result': None}} if ctx.LPAREN() else {'reference': name(ctx)}
        else:
            value = expr(ctx.expression(0))['value']
        if 'integer' in value and not -(2 ** 63) <= value['integer'] < 2 ** 63:
            raise Refusal(span(ctx)['start'], 'integer bound')
        return {'span': span(ctx), 'value': value}

    def call(ctx):
        return {'name': name(ctx.sourceQualifiedName()), 'arguments': [expr(arg) for arg in ctx.expression()], 'result': None}

    def body(ctx):
        result = []
        for stmt in ctx.sourceStatement():
            if stmt.USE():
                invoked = call(stmt.sourceCall(0))
                invoked['result'] = stmt.sourceName().getText().lower() if stmt.AS() else None
                value = {'use': invoked}
            elif stmt.EXPORT():
                exported = {'source': name(stmt.sourceQualifiedName()), 'operand': bool(stmt.DOLLAR()), 'alias': stmt.sourceName().getText().lower()}
                if stmt.TABLE():
                    value = {'table_export': exported}
                else:
                    value = {'log_export': {'kind': 'stream' if stmt.STREAM() else 'queue', **exported}}
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
                value = {'test_case': {'name': label, 'setup': [call(c) for c in stmt.sourceCall()], 'body': body(stmt.body(0))}}
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
                value = {'assertion': {'sql': template(assertion.tableTemplate()), 'expected': expected}}
            else:
                value = {'sql': template(stmt.tableTemplate())}
            result.append({'span': span(stmt), 'value': value})
        return result

    def parameters(ctx):
        result = []
        for param in ctx.parameter() if ctx else []:
            kind = param.parameterKind()
            if kind.MODULE():
                value = {'module': name(kind.sourceQualifiedName())}
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

    definitions = []
    for definition in root.definition():
        domain = None
        constructors = []
        if definition.DOMAIN():
            domain = {'base': definition.sourceBaseType().getText().lower(), 'identity': string(definition.STRING())}
            if not 1 <= len(domain['identity'].encode()) <= 128:
                raise Refusal(span(definition)['start'], 'domain identity bound')
        if definition.VARIANT():
            constructors = [{'name': ctor.sourceName().getText().lower(), 'fields': parameters(ctor.parameters())} for ctor in definition.variantConstructor()]
            names = [ctor['name'] for ctor in constructors]
            if len(constructors) > 64 or len(set(names)) != len(names):
                raise Refusal(span(definition)['start'], 'constructor bound/duplicate')
        definitions.append({'name': definition.sourceName().getText().lower(), 'public': bool(definition.PUBLIC()),
                            'kind': 'domain' if domain else 'variant' if constructors else 'module' if definition.MODULE() else 'interface' if definition.INTERFACE() else 'test_target' if definition.TEST() else 'target',
                            'parameters': parameters(definition.parameters()), 'body': body(definition.body()) if definition.body() else [],
                            'span': span(definition), 'domain': domain, 'constructors': constructors})
    imports = [{'alias': item.sourceName(0).getText().lower(), 'package': item.sourceName(1).getText().lower() if item.PACKAGE() else None,
                'path': string(item.STRING()), 'span': span(item)} for item in root.sourceImport()]
    dependencies = [{'name': item.sourceName().getText().lower(), 'repository': string(item.STRING(0)), 'revision': string(item.STRING(1)),
                     'subdirectory': string(item.STRING(2)) if item.SUBDIRECTORY() else '', 'span': span(item)} for item in root.dependency()]
    return {'definitions': definitions, 'imports': imports, 'dependencies': dependencies}
