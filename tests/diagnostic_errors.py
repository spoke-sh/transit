#!/usr/bin/env python3
"""Check actual compiler-inferred boundary types and unknown-cause projections.

Finite sets are conservative type information, not a reachability proof. Open
sets stay open. Known-cause semantic mappings and real fault proofs are separate.
"""
import copy
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def validate(manifest, rows):
    assert manifest['version'] == 1
    mappings = {row['id']: row['codes'] for row in json.loads((ROOT / 'contracts/diagnostics/mappings.json').read_text())['boundaries']}
    seen, fallbacks = set(), set()
    for row in rows:
        if 'boundary' in row:
            name = row['boundary']
            assert name not in seen and name in manifest['boundaries'], name
            seen.add(name)
            boundary = manifest['boundaries'][name]
            assert boundary['reason'], name
            actual = None if row['causes'] is None else sorted(row['causes'])
            assert actual == boundary['causes'], ('inferred error set changed', name, actual)
            if actual is None:
                owner = boundary['fallback']
                assert owner == 'file' or owner + '.read' in manifest['fallbacks'], name
                assert not boundary['exceptions'], name
            else:
                mapped = set().union(*(set(mappings[owner]) for owner in boundary['mappings']))
                exceptions = boundary['exceptions']
                assert set(exceptions) <= set(actual) and all(exceptions.values()), name
                assert set(actual) <= mapped | set(exceptions), ('unmapped inferred cause', name, set(actual) - mapped - set(exceptions))
        else:
            name = row['owner'] + '.' + row['scenario']
            assert name not in fallbacks and name in manifest['fallbacks'], name
            fallbacks.add(name)
            actual = {key: row[key] for key in ('code', 'category', 'stage', 'outcome', 'evidence')}
            actions = [action for action in row['actions'] if action is not None]
            actual['actions'] = [action['kind'] for action in actions]
            assert actual == manifest['fallbacks'][name], ('unknown-cause semantics changed', name, actual)
            assert all(action['target'] == row['identity'] for action in actions), row
            if row['scenario'] != 'read':
                assert row['identity']['domain'] == 'transport' and row['identity']['sequence'] == '12', row
    assert seen == set(manifest['boundaries']), ('missing inferred boundary', seen)
    assert fallbacks == set(manifest['fallbacks']), ('missing unknown projection', fallbacks)


def self_test(manifest, rows):
    def reject(changed):
        try:
            validate(manifest, changed)
        except AssertionError:
            return
        raise AssertionError('boundary mutation passed')
    reject(rows[:-1])
    reject(rows + rows[:1])
    changed = copy.deepcopy(rows)
    next(row for row in changed if row.get('causes'))['causes'].append('NewPublicFailure')
    reject(changed)
    changed = copy.deepcopy(rows)
    next(row for row in changed if row.get('causes'))['causes'] = None
    reject(changed)
    changed = copy.deepcopy(rows)
    next(row for row in changed if row.get('scenario') == 'dispatched')['outcome'] = 'rejected'
    reject(changed)
    changed = copy.deepcopy(rows)
    next(row for row in changed if row.get('scenario') == 'dispatched')['actions'][0]['target']['id'] = '13'
    reject(changed)


def main():
    manifest = json.loads((ROOT / 'contracts/diagnostics/boundaries.json').read_text())
    completed = subprocess.run([str(Path(sys.argv[1]).resolve())], capture_output=True, text=True, check=True, timeout=60)
    assert not completed.stderr, completed.stderr
    rows = [json.loads(line) for line in completed.stdout.splitlines()]
    validate(manifest, rows)
    self_test(manifest, rows)
    print(f'Diagnostic boundary types: {len(manifest["boundaries"])} compiler-inferred sets; {len(manifest["fallbacks"])} unknown-cause projections; mutations rejected.')


if __name__ == '__main__':
    main()
