import hashlib,json,sys,time
from pathlib import Path
source=Path('/var/tmp/transit-ci-v8yj1aid/src');sys.path.insert(0,str(source/'tests'))
import server_sql_lifetimes as proof
base=Path('/var/tmp/transit-lifecycle-lifetimes-diagnostic');capture=Path(str(base)+'-stderr');capture.mkdir(exist_ok=True)
original_root=Path('/var/tmp/transit-server-proof-g6tgbw00')
artifacts=[original_root/'transit',*(original_root/'bin'/name for name in ('transit-node','transit-query-host','transit-board','transit-sql-gateway'))]
r={'revision':'14c7175e3161e6ffec1c8a17c0b29b45cf64e4ee','started':time.time(),'complete':False,'method':'Run the full SQL lifetime schedule with the same installed binary bytes; explicit native/gateway exec wrappers retain stderr outside the successful-fixture cleanup. This changes configured artifact paths and is a diagnostic, not installed-adjacency qualification. No SQL replay or deadline change.','artifacts':{p.name:{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in artifacts},'captures':[]}
original=proof.freeze_executables

def freeze(fixture):
 original(fixture)
 for role in ['node','sql_gateway']:
  executable=fixture.config['executables'][role];wrapper=fixture.root/(role+'-diagnostic');log=capture/(fixture.root.name+'-'+role+'.stderr')
  code='#!'+sys.executable+'\nimport os,sys\nfd=os.open('+repr(str(log))+',os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600)\nos.dup2(fd,2)\nos.close(fd)\nos.execv('+repr(executable)+',['+repr(executable)+',*sys.argv[1:]])\n'
  wrapper.write_text(code);wrapper.chmod(0o700);fixture.config['executables'][role]=str(wrapper);r['captures'].append(str(log))
 r.setdefault('installations',[]).append(str(fixture.root));base.with_suffix('.json').write_text(json.dumps(r,indent=2)+'\n')
proof.freeze_executables=freeze
try:
 proof.run(*map(str,artifacts));r['complete']=True
except BaseException as e:r['failure']=repr(e);raise
finally:
 r['finished']=time.time();r['capture_hashes']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in capture.glob('*.stderr')};base.with_suffix('.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k] for k in ['complete','failure','started','finished'] if k in r}),flush=True)
