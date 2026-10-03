#!/usr/bin/env python3
"""Check reviewed semantic mappings independently of source-inventory recording.

This gate covers declared boundaries in mappings.json. Runtime owner tests execute
through just test::unit; finding their source is an ownership check, not a test run.
Unlisted boundaries are not certified by this gate.
"""
import copy
from fnmatch import fnmatchcase
import json
from pathlib import Path
import re

from diagnostic_inventory import ROOT, inventory, production, tokens

MANIFEST = ROOT / 'contracts/diagnostics/mappings.json'
ENTRY = re.compile(r'\. cause = error \. (\w+) , \. code = ("(?:\\.|[^"\\])*") , \. category = \. (\w+)')
NAMED_ENTRY = re.compile(r'\. name = ("(?:\\.|[^"\\])*") , \. value = \. \{ \. code = ("(?:\\.|[^"\\])*") , \. category = \. (\w+)')


def registry_entries(text, kind='error'):
    registry = ' '.join(production(text))
    if kind == 'error':
        return ENTRY.findall(registry)
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
        causes = {cause for cause, _, _ in entries}
        codes = [json.loads(code) for _, code, _ in entries]
        assert entries and len(causes) == len(entries) == len(set(codes)), identity
        assert boundary['codes'] == {cause: {'code': json.loads(code), 'category': category}
                                     for cause, code, category in entries}, ('changed semantic mapping', identity)
        if kind == 'error':
            assert causes == set(surface['sources'][boundary['registry']]['errors']), 'unclassified registry error'
        tests_exist(boundary['tests'], files)
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
    changed = copy.deepcopy(manifest)
    changed['boundaries'].append(copy.deepcopy(boundary))
    changed['boundaries'][-1]['id'] = 'overlapping-boundary'
    rejected(changed_manifest=changed)
    changed = copy.deepcopy(surface)
    changed['sources']['packages/zig/transit-fuze/src/SqlNewOwner.zig'] = {'errors': {'NewExpectedUserFailure': 1}}
    rejected(changed_surface=changed)
    for named in manifest['boundaries']:
        if named.get('registry_kind') != 'named_class':
            continue
        changed = dict(files)
        entry = next(iter(named['codes'].values()))
        changed[named['registry']] = changed[named['registry']].replace(entry['code'], 'changed.semantic.code')
        rejected(changed_files=changed)
        changed = copy.deepcopy(surface)
        changed['sources'][named['owners'][0]]['errors']['NewExpectedMigrationFailure'] = 1
        rejected(changed_surface=changed)


def main():
    manifest = json.loads(MANIFEST.read_text())
    surface = inventory()
    paths = set(surface['sources'])
    for boundary in manifest['boundaries']:
        paths.update((boundary['registry'], boundary['projection']))
        for mapping in [boundary, *boundary['exceptions']]:
            paths.update(test['source'] for test in mapping['tests'])
            if 'projection' in mapping:
                paths.add(mapping['projection'])
    files = {path: (ROOT / path).read_text() for path in paths}
    result = validate(manifest, surface, files)
    self_test(manifest, surface, files)
    print('Diagnostic semantic mappings:', json.dumps(result, sort_keys=True),
          '(declared scope only; executable owner tests run in test::unit).')


if __name__ == '__main__':
    main()
