#!/usr/bin/env python3
"""Execute retained-outcome projections against independently reviewed mappings.

This checks the declared enum surfaces, codes, outcome/stage, evidence, identity,
fact availability/origin and exact action targets. It does not recreate a durable
transition, verify all witness values, or replace the owning recovery proofs.
There is deliberately no snapshot-recording mode.
"""
import copy
import json
from pathlib import Path
import subprocess
import sys

from diagnostic_inventory import ROOT, inventory
from diagnostic_mappings import registry_entries

MANIFEST = ROOT / 'contracts/diagnostics/outcomes.json'


def normalize(row):
    result = {key: value for key, value in row.items()
              if key not in ('family', 'variant', 'scenario', 'facts', 'actions')}
    if result.get('transport_status') is None:
        result.pop('transport_status', None)
    result['facts'] = [[fact['field'], fact['origin'], fact['availability']]
                       for fact in row['facts'] if fact is not None]
    result['actions'] = []
    for action in row['actions']:
        if action is None:
            continue
        assert action['target'] == row['identity'], ('wrong action target', row)
        result['actions'].append(action['kind'])
    if row['outcome'] in ('input_rejected', 'closed_unknown'):
        assert set(result['actions']) <= {'inspect_status', 'inspect_scope', 'contact_operator'}, row
    if row['outcome'] == 'unknown' and 'resume_exact' in result['actions']:
        assert row['evidence'] == 'saved_intent' and row['identity']['domain'] == 'transport' and row['identity']['sequence'] is not None, row
    return result


def validate(manifest, surface, rows):
    assert manifest['version'] == 1
    expected = {}
    for family, definition in manifest['families'].items():
        for field in ('projection', 'profile', 'context', 'disclosure', 'durable_evidence', 'recovery'):
            assert definition[field], (family, field)
        if 'mapping_boundary' in definition:
            mappings = json.loads((ROOT / 'contracts/diagnostics/mappings.json').read_text())
            boundary, = [item for item in mappings['boundaries'] if item['id'] == definition['mapping_boundary']]
            variants = set(boundary['codes'])
        elif 'registry_kind' in definition:
            variants = {entry[0] for entry in registry_entries((ROOT / definition['source']).read_text(), definition['registry_kind'])}
        else:
            variants = set(surface['sources'][definition['source']]['outcomes'][definition['type']])
        assert set(definition['cases']) == variants, ('unmapped outcome', family)
        for variant, case in definition['cases'].items():
            assert case['code'], (family, variant)
            for scenario, context in definition['scenarios'].items():
                base = {key: value for key, value in case.items() if key != 'scenarios'}
                expected[family, variant, scenario] = definition['defaults'] | base | context | case.get('scenarios', {}).get(scenario, {})
    seen = set()
    for row in rows:
        key = row['family'], row['variant'], row['scenario']
        assert key in expected and key not in seen, ('unexpected/duplicate projection', key)
        seen.add(key)
        actual = normalize(row)
        assert actual == expected[key], ('semantic projection changed', key, expected[key], actual)
    assert seen == set(expected), ('missing executable projections', set(expected) - seen)
    return len(seen)


def self_test(manifest, surface, rows):
    def rejected(changed_manifest=manifest, changed_surface=surface, changed_rows=rows):
        try:
            validate(changed_manifest, changed_surface, changed_rows)
        except AssertionError:
            return
        raise AssertionError('outcome coverage mutation passed')
    rejected(changed_rows=rows[:-1])
    rejected(changed_rows=rows + rows[:1])
    for field, value in (('code', 'invented.code'), ('category', 'constraint'),
                         ('stage', 'output'), ('outcome', 'applied'), ('evidence', 'local')):
        changed = copy.deepcopy(rows)
        changed[0][field] = value
        rejected(changed_rows=changed)
    changed = copy.deepcopy(rows)
    changed[0]['actions'][0]['target']['id'] = '999'
    rejected(changed_rows=changed)
    changed = copy.deepcopy(rows)
    changed[0]['facts'][0]['availability'] = 'withheld'
    rejected(changed_rows=changed)
    changed = copy.deepcopy(rows)
    row = next(row for row in changed if row['outcome'] == 'closed_unknown')
    row['actions'][0]['kind'] = 'resume_exact'
    rejected(changed_rows=changed)
    changed = copy.deepcopy(surface)
    first = next(iter(manifest['families'].values()))
    changed['sources'][first['source']]['outcomes'][first['type']].append('new_terminal_reason')
    rejected(changed_surface=changed)
    changed = copy.deepcopy(manifest)
    first = next(iter(changed['families'].values()))
    first['cases'].pop(next(iter(first['cases'])))
    rejected(changed_manifest=changed)


def main():
    manifest = json.loads(MANIFEST.read_text())
    surface = inventory()
    completed = subprocess.run([str(Path(sys.argv[1]).resolve())], check=True,
                               capture_output=True, text=True, timeout=60)
    assert not completed.stderr, completed.stderr
    rows = [json.loads(line) for line in completed.stdout.splitlines()]
    count = validate(manifest, surface, rows)
    self_test(manifest, surface, rows)
    print(f'Diagnostic outcomes: {count} executed projections across '
          f'{len(manifest["families"])} complete declared outcome surfaces; semantic drift mutations rejected.')


if __name__ == '__main__':
    main()
