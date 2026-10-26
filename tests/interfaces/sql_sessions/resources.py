"""Observe direct children and WAL file capacity in one owned Linux proof fixture.

Usage: python3 tests/interfaces/sql_sessions/resources.py PID FIXTURE OUTPUT.json
PID is the live integration Python process, not the SQL service. This read-only
observer ends with that process and does not manage or stop fixture processes.
"""
import json, sys, time
from pathlib import Path
owner=int(sys.argv[1]); root=Path(sys.argv[2]); output=Path(sys.argv[3])
start=time.monotonic(); samples=0; peak_rss=peak_wal=peak_gateway=0
while Path(f'/proc/{owner}').exists():
    children=set()
    try:
        for task in Path(f'/proc/{owner}/task').iterdir():
            try: children.update(task.joinpath('children').read_text().split())
            except FileNotFoundError: pass
    except FileNotFoundError: break
    rss=0
    for child in children:
        process=Path('/proc')/child
        try:
            fields=dict(line.split(':',1) for line in process.joinpath('status').read_text().splitlines())
            rss+=int(fields.get('VmRSS','0 kB').split()[0])
            executable=process.joinpath('cmdline').read_bytes().split(b'\0')[0]
            if executable.endswith(b'/transit-sql-gateway'):
                peak_gateway=max(peak_gateway,int(fields.get('VmHWM','0 kB').split()[0]))
        except (FileNotFoundError,ProcessLookupError,PermissionError): pass
    peak_rss=max(peak_rss,rss)
    try: peak_wal=max(peak_wal,sum(p.stat().st_size for p in root.joinpath('wal').rglob('*') if p.is_file()))
    except FileNotFoundError: pass
    samples+=1
    time.sleep(.25)
output.write_text(json.dumps(dict(profile='native_sql_resource_observation', samples=samples, elapsed_seconds=round(time.monotonic()-start,3), direct_children_peak_sampled_rss_kib=peak_rss, sql_service_peak_hwm_kib=peak_gateway, wal_peak_file_bytes=peak_wal, limits='Sampling starts during provisioning. Direct child RSS sums node/store/SQL/source/CLI processes; subprocess descendants and cold-store bytes excluded. WAL file sizes include allocated segment capacity and do not isolate operation ledger bytes. SQL HWM is the largest kernel high-water mark observed across service incarnations. Process SIGKILL only; not power loss, isolated load, baseline comparison or throughput qualification.'),indent=2)+'\n')
