#!/usr/bin/env python3
"""Execute reviewed grammar cases, public diagnostics and independent EBNF coverage."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile

from grammar_coverage import covered, obligations, rules, self_test

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'contracts/diagnostics/grammar.json'


def reference(case, parsers):
    from antlr4 import InputStream, CommonTokenStream
    from antlr4.error.ErrorListener import ErrorListener
    from antlr4.atn.PredictionMode import PredictionMode

    class Strict(ErrorListener):
        def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
            raise ValueError(f'{line}:{column}: {msg}')

        def reportAmbiguity(self, *args):
            raise AssertionError('ambiguous reference input')

    lexer_type, parser_type = parsers[case['grammar']]
    lexer = lexer_type(InputStream(case['sql']))
    lexer.removeErrorListeners()
    lexer.addErrorListener(Strict())
    parser = parser_type(CommonTokenStream(lexer))
    parser.removeErrorListeners()
    parser.addErrorListener(Strict())
    parser._interp.predictionMode = PredictionMode.LL_EXACT_AMBIG_DETECTION
    return getattr(parser, case['root'])(), parser_type


def validate(case, result):
    expected = case['expected']
    assert result['id'] == case['id'] and result['accepted'] == expected['accepted'], (case['id'], result)
    if expected['accepted']:
        assert result['diagnostic'] is None
        return
    diagnostic = result['diagnostic']
    assert diagnostic['code'] == expected['code'], (case['id'], diagnostic['code'], expected['code'])
    assert diagnostic['category'] == expected['category'], (case['id'], diagnostic['category'])
    assert diagnostic['outcome'] == 'not_submitted' and diagnostic['evidence'] == 'local_before_dispatch'
    assert diagnostic['identity'] is None
    for fragment in expected.get('message_contains', []):
        assert fragment in diagnostic['message'], (case['id'], fragment)
    if 'kind' in expected:
        assert result['kind'] == expected['kind'], (case['id'], result['kind'])
    for field in ('stage', 'cause'):
        if field in expected:
            assert diagnostic[field] == expected[field], (case['id'], field, diagnostic[field])
    assert diagnostic['actions'][0] is not None
    for action in filter(None, diagnostic['actions']):
        assert action['kind'] in ('correct_input', 'inspect_scope', 'recompile', 'contact_operator')
        assert action['target'] is None
    for field, value in expected.get('facts', {}).items():
        assert any(fact and fact['field'] == field and fact['value'] == value
                   for fact in diagnostic['facts']), (case['id'], field, diagnostic['facts'])
    if expected.get('location'):
        assert diagnostic['location'] is not None
        offset = int(diagnostic['location']['offset'])
        assert offset == len(case['sql'][:case['sql'].index(expected['location'])].encode())


def main():
    self_test()
    manifest = json.loads(MANIFEST.read_text())
    assert manifest['version'] == 1 and manifest['scope']
    cases = manifest['cases']
    assert len({case['id'] for case in cases}) == len(cases)
    for profile, owner in manifest['profiles'].items():
        assert (ROOT / owner['source']).is_file() and owner['contract'] and owner['behavior']
        assert any(case['profile'] == profile for case in cases), profile
    for case in cases:
        assert case['profile'] in manifest['profiles']
    grammars = {}
    for name, path, stem in [('sql', 'contracts/sql', 'TransitExtensions'),
                             ('application', 'contracts/application', 'Application')]:
        cache = ROOT / '.cache/verification/diagnostic-grammar' / name
        cache.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(['antlr4', '-Dlanguage=Python3', '-Werror', '-o', str(cache), stem + '.g4'],
                                cwd=ROOT / path, text=True, capture_output=True)
        assert result.returncode == 0 and not result.stdout and not result.stderr, result.stderr
        sys.path.insert(0, str(cache))
        grammars[name] = rules((ROOT / path / (stem + '.g4')).read_text())
    from TransitExtensionsLexer import TransitExtensionsLexer
    from TransitExtensionsParser import TransitExtensionsParser
    from ApplicationLexer import ApplicationLexer
    from ApplicationParser import ApplicationParser
    parsers = {'sql': (TransitExtensionsLexer, TransitExtensionsParser),
               'application': (ApplicationLexer, ApplicationParser)}
    coverage = {name: set() for name in grammars}
    for case in cases:
        try:
            tree, parser = reference(case, parsers)
        except ValueError:
            assert not case['reference'], (case['id'], 'reference rejected reviewed valid input')
        else:
            assert case['reference'], (case['id'], 'reference accepted reviewed malformed input')
            coverage[case['grammar']].update(covered(grammars[case['grammar']], tree, parser))
    for name, grammar in grammars.items():
        missing = obligations(grammar) - coverage[name]
        assert not missing, ('uncovered parser alternatives/boundaries', name, sorted(missing))
    with tempfile.TemporaryDirectory(prefix='transit-grammar-diagnostics-') as temp:
        path = Path(temp) / 'cases.json'
        path.write_text(json.dumps(cases))
        run = subprocess.run([str(Path(sys.argv[1]).resolve()), str(path)], capture_output=True, text=True, timeout=60)
    assert run.returncode == 0 and not run.stderr, run.stderr
    results = [json.loads(line) for line in run.stdout.splitlines()]
    assert len(results) == len(cases)
    for case, result in zip(cases, results):
        validate(case, result)
    for case, result in zip(cases, results):
        if not case['expected']['accepted']:
            for field, value in [('code', 'invented.code'), ('outcome', 'applied'), ('evidence', 'domain_status')]:
                changed = copy.deepcopy(result)
                changed['diagnostic'][field] = value
                try:
                    validate(case, changed)
                except AssertionError:
                    continue
                raise AssertionError(('semantic mutation passed', field))
            break
    print(f'Diagnostic grammar: {len(cases)} public compiler cases; '
          f'{sum(len(value) for value in coverage.values())} parser rule/alternative/boundary obligations; '
          'reference acceptance, semantic diagnostics and mutation checks passed. No authority execution claimed.')


if __name__ == '__main__':
    main()
