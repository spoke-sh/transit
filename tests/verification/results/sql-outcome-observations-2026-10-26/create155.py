import ctypes,json,subprocess,sys,time,urllib.request
from pathlib import Path
sys.path.insert(0,'tests')
from server import Fixture
assert ctypes.CDLL(None).prctl(36,1,0,0,0)==0
root=Path('/var/tmp/transit-server-proof-blupbnop')
f=Fixture.__new__(Fixture)
f.root=root;f.cli=str(root/'transit');f.path=root/'transit.yaml';f.config=json.loads(f.path.read_text())
f.no_ui=True;f.process=None;f.logs=[p.open('rb') for p in sorted(root.glob('manager-*.stderr'))];f.activation=None;f.markers=set();f.reserved_ports=set()
f.http=urllib.request.build_opener(urllib.request.ProxyHandler({}));f.url='http://127.0.0.1:'+str(f.config['ports']['gateway'])
record=dict(installation=str(root),operation=155,account='owner',started=time.time(),complete=False)
destination=Path('/var/tmp/transit-lifecycle-sql-create155-control.json')
destination.write_text(json.dumps(record,indent=2)+'\n')
try:
    f.start();f.ready(timeout=300)
    deadline=time.monotonic()+90
    while True:
        command=['/var/tmp/transit-server-proof-blupbnop/bin/transit-sql-gateway','control',str(f.installation/'sql/accounts/owner/control.json'),'status','155']
        result=subprocess.run(command,capture_output=True,text=True,timeout=40)
        if result.returncode==0:
            outcome=json.loads(result.stdout);record['outcome']=outcome
            if outcome.get('terminal') is not None:
                record['complete']=True;break
        else:record['observation_error']=result.stderr[-2000:]
        if time.monotonic()>=deadline:break
        time.sleep(.5)
finally:
    f.cleanup()
    record['finished']=time.time();destination.write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record),flush=True)
