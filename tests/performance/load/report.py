"""Reject incomplete installed experiments before summarizing their observations."""
import argparse
import json
from pathlib import Path

from performance.sdk.report import distribution, integer

MANAGED_PHASES = ('acquire', 'evaluate', 'prepare', 'execute', 'checkpoint_prepare', 'checkpoint_execute', 'decide', 'abort')
OWNER_COUNTERS = dict(
    managed={phase + suffix for phase in MANAGED_PHASES for suffix in ('_calls', '_ns')} |
            {'failed_steps', 'result_rows', 'result_pages', 'result_record_bytes'},
    owned_records={'stage_calls', 'stage_failures', 'reservation_attempts', 'reservation_returns',
                   'readiness_attempts', 'readiness_returns', 'reused_returns', 'stored_bytes',
                   'reservation_logical_bytes'})
UNAVAILABLE = ('heap_allocations', 'live_allocation_bytes', 'peak_workspace_bytes', 'physical_object_writes',
               'physical_log_writes', 'physical_syncs', 'retained_bytes', 'reclaimable_bytes', 'copies')


def counters(value):
    if not isinstance(value, dict) or value.keys() != OWNER_COUNTERS.keys():
        raise ValueError('missing owner attribution')
    for owner, fields in OWNER_COUNTERS.items():
        if not isinstance(value[owner], dict) or value[owner].keys() != fields:
            raise ValueError('missing owner counter: ' + owner)
        for count in value[owner].values():
            if integer(count) >= 2**64:
                raise ValueError('overflowed counter')
    return value


def owner_snapshot(value):
    if not isinstance(value, dict) or value.keys() != {'instance', *OWNER_COUNTERS}:
        raise ValueError('missing owner snapshot')
    instance = value['instance']
    if not isinstance(instance, list) or len(instance) != 16 or any(type(n) is not int or not 0 <= n <= 255 for n in instance):
        raise ValueError('missing owner instance')
    for owner in OWNER_COUNTERS:
        if not isinstance(value[owner], dict) or value[owner].keys() != {'values', 'overflowed'} or value[owner]['overflowed'] is not False:
            raise ValueError('overflowed or missing owner counters')
    return instance, counters({owner: value[owner]['values'] for owner in OWNER_COUNTERS})


def inventory(manifest):
    repeat = integer(manifest['repeat'], 1)
    if repeat > 100 or not 1 <= integer(manifest['rows'], 1) <= 900 or not 1 <= integer(manifest['peers'], 1) <= 16:
        raise ValueError('invalid workload bound')
    result = {('startup', 0)}
    if manifest['profile'] == 'managed':
        result |= {(case, 0) for case in ('activation', 'idle', 'retained_restart')}
        result |= {(case, index) for case in ('foreground_baseline', 'source_update') for index in range(repeat)}
    elif manifest['profile'] == 'connections':
        for protocol in ('postgres', 'mysql'):
            result |= {(protocol + '_' + case, index) for case in ('connect', 'warm', 'loaded', 'control') for index in range(repeat)}
            result |= {(protocol + '_idle_peer', index) for index in range(manifest['peers'])}
            result.add((protocol + '_partial_control', 0))
    else:
        raise ValueError('unknown workload profile')
    return result


def summarize(records):
    if not records or records[0] != dict(phase='campaign', outcome='started') or records[-1] != dict(phase='campaign', outcome='complete'):
        raise ValueError('incomplete campaign')
    if sum(record.get('phase') == 'campaign' for record in records) != 2:
        raise ValueError('duplicate campaign')
    manifests = [record for record in records if record.get('phase') == 'manifest']
    if len(manifests) != 1:
        raise ValueError('missing manifest')
    manifest, = manifests
    for key in ('source', 'binary_revision', 'binaries', 'drivers', 'system', 'machine', 'cpus', 'host_id',
                'storage_device', 'toolchain', 'maintenance', 'durability', 'cache', 'instrumentation', 'bounds',
                'build_mode', 'tls', 'client_versions', 'sql_limits', 'host_limits', 'unavailable'):
        if not manifest.get(key):
            raise ValueError('missing attribution: ' + key)
    if type(manifest.get('attribution')) is not bool or manifest['unavailable'] != list(UNAVAILABLE):
        raise ValueError('missing measurement availability')
    expected = inventory(manifest)
    samples, resource_cases = {}, set()
    for record in records[1:-1]:
        phase = record.get('phase')
        if phase == 'manifest':
            continue
        if phase == 'resources':
            if record['case'] in resource_cases or not record.get('processes'):
                raise ValueError('duplicate or missing resource sample')
            resource_cases.add(record['case'])
            continue
        if phase != 'sample':
            raise ValueError('unknown record')
        key = record.get('case'), integer(record.get('index'))
        if key not in expected or key in samples or record.get('outcome') != 'complete' or record.get('verified') is not True:
            raise ValueError('failed, duplicate or unverified sample')
        integer(record['elapsed_ns'])
        for value in record.get('local_attempts', {}).values():
            integer(value)
        for value in record.get('foreground_ns', []):
            integer(value)
        measured = key[0] in ('foreground_baseline', 'activation', 'source_update', 'idle') or (
            manifest['profile'] == 'connections' and key[0] != 'startup' and not key[0].endswith('_idle_peer'))
        if manifest['attribution'] and measured:
            counters(record.get('owner_counters'))
            before_instance, before = owner_snapshot(record.get('owner_before'))
            after_instance, after = owner_snapshot(record.get('owner_after'))
            if before_instance != after_instance or any(
                    after[owner][field] - before[owner][field] != record['owner_counters'][owner][field]
                    for owner, fields in OWNER_COUNTERS.items() for field in fields):
                raise ValueError('reset or inconsistent owner counters')
        elif any(field in record for field in ('owner_counters', 'owner_before', 'owner_after')):
            raise ValueError('unexpected instrumentation')
        if key[0] in ('activation', 'source_update'):
            target = manifest['rows'] + (key[1] + 1 if key[0] == 'source_update' else 0)
            if type(record.get('rows')) is not int or record['rows'] != target or not record.get('foreground_ns'):
                raise ValueError('incomplete managed result')
            integer(record['revision'], 1)
        if key[0].endswith('_idle_peer'):
            if type(record.get('admitted')) is not bool:
                raise ValueError('missing admission outcome')
            if not record['admitted']:
                basis, state = record.get('refusal_basis'), record.get('sqlstate')
                typed = basis == 'sqlstate' and state in ('53000', '53300', '28000', '28P01')
                diagnostic = basis == 'postgres_fatal_message' and state is None and key[0] == 'postgres_idle_peer'
                if not (typed or diagnostic):
                    raise ValueError('missing refusal evidence')
        samples[key] = record
    if samples.keys() != expected:
        raise ValueError('missing workload samples')
    resources = {'settled'} if manifest['profile'] == 'managed' else {'before_peers', 'postgres_idle', 'mysql_idle', 'after_peers'}
    if resource_cases != resources:
        raise ValueError('missing resource phases')
    definition = samples['startup', 0].get('definition')
    if not isinstance(definition, str) or len(definition) != 64 or any(c not in '0123456789abcdef' for c in definition):
        raise ValueError('missing definition')
    cases = {}
    for case in sorted({key[0] for key in expected}):
        selected = [value for (name, _), value in samples.items() if name == case]
        cases[case] = dict(elapsed=distribution([value['elapsed_ns'] for value in selected]))
        foreground = [ns for value in selected for ns in value.get('foreground_ns', [])]
        if foreground:
            cases[case]['foreground'] = distribution(foreground)
        if selected[0].get('owner_counters') is not None:
            cases[case]['owner_totals'] = {owner: {field: sum(s['owner_counters'][owner][field] for s in selected)
                for field in sorted(fields)} for owner, fields in OWNER_COUNTERS.items()}
        if case.endswith('_idle_peer'):
            cases[case]['admitted'] = sum(value['admitted'] for value in selected)
            cases[case]['refused'] = len(selected) - cases[case]['admitted']
    return dict(manifest=manifest, definition=definition, cases=cases,
                qualification='finite diagnostic experiment; no sustainable throughput or latency SLO',
                samples=list(samples.values()), resources=[r for r in records if r.get('phase') == 'resources'])


def compare(control, candidate):
    keys = ('profile', 'rows', 'repeat', 'peers', 'drivers', 'system', 'machine', 'cpus', 'host_id',
            'storage_device', 'toolchain', 'maintenance', 'durability', 'cache', 'instrumentation', 'bounds',
            'build_mode', 'tls', 'client_versions', 'sql_limits', 'attribution', 'host_limits', 'unavailable')
    if control['definition'] != candidate['definition'] or any(control['manifest'][key] != candidate['manifest'][key] for key in keys):
        raise ValueError('incomparable campaigns')
    def admissions(report):
        return sorted((s['case'], s['index'], s['admitted'], s.get('refusal_basis'), s.get('sqlstate'))
                      for s in report['samples'] if s['case'].endswith('_idle_peer'))
    if admissions(control) != admissions(candidate):
        raise ValueError('incomparable admission evidence')
    ratios = {}
    for case, value in candidate['cases'].items():
        # Changing the admission outcome changes the workload, not just latency.
        previous = control['cases'][case]
        if value.get('admitted') != previous.get('admitted'):
            raise ValueError('incomparable admission outcomes')
        old, new = previous['elapsed']['p50_ns'], value['elapsed']['p50_ns']
        if old <= 0 or new <= 0:
            raise ValueError('nonpositive comparison timing')
        ratios[case] = old / new
    return ratios


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    parser.add_argument('--control', type=Path)
    args = parser.parse_args()
    def read(path):
        return summarize([json.loads(line) for line in path.read_text().splitlines()])
    report = read(args.path)
    if args.control:
        report['p50_speedup'] = compare(read(args.control), report)
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
