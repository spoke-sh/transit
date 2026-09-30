"""Seeded authority/delivery schedules against the real long-lived Zig engine."""
import argparse
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time

from transitions import minimize

ROOT = Path(__file__).resolve().parents[2]
CORPUS = Path(__file__).resolve().parent / "simulation"
GENERATOR = "xorshift64-delivery-v1"


class Model:
    """Contract projection: two producer mailboxes, one sink, eight delayed slots.

    No page tree, signature implementation, route index or production helper is
    shared with Zig. Every output must account for exactly one consumed input;
    destination admission records the original output's content and provenance.
    """
    def __init__(self):
        self.state = dict(position=9, sequences=[8, 0, 0, 0],
                          permissions=[255] * 4, outputs=[], received=[], processes=[])
        for i in range(3):
            self.state['processes'].append(dict(pid=i + 4, owner=i + 1 if i < 2 else None,
                generation=1 if i < 2 else 0, revision=0, admitted=0, consumed=0,
                cancelled=0, lifecycle='running'))
        self.inputs = [[], []]
        self.saved = {}
        self.receipts = {}

    def permission(self, command, principal):
        needed = 8 if command['kind'] == 'turn' else 128
        return bool(self.state['permissions'][principal] & needed)

    def validate(self, command, principal):
        if not self.permission(command, principal):
            return 'Forbidden'
        if command['kind'] == 'turn':
            process = self.state['processes'][command['source']]
            if process['lifecycle'] != 'running':
                return 'RetiredProcess'
            if process['owner'] != principal or process['generation'] != command['generation']:
                return 'StaleGeneration'
            if process['revision'] != command['revision']:
                return 'StaleState'
            if (process['consumed'] == process['admitted'] or
                    self.inputs[command['source']][process['consumed']]['position'] != command['input']):
                return 'InvalidInput'
            if not self.state['permissions'][principal] & 64:
                return 'Forbidden'
        else:
            outputs = self.state['outputs']
            if not 1 <= command['output'] <= len(outputs):
                return 'UnknownOutput'
            output = outputs[command['output'] - 1]
            if output['phase'] != 'pending':
                return 'OutputAlreadyResolved'
            if any(o['source'] == output['source'] and o['phase'] == 'pending'
                   for o in outputs[:command['output'] - 1]):
                return 'RouteBlocked'

    def publish(self, candidate):
        s, command = self.state, candidate['command']
        at = s['position']
        if command['kind'] == 'turn':
            process = s['processes'][command['source']]
            process.update(consumed=process['consumed'] + 1, revision=at)
            s['outputs'].append(dict(id=len(s['outputs']) + 1, source=process['pid'],
                destination=6, turn=at, value=command['value'], phase='pending', resolved_at=None))
        else:
            output = s['outputs'][command['output'] - 1]
            source = s['processes'][output['source'] - 4]
            phase = ('cancelled' if source['lifecycle'] != 'running' else
                     'denied' if not s['permissions'][3] & 4 else 'delivered')
            output.update(phase=phase, resolved_at=at)
            if phase == 'delivered':
                sink = s['processes'][2]
                sink['admitted'] += 1
                s['received'].append(dict(position=at, ordinal=sink['admitted'],
                    value=output['value'], source=output['source'], turn=output['turn'], output=output['id']))
        principal, sequence = candidate['principal'], candidate['sequence']
        s['sequences'][principal] = sequence
        self.receipts[principal, sequence] = (copy.deepcopy(command), at)
        s['position'] += 1
        return at

    def step(self, action):
        s = self.state
        kind, slot = action['kind'], action.get('slot', 0)
        source, principal = action.get('source', 0), action.get('principal', 1)
        process = s['processes'][source]
        fault = action.get('fault', 'none')
        failure = receipt = None
        if kind in {'prepare_turn', 'prepare_delivery'}:
            self.saved.pop(slot, None)
            command = None
            if kind == 'prepare_turn':
                if process['consumed'] + process['cancelled'] == process['admitted']:
                    failure = 'NoInput'
                elif process['owner'] is None:
                    failure = 'NoOwner'
                else:
                    principal = process['owner']
                    incoming = self.inputs[source][process['consumed']]
                    command = dict(kind='turn', source=source, generation=process['generation'],
                                   revision=process['revision'], input=incoming['position'], value=incoming['value'])
            else:
                principal = 3
                command = dict(kind='deliver', output=action.get('output', 1))
            if command is not None:
                failure = self.validate(command, principal)
                if failure is None:
                    self.saved[slot] = dict(command=command, principal=principal,
                        sequence=s['sequences'][principal] + 1, position=s['position'])
        elif kind in {'commit', 'retry'}:
            candidate = self.saved.get(slot)
            if candidate is None:
                failure = 'NoPreparation'
            elif kind == 'commit':
                if fault == 'before_append':
                    failure = 'StorageUnavailable'
                elif candidate['position'] != s['position']:
                    failure = 'Conflict'
                else:
                    receipt = self.publish(candidate)
                    if fault == 'after_append':
                        failure, receipt = 'LostAcknowledgement', None
            else:
                command, principal, sequence = (candidate[k] for k in ('command', 'principal', 'sequence'))
                if not self.permission(command, principal):
                    failure = 'Forbidden'
                elif sequence <= s['sequences'][principal]:
                    previous, at = self.receipts[principal, sequence]
                    if previous == command:
                        receipt = at
                    else:
                        failure = 'ConflictingRetry'
                elif sequence != s['sequences'][principal] + 1:
                    failure = 'SequenceGap'
                elif failure := self.validate(command, principal):
                    pass
                elif fault == 'before_append':
                    failure = 'StorageUnavailable'
                else:
                    receipt = self.publish(candidate)
                    if fault == 'after_append':
                        failure, receipt = 'LostAcknowledgement', None
        elif kind in {'send', 'own', 'policy', 'terminate'}:
            if kind != 'policy' and process['lifecycle'] != 'running':
                failure = 'RetiredProcess'
            elif kind == 'own' and not s['permissions'][principal] & 8:
                failure = 'Forbidden'
            else:
                receipt = s['position']
                if kind == 'send':
                    self.inputs[source].append(dict(position=receipt, value=action.get('value', 1)))
                    process['admitted'] += 1
                elif kind == 'own':
                    process.update(owner=principal, generation=process['generation'] + 1)
                elif kind == 'policy':
                    s['permissions'][principal] = {'allow': 255, 'revoke': 0, 'delivery_only': 128}[action.get('policy', 'allow')]
                else:
                    process.update(lifecycle='terminated', owner=None, cancelled=process['admitted'] - process['consumed'])
                s['sequences'][0] += 1
                s['position'] += 1
        elif kind == 'assert_drained':
            if (any(p['lifecycle'] == 'running' and p['consumed'] != p['admitted'] for p in s['processes'][:2]) or
                    any(o['phase'] == 'pending' for o in s['outputs'])):
                failure = 'ProgressStalled'
        elif kind not in {'restart', 'progress'}:
            raise ValueError(f'unmodeled action {kind}')
        return dict(failure=failure, receipt=receipt, state=copy.deepcopy(s))


def validate_trace(trace):
    if trace.get('version') != 1 or trace.get('profile') != 'delivery':
        raise ValueError('unsupported simulation trace')
    actions = trace.get('actions', [])
    if not 0 < len(actions) <= 4096:
        raise ValueError('trace must contain 1..4096 actions')
    kinds = {'send', 'prepare_turn', 'prepare_delivery', 'commit', 'retry', 'own',
             'policy', 'terminate', 'restart', 'progress', 'assert_drained'}
    for action in actions:
        if action.get('kind') not in kinds:
            raise ValueError('unknown simulation action')
        if (action.get('source', 0) not in range(2) or action.get('slot', 0) not in range(8) or
                action.get('principal', 1) not in range(1, 4)):
            raise ValueError('simulation actor/slot out of range')
        if action.get('policy', 'allow') not in {'allow', 'revoke', 'delivery_only'}:
            raise ValueError('unknown policy')
        if action.get('fault', 'none') not in {'none', 'before_append', 'after_append'}:
            raise ValueError('unknown fault')
        if action.get('fault', 'none') != 'none' and action['kind'] not in {'commit', 'retry'}:
            raise ValueError('append faults require commit or retry')


def finish(actions):
    """Append an explicit finite fair schedule, preserving retired identities.

    The phase heals worker/courier permissions, admits no fresh input, processes
    each remaining eligible input once and resolves each pending route in order.
    It checks this schedule's progress, not an automatic worker scheduler.
    """
    model = Model()
    for action in actions:
        model.step(action)
    def add(action):
        actions.append(action)
        result = model.step(action)
        if result['failure']:
            raise ValueError(f'invalid progress schedule: {action}: {result}')
    add(dict(kind='progress'))
    for principal in (1, 2, 3):
        add(dict(kind='policy', principal=principal))
    for source in (0, 1):
        process = model.state['processes'][source]
        while process['lifecycle'] == 'running' and process['consumed'] < process['admitted']:
            add(dict(kind='prepare_turn', source=source))
            add(dict(kind='commit'))
    for output in model.state['outputs']:
        if output['phase'] == 'pending':
            add(dict(kind='prepare_delivery', output=output['id']))
            add(dict(kind='commit'))
    add(dict(kind='assert_drained'))
    add(dict(kind='restart'))
    add(dict(kind='assert_drained'))
    return actions


def generated(seed, steps):
    state = seed or 1
    def draw(size):
        nonlocal state
        state ^= (state << 13) & ((1 << 64) - 1)
        state ^= state >> 7
        state ^= (state << 17) & ((1 << 64) - 1)
        return state % size
    model, actions = Model(), []
    def add(action):
        actions.append(action)
        model.step(action)
    # Both routes start with eligible work, even for short random schedules.
    for source in (0, 1):
        add(dict(kind='send', source=source, value=draw(10000)))
    choices = ('send', 'prepare_turn', 'prepare_turn', 'prepare_delivery',
               'commit', 'retry', 'own', 'policy', 'restart', 'terminate')
    for _ in range(steps):
        kind = choices[draw(len(choices))]
        action = dict(kind=kind)
        if kind in {'send', 'prepare_turn', 'own', 'terminate'}:
            action['source'] = draw(2)
        if kind == 'send':
            action['value'] = draw(10000)
        if kind in {'prepare_turn', 'prepare_delivery', 'commit', 'retry'}:
            action['slot'] = draw(8)
        if kind == 'prepare_delivery':
            action['output'] = 1 + draw(max(1, len(model.state['outputs'])))
        if kind in {'commit', 'retry'}:
            # Usually choose a real delayed request; retain empty-slot cases.
            if model.saved and draw(4):
                action['slot'] = sorted(model.saved)[draw(len(model.saved))]
            action['fault'] = ('none', 'none', 'before_append', 'after_append')[draw(4)]
        if kind == 'own':
            action['principal'] = 1 + draw(2)
        if kind == 'policy':
            action.update(principal=1 + draw(3), policy=('allow', 'allow', 'revoke', 'delivery_only')[draw(4)])
        # Retirement is irreversible. Keep most runs active long enough to
        # exercise delayed decisions and independent route progress.
        if kind == 'terminate' and draw(8):
            action = dict(kind='restart')
        add(action)
    return dict(version=1, profile='delivery', seed=seed, generator=GENERATOR, actions=finish(actions))


def compare(trace, lines):
    if len(lines) != len(trace['actions']):
        return dict(kind='incomplete', expected=len(trace['actions']), actual=len(lines))
    model, progress = Model(), False
    for index, (action, actual) in enumerate(zip(trace['actions'], lines)):
        if actual.get('index') != index:
            return dict(kind='incomplete', index=index)
        expected = model.step(action)
        observed = {name: actual.get(name) for name in expected}
        if observed != expected:
            return dict(kind='correspondence', index=index, action=action, expected=expected, actual=observed)
        progress |= action['kind'] == 'progress'
        if (progress or action['kind'] == 'assert_drained') and actual['failure']:
            return dict(kind='progress', index=index, action=action, failure=actual['failure'])
    return None


def run(binary, trace, directory):
    validate_trace(trace)
    path = directory / 'trace.json'
    path.write_text(json.dumps(trace) + '\n')
    try:
        result = subprocess.run([str(binary), str(path)], capture_output=True, text=True, timeout=90)
    except subprocess.TimeoutExpired:
        return dict(kind='timeout'), []
    if result.returncode:
        return dict(kind='driver', exit=result.returncode, stderr=result.stderr[-8192:]), []
    try:
        lines = [json.loads(line) for line in result.stdout.splitlines()]
        if any(line.get('trace') != str(path) for line in lines):
            return dict(kind='incomplete', reason='foreign trace output'), lines
        return compare(trace, lines), lines
    except (ValueError, KeyError, TypeError, AttributeError) as failure:
        return dict(kind='invalid_output', reason=str(failure)), []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--seeds', type=int, default=8)
    parser.add_argument('--steps', type=int, default=48)
    parser.add_argument('--trace', type=Path)
    args = parser.parse_args()
    if not 1 <= args.seeds <= 10000 or not 1 <= args.steps <= 512:
        parser.error('use 1..10000 seeds and 1..512 generated steps')
    traces = ([json.loads(args.trace.read_text())] if args.trace else
              [json.loads(path.read_text()) for path in sorted(CORPUS.glob('*.json'))] +
              [generated(seed, args.steps) for seed in range(1, args.seeds + 1)])
    evidence = ROOT / '.cache/verification/simulation'
    evidence.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    identity = dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
                    binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),
                    oracle_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    zig=subprocess.check_output(['zig', 'version'], text=True).strip(), generator=GENERATOR,
                    configuration=dict(seeds=args.seeds, steps=args.steps,
                                       trace=str(args.trace) if args.trace else None))
    report_path = evidence.parent / 'simulation.json'
    # A failed or interrupted new run must not leave a previous success looking
    # like the result of this invocation.
    report_path.write_text(json.dumps(dict(identity, completed=False), indent=2) + '\n')
    events, digests = 0, []
    actions_seen, outcomes_seen = Counter(), Counter()
    with tempfile.TemporaryDirectory(prefix='transit-simulation-') as directory:
        directory = Path(directory)
        for trace in traces:
            failure, lines = run(args.binary, trace, directory)
            if failure:
                artifact = dict(identity=identity, trace=trace, failure=failure)
                (evidence / 'failure.json').write_text(json.dumps(trace, indent=2) + '\n')
                (evidence / 'failure-evidence.json').write_text(json.dumps(artifact, indent=2) + '\n')
                # Incomplete/timeout/invalid-driver runs are retained as failures,
                # never minimized into evidence of a protocol property violation.
                if failure['kind'] in {'correspondence', 'progress'}:
                    def fails(actions):
                        candidate = dict(trace, actions=actions)
                        result, _ = run(args.binary, candidate, directory)
                        return result is not None and result['kind'] == failure['kind']
                    reduced = dict(trace, actions=minimize(trace['actions'], fails))
                    (evidence / 'minimized.json').write_text(json.dumps(reduced, indent=2) + '\n')
                raise SystemExit(f'Simulation failed ({failure["kind"]}); evidence: {evidence}')
            # Replay every schedule twice. Ignore only the temporary trace path;
            # observations, errors and receipt identities must be byte-stable.
            repeated, replay = run(args.binary, trace, directory)
            if repeated or replay != lines:
                (evidence / 'failure.json').write_text(json.dumps(trace, indent=2) + '\n')
                (evidence / 'failure-evidence.json').write_text(json.dumps(dict(identity=identity,
                    failure=dict(kind='reproducibility', repeated=repeated), first=lines, replay=replay), indent=2) + '\n')
                raise SystemExit(f'Non-reproducible simulation; trace: {evidence / "failure.json"}')
            events += len(trace['actions'])
            actions_seen.update(action['kind'] for action in trace['actions'])
            outcomes_seen.update(line['failure'] or 'success' for line in lines)
            digests.append(hashlib.sha256(json.dumps(trace, sort_keys=True).encode()).hexdigest())
        # Agreement with the oracle is insufficient for progress: both sides
        # can agree that work remains. Intentionally omit the scheduled turn
        # and require a failing progress result from the actual driver.
        stalled = dict(version=1, profile='delivery', actions=[dict(kind='send'),
                       dict(kind='progress'), dict(kind='assert_drained')])
        failure, lines = run(args.binary, stalled, directory)
        if failure is None or failure['kind'] != 'progress':
            raise RuntimeError(f'progress negative control did not execute: {failure}')
        if compare(stalled, lines[:-1])['kind'] != 'incomplete':
            raise RuntimeError('incomplete output passed the checker')
    report = dict(identity, traces=len(traces), events=events, executions=2 * len(traces) + 1,
                  actions=dict(actions_seen), outcomes=dict(outcomes_seen), trace_sha256=digests,
                  negative_controls=['undrained_work', 'incomplete_observation'],
                  negative_control_events=len(stalled['actions']),
                  elapsed_seconds=round(time.monotonic() - started, 3), completed=True)
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Delivery simulation: {len(traces)} traces, {events} events, identical replay; {report["elapsed_seconds"]}s')


if __name__ == '__main__':
    main()
