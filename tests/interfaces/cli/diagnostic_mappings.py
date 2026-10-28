#!/usr/bin/env python3
"""Check reviewed semantic mappings independently of source-inventory recording.

This gate covers declared boundaries in mappings.json. Runtime owner tests execute
through just check::native; finding their source is an ownership check, not a test run.
Unlisted boundaries are not certified by this gate.
"""
import copy
from fnmatch import fnmatchcase
import json
from pathlib import Path
import re

from interfaces.cli.diagnostic_inventory import ROOT, inventory, production, source, tokens

MANIFEST = ROOT / 'contracts/diagnostics/mappings.json'
ENTRY = re.compile(r'\. cause = error \. (\w+) , \. code = ("(?:\\.|[^"\\])*") , \. category = \. (\w+)')
NAMED_ENTRY = re.compile(r'\. name = ("(?:\\.|[^"\\])*") , \. value = \. \{ \. code = ("(?:\\.|[^"\\])*") , \. category = \. (\w+)')


def function_tokens(text, name):
    values = production(text)
    starts = [i for i in range(len(values) - 2) if values[i:i + 3] == ['fn', name, '(']]
    assert len(starts) == 1, ('ambiguous/missing classification function', name)
    start = values.index('{', starts[0])
    depth = 1
    end = start + 1
    while depth:
        depth += (values[end] == '{') - (values[end] == '}')
        end += 1
    return values[start + 1:end - 1]


def registry_entries(text, kind='error'):
    registry = ' '.join(production(text))
    if kind == 'error':
        return ENTRY.findall(registry)
    if kind == 'query_failure':
        body = function_tokens(text, 'fromError')
        groups = re.findall(r'((?:error \. \w+ , )*error \. \w+) = > \. (\w+)', ' '.join(body))
        entries = [(cause, code) for group, code in groups for cause in re.findall(r'error \. (\w+)', group)]
        assert len(entries) == len({cause for cause, _ in entries}), 'duplicate query classification'
        assert {cause for cause, _ in entries} == {body[i + 2] for i in range(len(body) - 2) if body[i:i + 2] == ['error', '.']}
        # Categories are reviewed independently and exercised by the outcome
        # driver. This delegate checks the actual error-to-recorded-code path.
        cases = json.loads((ROOT / 'contracts/diagnostics/outcomes.json').read_text())['families']['query.failure']['cases']
        return [(cause, json.dumps('query.' + code), cases[code]['category']) for cause, code in entries]
    if kind == 'transport_predicate':
        body = function_tokens(text, 'unavailable')
        causes = [body[i + 2] for i in range(len(body) - 2) if body[i:i + 2] == ['error', '.']]
        assert len(causes) == len(set(causes)) and causes
        return [(cause, json.dumps('query.transport_unavailable'), 'unavailable') for cause in causes]
    assert kind == 'named_class', kind
    return [(json.loads(cause), code, category) for cause, code, category in NAMED_ENTRY.findall(registry)]


def tests_exist(tests, files):
    assert tests, 'mapping requires executable test ownership'
    for case in tests:
        name = ['test', json.dumps(case['name']), '{']
        values = tokens(files[case['source']])
        assert any(values[i:i + 3] == name for i in range(len(values) - 2)), case


def validate(manifest, surface, files):
    assert manifest['version'] == 1
    ids, covered, result = set(), set(), {}
    for boundary in manifest['boundaries']:
        identity = boundary['id']
        assert identity not in ids, identity
        ids.add(identity)
        for field in ('profile', 'stage', 'outcome', 'durable_evidence', 'context', 'disclosure', 'recovery', 'propagation'):
            assert boundary[field], (identity, field)
        kind = boundary.get('registry_kind', 'error')
        entries = registry_entries(files[boundary['registry']], kind)
        own_causes = {cause for cause, _, _ in entries}
        assert entries and len(own_causes) == len(entries), identity
        overrides = set()
        combined = {cause: (cause, code, category) for cause, code, category in entries}
        for delegate in boundary.get('delegates', []):
            delegated = registry_entries(files[delegate['source']], delegate['kind'])
            assert delegated
            for cause, code, category in delegated:
                if cause in combined:
                    overrides.add(cause)
                else:
                    combined[cause] = cause, code, category
        assert overrides == set(boundary.get('overrides', [])), ('unreviewed classifier overlap', identity, overrides)
        entries = list(combined.values())
        causes = set(combined)
        codes = [json.loads(code) for _, code, _ in entries]
        assert boundary.get('shared_codes', False) or len(codes) == len(set(codes)), identity
        assert boundary['codes'] == {cause: {'code': json.loads(code), 'category': category}
                                     for cause, code, category in entries}, ('changed semantic mapping', identity)
        if kind == 'error':
            assert own_causes == set(surface['sources'][boundary['registry']]['errors']), 'unclassified registry error'
        tests_exist(boundary['tests'], files)
        for pattern in boundary['owners']:
            assert any(fnmatchcase(path, pattern) and path not in boundary['exclude']
                       for path in surface['sources']), ('missing diagnostic owner', identity, pattern)
        owners = [path for path in surface['sources'] if any(fnmatchcase(path, pattern) for pattern in boundary['owners']) and path not in boundary['exclude']]
        assert owners, identity
        exceptions = {}
        for exception in boundary['exceptions']:
            pair = exception['source'], exception['cause']
            assert pair not in exceptions and pair[0] in owners, pair
            assert pair[1] in surface['sources'][pair[0]]['errors'], ('stale exception', pair)
            assert pair[1] not in causes, ('redundant exception', pair)
            assert exception['reason'], pair
            assert exception['disposition'] in ('control_flow', 'mapped_boundary', 'internal_invariant'), pair
            tests_exist(exception['tests'], files)
            if exception['disposition'] == 'mapped_boundary':
                projection = production(files[exception['projection']])
                assert json.dumps(exception['code']) in projection, pair
                assert any(projection[i:i + 3] == ['error', '.', pair[1]] for i in range(len(projection) - 2)), pair
            exceptions[pair] = exception
        for owner in owners:
            for cause in surface['sources'][owner]['errors']:
                pair = owner, cause
                assert pair not in covered, ('ambiguous mapping ownership', pair)
                covered.add(pair)
                assert cause in causes or pair in exceptions, ('unmapped public failure', pair)
        result[identity] = {'codes': len(entries), 'owner_error_pairs': sum(len(surface['sources'][p]['errors']) for p in owners), 'exceptions': len(exceptions)}
    return result


def self_test(manifest, surface, files):
    def rejected(changed_manifest=manifest, changed_surface=surface, changed_files=files):
        try:
            validate(changed_manifest, changed_surface, changed_files)
        except AssertionError:
            return
        raise AssertionError('semantic coverage mutation passed')
    boundary = manifest['boundaries'][0]
    changed = copy.deepcopy(surface)
    owner = boundary['exceptions'][0]['source']
    changed['sources'][owner]['errors']['NewExpectedUserFailure'] = 1
    rejected(changed_surface=changed)
    changed = copy.deepcopy(manifest)
    changed['boundaries'][0]['exceptions'].pop()
    rejected(changed_manifest=changed)
    changed = dict(files)
    changed[boundary['registry']] = changed[boundary['registry']].replace('error.TypeMismatch', 'error.ReplacedCause')
    rejected(changed_files=changed)
    changed = dict(files)
    changed[boundary['registry']] = changed[boundary['registry']].replace('sql.type_mismatch', 'sql.changed_meaning')
    rejected(changed_files=changed)
    changed = copy.deepcopy(manifest)
    changed['boundaries'][0]['tests'][0]['name'] = 'missing executable case'
    rejected(changed_manifest=changed)
    for pattern in ('packages/zig/missing-owner/src/Owner.zig',
                    'packages/zig/missing-owner/src/*.zig'):
        changed = copy.deepcopy(manifest)
        changed['boundaries'][0]['owners'].append(pattern)
        rejected(changed_manifest=changed)
    changed = copy.deepcopy(manifest)
    changed['boundaries'].append(copy.deepcopy(boundary))
    changed['boundaries'][-1]['id'] = 'overlapping-boundary'
    rejected(changed_manifest=changed)
    changed = copy.deepcopy(surface)
    changed['sources']['packages/zig/transit-fuze/src/SqlNewOwner.zig'] = {'errors': {'NewExpectedUserFailure': 1}}
    rejected(changed_surface=changed)
    for named in manifest['boundaries']:
        changed = dict(files)
        # The combined map may start with a delegated entry. Mutate a code
        # owned by this registry so ordering the manifest cannot make this
        # negative check silently test an unchanged file.
        entry = registry_entries(files[named['registry']], named.get('registry_kind', 'error'))[0]
        changed[named['registry']] = changed[named['registry']].replace(json.loads(entry[1]), 'changed.semantic.code')
        assert changed[named['registry']] != files[named['registry']], named['id']
        rejected(changed_files=changed)
        changed = copy.deepcopy(surface)
        owner = next(path for path in surface['sources'] if path not in named['exclude'] and any(fnmatchcase(path, pattern) for pattern in named['owners']))
        changed['sources'][owner]['errors']['NewExpectedBoundaryFailure'] = 1
        rejected(changed_surface=changed)


def main():
    manifest = json.loads(MANIFEST.read_text())
    surface = inventory()
    # Private callers still prove library error mappings. Check their explicitly
    # named sources without counting test code as installed production owners.
    for boundary in manifest['boundaries']:
        for path in [boundary['registry'], *boundary['owners']]:
            if path.startswith('tests/'):
                surface['sources'][path] = source((ROOT / path).read_text())
    paths = set(surface['sources'])
    for boundary in manifest['boundaries']:
        paths.update((boundary['registry'], boundary['projection']))
        paths.update(delegate['source'] for delegate in boundary.get('delegates', []))
        for mapping in [boundary, *boundary['exceptions']]:
            paths.update(test['source'] for test in mapping['tests'])
            if 'projection' in mapping:
                paths.add(mapping['projection'])
    files = {path: (ROOT / path).read_text() for path in paths}
    result = validate(manifest, surface, files)
    self_test(manifest, surface, files)
    print('Diagnostic semantic mappings:', json.dumps(result, sort_keys=True),
          '(declared scope only; executable owner tests run in check::native).')


if __name__ == '__main__':
    main()
