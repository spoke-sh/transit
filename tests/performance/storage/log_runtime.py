"""Installed signed Stream/Queue baselines; original outcomes and restart oracle."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import statistics
import struct
import subprocess
import tempfile
import time

from runner.capture import identity, provenance, run as capture, write_json
from runner.paths import ROOT
from storage.tables.direct_table_maintenance import process_usage


PROFILES = (
    dict(id=1, kind='stream', batch=1, keys=0, claim=1),
    dict(id=2, kind='stream', batch=128, keys=0, claim=16),
    dict(id=3, kind='queue', batch=1, keys=0, claim=1),
    dict(id=4, kind='queue', batch=128, keys=0, claim=16),
    dict(id=5, kind='queue', batch=128, keys=64, claim=16),
    dict(id=6, kind='queue', batch=128, keys=1, claim=16),
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def oracle(offsets):
    digest = hashlib.sha256()
    for offset in offsets:
        require(type(offset) is int and offset >= 0, 'Invalid read offset')
        digest.update(struct.pack('<Q', offset))
        digest.update(bytes((offset * 17 + index * 31 + 7) % 256 for index in range(128)))
    return digest.hexdigest()


def distribution(values):
    ordered = sorted(values)
    require(ordered and all(type(x) is int and x > 0 for x in ordered), 'Invalid timing samples')
    count = len(ordered)
    return dict(samples=count, min_ns=ordered[0], p50_ns=statistics.median(ordered),
                p95_ns=ordered[math.ceil(count * .95) - 1] if count >= 20 else None,
                p99_ns=ordered[math.ceil(count * .99) - 1] if count >= 100 else None,
                max_ns=ordered[-1], total_ns=sum(ordered))


def validate(records, profile, recovery):
    """Success requires complete attempt accounting and every independent row."""
    attempts, completed, readback = {}, {}, defaultdict(list)
    recovery_steps = Counter()
    terminal = []
    owner_budgets = []
    measured = defaultdict(list)
    allocation = defaultdict(Counter)
    for record in records:
        require(record.get('profile') == profile['id'], 'Wrong profile identity')
        event = record['event']
        if event == 'attempt':
            serial = record['serial']
            require(serial not in attempts, 'Duplicate attempt')
            attempts[serial] = record
        elif event == 'recovery_step':
            serial = record['serial']
            require(serial in attempts and serial not in completed, 'Unmatched recovery progress')
            require(attempts[serial]['action'] in ('operation', 'observe', 'cursor', 'page', 'group'), 'Mutation replay is forbidden')
            recovery_steps[serial] += 1
            require(record['http_call'] == recovery_steps[serial], 'Missing recovery attempt')
        elif event == 'sample':
            serial = record['serial']
            require(serial in attempts and serial not in completed, 'Unmatched sample')
            original = attempts[serial]
            require(all(original[key] == record[key] for key in ('stage', 'action')), 'Changed attempt')
            require(type(record['ns']) is int and record['ns'] > 0, 'Invalid elapsed time')
            require(record['http_calls'] == recovery_steps[serial] + 1, 'Missing HTTP attempt')
            completed[serial] = record
            backing = record['backing']
            fields = {'alloc_attempts', 'alloc_successes', 'resize_attempts', 'resize_successes',
                      'growing_resize_attempts', 'remap_attempts', 'remap_successes', 'frees',
                      'requested_bytes', 'acquired_bytes', 'released_bytes', 'forbidden_attempts'}
            require(set(backing) == fields, 'Missing backing allocation observation')
            require(all(type(value) is int and value >= 0 for value in backing.values()), 'Invalid allocation counts')
            for kind in ('alloc', 'resize', 'remap'):
                require(backing[kind + '_successes'] <= backing[kind + '_attempts'], 'Invalid allocation successes')
            require(backing['forbidden_attempts'] == 0, 'Unexpected sealed measurement')
            require(backing['growing_resize_attempts'] <= backing['resize_attempts'] and
                    backing['acquired_bytes'] <= backing['requested_bytes'], 'Invalid allocation growth')
            if record['stage'] == 'measured':
                measured[record['action']].append(record['ns'])
                allocation[record['action']].update(backing)
        elif event == 'readback':
            require(record['sha256'] == oracle(record['offsets']), 'Payload digest mismatch')
            readback[record['stage']].extend(record['offsets'])
        elif event == 'owner_budgets':
            limits = record['limits']
            common = {'catalog_pages', 'catalog_index_work_bytes', 'partition_pages',
                      'partition_index_work_bytes', 'tail_slots', 'tail_borrow_slots',
                      'tail_slot_bytes', 'tail_resident_bytes'}
            queue = {'queue_candidate_objects', 'queue_candidate_resident_bytes',
                     'queue_deadline_rows', 'queue_visibility_rows', 'queue_affinity_rows'}
            require(set(limits) == common | queue, 'Missing owner budget')
            for key, value in limits.items():
                if key in queue and profile['kind'] == 'stream':
                    require(value is None, 'Queue budget attributed to Stream')
                else:
                    minimum = 0 if key in ('catalog_pages', 'partition_pages') else 1
                    require(type(value) is int and value >= minimum, 'Invalid owner budget')
            owner_budgets.append(limits)
        elif event == 'complete':
            terminal.append(record)
        else:
            raise ValueError(f'Failed or unknown measurement event: {event}')
    require(attempts and attempts.keys() == completed.keys(), 'Missing attempt outcome')
    require(len(terminal) == 1 and records[-1] == terminal[0], 'Missing unique terminal completion')
    require(len(owner_budgets) == 1, 'Missing unique owner budgets')
    require(terminal[0]['recovery'] == recovery and terminal[0]['build_mode'] == 'safe', 'Wrong recovery/build profile')
    warm_rows = profile['warmup'] * profile['batch']
    total = warm_rows + profile['repeat'] * profile['batch']
    expected = {'recovery': range(total)} if recovery else {'warmup': range(warm_rows), 'measured': range(warm_rows, total)}
    for stage, offsets in expected.items():
        require(sorted(readback.pop(stage, [])) == list(offsets), f'{stage}: missing, duplicate or foreign rows')
    require(not readback, 'Unexpected readback phase')
    if not recovery:
        append = 'append' if profile['kind'] == 'stream' else 'enqueue'
        require(len(measured[append]) == profile['repeat'], 'Wrong append denominator')
        if profile['kind'] == 'queue':
            require(len(measured['settle']) == profile['repeat'] * profile['batch'], 'Missing ACK sample')
    return dict(passed=True, attempts=len(attempts), successful=len(completed), refused=0, failed=0, unknown=0,
                http_calls=sum(record['http_calls'] for record in completed.values()),
                recovery_steps=sum(recovery_steps.values()),
                rows=total, distributions={key: distribution(values) for key, values in measured.items()},
                owner_budgets=owner_budgets[0],
                client_backing={key: dict(values) for key, values in allocation.items()})


def incomplete(records):
    """Retain failure/uncertainty denominators even when validation cannot finish."""
    attempts = {record['serial'] for record in records if record.get('event') == 'attempt'}
    successes = {record['serial'] for record in records if record.get('event') == 'sample'}
    failures = {record['serial']: record for record in records if record.get('event') == 'failure'}
    refused = failed = unknown = 0
    for serial in attempts - successes:
        record = failures.get(serial, {})
        outcome = (record.get('diagnostic') or {}).get('outcome')
        if outcome in ('input_rejected', 'rejected'):
            refused += 1
        elif outcome in ('failed', 'not_submitted', 'not_dispatched') or record.get('mutation_attempted') is False:
            failed += 1
        else:
            unknown += 1
    return dict(passed=False, attempts=len(attempts), successful=len(successes),
                refused=refused, failed=failed, unknown=unknown)


def exercise(node, caller, root, profile_path, url, settings_path, restart, owner):
    settings = json.loads(Path(settings_path).read_text())
    destination = Path(settings['output'])
    report = settings['report']
    report['definition'] = json.loads(profile_path.read_text())['definition']
    configuration = json.loads((root / 'node.json').read_text())
    report['fixture'] = dict(native_resident_pages=configuration['resident_pages'],
                            server_timeout_ms=configuration['request_timeout_ms'],
                            max_clock_error_ms=configuration['genesis']['max_clock_error_ms'],
                            automatic_maintenance=False)
    # Binary files are frozen by main before setup. The endpoint goes directly
    # to the owner; the correctness fault proxy is not in the timing path.
    for profile in settings['profiles']:
        Path(str(profile_path) + '.baseline.json').write_text(json.dumps(profile))
        item = dict(profile=profile, phases=[], completed=False)
        report['profiles'].append(item)
        write_json(destination / 'report.json', report)
        for phase in ('measure', 'recover'):
            stopped = restart() if phase == 'recover' else None
            prefix = destination / f"{profile['id']:02d}-{phase}"
            result = dict(phase=phase, completed=False)
            if stopped is not None:
                result['restart'] = stopped
            item['phases'].append(result)
            result['node_before'] = process_usage(owner())
            started = time.monotonic()
            write_json(destination / 'report.json', report)
            records = []
            try:
                with (destination / 'diagnostics.log').open('ab') as console:
                    execution = capture([caller, url, 'log-baseline-' + phase, str(profile_path)],
                                        cwd=ROOT, log=prefix.with_suffix('.stderr'),
                                        result=result, capture_stdout=True, console=console)
                execution.check_returncode()
                records = [json.loads(line) for line in prefix.with_suffix('.stdout').read_text().splitlines()]
                result['verification'] = validate(records, profile, phase == 'recover')
                if phase == 'recover':
                    require(result['verification']['owner_budgets'] == item['phases'][0]['verification']['owner_budgets'],
                            'Owner budgets changed during restart')
                result['node_after'] = process_usage(owner())
                before, after = result['node_before'], result['node_after']
                require((before['pid'], before['start_ticks']) == (after['pid'], after['start_ticks']), 'Owner changed during measurement')
                result['node_delta'] = {key: after[key] - before[key] for key in ('user_ticks', 'system_ticks', 'read_bytes', 'write_bytes', 'rchar', 'wchar')}
                result['completed'] = True
            except BaseException:
                stdout = prefix.with_suffix('.stdout')
                if stdout.exists():
                    for line in stdout.read_text().splitlines()[len(records):]:
                        try:
                            records.append(json.loads(line))
                        except ValueError:
                            break
                result['verification'] = incomplete(records)
                result['completed'] = False
                raise
            finally:
                result['phase_seconds'] = time.monotonic() - started
                write_json(destination / 'report.json', report)
        item['completed'] = True
        write_json(destination / 'report.json', report)
        print(f"Log baseline profile {profile['id']}: {profile['kind']}, batch {profile['batch']}, {profile['repeat']} samples and restart readback passed.", flush=True)
    report['completed'] = True
    write_json(destination / 'report.json', report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('node', type=Path)
    parser.add_argument('caller', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeat', type=int, default=20)
    parser.add_argument('--warmup', type=int, default=3)
    parser.add_argument('--profiles', type=int, nargs='+', choices=range(1, 7), default=list(range(1, 7)))
    args = parser.parse_args()
    require(1 <= args.repeat <= 100 and 0 <= args.warmup <= 10, 'Invalid sample budget')
    require(len(set(args.profiles)) == len(args.profiles), 'Repeated profile')
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=False)
    report = dict(version=1, source=provenance(ROOT), completed=False, profiles=[],
                  source_diff_sha256=hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT)).hexdigest(),
                  machine=dict(platform=platform.platform(), cpu_count=os.cpu_count(), affinity=sorted(os.sched_getaffinity(0)), load=os.getloadavg()),
                  method=dict(payload_bytes=128, worker_count=1, offered_load='sequential',
                              storage='local disk TWAL1 and object store', cache='warm process; no OS cache eviction',
                              lease_ms=60000, native_resident_pages=1, active_leases=64, waiters=64, timer_steps=64,
                              owner_budget_source='compiled catalog/log defaults used by the fixture host; per-phase owner_budgets',
                              retention='unlimited', client_timeout_ms=30000,
                              allocation_scope='public client, transport and output arena; per call after output reset',
                              storage_iops='unmeasured', server_allocations='unmeasured', cpu_cycles='unmeasured',
                              client_process_peak_rss='unmeasured', node_peak_rss='process lifetime high-water mark',
                              excludes=['offered-load concurrency', 'sealed/cold reads', 'consumer groups', 'delays', 'wait wakeups', 'lease expiry']),
                  drivers=[identity(ROOT / path) for path in ('tests/performance/storage/log_runtime.py', 'tests/performance/storage/log_runtime.zig', 'tests/storage/tables/direct_table_service.py', 'tests/interfaces/native/direct_table_client.zig')])
    write_json(destination / 'report.json', report)
    with tempfile.TemporaryDirectory(prefix='transit-log-baseline-binaries-', dir='/var/tmp') as frozen:
        binaries = []
        for name, source in (('node', args.node), ('caller', args.caller)):
            target = Path(frozen) / name
            shutil.copy2(source.resolve(), target)
            binaries.append(target)
        report['binaries'] = [identity(path) for path in binaries]
        settings = dict(output=str(destination), report=report,
                        profiles=[dict(profile, repeat=args.repeat, warmup=args.warmup) for profile in PROFILES if profile['id'] in args.profiles])
        settings_path = destination / 'settings.json'
        write_json(settings_path, settings)
        from storage.tables.direct_table_service import run
        run(*binaries, 'log-baseline', str(settings_path))
    print(f'Baseline evidence: {destination / "report.json"}', flush=True)


if __name__ == '__main__':
    main()
