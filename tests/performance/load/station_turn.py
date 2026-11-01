"""Real installed Station handler turns, confirmed state and retained outbox."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import time
import urllib.request

from harness.services import free_port, wait_ready
from performance.storage.log_runtime import distribution, require
from runner.capture import identity, provenance, run as capture, write_json
from runner.paths import ROOT
from storage.tables.direct_table_maintenance import process_usage


def payload_hash(index):
    return hashlib.sha256(bytes((index * 17 + n * 31 + 7) % 256 for n in range(128))).hexdigest()


def validate(records, config, recovery, definition, accepted=None):
    count = config['warmup'] + config['repeat']
    attempts, confirmations, samples, admissions, inputs, outputs, states = {}, {}, {}, {}, {}, {}, {}
    terminal = []
    allocations = Counter()
    timings = []
    for row in records:
        kind = row['event']
        if kind == 'complete':
            terminal.append(row)
            continue
        require(type(row['index']) is int and 0 <= row['index'] < count, 'Foreign turn')
        index = row['index']
        group = {'input_attempt': admissions, 'input_accepted': inputs, 'attempt': attempts, 'confirmed': confirmations,
                 'sample': samples, 'output': outputs, 'state': states}.get(kind)
        require(group is not None and index not in group, 'Failure or duplicate evidence')
        group[index] = row
        if kind in ('state', 'output'):
            require(row['recovery'] == recovery and row['sha256'] == payload_hash(index), 'Corrupt readback')
        elif kind == 'input_accepted':
            require(index in admissions and row['input'] > 0, 'Missing input admission')
        elif kind == 'attempt':
            require(index in inputs and row['input'] == inputs[index]['input'], 'Missing accepted input')
        elif kind == 'confirmed':
            require(index in attempts and row['input'] == attempts[index]['input'] and row['commit'] > row['input'], 'Missing original turn')
        elif kind == 'sample':
            require(index in confirmations and all(row[key] == confirmations[index][key] for key in ('input', 'commit')), 'Missing turn confirmation')
            require(row['stage'] == attempts[index]['stage'] == ('warmup' if index < config['warmup'] else 'measured'), 'Wrong phase')
            require(type(row['ns']) is int and row['ns'] > 0 and row['commit'] > row['input'], 'Invalid completion')
            counts = row['backing']
            expected = {'alloc_attempts', 'alloc_successes', 'resize_attempts', 'resize_successes', 'growing_resize_attempts',
                        'remap_attempts', 'remap_successes', 'frees', 'requested_bytes', 'acquired_bytes', 'released_bytes', 'forbidden_attempts'}
            require(set(counts) == expected and all(type(n) is int and n >= 0 for n in counts.values()), 'Missing allocator observations')
            require(all(counts[k + '_successes'] <= counts[k + '_attempts'] for k in ('alloc', 'resize', 'remap')), 'Invalid allocator counts')
            require(counts['growing_resize_attempts'] <= counts['resize_attempts'] and counts['acquired_bytes'] <= counts['requested_bytes'] and counts['forbidden_attempts'] == 0, 'Invalid allocator growth')
            if row['stage'] == 'measured':
                timings.append(row['ns'])
                allocations.update(counts)
    require(len(terminal) == 1 and records[-1] == terminal[0], 'Missing unique terminal outcome')
    require(terminal[0] == dict(event='complete', recovery=recovery, definition=definition, build_mode='safe'), 'Wrong build or definition')
    require(set(outputs) == set(range(count)), 'Missing or foreign outputs')
    if recovery:
        require(not (attempts or confirmations or samples or admissions or inputs) and set(states) == {count - 1}, 'Recovery dispatched work')
        require(accepted is not None, 'Missing original confirmations')
        expected = accepted
    else:
        require(all(set(group) == set(range(count)) for group in (attempts, confirmations, samples, admissions, inputs, states)), 'Incomplete turn coverage')
        require(len(timings) == config['repeat'], 'Wrong measured denominator')
        expected = [dict(index=i, input=samples[i]['input'], commit=samples[i]['commit']) for i in range(count)]
    require(len({row['input'] for row in expected}) == count and len({row['commit'] for row in expected}) == count, 'Reused input or commit')
    for original in expected:
        require(all(outputs[original['index']][key] == original[key] for key in ('input', 'commit')), 'Changed original attribution')
    return dict(passed=True, attempts=len(attempts), successful=len(samples), refused=0, failed=0, unknown=0,
                rows=count, accepted=expected, turn_ns=distribution(timings) if timings else None, client_backing=dict(allocations))


def incomplete(records):
    attempts = {r['index'] for r in records if r.get('event') == 'attempt'}
    samples = {r['index'] for r in records if r.get('event') == 'sample'}
    confirmations = {r['index'] for r in records if r.get('event') == 'confirmed'}
    admissions = {r['index'] for r in records if r.get('event') == 'input_attempt'}
    inputs = {r['index'] for r in records if r.get('event') == 'input_accepted'}
    # A missing turn confirmation is conservatively unresolved, including
    # a failure with a pending permit/open. No rejection is inferred from EOF.
    return dict(passed=False, attempts=len(attempts), successful=len(samples & attempts),
                refused=0, failed=len((confirmations & attempts) - samples), unknown=len(attempts - confirmations), admission_unknown=len(admissions - inputs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('node', type=Path)
    parser.add_argument('caller', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--warmup', type=int, default=3)
    parser.add_argument('--repeat', type=int, default=20)
    args = parser.parse_args()
    require(1 <= args.warmup <= 10 and 1 <= args.repeat <= 100, 'Invalid sample budget')
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=False)
    root = Path(tempfile.mkdtemp(prefix='transit-station-baseline-', dir='/var/tmp'))
    print(f'Station baseline private installation: {root}', flush=True)
    node, caller = root / 'node', root / 'caller'
    config = dict(warmup=args.warmup, repeat=args.repeat)
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    report = dict(version=1, completed=False, source=provenance(ROOT), definition=definition,
                  source_diff_sha256=hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT)).hexdigest(),
                  config=config, phases=[], stops=[],
                  machine=dict(platform=platform.platform(), cpu_count=os.cpu_count(), affinity=sorted(os.sched_getaffinity(0)), load=os.getloadavg()),
                  method=dict(runtime='current native GenServer', storage='local disk native WAL', resident_pages=1,
                              workers=1, offered_load='sequential', state_bytes=128, outputs_per_turn=1,
                              timer='prepare through durable commit confirmation, including private pending-record writes',
                              excludes=['input admission', 'output delivery', 'remote effects', 'verification reads'],
                              client_allocations='client and HTTP transport; excludes private recorder',
                              server_allocations='unmeasured', cpu_cycles='unmeasured', storage_iops='unmeasured',
                              node_peak_rss='process lifetime high-water mark', client_peak_rss='unmeasured'),
                  drivers=[identity(ROOT / path) for path in ('tests/performance/load/station_turn.py', 'tests/performance/load/station_turn.zig')])
    child = None
    log = None
    success = False

    def stop():
        nonlocal child
        if child is not None:
            child.terminate()
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=15)
                report['stops'].append(dict(requested_signal='SIGTERM', forced_kill=True, exit_code=child.returncode))
                child = None
                raise
            code = child.returncode
            report['stops'].append(dict(requested_signal='SIGTERM', forced_kill=False, exit_code=code))
            child = None
            require(code in (0, -15), 'Unexpected node stop result')

    try:
        for source, target in ((args.node, node), (args.caller, caller)):
            shutil.copy2(source.resolve(), target)
        report['binaries'] = [identity(node), identity(caller)]
        write_json(root / 'settings.json', config)
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        settings = dict(genesis=dict(realm=43, root_key=json.loads(subprocess.check_output([caller, 'public'], timeout=10)), max_clock_error_ms=10000),
                        local_directory=str(root / 'native'), port=port, resident_pages=1, request_timeout_ms=10000)
        write_json(root / 'node.json', settings)
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        log = (root / 'node.log').open('wb')
        accepted = None
        for phase in ('measure', 'recover'):
            child = subprocess.Popen([node, str(root / 'node.json'), '--bootstrap'], stdout=log, stderr=subprocess.STDOUT)
            wait_ready(http, child, url + '/health')
            result = dict(phase=phase, completed=False, node_before=process_usage(child))
            report['phases'].append(result)
            write_json(destination / 'report.json', report)
            prefix = destination / phase
            records = []
            started = time.monotonic()
            try:
                with (destination / 'diagnostics.log').open('ab') as console:
                    execution = capture([caller, url, phase, str(root)], cwd=ROOT, log=prefix.with_suffix('.stderr'),
                                        result=result, capture_stdout=True, console=console)
                execution.check_returncode()
                records = [json.loads(line) for line in prefix.with_suffix('.stdout').read_text().splitlines()]
                result['verification'] = validate(records, config, phase == 'recover', definition, accepted)
                accepted = result['verification']['accepted']
                result['node_after'] = process_usage(child)
                result['node_delta'] = {key: result['node_after'][key] - result['node_before'][key]
                                        for key in ('user_ticks', 'system_ticks', 'read_bytes', 'write_bytes', 'rchar', 'wchar')}
                result['completed'] = True
            except BaseException:
                if prefix.with_suffix('.stdout').exists():
                    for line in prefix.with_suffix('.stdout').read_text().splitlines()[len(records):]:
                        try:
                            records.append(json.loads(line))
                        except ValueError:
                            break
                result['verification'] = incomplete(records)
                raise
            finally:
                result['phase_seconds'] = time.monotonic() - started
                write_json(destination / 'report.json', report)
            stop()
        success = report['completed'] = True
    finally:
        try:
            stop()
        finally:
            if log is not None:
                log.close()
            write_json(destination / 'report.json', report)
            if success:
                shutil.rmtree(root)
            else:
                print(f'Failed Station baseline retained at {root}', flush=True)
    print(f'Station baseline verified: {destination / "report.json"}', flush=True)


if __name__ == '__main__':
    main()
