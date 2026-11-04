"""Require complete, verified journeys before reporting or applying budgets."""
import argparse
from collections import defaultdict
import json
import math
from pathlib import Path

from performance.mutations.mutation_latency import distribution

CONSOLE = ('console_warm_empty', 'console_insert', 'console_after_insert', 'console_warm_one',
           'console_update', 'console_after_update', 'console_noop', 'console_delete',
           'console_after_delete', 'console_zero_match')
DATAFLOW = ('source_insert', 'dataflow_after_insert', 'source_update', 'dataflow_after_update',
            'source_delete', 'dataflow_after_delete')


def positive(value):
    if type(value) is not int or value < 0:
        raise ValueError('invalid measurement')
    return value


def inventory(manifest):
    count = positive(manifest['repeat'])
    if not 1 <= count <= 100 or manifest['scenario'] not in ('console', 'dataflow', 'webhook', 'all'):
        raise ValueError('invalid scenario manifest')
    exact = dict(startup=1, retained_restart=1, console_after_restart=1)
    variable = {}
    if manifest['scenario'] in ('console', 'all'):
        exact.update(console_cold=1, **dict.fromkeys(CONSOLE, count))
    if manifest['scenario'] in ('dataflow', 'all'):
        exact.update(dataflow_initial=1, dataflow_idle=1, **dict.fromkeys(DATAFLOW, count))
        variable['console_during_dataflow'] = 1
    if manifest['scenario'] in ('webhook', 'all'):
        exact.update(webhook_initial=1, webhook_denied=1, webhook_accept=2, webhook_duplicate=2,
                     webhook_derived=2, effect_prepare=2, effect_observed=1, effect_unknown=1,
                     console_during_http=2, recorded_outcomes=2, effect_replay_after_restart=2, outcomes_after_restart=1)
    derived = (1 + count * 3 if manifest['scenario'] in ('dataflow', 'all') else 0)
    derived += 3 if manifest['scenario'] in ('webhook', 'all') else 0
    if derived:
        exact['derived_result'] = derived
        variable['setup'] = 1
    return exact, variable


def summarize(records):
    if (not records or records[0] != dict(phase='campaign', outcome='started')
            or records[-1] != dict(phase='campaign', outcome='complete')
            or sum(item.get('phase') == 'campaign' for item in records) != 2):
        raise ValueError('incomplete scenario campaign')
    manifests = [item for item in records if item.get('phase') == 'manifest']
    if len(manifests) != 1:
        raise ValueError('missing or duplicate scenario manifest')
    manifest, = manifests
    for field in ('source', 'cli_version', 'binaries', 'drivers', 'host_id', 'storage_device',
                  'host_limits', 'toolchain', 'durability', 'maintenance', 'build_mode', 'cache', 'unavailable'):
        if not manifest.get(field):
            raise ValueError('missing scenario provenance: ' + field)
    exact, variable = inventory(manifest)
    samples, identifiers = defaultdict(list), set()
    for record in records[1:-1]:
        if record.get('phase') in ('manifest', 'resources'):
            continue
        if record.get('phase') != 'sample' or record.get('outcome') != 'complete' or record.get('verified') is not True:
            raise ValueError('failed or unverified scenario sample')
        case, index = record['case'], positive(record['index'])
        if case not in exact and case not in variable:
            raise ValueError('unexpected scenario sample: ' + case)
        if (case, index) in identifiers:
            raise ValueError('duplicate scenario sample')
        identifiers.add((case, index))
        samples[case].append(positive(record['elapsed_ns']))
    for case, count in exact.items():
        if len(samples[case]) != count:
            raise ValueError('missing scenario coverage: ' + case)
    for case, minimum in variable.items():
        if len(samples[case]) < minimum:
            raise ValueError('missing scenario coverage: ' + case)
    for case, values in samples.items():
        if any((case, index) not in identifiers for index in range(len(values))):
            raise ValueError('noncontiguous scenario samples')
    startup = next(record for record in records if record.get('case') == 'startup')
    definition = startup.get('definition')
    if not isinstance(definition, str) or len(definition) != 64 or any(c not in '0123456789abcdef' for c in definition):
        raise ValueError('missing executed definition')
    manifest = dict(manifest, definition=definition)
    return dict(manifest=manifest, distributions={case: distribution(values) for case, values in samples.items()})


def check_budgets(report, budgets):
    if set(budgets) != {'scenario', 'minimum_repeat', 'limits_ms'}:
        raise ValueError('invalid scenario budget')
    manifest = report['manifest']
    if type(budgets['minimum_repeat']) is not int or not 1 <= budgets['minimum_repeat'] <= 100:
        raise ValueError('invalid budget repetition requirement')
    if budgets['scenario'] != manifest['scenario'] or manifest['repeat'] < budgets['minimum_repeat']:
        raise ValueError('scenario budget workload mismatch')
    if not budgets['limits_ms']:
        raise ValueError('empty scenario budget')
    for case, limits in budgets['limits_ms'].items():
        observed = report['distributions'].get(case)
        if observed is None or not limits:
            raise ValueError('budget has no verified scenario samples: ' + case)
        for field, maximum in limits.items():
            if field not in ('max_ms', 'p50_ms', 'p95_ms', 'p99_ms') or type(maximum) not in (int, float) or not math.isfinite(maximum) or maximum <= 0:
                raise ValueError('invalid scenario latency budget')
            measured = observed.get(field)
            if measured is None:
                raise ValueError('insufficient samples for budget: ' + case + '/' + field)
            if measured > maximum:
                raise ValueError(f'scenario latency budget exceeded: {case}/{field}: {measured:.3f} > {maximum:.3f} ms')


def compare(control, candidate, maximum_ratio):
    # Builds may differ. Workload, driver, definition, host and durability may
    # not; an incompatible cutover needs a separately reviewed experiment.
    for field in ('scenario', 'repeat', 'definition', 'drivers', 'host_id', 'storage_device', 'host_limits',
                  'toolchain', 'durability', 'maintenance', 'build_mode', 'cache'):
        if control['manifest'][field] != candidate['manifest'][field]:
            raise ValueError('incomparable scenario reports: ' + field)
    if not math.isfinite(maximum_ratio) or maximum_ratio <= 0:
        raise ValueError('invalid regression ratio')
    ratios = {}
    for case in control['distributions']:
        before, after = control['distributions'][case], candidate['distributions'][case]
        if before['p50_ms'] is None or after['p50_ms'] is None:
            continue
        if before['p50_ms'] <= 0:
            raise ValueError('invalid control duration')
        ratios[case] = after['p50_ms'] / before['p50_ms']
        if ratios[case] > maximum_ratio:
            raise ValueError('scenario regression: ' + case)
    if not ratios:
        raise ValueError('no comparable repeated samples')
    return ratios


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('records', type=Path)
    parser.add_argument('--budgets', type=Path)
    parser.add_argument('--control', type=Path)
    parser.add_argument('--maximum-ratio', type=float, default=1.25)
    args = parser.parse_args()
    def load(path):
        return summarize([json.loads(line) for line in path.read_text().splitlines()])
    report = load(args.records)
    if args.budgets:
        check_budgets(report, json.loads(args.budgets.read_text()))
    if args.control:
        report['ratios'] = compare(load(args.control), report, args.maximum_ratio)
    print(json.dumps(report))


if __name__ == '__main__':
    main()
