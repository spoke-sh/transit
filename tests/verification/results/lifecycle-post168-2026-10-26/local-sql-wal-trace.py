import hashlib,json,sys,time
from pathlib import Path
source=Path('/var/tmp/transit-ci-uoql38ci/src');sys.path.insert(0,str(source/'tests'))
import server_sql_local as proof
base=Path('/var/tmp/transit-lifecycle-local-sql-wal-trace');capture=Path(str(base)+'-stderr');capture.mkdir(exist_ok=True)
bundle=source/'.cache/transit-sql-local/bin'
artifacts=[bundle/name for name in ('transit','transit-node','transit-query-host','transit-board','transit-sql-gateway')]
r={'revision':'0582556e31766f91050ca6796942ccced9ae52cf','started':time.time(),'complete':False,'method':'Run the full local-authentication schedule with a node rebuilt with diagnostic-only WAL I/O failure labels; the other installed binary bytes are unchanged. Explicit native/gateway exec wrappers retain stderr outside successful-fixture cleanup. This changes configured artifact paths and is a diagnostic, not installed-adjacency qualification. No SQL replay or deadline change.','artifacts':{p.name:{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in artifacts},'captures':[]}
original=proof.freeze

def freeze(fixture):
 original(fixture)
 for role in ['node','sql_gateway']:
  executable=fixture.config['executables'][role];wrapper=fixture.root/(role+'-diagnostic');log=capture/(fixture.root.name+'-'+role+'.stderr')
  code='#!'+sys.executable+'\nimport os,sys\nfd=os.open('+repr(str(log))+',os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600)\nos.dup2(fd,2)\nos.close(fd)\nos.execv('+repr(executable)+',['+repr(executable)+',*sys.argv[1:]])\n'
  wrapper.write_text(code);wrapper.chmod(0o700);fixture.config['executables'][role]=str(wrapper);r['captures'].append(str(log))
 r.setdefault('installations',[]).append(str(fixture.root));base.with_suffix('.json').write_text(json.dumps(r,indent=2)+'\n')
proof.freeze=freeze
try:
 proof.run(*map(str,artifacts));proof.bootstrap_fault(*map(str,artifacts));r['complete']=True
except BaseException as e:r['failure']=repr(e);raise
finally:
 r['finished']=time.time();r['capture_hashes']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in capture.glob('*.stderr')};base.with_suffix('.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k] for k in ['complete','failure','started','finished'] if k in r}),flush=True)
