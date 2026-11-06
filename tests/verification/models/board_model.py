"""Finite Board models with complete TypeScript edge replay and negative controls."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
from runner.paths import ROOT
from verification.models.tlc_support import complete, record

MODELS = Path(__file__).resolve().parent
DEST = ROOT / '.cache/verification/board-model'
FIELDS = {
    'Observation': {'tag', 'generation', 'failures', 'value', 'failure'},
    'Statement': {'reader', 'generation', 'phase', 'visible', 'available', 'disclosed', 'disposed', 'failure'},
    'Scheduler': {'read', 'control'},
    'Plane': {'width', 'left', 'right', 'last', 'tab', 'detail', 'leftOpen', 'rightOpen', 'takeover'},
    'Workbook': {
        'active', 'live', 'composing', 'phase', 'queued', 'generation', 'watermark',
        'depUsesSource', 'issue', 'sourceState', 'depState', 'sourceOut', 'depOut', 'failure',
    },
}
GUARDS = [('Observation', 'CheckGeneration', 'NoStaleReply'),
          ('Observation', 'CheckDenial', 'ClearDenied'),
          ('Statement', 'CheckRun', 'NoDuplicateRun'),
          ('Plane', 'CheckConstrained', 'SingleSideWhenConstrained'),
          ('Plane', 'CheckNarrowFold', 'NarrowFoldReturnsToWork'),
          ('Workbook', 'CheckLineage', 'CurrentImpliesComplete'),
          ('Workbook', 'CheckComposition', 'CompositionBlocksEval'),
          ('Workbook', 'CheckDenial', 'ClearDeniedAndHidden')]


def projection(mode, label):
    if mode == 'Observation':
        return {'a': record(label, 'a', FIELDS[mode]), 'b': record(label, 'b', FIELDS[mode]),
                'effects': record(label, 'effects', {'cancel', 'read', 'delay'})}
    value = {'state': record(label, 's', FIELDS[mode])}
    if mode == 'Statement':
        value['effects'] = record(label, 'effects', {'cancel', 'close', 'action'})
    elif mode == 'Workbook':
        value['effects'] = record(label, 'effects', {'action', 'cancel'})
    return value


def graph(mode, path):
    nodes, edges, initial = {}, [], []
    for line in path.read_text().splitlines():
        edge = re.match(r'(-?\d+) -> (-?\d+) \[label="Step"', line)
        node = re.match(r'(-?\d+) \[label=("(?:\\.|[^"\\])*")', line)
        if edge:
            edges.append([edge[1], edge[2]])
        elif node:
            label = json.loads(node[2])
            last = re.search(r'/\\ last = "(\w+)"', label)
            if not last or node[1] in nodes:
                raise ValueError('missing event or duplicate node')
            nodes[node[1]] = {'expected': projection(mode, label), 'event': last[1]}
            if last[1] == 'Init':
                initial.append(node[1])
        elif re.match(r'-?\d+', line):
            raise ValueError(f'unmapped graph record: {line[:100]}')
    if len(initial) != 1 or not edges:
        raise ValueError('incomplete graph')
    return {'mode': mode, 'nodes': nodes, 'edges': edges, 'initial': initial[0]}


def tlc(mode, config, label, dump=False):
    args = ['tlc', '-workers', '1', '-seed', '1', '-fp', '0', '-metadir',
            str(DEST / (label + '-states')), '-config', str(config)]
    if dump:
        args += ['-dump', 'dot,actionlabels', str(DEST / (label + '.dot'))]
    args += ['Board' + mode + '.tla']
    run = subprocess.run(args, cwd=DEST, capture_output=True, text=True,
                         env=os.environ | {'JAVA_TOOL_OPTIONS': '-Xmx512m'}, timeout=120)
    output = run.stdout + run.stderr
    (DEST / (label + '.log')).write_text(output)
    return run.returncode, output


def replay(artifact, mutation=None):
    env = os.environ | {'BOARD_MODEL_ARTIFACT': str(artifact)}
    if mutation:
        env['BOARD_MODEL_MUTATION'] = str(mutation)
    result = subprocess.run(['vp', 'test', 'run', '--config',
        'tests/verification/models/board-replay.config.ts'], cwd=ROOT, env=env,
        capture_output=True, text=True, timeout=120)
    label = mutation.stem if mutation else 'replay'
    output = result.stdout + result.stderr
    (DEST / (label + '.log')).write_text(output)
    if mutation:
        if result.returncode == 0 or 'BOARD_MODEL_DIVERGENCE' not in output:
            raise AssertionError(f'implementation mutation not detected by replay: {label}\n{output[-2500:]}')
    elif result.returncode:
        raise AssertionError(f'TypeScript replay failed:\n{output[-4000:]}')


def main():
    if not shutil.which('tlc'):
        raise SystemExit('TLC missing: use the pinned test::board-model task')
    DEST.mkdir(parents=True, exist_ok=True)
    evidence = {'status': 'inconclusive', 'revision': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
        'models': [], 'controls': [], 'started': time.time(),
        'tools': {name: str(Path(shutil.which(name)).resolve()) for name in ('tlc', 'vp')},
        'sources': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in [*MODELS.glob('Board*.*'), MODELS / 'board_model.py',
                         MODELS / 'board-replay.config.ts', MODELS / 'board-replay.test.ts',
                         *[ROOT / f'apps/transit-board-web/src/{name}.ts' for name in
                           ('observation', 'observation-owner', 'statement-state', 'statement-owner',
                            'request-scheduler', 'plane-state', 'workbook-state')]]},
        'scope': 'Observation, Statement, Scheduler, D5 Plane, and D5 Reactive Workbook models. Safety only; no arbitrary scheduling, fairness, server authority or latency proof.'}
    try:
        graphs, controls = [], []
        for mode in ('Observation', 'Statement', 'Scheduler', 'Plane', 'Workbook'):
            for suffix in ('tla', 'cfg'):
                shutil.copyfile(MODELS / f'Board{mode}.{suffix}', DEST / f'Board{mode}.{suffix}')
            generated, distinct = complete(*tlc(mode, DEST / f'Board{mode}.cfg', mode, dump=True))
            data = graph(mode, DEST / (mode + '.dot'))
            if len(data['nodes']) != distinct or len(data['edges']) != generated - 1:
                raise AssertionError('incomplete exported state/edge counts')
            graphs.append(data)
            evidence['models'].append({'mode': mode, 'states': distinct, 'edges': len(data['edges']),
                'sha256': hashlib.sha256((MODELS / f'Board{mode}.tla').read_bytes()).hexdigest()})
        for mode, guard, invariant in GUARDS:
            control_id = f'{mode}_{guard}'
            cfg = DEST / (control_id + '.cfg')
            cfg.write_text((MODELS / f'Board{mode}.cfg').read_text().replace(guard + ' = TRUE', guard + ' = FALSE'))
            code, output = tlc(mode, cfg, control_id)
            violation = re.search(r'Error: Invariant (\w+) is violated\.', output)
            if code != 12 or not violation or violation[1] != invariant:
                raise AssertionError(f'{control_id} did not violate {invariant}: {output[-2500:]}')
            events = re.findall(r'^/\\ last = "(\w+)"$', output, re.M)
            if len(events) < 2 or events[0] != 'Init':
                raise AssertionError('missing counterexample')
            bad = projection(mode, re.split(r'\nState \d+:', output)[-1].split('\n\n', 1)[0] + '\n')
            controls.append({'mode': mode, 'events': events[1:], 'bad': bad})
            evidence['controls'].append({'guard': f'{mode}.{guard}', 'invariant': invariant})
        artifact = DEST / 'graphs.json'
        artifact.write_text(json.dumps({'graphs': graphs, 'controls': controls}, separators=(',', ':')))
        replay(artifact)
        mutations = [
            ('observation', 'Observation.CheckGeneration', 'event.generation !== state.generation', 'false'),
            ('observation', 'Observation.CheckDenial', 'value: null,\n      failure: event.failure', 'value: state.value,\n      failure: event.failure'),
            ('statement-state', 'Statement.CheckRun', '|| statementBusy(state)', '|| false'),
            ('plane-state', 'Plane.CheckConstrained', 'const constrained = state.width < 1232;', 'const constrained = false;'),
            ('plane-state', 'Plane.CheckNarrowFold', 'case "fold":\n      return state.width < 800', 'case "fold":\n      return false'),
            ('workbook-state', 'Workbook.CheckLineage', 'const invalidateLineage = true;', 'const invalidateLineage = false;'),
            ('workbook-state', 'Workbook.CheckComposition', 'const enforceComposition = true;', 'const enforceComposition = false;'),
            ('workbook-state', 'Workbook.CheckDenial', 'failure: "denied",\n          issue: "none",\n          sourceOut: "none",\n          depOut: "none",', 'failure: "denied",\n          issue: "none",\n          sourceOut: demote(state.sourceOut),\n          depOut: demote(state.depOut),'),
        ]
        for source, guard, needle, replacement in mutations:
            original = ROOT / f'apps/transit-board-web/src/{source}.ts'
            text = original.read_text()
            if text.count(needle) != 1:
                raise AssertionError(f'mutation guard moved: {source} {guard}')
            safe_guard = guard.replace('.', '_')
            changed = DEST / f'{source}-{safe_guard}.ts'
            changed.write_text(text.replace(needle, replacement))
            replay(artifact, changed)
            next(item for item in evidence['controls'] if item['guard'] == guard)['production_mutation'] = 'detected'
        evidence['status'] = 'passed'
        print('Board model: complete finite graphs replayed against TypeScript; eight model and eight implementation controls detected.')
    finally:
        evidence['elapsed_seconds'] = round(time.time() - evidence.pop('started'), 2)
        (DEST / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')

if __name__ == '__main__':
    main()
