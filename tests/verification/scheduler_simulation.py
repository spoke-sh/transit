"""Shared Session/courier schedules with independent mailbox and provenance checks."""
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

ROOT=Path(__file__).resolve().parents[2]
CORPUS=Path(__file__).parent/'scheduler-simulation'


def generated(seed, steps):
    state=seed or 1
    def draw(n):
        nonlocal state
        state ^= (state << 13) & ((1 << 64)-1)
        state ^= state >> 7
        state ^= (state << 17) & ((1 << 64)-1)
        return state % n
    actions=[dict(kind='send',source=source,value=source*1000+i) for source in (0,1) for i in range(4)]
    for _ in range(steps):
        actor=draw(5)
        if actor<2:
            action=dict(kind='worker',source=actor)
        elif actor==2:
            action=dict(kind='courier')
        elif actor==3:
            action=dict(kind='crash_worker',source=draw(2))
        else:
            action=dict(kind=('restart','crash_courier')[draw(2)])
        if actor<3:
            action.update(fault=('none','before_query','after_query','before_submit','after_submit')[draw(5)],expected_error='transport')
        actions.append(action)
    # A finite fair suffix: each input needs prepare+submit; eight inputs plus
    # two possibly uncertain requests fit comfortably within twenty rounds.
    for _ in range(20):
        actions += [dict(kind='worker',source=0),dict(kind='worker',source=1),dict(kind='courier')]
    actions += [dict(kind='assert_drained'),dict(kind='checkpoint'),dict(kind='trim'),dict(kind='restart'),dict(kind='assert_drained')]
    return dict(version=1,profile='scheduler',seed=seed,actions=actions)


def compare(trace, lines):
    if len(lines)!=len(trace['actions']):
        return dict(kind='incomplete')
    inputs=[[],[]]
    generations=[1,1]
    permissions=[255]*4
    previous=None
    accepted={}
    for index,(action,line) in enumerate(zip(trace['actions'],lines)):
        def fail(reason):
            return dict(kind='invariant',index=index,reason=reason,action=action,actual=line)
        if line.get('index')!=index:
            return dict(kind='incomplete',index=index)
        expected=action.get('expected_error')
        failure=line['failure']
        if expected=='transport':
            if failure not in (None,'AuthorityUnavailable'):
                return fail('unexpected transport outcome')
        elif expected!=failure:
            return fail('unexpected operation outcome')
        if action.get('expected_rejection') and line['rejection']!=action['expected_rejection']:
            return fail('wrong protocol rejection')
        if action.get('require_fault') and not line['fault_fired']:
            return fail('requested fault did not execute')
        s=line['state']
        kind,source=action['kind'],action.get('source',0)
        if kind=='send' and failure is None:
            inputs[source].append(action.get('value',1))
        if kind=='own' and failure is None:
            generations[source]+=1
        if kind=='policy' and failure is None:
            permissions[action.get('principal',1)]=action.get('permissions',255)
        if s['permissions']!=permissions:
            return fail('current policy differs')
        action_source=source
        for source in (0,1):
            process=s['processes'][source]
            consumed=process['consumed']
            if process['admitted']!=len(inputs[source]) or not 0<=consumed<=len(inputs[source]):
                return fail('accepted input was lost or invented')
            if process['generation']!=generations[source]:
                return fail('ownership generation differs')
            expected_values=[] if trace.get('finite') and source==0 else inputs[source][:consumed]
            outputs=[o for o in s['outputs'] if o['source']==source+4]
            if [o['value'] for o in outputs]!=expected_values:
                return fail('input progress and original outputs disagree')
            if any(o['destination']!=6 for o in outputs):
                return fail('original destination changed')
            if previous and not previous['state']['processes'][source]['consumed']<=consumed<=previous['state']['processes'][source]['consumed']+1:
                return fail('input progress skipped or moved backwards')
            if process['lifecycle']!='running' and consumed+process['cancelled']!=process['admitted']:
                return fail('retirement lost accepted input accounting')
        source=action_source
        outputs=s['outputs']
        if [o['id'] for o in outputs]!=list(range(1,len(outputs)+1)):
            return fail('duplicate or missing output identity')
        delivered=sorted((o for o in outputs if o['phase']=='delivered'),key=lambda o:o['resolved_at'])
        expected_received=[dict(position=o['resolved_at'],ordinal=i+1,value=o['value'],source=o['source'],turn=o['turn'],output=o['id']) for i,o in enumerate(delivered)]
        if s['received']!=expected_received or s['processes'][2]['admitted']!=len(expected_received):
            return fail('destination admission or provenance differs')
        if kind=='assert_drained' and failure is None:
            if any(p['lifecycle']=='running' and p['consumed']!=p['admitted'] for p in s['processes'][:2]) or any(o['phase']=='pending' for o in outputs):
                return fail('eligible workload did not drain')
        if failure in ('AccessDenied','Rejected','StaleActivation','ProcessExpired','ProcessTerminated','RetiredProcess','ClockRollback','UntrustedTime') and s['position']!=line['before']:
            return fail('rejected operation changed authority')
        submitted=line['submitted']
        # A first submission may create pending bytes and lose its reply in the
        # same step. Comparing only against the previous step misses this case.
        if submitted and failure=='AuthorityUnavailable':
            actor=2 if kind=='courier' else source
            if line['pending'][actor]!=submitted['digest']:
                return fail('uncertain submission did not retain its exact identity')
        if submitted and s['sequences'][submitted['principal']]==submitted['sequence']:
            identity=(submitted['principal'],submitted['sequence'])
            if identity in accepted and accepted[identity]!=submitted['digest']:
                return fail('accepted signed identity changed content')
            accepted[identity]=submitted['digest']
        if previous:
            for actor in range(3):
                before=previous['pending'][actor]
                if before is None:
                    continue
                active=(kind=='worker' and source==actor) or (kind=='courier' and actor==2)
                reset=(kind in ('crash_worker','adopt') and source==actor) or (kind=='crash_courier' and actor==2)
                if not reset and (not active or failure is not None) and line['pending'][actor]!=before:
                    return fail('uncertain pending operation changed or disappeared')
            for old,new in zip(previous['state']['outputs'],outputs):
                if {k:v for k,v in old.items() if k not in ('phase','resolved_at')}!={k:v for k,v in new.items() if k not in ('phase','resolved_at')}:
                    return fail('committed output was rewritten')
                if old['phase']!='pending' and old!=new:
                    return fail('terminal output reopened')
        previous=line
    return None


def run(binary,trace,directory):
    path=directory/'trace.json';path.write_text(json.dumps(trace)+'\n')
    try:
        result=subprocess.run([str(binary),str(path)],capture_output=True,text=True,timeout=90)
    except subprocess.TimeoutExpired:
        return dict(kind='timeout'),[]
    if result.returncode:
        return dict(kind='driver',stderr=result.stderr[-8192:],exit=result.returncode),[]
    try:
        lines=[json.loads(line) for line in result.stdout.splitlines()]
        return compare(trace,lines),lines
    except (ValueError,KeyError,AttributeError,TypeError) as error:
        return dict(kind='invalid_output',reason=str(error)),[]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary',type=Path)
    parser.add_argument('--seeds',type=int,default=4)
    parser.add_argument('--steps',type=int,default=48)
    parser.add_argument('--trace',type=Path)
    args=parser.parse_args()
    if not 1<=args.seeds<=64 or not 1<=args.steps<=256:
        parser.error('use 1..64 seeds and 1..256 steps')
    traces=[json.loads(args.trace.read_text())] if args.trace else [json.loads(p.read_text()) for p in sorted(CORPUS.glob('*.json'))]+[generated(seed,args.steps) for seed in range(1,args.seeds+1)]
    evidence=ROOT/'.cache/verification/scheduler-simulation';evidence.mkdir(parents=True,exist_ok=True)
    identity=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT)),zig=subprocess.check_output(['zig','version'],text=True).strip(),binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),oracle_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),generator='xorshift64-scheduler-v1',configuration=dict(seeds=args.seeds,steps=args.steps,trace=str(args.trace) if args.trace else None))
    report_path=evidence.with_suffix('.json');report_path.write_text(json.dumps(identity|dict(completed=False),indent=2)+'\n')
    started=time.monotonic();events=0;faults=Counter();hashes=[]
    with tempfile.TemporaryDirectory(prefix='transit-scheduler-simulation-') as directory:
        directory=Path(directory)
        for trace in traces:
            failure,lines=run(args.binary,trace,directory)
            if failure:
                (evidence/'failure.json').write_text(json.dumps(trace,indent=2)+'\n')
                (evidence/'failure-evidence.json').write_text(json.dumps(dict(identity=identity,failure=failure),indent=2)+'\n')
                if failure['kind']=='invariant':
                    def fails(actions):
                        result,_=run(args.binary,dict(trace,actions=actions),directory)
                        return result is not None and result['kind']=='invariant'
                    (evidence/'minimized.json').write_text(json.dumps(dict(trace,actions=minimize(trace['actions'],fails)),indent=2)+'\n')
                raise SystemExit(f'Scheduler simulation failed ({failure["kind"]}); evidence: {evidence}')
            error,replay=run(args.binary,trace,directory)
            if error or replay!=lines:
                (evidence/'failure.json').write_text(json.dumps(trace,indent=2)+'\n')
                raise RuntimeError('scheduler replay differs')
            events+=len(lines);faults.update(action.get('fault','none') for action,line in zip(trace['actions'],lines) if line['fault_fired'])
            hashes.append(hashlib.sha256(json.dumps(trace,sort_keys=True).encode()).hexdigest())
        control=generated(1,1);failure,lines=run(args.binary,control,directory)
        if failure: raise RuntimeError('negative-control baseline failed')
        for key in ('destination','value'):
            changed=copy.deepcopy(lines)
            index=next(i for i,line in enumerate(changed) if line['state']['outputs'])
            changed[index]['state']['outputs'][0][key]=-1
            if compare(control,changed) is None: raise RuntimeError(f'{key} corruption survived')
        if compare(control,lines[:-1])['kind']!='incomplete': raise RuntimeError('incomplete trace passed')
    report=identity|dict(completed=True,traces=len(traces),events=events,executions=2*len(traces)+1,faults=dict(faults),trace_sha256=hashes,negative_controls=['destination','value','incomplete'],elapsed_seconds=round(time.monotonic()-started,3))
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print(f'Scheduler simulation: {len(traces)} traces, {events} events, identical replay; {report["elapsed_seconds"]}s')


if __name__=='__main__': main()
