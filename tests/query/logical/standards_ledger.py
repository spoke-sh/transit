#!/usr/bin/env python3
"""Validate the neutral capability ledger and regenerate its exact Zig projection.

This checks consistency, not semantic conformance. Compiler and installed-runtime
checks own the advertised behavior; source-file presence is never execution proof.
"""
from runner.paths import ROOT
import argparse
import copy
import hashlib
import json
import re

LEDGER = ROOT / 'contracts/sql/standards-ledger.json'
ZIG_LEDGER = ROOT / 'packages/zig/transit-fuze/src/StandardsLedger.zig'
ZIG_DATA = ROOT / 'packages/zig/transit-fuze/src/StandardsLedgerData.zig'
ZIG_TRAITS = ROOT / 'packages/zig/transit-fuze/src/OperatorTraits.zig'
PUBLIC = ROOT / 'docs/handbook/reference/sql/grammar-surface.md'
START = '<!-- standards-ledger:start -->'
END = '<!-- standards-ledger:end -->'
STAGES = {'parse', 'lower', 'execute', 'recover', 'transport'}
STATES = {'implemented', 'staged', 'reference_only', 'rejected'}


def validate(ledger):
    assert ledger['version'] == 1
    assert f'"{ledger["definition"]}"' in ZIG_LEDGER.read_text()
    assert f'"{ledger["operator_traits"]["definition"]}"' in ZIG_TRAITS.read_text()
    assert ledger['scope']
    ids = set()
    for group in ('collations', 'physical_codecs', 'features'):
        for entry in ledger[group]:
            assert entry['id'] not in ids, entry['id']
            ids.add(entry['id'])
            assert set(entry['states']) == STAGES, entry['id']
            assert set(entry['states'].values()) <= STATES, entry['id']
            assert (ROOT / entry['owner']).is_file(), entry['owner']
    for entry in ledger['features']:
        assert set(entry['dependencies']) <= ids, entry['id']
        assert entry['corpus_sources'], entry['id']
        for path in entry['corpus_sources']:
            assert (ROOT / path).is_file(), path
        assert isinstance(entry['reference_verified'], bool), entry['id']
        assert entry['profile'] and entry['evidence_sources'], entry['id']
        for path in entry['evidence_sources']:
            assert (ROOT / path).is_file(), path
    features = {entry['id']: entry for entry in ledger['features']}
    def visit(feature, visiting, visited):
        assert feature not in visiting, f'Capability dependency cycle: {feature}'
        if feature in visited or feature not in features:
            return
        visiting.add(feature)
        for dependency in features[feature]['dependencies']:
            visit(dependency, visiting, visited)
        visiting.remove(feature)
        visited.add(feature)
    visited = set()
    for feature in features:
        visit(feature, set(), visited)
    cases = set()
    for case in ledger['compiler_cases']:
        assert set(case) == {'id', 'feature', 'entrypoint', 'sql', 'accept'}, case
        assert case['id'] not in cases, case['id']
        cases.add(case['id'])
        feature = features[case['feature']]
        assert case['entrypoint'] in {'table_ddl', 'relational_sql', 'inspection'}, case['id']
        assert isinstance(case['accept'], bool) and case['sql'], case['id']
        if case['accept']:
            assert feature['states']['parse'] == 'implemented', case['id']
        else:
            assert feature['states']['parse'] == 'rejected', case['id']
    assert ledger['fixture_provenance']['license'] == 'MIT'
    payload = {k: v for k, v in ledger.items() if k != 'sha256'}
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def string(value):
    # Zig permits UTF-8 literals; JSON's control escapes except \\u are shared.
    assert not any(ord(c) < 32 for c in value), value
    return json.dumps(value, ensure_ascii=False)


def tag(value):
    assert re.fullmatch('[a-z][a-z0-9_]*', value), value
    return '.' + value


def render(ledger):
    lines = ['// Generated from contracts/sql/standards-ledger.json. Do not edit.',
             '// Regenerate with tests/query/logical/standards_ledger.py --write.',
             'const l = @import("StandardsLedger.zig");', '']
    for group, kind in (('collations', 'CollationDescriptor'),
                        ('physical_codecs', 'PhysicalCodecDescriptor'),
                        ('features', 'FeatureDescriptor'),
                        ('compiler_cases', 'CompilerCase')):
        lines.append(f'pub const {group} = [_]l.{kind}{{')
        for entry in ledger[group]:
            lines.append('    .{')
            for key, value in entry.items():
                if value is None:
                    literal = 'null'
                elif isinstance(value, bool):
                    literal = str(value).lower()
                elif key == 'states':
                    literal = '.{ ' + ', '.join(f'.{stage} = {tag(value[stage])}' for stage in ('parse', 'lower', 'execute', 'recover', 'transport')) + ' }'
                elif key in ('runtime_tag', 'encoding', 'standard', 'entrypoint'):
                    literal = tag(value)
                elif key == 'pad_attribute':
                    literal = tag(value.lower())
                elif isinstance(value, list):
                    space = ' ' if len(value) > 1 else ''
                    literal = '&.{' + space + ', '.join(map(string, value)) + space + '}'
                else:
                    literal = string(value)
                lines.append(f'        .{key} = {literal},')
            lines.append('    },')
        lines.extend(['};', ''])
    return '\n'.join(lines)


def public_projection(ledger):
    def cell(value):
        return value.replace('|', '\\|').replace('\n', ' ')
    lines = [START, '## Capability ledger', '',
             'This generated summary describes the selected production entry points,',
             'not the availability of internal helpers. Stage states are independent;',
             'an implemented compiler is not execution, recovery or transport evidence.',
             'Feature IDs and edition/clause references are inventory labels. References',
             'marked unverified have not been audited for standards conformance.', '',
             'The [neutral ledger](../../../../contracts/sql/standards-ledger.json)',
             'records owners, evidence sources, dependencies and compiler cases.',
             'Its compiler corpus is Transit-authored under MIT; it contains no copied',
             'standards text. Runtime and installed caller checks remain separate.', '',
             '| Feature | Parse | Lower | Execute | Recover | Transport | Reference | Scope and limits |',
             '| --- | --- | --- | --- | --- | --- | --- | --- |']
    for feature in ledger['features']:
        values = [feature['id'], *(feature['states'][s] for s in ('parse', 'lower', 'execute', 'recover', 'transport')),
                  'verified' if feature['reference_verified'] else 'unverified', feature['deviations']]
        lines.append('| ' + ' | '.join(map(cell, values)) + ' |')
    lines.extend(['', END])
    return '\n'.join(lines)


def negative_controls(ledger):
    # A generated file matching its input cannot detect unsupported claims or
    # cyclic requirements. Exercise those validation failures independently.
    invalid = copy.deepcopy(ledger)
    invalid['features'][0]['dependencies'].append(invalid['features'][0]['id'])
    try:
        validate(invalid)
    except AssertionError:
        pass
    else:
        raise AssertionError('Self-dependent feature accepted')
    invalid = copy.deepcopy(ledger)
    invalid['compiler_cases'][0]['accept'] = False
    try:
        validate(invalid)
    except AssertionError:
        pass
    else:
        raise AssertionError('Compiler expectation contradicting capability accepted')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    ledger = json.loads(LEDGER.read_text())
    digest = validate(ledger)
    negative_controls(ledger)
    generated = render(ledger)
    public = PUBLIC.read_text()
    assert public.count(START) == public.count(END) == 1
    before, rest = public.split(START)
    _, after = rest.split(END)
    expected_public = before + public_projection(ledger) + after
    if args.write:
        ledger['sha256'] = digest
        LEDGER.write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + '\n')
        ZIG_DATA.write_text(generated)
        PUBLIC.write_text(expected_public)
    else:
        assert ledger['sha256'] == digest, 'Neutral ledger digest drift; regenerate deliberately with --write'
        assert ZIG_DATA.read_text() == generated, 'Zig projection drift; regenerate deliberately with --write'
        assert public == expected_public, 'Public capability projection drift; regenerate deliberately with --write'
    print(f'Capability ledger consistency: {len(ledger["features"])} features, '
          f'{len(ledger["collations"])} collations, {len(ledger["physical_codecs"])} codecs; '
          'behavior is checked by the owning compiler/runtime suites')


if __name__ == '__main__':
    main()
