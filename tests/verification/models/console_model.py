"""Finite console model, exhaustive edge replay, and removed-guard controls."""
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
MODELS = Path(__file__).resolve().parent
FIELDS = {'mode', 'request', 'freshness', 'intent', 'source', 'text', 'cursor',
          'saved', 'savedCursor', 'filter', 'matched', 'failed'}
EFFECTS = {'cancel', 'clear', 'install', 'action'}
GUARDS = {'CheckFresh': 'NoStaleInsertion', 'CheckUnique': 'ProvenUnique', 'CheckBasis': 'ValidatedBasis',
          'CheckRestore': 'RestoresDraft', 'CheckOwnership': 'ExclusiveOwner',
          'CheckProtected': 'ClearsPrivate'}


def record(label, name, fields):
    match = re.search(r'/\\ ' + name + r' = \[(.*?)\](?:\n|$)', label, re.S)
    if not match:
        raise ValueError(f'missing {name} record')
    value = match[1]
    tokens = list(re.finditer(r'(\w+)\s*\|->\s*("[^"\\]*"|TRUE|FALSE|\d+)', value))
    remainder = re.sub(r'(\w+)\s*\|->\s*("[^"\\]*"|TRUE|FALSE|\d+)', '', value)
    if remainder.strip(' ,\n\t'):
        raise ValueError(f'unmapped {name} record: {value}')
    result = {m[1]: json.loads(m[2].lower() if m[2] in {'TRUE', 'FALSE'} else m[2]) for m in tokens}
    if set(result) != fields or len(tokens) != len(fields):
        raise ValueError(f'unmapped {name} fields: {result}')
    return result


def projection(label):
    return {'state': record(label, 's', FIELDS), 'effects': record(label, 'effects', EFFECTS)}


def graph(path):
    nodes, edges, initial = {}, [], []
    for line in path.read_text().splitlines():
        edge = re.match(r'(-?\d+) -> (-?\d+) \[label="Step"', line)
        node = re.match(r'(-?\d+) \[label=("(?:\\.|[^"\\])*")', line)
        if edge:
            edges.append((edge[1], edge[2]))
        elif node:
            label = json.loads(node[2])
            event = re.search(r'/\\ last = "(\w+)"', label)
            if not event:
                raise ValueError('missing event in graph')
            if node[1] in nodes:
                raise ValueError('duplicate graph node')
            nodes[node[1]] = (projection(label), event[1])
            if event[1] == 'Init':
                initial.append(node[1])
        elif re.match(r'-?\d+', line):
            raise ValueError(f'unmapped graph line: {line[:200]}')
    if len(initial) != 1 or not edges:
        raise ValueError('incomplete state graph')
    successors = {key: {} for key in nodes}
    for before, after in edges:
        event = nodes[after][1]
        if event in successors[before] and successors[before][event] != after:
            raise ValueError('non-deterministic abstract transition')
        successors[before][event] = after
    paths = {initial[0]: []}
    pending = deque(initial)
    while pending:
        before = pending.popleft()
        for event, after in successors[before].items():
            if after not in paths:
                paths[after] = paths[before] + [event]
                pending.append(after)
    if len(paths) != len(nodes):
        raise ValueError('unreachable exported state')
    return nodes, edges, paths, successors, initial[0]


def run_traces(binary, traces, destination, seconds):
    path = destination / 'replay.json'
    path.write_text(json.dumps(traces, separators=(',', ':')) + '\n')
    result = subprocess.run([binary, str(path)], cwd=ROOT, capture_output=True, text=True, timeout=seconds)
    if result.returncode:
        raise AssertionError(f'Zig replay failed: {result.stderr[-4000:]}')
    rows = [json.loads(line) for line in result.stdout.splitlines()]
    if len(rows) != len(traces):
        raise AssertionError('incomplete Zig replay')
    return rows


def verify_trace(binary, events, expected, destination, seconds):
    actual = run_traces(binary, [events], destination, seconds)[0]
    if actual != expected:
        failure = {'events': events, 'expected': expected, 'actual': actual}
        (destination / 'divergence.json').write_text(json.dumps(failure, indent=2) + '\n')
        raise AssertionError(f'editor/model divergence: {failure}')
    return actual


def tlc(config, name, destination, seconds, dump=False):
    shutil.copyfile(MODELS / 'Console.tla', destination / 'Console.tla')
    local_config = destination / config.name
    if config.resolve() != local_config.resolve():
        shutil.copyfile(config, local_config)
    command = ['tlc', '-workers', '1', '-seed', '1', '-fp', '0',
               '-metadir', str(destination / (name + '-states')), '-config', config.name]
    if dump:
        command += ['-dump', 'dot,actionlabels', str(destination / 'states.dot')]
    command.append('Console.tla')
    result = subprocess.run(command, cwd=destination, capture_output=True, text=True,
                            env=os.environ | {'JAVA_TOOL_OPTIONS': '-Xmx512m'}, timeout=seconds)
    output = result.stdout + result.stderr
    (destination / (name + '.log')).write_text(output)
    return result.returncode, output


def complete(code, output):
    counts = re.search(r'([\d,]+) states generated, ([\d,]+) distinct states found, 0 states left on queue', output)
    if code != 0 or 'Model checking completed. No error has been found.' not in output or not counts:
        raise AssertionError(f'inconclusive/failed TLC exploration: {output[-4000:]}')
    return tuple(int(value.replace(',', '')) for value in counts.groups())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary')
    parser.add_argument('--seconds', type=int, default=60)
    args = parser.parse_args()
    if shutil.which('tlc') is None:
        raise SystemExit('TLC missing: use just test::console-model with the pinned tool')
    binary = str(Path(args.binary).resolve())
    destination = ROOT / '.cache/verification/console-model'
    destination.mkdir(parents=True, exist_ok=True)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True))
    evidence = {'status': 'inconclusive', 'revision': revision, 'dirty': dirty,
                'model_sha256': hashlib.sha256((MODELS / 'Console.tla').read_bytes()).hexdigest(),
                'binary_sha256': hashlib.sha256(Path(binary).read_bytes()).hexdigest(),
                'guards': [], 'bounds': 'three draft classes; four filter classes; start/end cursor; one borrower',
                'limits': 'Finite reducer projection; shortest representative path to every state and every outgoing edge. Not arbitrary Zig traces, terminal I/O, grammar, memory lifetime, transport liveness or latency.'}
    started = time.monotonic()
    try:
        generated, distinct = complete(*tlc(MODELS / 'Console.cfg', 'safe', destination, args.seconds, dump=True))
        nodes, edges, paths, successors, initial = graph(destination / 'states.dot')
        if len(nodes) != distinct or len(edges) != generated - 1:
            raise AssertionError('incomplete exported graph')
        verify_trace(binary, [], nodes[initial][0], destination, args.seconds)
        for start in range(0, len(edges), 4096):
            batch = edges[start:start + 4096]
            traces = [paths[before] + [nodes[after][1]] for before, after in batch]
            actual = run_traces(binary, traces, destination, args.seconds)
            for events, (_, after), value in zip(traces, batch, actual):
                if value != nodes[after][0]:
                    (destination / 'divergence.json').write_text(json.dumps({'events': events,
                        'expected': nodes[after][0], 'actual': value}, indent=2) + '\n')
                    raise AssertionError(f'editor/model divergence: {events}; see divergence.json')
        evidence.update(distinct_states=distinct, replayed_edges=len(edges))
        template = (MODELS / 'Console.cfg').read_text()
        for guard, invariant in GUARDS.items():
            config = destination / f'{guard}.cfg'
            config.write_text(template.replace(f'{guard} = TRUE', f'{guard} = FALSE'))
            code, output = tlc(config, guard, destination, args.seconds)
            violation = re.search(r'Error: Invariant (\w+) is violated\.', output)
            if code != 12 or not violation or violation[1] != invariant:
                raise AssertionError(f'{guard} did not expose {invariant}: {output[-4000:]}')
            events = re.findall(r'^/\\ last = "(\w+)"$', output, re.M)
            if len(events) < 2 or events[0] != 'Init':
                raise AssertionError('missing model counterexample')
            current = initial
            for event in events[1:]:
                current = successors[current][event]  # Unknown/disabled events reject.
            actual = verify_trace(binary, events[1:], nodes[current][0], destination, args.seconds)
            chunks = re.split(r'\nState \d+:', output)
            if len(chunks) < 3:
                raise AssertionError('missing explicit model states')
            bad = projection(chunks[-1].split('\n\n', 1)[0] + '\n')
            if actual == bad:
                raise AssertionError('Zig repeated the model violation')
            (destination / f'{guard}.json').write_text(json.dumps({'events': events[1:],
                'violation': invariant, 'model': bad, 'implementation': actual}, indent=2) + '\n')
            evidence['guards'].append({'guard': guard, 'invariant': invariant, 'status': 'detected-and-replayed'})
        fair = destination / 'fair.cfg'
        fair.write_text(template.replace('SPECIFICATION Spec', 'SPECIFICATION FairSpec') + '\nPROPERTY BorrowerReleased\n')
        complete(*tlc(fair, 'fair', destination, args.seconds))
        evidence['progress'] = 'BorrowerReleased under weak fairness of response failure/timeout, cancellation join and foreground completion'
        evidence['status'] = 'passed'
        print(f'Console model: {distinct} states, {len(edges)} edges replayed against Zig; six removed guards detected and replayed; fair borrower release passed.')
    except BaseException as failure:
        evidence['failure'] = str(failure)
        raise
    finally:
        evidence['seconds'] = round(time.monotonic() - started, 3)
        (destination / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')


if __name__ == '__main__':
    main()
