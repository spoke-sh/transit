#!/usr/bin/env python3
"""Review gate for declarative failure owners, routes and checked grammar.

This inventories literal error references, qualified named/inline outcome tags,
declared error sets, error-return boundaries, propagation and imports after lexing
out comments, strings and inline test bodies. It is a conservative source inventory,
not whole-program reachability analysis. Inferred/open and external failures need
boundary mappings and executable evidence in addition to this drift gate.
"""
import argparse
from collections import Counter
import difflib
import json
from pathlib import Path
import re
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'contracts/diagnostics/inventory.json'
PACKAGES = (
    'transit-fuze', 'transit-query', 'transit-catalog', 'transit-station-app',
    'transit-serving', 'transit-serving-http', 'transit-flight', 'transit-board-api',
    'transit-station-bindings', 'transit-station-document', 'transit-station',
    'transit-station-http', 'transit-station-grpc', 'transit-station-flight',
    'transit-exchange', 'transit-client', 'transit-protocol',
    'transit-grpc', 'transit-tls', 'transit-http-server',
    'transit-tls-server', 'transit-sql-gateway', 'transit-postgres', 'transit-mysql',
)
APPS = ('transit-cli', 'transit-board', 'transit-flight-gateway', 'transit-station-host',
        'transit-station-http-worker', 'transit-station-grpc-worker', 'transit-sql-gateway')
GRAMMARS = ('contracts/sql/TransitExtensions.g4', 'contracts/application/Application.g4')
TOKEN = re.compile(r'''//[^\n]*|/\*.*?\*/|\\\\[^\n]*|@?"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[A-Za-z_][A-Za-z_0-9]*|[^\s]''', re.S)


def tokens(text):
    return [m.group() for m in TOKEN.finditer(text) if not m.group().startswith(('//', '/*', '\\\\'))]


def production(text):
    raw = tokens(text)
    result, i, depth = [], 0, 0
    while i < len(raw):
        if raw[i] == 'test':
            j = i + 1
            if j < len(raw) and raw[j].startswith('"'):
                j += 1
            if j < len(raw) and raw[j] == '{':
                level = 1
                j += 1
                while j < len(raw) and level:
                    level += (raw[j] == '{') - (raw[j] == '}')
                    j += 1
                if level:
                    raise ValueError('unterminated inline test')
                i = j
                continue
        result.append(raw[i])
        i += 1
    return result


def structured_surfaces(ts):
    """Lexical declaration inventory, including inline types and explicit errors.

    Qualified names use lexical type/function containers, not inferred types.
    Inferred/open errors remain explicit obligations; this does not resolve them.
    """
    matching, stack = {}, []
    pairs = {'}': '{', ')': '(', ']': '['}
    for i, token in enumerate(ts):
        if token in ('{', '(', '['):
            stack.append(i)
        elif token in pairs:
            if not stack or ts[stack[-1]] != pairs[token]:
                raise ValueError('unbalanced production tokens')
            start = stack.pop()
            matching[start] = i
    if stack:
        raise ValueError('unclosed production tokens')

    def name_before(i, fallback):
        # Both declaration and member names may be quoted Zig identifiers.
        j = i - 1
        while j >= 0 and ts[j] in ('?', '*', 'const', 'volatile', 'allowzero'):
            j -= 1
        if j >= 1 and ts[j] == ':':
            return ts[j - 1]
        if j >= 1 and ts[j] == '=':
            k = j - 1
            while k >= 0 and ts[k] not in ('const', 'var', ';', '{', '}'):
                k -= 1
            if k >= 0 and ts[k] in ('const', 'var'):
                return ts[k + 1]
        if j >= 0 and ts[j] == 'return':
            return '<return>'
        return fallback

    containers = []
    for i, token in enumerate(ts):
        if token not in ('struct', 'enum', 'union', 'error'):
            continue
        j = i + 1
        if j < len(ts) and ts[j] == '(':
            j = matching[j] + 1
        if j >= len(ts) or ts[j] != '{':
            continue
        containers.append({'start': i, 'open': j, 'end': matching[j], 'kind': token,
                           'name': name_before(i, '<' + token + '>')})
    type_opens = {c['open']: c for c in containers}
    functions = []
    for i, token in enumerate(ts):
        if token != 'fn' or i + 2 >= len(ts):
            continue
        named = ts[i + 1] != '('
        opening = i + (2 if named else 1)
        if ts[opening] != '(':
            continue
        parameters_end = matching[opening]
        j = parameters_end + 1
        while j < len(ts):
            if ts[j] in (';', ',', '='):
                break
            if j in type_opens:
                j = matching[j] + 1
            elif ts[j] == '{':
                break
            elif ts[j] in ('(', '['):
                j = matching[j] + 1
            elif ts[j] in (')', '}', ']'):
                break
            else:
                j += 1
        body = j < len(ts) and ts[j] == '{'
        name = ts[i + 1] if named else name_before(i, '<callback>')
        functions.append({'start': i, 'open': j if body else parameters_end,
                          'end': matching[j] if body else j, 'kind': 'fn', 'name': name + '()',
                          'return': ts[parameters_end + 1:j]})
    scopes = containers + functions
    names, duplicates = {}, Counter()
    for item in sorted(scopes, key=lambda c: c['start']):
        parents = [c for c in scopes if c['start'] < item['start'] < c['end'] and item['end'] <= c['end']]
        parent = max(parents, key=lambda c: c['start']) if parents else None
        prefix = names[parent['start']] + '.' if parent else ''
        name = prefix + item['name']
        duplicates[name] += 1
        if duplicates[name] > 1:
            name += '#' + str(duplicates[name])
        names[item['start']] = name

    def fields(item):
        result, j = [], item['open'] + 1
        while j < item['end']:
            start = j
            while j < item['end'] and ts[j] not in (',', ';'):
                j = matching[j] + 1 if ts[j] in ('{', '(', '[') else j + 1
            segment = ts[start:j]
            if segment and (len(segment) == 1 or segment[1] in ('=', ':')) and segment[0] not in ('pub', 'const', 'var', 'fn', 'comptime'):
                result.append(segment[0])
            j += 1
        return result

    outcomes, error_sets = {}, {}
    for item in containers:
        if item['kind'] == 'struct':
            continue
        tags = fields(item)
        target = error_sets if item['kind'] == 'error' else outcomes
        target[names[item['start']]] = tags
    returns = {}
    for item in functions:
        signature = item['return']
        if '!' in signature:
            index = signature.index('!')
            # Calling conventions/alignments precede the return type. Preserve
            # the expression verbatim rather than guessing its resolved errors.
            expression = ' '.join(signature[:index]) or '<inferred>'
            returns[names[item['start']]] = expression
        elif 'anyerror' in signature:
            returns[names[item['start']]] = 'anyerror'
    return dict(sorted(outcomes.items())), dict(sorted(error_sets.items())), dict(sorted(returns.items()))


def source(text):
    ts = production(text)
    errors = dict(sorted(Counter(ts[i + 2] for i in range(len(ts) - 2) if ts[i:i + 2] == ['error', '.']).items()))
    imports = sorted({json.loads(ts[i + 3]) for i in range(len(ts) - 3)
                      if ts[i:i + 3] == ['@', 'import', '('] and ts[i + 3].startswith('"')})
    outcomes, error_sets, error_returns = structured_surfaces(ts)
    return {'errors': errors, 'outcomes': outcomes, 'error_sets': error_sets,
            'error_returns': error_returns, 'open_error_set_uses': ts.count('anyerror'),
            'propagation': {'try': ts.count('try'), 'catch': ts.count('catch')},
            'imports': imports}



def grammar(text):
    ts = tokens(text)
    result, i = {}, 0
    while i + 1 < len(ts):
        if re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', ts[i]) and ts[i + 1] == ':':
            name, j = ts[i], i + 2
            while j < len(ts) and ts[j] != ';':
                j += 1
            if j == len(ts):
                raise ValueError('unterminated grammar production: ' + name)
            result[name] = ' '.join(ts[i + 2:j])
            i = j
        i += 1
    return result


def inventory(root=ROOT):
    directories = [root / 'packages/zig' / p / 'src' for p in PACKAGES]
    directories += [root / 'apps' / p for p in APPS]
    sources = {}
    for directory in directories:
        if not directory.is_dir():
            raise ValueError('missing diagnostic owner: ' + str(directory))
        for path in sorted(directory.rglob('*.zig')):
            if any(part.startswith('.') or part in ('zig-pkg', 'zig-out', 'node_modules')
                   for part in path.relative_to(directory).parts):
                continue
            if path.name.endswith(('_test.zig', '_fixture.zig')) or path.name.endswith('Tests.zig') or path.name.startswith('Test'):
                continue
            value = source(path.read_text())
            sources[str(path.relative_to(root))] = value
    return {'version': 1, 'sources': dict(sorted(sources.items())),
            'grammars': {path: grammar((root / path).read_text()) for path in GRAMMARS}}


def self_test():
    sample = '''// error.Comment
const quoted = "error.String";
const multi = \\\\error.Multiline
;
test "inline" { _ = error.Test; if (true) { _ = error.Nested; } }
pub fn run() !void { return error.Actual; }
const Phase = enum(u8) { pending = 1, rejected = 2, pub fn f() void {} };
const Action = union(enum) { submit: struct { id: u64, }, read, };
const dependency = @import("owner.zig");
'''
    value = source(sample)
    assert value['errors'] == {'Actual': 1}, value
    assert value['outcomes'] == {'Phase': ['pending', 'rejected'], 'Action': ['submit', 'read']}, value
    assert value['imports'] == ['owner.zig'], value
    assert grammar("root: A | ';' B EOF; A: 'a';") == {'root': "A | ';' B EOF", 'A': "'a'"}
    assert source(sample + '\nfn added() !void { return error.Actual; }')['errors'] == {'Actual': 2}
    assert source(sample + '\nfn added() !void { return error.NewFailure; }') != value
    assert source(sample.replace('rejected = 2,', 'rejected = 2, retired = 3,')) != value
    assert source(sample.replace('owner.zig', 'new_boundary.zig')) != value
    assert source(sample + '\n// error.NewFailure\n') == value
    assert grammar('root: A EOF;') != grammar('root: (A | B) EOF;')
    nested = """
const Left = struct { phase: enum(u8) { waiting, refused }, const Error = error { LeftFailure }; };
const Right = struct { phase: enum { ready, done }, const Error = error { RightFailure }; };
fn read() error { Denied, Busy }!void { return error.Denied; }
fn external() Foreign.Error!void { try foreign(); }
fn open() anyerror!void { return error.Unknown; }
fn inferred() !void { try external(); }
const Callback = *const fn (u64) anyerror!void;
"""
    value = source(nested)
    assert value['outcomes'] == {'Left.phase': ['waiting', 'refused'], 'Right.phase': ['ready', 'done']}, value
    assert value['error_sets'] == {'Left.Error': ['LeftFailure'], 'Right.Error': ['RightFailure'], 'read().<error>': ['Denied', 'Busy']}, value
    assert value['error_returns'] == {'Callback()': 'anyerror', 'external()': 'Foreign . Error', 'inferred()': '<inferred>', 'open()': 'anyerror', 'read()': 'error { Denied , Busy }'}, value
    assert source(nested.replace('waiting, refused', 'waiting, refused, cancelled')) != value
    assert source(nested.replace('RightFailure', 'AnotherFailure')) != value
    assert source(nested.replace('Foreign.Error', 'Foreign.Changed')) != value
    assert source(nested.replace('try external()', 'external() catch unreachable')) != value
    assert source(nested.replace('anyerror!void', 'error{Only}!void')) != value
    assert source('const X = struct { const Tag = enum { a }; }; const Y = struct { const Tag = enum { b }; };')['outcomes'] == {'X.Tag': ['a'], 'Y.Tag': ['b']}
    with tempfile.TemporaryDirectory(prefix='transit-diagnostic-inventory-') as directory:
        root = Path(directory)
        for package in PACKAGES:
            (root / 'packages/zig' / package / 'src').mkdir(parents=True)
        for app in APPS:
            (root / 'apps' / app).mkdir(parents=True)
        for path in GRAMMARS:
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('root: EOF;')
        owner = root / 'apps/transit-cli/Real.zig'
        owner.write_text('fn run() !void { return error.Owned; }')
        baseline = inventory(root)
        for name in ('.zig-cache', 'zig-pkg', 'zig-out', 'node_modules'):
            cache = owner.parent / name / 'external.zig'
            cache.parent.mkdir()
            cache.write_text('fn run() !void { return error.UnrelatedLocalCache; }')
        assert inventory(root) == baseline
        owner.with_name('New.zig').write_text('fn run() !void { return error.NewPublicFailure; }')
        assert inventory(root) != baseline



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true', help='record the reviewed source surface; does not certify mappings or tests')
    args = parser.parse_args()
    self_test()
    actual = inventory()
    text = json.dumps(actual, indent=2, ensure_ascii=False) + '\n'
    if args.record:
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST.write_text(text)
    elif not MANIFEST.is_file() or MANIFEST.read_text() != text:
        previous = MANIFEST.read_text() if MANIFEST.is_file() else ''
        sys.stderr.writelines(difflib.unified_diff(previous.splitlines(True), text.splitlines(True), fromfile='recorded diagnostic owners', tofile='current owners'))
        raise SystemExit('Diagnostic surface changed. Review mappings, provenance and negative evidence before recording the new inventory.')
    print(f'Diagnostic inventory: {len(actual["sources"])} production owners, '
          f'{sum(len(v["errors"]) for v in actual["sources"].values())} owner/error pairs, '
          f'{sum(len(v["outcomes"]) for v in actual["sources"].values())} qualified enum/union surfaces, '
          f'{sum(len(v["error_sets"]) for v in actual["sources"].values())} declared error sets, '
          f'{sum(len(v["error_returns"]) for v in actual["sources"].values())} error-return boundaries, '
          f'{sum(len(v) for v in actual["grammars"].values())} grammar productions. Mapping/proof completeness is a separate gate.')


if __name__ == '__main__':
    main()
