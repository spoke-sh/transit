#!/usr/bin/env python3
"""Validate the neutral capability ledger and regenerate its exact Zig projection.

This checks consistency, not semantic conformance. Compiler and installed-runtime
checks own the advertised behavior; source-file presence is never execution proof.
"""
from runner.paths import ROOT
import argparse
import hashlib
import json
import re

LEDGER = ROOT / 'contracts/sql/standards-ledger.json'
ZIG_LEDGER = ROOT / 'packages/zig/transit-fuze/src/StandardsLedger.zig'
ZIG_DATA = ROOT / 'packages/zig/transit-fuze/src/StandardsLedgerData.zig'
ZIG_TRAITS = ROOT / 'packages/zig/transit-fuze/src/OperatorTraits.zig'
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
                        ('features', 'FeatureDescriptor')):
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
                elif key in ('runtime_tag', 'encoding', 'standard'):
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    ledger = json.loads(LEDGER.read_text())
    digest = validate(ledger)
    generated = render(ledger)
    if args.write:
        ledger['sha256'] = digest
        LEDGER.write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + '\n')
        ZIG_DATA.write_text(generated)
    else:
        assert ledger['sha256'] == digest, 'Neutral ledger digest drift; regenerate deliberately with --write'
        assert ZIG_DATA.read_text() == generated, 'Zig projection drift; regenerate deliberately with --write'
    print(f'Capability ledger consistency: {len(ledger["features"])} features, '
          f'{len(ledger["collations"])} collations, {len(ledger["physical_codecs"])} codecs; '
          'behavior is checked by the owning compiler/runtime suites')


if __name__ == '__main__':
    main()
