import ctypes, hashlib, json, sys, time, urllib.request
from pathlib import Path
source=Path('/var/tmp/transit-ci-v8yj1aid/src');sys.path.insert(0,str(source/'tests'))
from server import Fixture
from server_sql import call, wait_status
assert ctypes.CDLL(None).prctl(36,1,0,0,0)==0
root=Path('/var/tmp/transit-server-proof-g6tgbw00');gateway=root/'bin/transit-sql-gateway'
f=Fixture.__new__(Fixture);f.root=root;f.cli=str(root/'transit');f.path=root/'transit.yaml';f.config=json.loads(f.path.read_text());f.no_ui=True;f.process=None;f.logs=[p.open('rb') for p in sorted(root.glob('manager-*.stderr'))];f.activation=None;f.markers=set();f.reserved_ports=set();f.http=urllib.request.build_opener(urllib.request.ProxyHandler({}));f.url='http://127.0.0.1:'+str(f.config['ports']['gateway'])
r={'revision':'14c7175e3161e6ffec1c8a17c0b29b45cf64e4ee','installation':str(root),'started':time.time(),'complete':False,'actions':['restart original retained installation with unchanged binaries/configuration','list original local-account operations through signed control','inspect their original status; no SQL resubmission'],'artifacts':{p.name:{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [root/'transit',*(root/'bin').iterdir()]}}
p=Path('/var/tmp/transit-lifecycle-lifetime-insert-observation.json');p.write_text(json.dumps(r,indent=2)+'\n')
try:
 f.start();f.ready(timeout=300);wait_status(f,lambda s:s['service']['state']=='accepting' and all(a['initialized'] for a in s['accounts']))
 control=f.installation/'sql/accounts/local/control.json'
 r['operations']=json.loads(call([gateway,'control',control,'list'],timeout=120,retry_observation=True));assert r['operations']['next'] is None,r['operations']
 r['statuses']=[json.loads(call([gateway,'control',control,'status',str(e['operation'])],timeout=120,retry_observation=True)) for e in r['operations']['entries']]
 r['complete']=True
except BaseException as e:r['failure']=repr(e);raise
finally:
 f.cleanup();r['finished']=time.time();p.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k] for k in ['complete','operations','statuses','failure','started','finished'] if k in r}),flush=True)
