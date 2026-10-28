"""Finite SQL result safety, complete Progress edge replay and guard controls."""
from collections import deque
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import time

from runner.paths import ROOT
from verification.models.tlc_support import complete, record, run_traces

MODELS = Path(__file__).resolve().parent
FIELDS = {'received', 'delivered', 'outcome', 'consumption', 'released', 'terminal', 'evidence'}
EVENT_FIELDS = {'kind', 'rows', 'identity'}
KINDS = {'Init', 'receive', 'deliver', 'finish', 'fail', 'cancel', 'release'}
GUARDS = {'CheckIdentity': 'StableAttribution', 'CheckCount': 'TerminalAgreement',
          'CheckRelease': 'ReleasedIsFinal', 'CheckTerminal': 'VerifiedTerminal',
          'CheckPreserveCompletion': 'CompletionPreserved'}
SESSION_GUARDS = {'CheckRepeat': 'ExactOccurrences', 'CheckDisclosure': 'AuthorizedDisclosure'}


def projection(label):
    error = re.search(r'^/\\ error = "(\w+)"$', label, re.M)
    if not error:
        raise ValueError('missing transition outcome')
    return {'state': record(label, 's', FIELDS), 'error': error[1]}


def event(label):
    value = record(label, 'last', EVENT_FIELDS)
    if (value['kind'] not in KINDS or type(value['rows']) is not int or value['rows'] < 0
            or type(value['identity']) is not int or value['identity'] not in range(4)):
        raise ValueError(f'unmapped progress event: {value}')
    return value


def graph(path):
    nodes, edges, initial = {}, [], []
    for line in path.read_text().splitlines():
        edge = re.match(r'(-?\d+) -> (-?\d+) \[label="Step"', line)
        node = re.match(r'(-?\d+) \[label=("(?:\\.|[^"\\])*")', line)
        if edge:
            edges.append((edge[1], edge[2]))
        elif node:
            label = json.loads(node[2])
            if node[1] in nodes:
                raise ValueError('duplicate graph node')
            nodes[node[1]] = (projection(label), event(label))
            if nodes[node[1]][1]['kind'] == 'Init':
                initial.append(node[1])
        elif re.match(r'-?\d+', line):
            raise ValueError(f'unmapped graph line: {line[:200]}')
    if len(initial) != 1 or not edges:
        raise ValueError('incomplete progress graph')
    successors = {key: {} for key in nodes}
    for before, after in edges:
        key = json.dumps(nodes[after][1], sort_keys=True)
        if key in successors[before] and successors[before][key] != after:
            raise ValueError('non-deterministic progress transition')
        successors[before][key] = after
    paths = {initial[0]: []}
    pending = deque(initial)
    while pending:
        before = pending.popleft()
        for after in successors[before].values():
            if after not in paths:
                paths[after] = paths[before] + [nodes[after][1]]
                pending.append(after)
    if len(paths) != len(nodes):
        raise ValueError('unreachable exported state')
    return nodes, edges, paths, successors, initial[0]


def tlc(module, template, name, destination, seconds, dump=False):
    local = destination / name
    local.mkdir()
    for source in ('StatementResult.tla', 'StatementResultSession.tla'):
        shutil.copyfile(MODELS / source, local / source)
    (local / 'model.cfg').write_text(template)
    (local / 'configuration.sha256').write_text(hashlib.sha256(template.encode()).hexdigest() + '\n')
    command = ['tlc', '-workers', '1', '-seed', '1', '-fp', '0',
               '-metadir', str(local / 'states'), '-config', 'model.cfg']
    if dump:
        command += ['-dump', 'dot,actionlabels', str(local / 'states.dot')]
    command.append(module + '.tla')
    (local / 'command.json').write_text(json.dumps(command) + '\n')
    try:
        result = subprocess.run(command, cwd=local, capture_output=True, text=True,
                                env=os.environ | {'JAVA_TOOL_OPTIONS': '-Xmx512m'}, timeout=seconds)
    except subprocess.TimeoutExpired as failure:
        output = (failure.stdout or b'') + (failure.stderr or b'')
        (local / 'tlc.log').write_bytes(output)
        raise
    output = result.stdout + result.stderr
    (local / 'tlc.log').write_text(output)
    return result.returncode, output


def counterexample(code, output, invariant):
    violation = re.search(r'Error: Invariant (\w+) is violated\.', output)
    numbers = [int(number) for number in re.findall(r'\nState (\d+):', output)]
    chunks = re.split(r'\nState \d+:', output)[1:]
    if (code != 12 or not violation or violation[1] != invariant or len(chunks) < 2
            or numbers != list(range(1, len(numbers) + 1)) or 'Finished in ' not in output):
        raise AssertionError(f'expected explicit {invariant} counterexample: {output[-4000:]}')
    labels = [chunk.split('\n\n', 1)[0] + '\n' for chunk in chunks]
    events = [record(label, 'last', EVENT_FIELDS) for label in labels]
    if events[0] != {'kind': 'Init', 'rows': 0, 'identity': 0}:
        raise AssertionError('missing counterexample initial state')
    return events[1:], labels[-1]


def runner_controls():
    """A failed tool, incomplete graph or malformed trace cannot certify a model."""
    finished = ('Model checking completed. No error has been found.\n'
                '10 states generated, 2 distinct states found, 0 states left on queue')
    if complete(0, finished) != (10, 2):
        raise AssertionError('completion parser control failed')
    controls = [lambda: complete(1, finished),
                lambda: complete(0, finished.replace('0 states left', '1 states left')),
                lambda: complete(0, 'Model checking completed. No error has been found.'),
                lambda: record('/\\ s = [a |-> 1, extra |-> 2]\n', 's', {'a'}),
                lambda: record('/\\ s = [a |-> 1, a |-> 2]\n', 's', {'a'}),
                lambda: event('/\\ last = [kind |-> "unknown", rows |-> 0, identity |-> 0]\n'),
                lambda: counterexample(12, 'Error: Invariant StableAttribution is violated.', 'StableAttribution')]
    for check in controls:
        try:
            check()
        except (AssertionError, ValueError):
            continue
        raise AssertionError('malformed/incomplete evidence was accepted')
    if record('/\\ s = [terminal |-> -1]\n', 's', {'terminal'}) != {'terminal': -1}:
        raise AssertionError('negative terminal sentinel was not parsed')


def equal(actual, expected, events, destination):
    if actual != expected:
        (destination / 'divergence.json').write_text(json.dumps(
            {'events': events, 'expected': expected, 'actual': actual}, indent=2) + '\n')
        raise AssertionError(f'Progress/model divergence; see {destination / "divergence.json"}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary')
    parser.add_argument('--rows', type=int, choices=range(2, 5), default=2)
    parser.add_argument('--seconds', type=int, default=60)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error('--seconds must be positive')
    if shutil.which('tlc') is None:
        raise SystemExit('TLC missing: use nix develop --command just test::statement-result-model')
    binary = str(Path(args.binary).resolve())
    base = ROOT / '.cache/verification/statement-result-model'
    destination = base / (time.strftime('%Y%m%dT%H%M%S') + f'-{os.getpid()}')
    destination.mkdir(parents=True)
    inputs = ['StatementResult.tla', 'StatementResult.cfg', 'StatementResultSession.tla',
              'StatementResultSession.cfg', 'statement_result_model.py', 'statement_result_state.zig', 'tlc_support.py']
    source_paths = [MODELS / name for name in inputs] + [
        ROOT / 'packages/zig/transit-sql-results/src/Progress.zig',
        ROOT / 'contracts/SQL_RESULTS_V1.md', ROOT / 'contracts/SQL_SESSION_V1.md', ROOT / 'flake.lock']
    evidence = {'status': 'inconclusive',
                'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)),
                'source_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in source_paths},
                'binary_sha256': hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                'tlc': str(Path(shutil.which('tlc')).resolve()),
                'bounds': {'rows': args.rows, 'readers': 1, 'server_batches': 1, 'in_flight_responses': 1},
                'guards': [], 'fairness': 'none; safety only',
                'limits': 'Complete finite Progress edge correspondence from representative paths. Session delivery is an abstract protocol model, not Zig adapter/server replay. No arbitrary histories, u64 overflow proof, allocator, codec, network, durable settlement or transaction proof.'}
    started = time.monotonic()
    try:
        runner_controls()
        evidence['runner_controls'] = 'passed'
        template = (MODELS / 'StatementResult.cfg').read_text().replace('MaxRows = 2', f'MaxRows = {args.rows}')
        generated, distinct = complete(*tlc('StatementResult', template, 'progress', destination, args.seconds, dump=True))
        nodes, edges, paths, successors, initial = graph(destination / 'progress/states.dot')
        if len(nodes) != distinct or len(edges) != generated - 1:
            raise AssertionError('incomplete exported Progress graph')
        equal(run_traces(binary, [[]], destination, args.seconds)[0], nodes[initial][0], [], destination)
        for start in range(0, len(edges), 4096):
            batch = edges[start:start + 4096]
            traces = [paths[before] + [nodes[after][1]] for before, after in batch]
            actual = run_traces(binary, traces, destination, args.seconds)
            for events, (_, after), value in zip(traces, batch, actual):
                equal(value, nodes[after][0], events, destination)
        evidence['progress'] = {'distinct_states': distinct, 'generated_states': generated, 'replayed_edges': len(edges)}
        for guard, invariant in GUARDS.items():
            code, output = tlc('StatementResult', template.replace(f'{guard} = TRUE', f'{guard} = FALSE'), guard, destination, args.seconds)
            events, label = counterexample(code, output, invariant)
            current = initial
            for step in events:
                current = successors[current][json.dumps(step, sort_keys=True)]
            actual = run_traces(binary, [events], destination, args.seconds)[0]
            equal(actual, nodes[current][0], events, destination)
            bad = projection(label)
            if actual == bad:
                raise AssertionError('Progress repeated the model violation')
            (destination / guard / 'counterexample.json').write_text(json.dumps(
                {'events': events, 'invariant': invariant, 'model': bad, 'implementation': actual}, indent=2) + '\n')
            evidence['guards'].append({'guard': guard, 'invariant': invariant, 'status': 'detected-and-replayed'})
        session = (MODELS / 'StatementResultSession.cfg').read_text().replace('MaxRows = 2', f'MaxRows = {args.rows}')
        generated, distinct = complete(*tlc('StatementResultSession', session, 'session', destination, args.seconds))
        evidence['session'] = {'distinct_states': distinct, 'generated_states': generated, 'implementation_replay': False}
        for guard, invariant in SESSION_GUARDS.items():
            code, output = tlc('StatementResultSession', session.replace(f'{guard} = TRUE', f'{guard} = FALSE'), guard, destination, args.seconds)
            events, _ = counterexample(code, output, invariant)
            (destination / guard / 'counterexample.json').write_text(json.dumps(
                {'events': events, 'invariant': invariant, 'implementation_replay': False}, indent=2) + '\n')
            evidence['guards'].append({'guard': guard, 'invariant': invariant, 'status': 'detected-model-only'})
        evidence['status'] = 'passed'
        print(f'Statement result model: {evidence["progress"]["distinct_states"]} progress states, '
              f'{len(edges)} edges replayed; {distinct} session states; five replayed and two model-only guard controls.')
    except BaseException as failure:
        evidence['failure'] = str(failure)
        raise
    finally:
        evidence['seconds'] = round(time.monotonic() - started, 3)
        (destination / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
        print(f'Evidence: {destination}')


if __name__ == '__main__':
    main()
