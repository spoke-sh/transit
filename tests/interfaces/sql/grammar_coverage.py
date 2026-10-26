"""Audit parser alternatives against actual ANTLR trees, independently of Zig.

This intentionally supports the checked grammars' parser EBNF, not arbitrary
ANTLR actions/predicates. Unsupported grammar notation fails the gate. Tokens
come from ANTLR, so this matcher cannot confer reference acceptance by itself.
"""
from dataclasses import dataclass
import re


@dataclass
class Node:
    kind: str
    key: str
    children: tuple = ()
    value: str = ''


def rules(source):
    source = re.sub(r'//[^\n]*|/\*.*?\*/', '', source, flags=re.S)
    result = {}
    for name, body in re.findall(r'\b([a-z]\w*)\s*:\s*([^;]+);', source):
        values = re.findall(r'\w+|[^\s]', body)
        index = 0
        serial = 0

        def node(kind, children=(), value=''):
            nonlocal serial
            serial += 1
            return Node(kind, f'{name}.{serial}', tuple(children), value)

        def choice():
            nonlocal index
            alternatives = [sequence()]
            while index < len(values) and values[index] == '|':
                index += 1
                alternatives.append(sequence())
            return alternatives[0] if len(alternatives) == 1 else node('choice', alternatives)

        def sequence():
            nonlocal index
            items = []
            while index < len(values) and values[index] not in ('|', ')'):
                token = values[index]
                index += 1
                if token == '(':
                    item = choice()
                    assert values[index] == ')', (name, body)
                    index += 1
                else:
                    assert re.fullmatch(r'\w+', token), ('unsupported parser notation', name, token)
                    item = node('symbol', value=token)
                if index < len(values) and values[index] in ('?', '*', '+'):
                    item = node(values[index], (item,))
                    index += 1
                items.append(item)
            assert items, ('empty parser alternative', name)
            return items[0] if len(items) == 1 else node('sequence', items)

        result[name] = choice()
        assert index == len(values), (name, values[index:])
    assert result
    return result


def obligations(grammar):
    required = set()

    def visit(node):
        if node.kind == 'choice':
            required.update(f'{node.key}:alt:{i}' for i in range(len(node.children)))
        elif node.kind in ('?', '*', '+'):
            required.update(f'{node.key}:count:{i}' for i in
                            ((0, 1) if node.kind == '?' else (1, 2) if node.kind == '+' else (0, 1, 2)))
        for child in node.children:
            visit(child)
    for name, node in grammar.items():
        required.add(name + ':rule')
        visit(node)
    return required


def match(node, symbols, start=0):
    """Return complete matching paths and only the obligations each path took."""
    if node.kind == 'symbol':
        return [(start + 1, set())] if start < len(symbols) and symbols[start] == node.value else []
    if node.kind == 'sequence':
        paths = [(start, set())]
        for child in node.children:
            paths = [(end, seen | more) for offset, seen in paths
                     for end, more in match(child, symbols, offset)]
        return paths
    if node.kind == 'choice':
        return [(end, seen | {f'{node.key}:alt:{i}'}) for i, child in enumerate(node.children)
                for end, seen in match(child, symbols, start)]
    assert node.kind in ('?', '*', '+')
    paths = [(start, set(), 0)]
    complete = []
    while paths:
        following = []
        for offset, seen, count in paths:
            if node.kind != '+' or count:
                complete.append((offset, seen | {f'{node.key}:count:{min(count, 2)}'}))
            if node.kind == '?' and count:
                continue
            for end, more in match(node.children[0], symbols, offset):
                assert end > offset, 'nullable repetition is outside this coverage model'
                following.append((end, seen | more, count + 1))
        paths = following
    return complete


def covered(grammar, tree, parser):
    result = set()

    def visit(context):
        name = parser.ruleNames[context.getRuleIndex()]
        symbols = []
        for child in context.getChildren():
            if hasattr(child, 'getRuleIndex'):
                symbols.append(parser.ruleNames[child.getRuleIndex()])
                visit(child)
            else:
                token = child.getSymbol()
                symbols.append('EOF' if token.type == -1 else parser.symbolicNames[token.type])
        paths = [seen for end, seen in match(grammar[name], symbols) if end == len(symbols)]
        assert len(paths) == 1, ('ambiguous coverage derivation', name, symbols, paths)
        result.add(name + ':rule')
        result.update(paths[0])
    visit(tree)
    return result


def self_test():
    grammar = rules('root: (A | B) C? (D E)* EOF;')
    required = obligations(grammar)
    seen = set()
    for symbols in [('A', 'EOF'), ('B', 'C', 'D', 'E', 'EOF'),
                    ('A', 'D', 'E', 'D', 'E', 'EOF')]:
        paths = [s for end, s in match(grammar['root'], symbols) if end == len(symbols)]
        assert len(paths) == 1
        seen.update(paths[0])
    assert seen | {'root:rule'} == required
    assert not [s for end, s in match(grammar['root'], ['A', 'D', 'EOF']) if end == 3]
    changed = rules('root: (A | B | F) C? (D E)* EOF;')
    assert obligations(changed) != required
    assert len(obligations(rules('root: A; child: B;'))) > 1
