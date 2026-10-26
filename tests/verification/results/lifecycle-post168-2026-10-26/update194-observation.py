import ctypes, hashlib, json, sys, time, urllib.request
from pathlib import Path
import yaml
source=Path('/var/tmp/transit-ci-uoql38ci/src')
sys.path.insert(0,str(source/'tests'))
from server import Fixture
from server_sql import call, wait_status
assert ctypes.CDLL(None).prctl(36,1,0,0,0)==0
root=Path('/var/tmp/transit-server-proof-zgixyqrd')
bundle=source/'.cache/transit-sql-local/bin'
f=Fixture.__new__(Fixture);f.root=root;f.cli=str(bundle/'transit');f.path=root/'transit.yaml';f.config=yaml.safe_load(f.path.read_text());f.no_ui=True;f.process=None;f.logs=[p.open('rb') for p in sorted(root.glob('manager-*.stderr'))];f.activation=None;f.markers=set();f.reserved_ports=set();f.http=urllib.request.build_opener(urllib.request.ProxyHandler({}));f.url='http://127.0.0.1:'+str(f.config['ports']['gateway'])
r={'revision':'0582556e31766f91050ca6796942ccced9ae52cf','installation':str(root),'original_operation':194,'started':time.time(),'complete':False,'actions':['restart same retained installation','inspect original owner-account operation194 with public signed status control','do not resubmit SQL'],'artifacts':{name:{'path':str(bundle/name),'sha256':hashlib.sha256((bundle/name).read_bytes()).hexdigest()} for name in ('transit','transit-node','transit-query-host','transit-board','transit-sql-gateway')}}
p=Path('/var/tmp/transit-lifecycle-local-update-observation.json');p.write_text(json.dumps(r,indent=2)+'\n')
try:
 f.start();f.ready(timeout=300)
 wait_status(f,lambda s:s['service']['state']=='accepting' and all(a['initialized'] for a in s['accounts']))
 r['status']=json.loads(call([bundle/'transit-sql-gateway','control',f.installation/'sql/accounts/owner/control.json','status','194'],timeout=120,retry_observation=True))
 r['complete']=True
except BaseException as e:r['failure']=repr(e);raise
finally:
 f.cleanup();r['finished']=time.time();p.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k] for k in ['complete','status','failure','started','finished'] if k in r}),flush=True)
