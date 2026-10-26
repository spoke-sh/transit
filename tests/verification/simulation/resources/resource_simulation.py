"""Resource publication under numbered page/journal faults, with a logical oracle."""
import argparse
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time

from verification.simulation.transitions.transitions import ResourceModel, minimize

from runner.paths import ROOT
FAULT_ERRORS = dict(stage_before='StorageUnavailable', stage_after='LostStageAcknowledgement',
                    load='PageUnavailable', before_append='StorageUnavailable',
                    after_append='LostAcknowledgement', trim_before='StorageUnavailable',
                    trim_after='LostTrimAcknowledgement')


class Model(ResourceModel):
    def __init__(self):
        super().__init__()
        self.state['history_floor'] = 0
        self.outputs = []

    def publish(self, candidate):
        at = super().publish(candidate)
        self.views[candidate['view']]['closed_at'] = at
        self.outputs.append(dict(id=len(self.outputs) + 1, turn=at,
                                 value=candidate['value'], source=2, destination=2))
        return at

    def step(self, action):
        kind, fault = action['kind'], action.get('fault', 'none')
        value = self.state['resource_value']
        if fault in {'stage_before', 'stage_after', 'load', 'before_append'}:
            if kind == 'prepare':
                self.prepared.pop(action.get('slot', 0), None)
            result = dict(self.state, receipt=None, failure=FAULT_ERRORS[fault])
        elif kind in {'evict', 'trim', 'checkpoint', 'assert_drained'}:
            receipt = failure = None
            if kind == 'checkpoint':
                receipt = self.state['position']
                self.state.update(position=receipt + 1, history_floor=receipt)
            elif kind == 'trim':
                if self.state['history_floor'] == 0:
                    failure = 'NoCheckpointIntent'
            elif kind == 'assert_drained' and self.state['admitted'] != self.state['consumed']:
                failure = 'ProgressStalled'
            result = dict(self.state, receipt=receipt, failure=failure)
        else:
            result = super().step(dict(action, fault='none'))
            if result['receipt'] is not None:
                if kind == 'open_view':
                    self.views[result['receipt']].update(value=value, closed_at=None)
                elif kind == 'close_view':
                    for view in self.views.values():
                        if view['closed'] and view.get('closed_at') is None:
                            view['closed_at'] = result['receipt']
        if fault in {'after_append', 'trim_before', 'trim_after'}:
            result.update(receipt=None, failure=FAULT_ERRORS[fault])
        failure, receipt = result.pop('failure'), result.pop('receipt')
        result['outputs'] = copy.deepcopy(self.outputs)
        result['views'] = [dict(id=v['id'], resource_revision=v['resource_revision'],
                                closed_at=v['closed_at'], value=v['value']) for v in self.views.values()]
        return dict(state=result, failure=failure, receipt=receipt)


def finish(actions):
    model = Model()
    for action in actions:
        model.step(action)
    def add(action):
        actions.append(action)
        result = model.step(action)
        if result['failure']:
            raise ValueError(f'invalid healthy suffix: {action}: {result["failure"]}')
    add(dict(kind='clock', time=dict(unix_ms=max(10, model.state['time_floor']))))
    add(dict(kind='grant'))
    add(dict(kind='resource_grant'))
    add(dict(kind='own'))
    while model.state['consumed'] < model.state['admitted']:
        add(dict(kind='open_view', deadline_ms=model.now['unix_ms'] + 100))
        add(dict(kind='prepare', value=model.state['consumed'] + 100))
        add(dict(kind='commit'))
    add(dict(kind='assert_drained'))
    add(dict(kind='checkpoint'))
    add(dict(kind='trim'))
    add(dict(kind='evict'))
    add(dict(kind='restart'))
    add(dict(kind='assert_drained'))
    return actions


def baseline(seed):
    # Explicit values and event order are retained in every derived fault trace.
    state = seed or 1
    def draw():
        nonlocal state
        state ^= (state << 13) & ((1 << 64) - 1)
        state ^= state >> 7
        state ^= (state << 17) & ((1 << 64) - 1)
        return state % 10000
    actions = []
    for _ in range(2):
        actions += [dict(kind='send', value=draw()), dict(kind='open_view'),
                    dict(kind='prepare', value=draw()), dict(kind='commit'),
                    dict(kind='retry'), dict(kind='evict'), dict(kind='restart')]
    actions += [dict(kind='checkpoint'), dict(kind='trim'), dict(kind='restart'), dict(kind='assert_drained')]
    return dict(version=1, profile='storage', seed=seed, actions=actions)


def compare(trace, lines):
    if len(lines) != len(trace['actions']):
        return dict(kind='incomplete')
    model = Model()
    for index, (action, line) in enumerate(zip(trace['actions'], lines)):
        if line['index'] != index:
            return dict(kind='incomplete', index=index)
        if action.get('fault', 'none') != 'none' and not line['io']['fired']:
            return dict(kind='fault_not_exercised', index=index, action=action)
        expected = model.step(action)
        actual = {name: line[name] for name in expected}
        if expected != actual:
            return dict(kind='correspondence', index=index, action=action, expected=expected, actual=actual)
        if action['kind'] == 'assert_drained' and line['failure']:
            return dict(kind='progress', index=index)
    return None


def run(binary, trace, directory):
    path = directory/'trace.json'
    path.write_text(json.dumps(trace)+'\n')
    try:
        process = subprocess.run([str(binary), str(path)], text=True, capture_output=True, timeout=90)
    except subprocess.TimeoutExpired:
        return dict(kind='timeout'), []
    if process.returncode:
        return dict(kind='driver', exit=process.returncode, stderr=process.stderr[-8192:]), []
    try:
        lines = [json.loads(line) for line in process.stdout.splitlines()]
        if any(line.get('trace') != str(path) for line in lines):
            return dict(kind='incomplete'), lines
        return compare(trace, lines), lines
    except (ValueError, TypeError, KeyError, AttributeError) as error:
        return dict(kind='invalid_output', reason=str(error)), []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--seeds', type=int, default=2)
    parser.add_argument('--exhaustive', action='store_true', help='inject every observed I/O boundary')
    parser.add_argument('--trace', type=Path)
    parser.add_argument('--smoke', action='store_true', help='only saved regression traces')
    args = parser.parse_args()
    if not 1 <= args.seeds <= 64:
        parser.error('use 1..64 seeds')
    evidence = ROOT/'.cache/verification/resource-simulation'
    evidence.mkdir(parents=True, exist_ok=True)
    report_path = evidence.with_suffix('.json')
    identity = dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                    dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT)),
                    zig=subprocess.check_output(['zig','version'],text=True).strip(),
                    binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),
                    oracle_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    oracle_dependencies={name:hashlib.sha256((ROOT/'tests/verification/simulation/transitions'/name).read_bytes()).hexdigest() for name in ('transitions.py',)},
                    generator='xorshift64-resource-v1', configuration=vars(args) | dict(binary=str(args.binary),trace=str(args.trace) if args.trace else None))
    report_path.write_text(json.dumps(identity | dict(completed=False),indent=2)+'\n')
    started = time.monotonic()
    counts, hashes, total_events = Counter(), [], 0
    with tempfile.TemporaryDirectory(prefix='transit-resource-simulation-') as directory:
        directory = Path(directory)
        def check(trace):
            nonlocal total_events
            failure, lines = run(args.binary,trace,directory)
            if failure:
                (evidence/'failure.json').write_text(json.dumps(trace,indent=2)+'\n')
                (evidence/'failure-evidence.json').write_text(json.dumps(dict(identity=identity,failure=failure),indent=2)+'\n')
                if failure['kind'] == 'correspondence':
                    def fails(actions):
                        result, _ = run(args.binary,dict(trace,actions=actions),directory)
                        return result is not None and result['kind']=='correspondence'
                    reduced=dict(trace,actions=minimize(trace['actions'],fails))
                    (evidence/'minimized.json').write_text(json.dumps(reduced,indent=2)+'\n')
                raise SystemExit(f'Resource simulation failed ({failure["kind"]}); evidence: {evidence}')
            failure, replay = run(args.binary,trace,directory)
            if failure or replay!=lines:
                (evidence/'failure.json').write_text(json.dumps(trace,indent=2)+'\n')
                raise RuntimeError('resource simulation replay differs')
            total_events += len(lines)
            counts.update(action.get('fault','none') for action in trace['actions'])
            hashes.append(hashlib.sha256(json.dumps(trace,sort_keys=True).encode()).hexdigest())
            return lines
        if args.trace:
            check(json.loads(args.trace.read_text()))
        else:
            for path in sorted((Path(__file__).parent/'corpus').glob('*.json')):
                check(json.loads(path.read_text()))
            for seed in range(1, (0 if args.smoke else args.seeds)+1):
                trace=baseline(seed)
                lines=check(trace)
                for index,line in enumerate(lines):
                    kind=trace['actions'][index]['kind']
                    candidates={'stages':('stage_before','stage_after'), 'loads':('load',),
                                'appends':('before_append','after_append'), 'trims':('trim_before','trim_after')}
                    # Retries of accepted requests have no publication; observation
                    # I/O is excluded from these per-event fault coordinates.
                    for field,faults in candidates.items():
                        count=line['io'][field]
                        ordinals=range(1,count+1) if args.exhaustive else sorted({1,(count+1)//2,count}) if count else []
                        for at in ordinals:
                            for fault in faults:
                                actions=copy.deepcopy(trace['actions'][:index+1])
                                actions[-1].update(fault=fault,fault_at=at)
                                # The remaining original schedule may use an
                                # unprepared decision; explicitly heal/drain instead.
                                candidate=dict(trace,actions=finish(actions))
                                check(candidate)
        stalled=dict(version=1,profile='storage',actions=[dict(kind='send'),dict(kind='assert_drained')])
        failure, _=run(args.binary,stalled,directory)
        if failure is None or failure['kind']!='progress':
            raise RuntimeError('progress negative control failed')
        trace=baseline(1)
        failure, lines=run(args.binary,trace,directory)
        if failure:
            raise RuntimeError('checker baseline failed')
        controls=[]
        for field,value in [('resource_value',-1),('consumed',999),('outputs',[]),('views',[])]:
            corrupted=copy.deepcopy(lines)
            corrupted[3]['state'][field]=value
            if compare(trace,corrupted)['kind']!='correspondence':
                raise RuntimeError(f'checker failed to reject {field}')
            controls.append(field)
        if compare(trace,lines[:-1])['kind']!='incomplete':
            raise RuntimeError('incomplete run passed')
    report=identity | dict(completed=True,traces=len(hashes),events=total_events, executions=2*len(hashes)+2,
                           trace_sha256=hashes,faults=dict(counts),negative_controls=controls+['progress','incomplete'],
                           elapsed_seconds=round(time.monotonic()-started,3))
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print(f'Resource simulation: {len(hashes)} traces, {total_events} events, identical replay; {report["elapsed_seconds"]}s')


if __name__=='__main__':
    main()
