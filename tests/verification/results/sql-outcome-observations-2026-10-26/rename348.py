import ctypes,json,subprocess,sys,time,urllib.request
from pathlib import Path
sys.path.insert(0,'tests')
from server import Fixture
assert ctypes.CDLL(None).prctl(36,1,0,0,0)==0
root=Path('/var/tmp/transit-server-proof-h1s8woyj')
f=Fixture.__new__(Fixture)
f.root=root;f.cli=str(root/'transit');f.path=root/'transit.yaml';f.config=json.loads(f.path.read_text())
f.no_ui=True;f.process=None;f.logs=[p.open('rb') for p in sorted(root.glob('manager-*.stderr'))];f.activation=None;f.markers=set();f.reserved_ports=set()
f.http=urllib.request.build_opener(urllib.request.ProxyHandler({}));f.url='http://127.0.0.1:'+str(f.config['ports']['gateway'])
record=dict(installation=str(root),source='0a7fcbb83',started=time.time(),complete=False,actions=['restart same retained installation','public operation inventory and read-only Table names; no SQL mutation resubmission'])
destination=Path('/var/tmp/transit-lifecycle-rename-outcome-control.json')
destination.write_text(json.dumps(record,indent=2)+'\n')
try:
    f.start();f.ready(timeout=300)
    record['operations']=f.sql_operations()
    record['tables']=f.console('SHOW TABLES;\n',request_timeout_ms=120000,timeout=180)
    record['complete']=True
finally:
    f.cleanup()
    record['finished']=time.time();destination.write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record),flush=True)
