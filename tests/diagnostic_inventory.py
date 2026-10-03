#!/usr/bin/env python3
"""Review gate for declarative failure owners, routes and checked grammar.

This inventories literal error references, named outcome tags and imports after
lexing out comments, strings and inline test bodies. It is a conservative source
inventory, not whole-program reachability analysis. Propagated external failures
need boundary mappings and executable evidence in addition to this drift gate.
"""
import argparse
from collections import Counter
import difflib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'contracts/diagnostics/inventory.json'
PACKAGES = (
    'transit-fuze', 'transit-query', 'transit-catalog', 'transit-station-app',
    'transit-serving', 'transit-serving-http', 'transit-flight', 'transit-board-api',
    'transit-station-bindings', 'transit-station-document', 'transit-station',
    'transit-station-http', 'transit-station-grpc', 'transit-station-flight',
    'transit-exchange', 'transit-client', 'transit-protocol',
)
APPS = ('transit-cli', 'transit-board', 'transit-flight-gateway', 'transit-station-host')
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


def source(text):
    ts = production(text)
    errors = dict(sorted(Counter(ts[i + 2] for i in range(len(ts) - 2) if ts[i:i + 2] == ['error', '.']).items()))
    imports = sorted({json.loads(ts[i + 3]) for i in range(len(ts) - 3)
                      if ts[i:i + 3] == ['@', 'import', '('] and ts[i + 3].startswith('"')})
    outcomes = {}
    for i in range(len(ts) - 4):
        if ts[i] != 'const' or ts[i + 2] != '=' or ts[i + 3] not in ('enum', 'union'):
            continue
        name, j = ts[i + 1], i + 4
        while j < len(ts) and ts[j] not in ('{', ';'):
            j += 1
        if j == len(ts) or ts[j] != '{':
            continue
        level, start, fields = 1, j + 1, []
        j += 1
        while j < len(ts) and level:
            token = ts[j]
            if token in ('{', '(', '['):
                level += 1
            elif token in ('}', ')', ']'):
                level -= 1
            if (token == ',' and level == 1) or level == 0:
                segment = ts[start:j]
                if segment and (len(segment) == 1 or segment[1] in ('=', ':')) and segment[0] not in ('pub', 'const', 'fn'):
                    fields.append(segment[0])
                start = j + 1
            j += 1
        if fields:
            if name in outcomes:
                raise ValueError('duplicate named enum/union: ' + name)
            outcomes[name] = fields
    return {'errors': errors, 'outcomes': outcomes, 'imports': imports}


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
            if any(part.startswith('.') for part in path.relative_to(directory).parts):
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
          f'{sum(len(v["outcomes"]) for v in actual["sources"].values())} named enum/union surfaces, '
          f'{sum(len(v) for v in actual["grammars"].values())} grammar productions. Mapping/proof completeness is a separate gate.')


if __name__ == '__main__':
    main()
