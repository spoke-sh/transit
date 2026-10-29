"""Bounded Linux process snapshots outside statement timing; never read argv."""
from pathlib import Path
import re
import time

from harness.processes import children


def start_ticks(stat):
    # comm may contain whitespace and parentheses; field 22 follows its final ).
    return int(stat[stat.rindex(')') + 2:].split()[19])


def fields(text, required):
    result = {}
    for line in text.splitlines():
        name, separator, value = line.partition(':')
        if separator and name in required:
            unit = required[name]
            match = re.fullmatch(r'\s*(\d+)' + (r'\s+kB' if unit else '') + r'\s*', value)
            if not match or name in result:
                raise ValueError(f'invalid resource field: {name}')
            result[name] = int(match[1]) * (1024 if unit else 1)
    if result.keys() != required.keys():
        raise ValueError(f'missing resource fields: {sorted(required.keys() - result.keys())}')
    return result


def process(pid, role, *, proc=Path('/proc')):
    root = proc / str(pid)
    before = start_ticks((root / 'stat').read_text())
    status = fields((root / 'status').read_text(),
                    dict(Threads=False, VmRSS=True, VmHWM=True, VmSize=True))
    memory = fields((root / 'smaps_rollup').read_text(), dict(Pss=True))
    if start_ticks((root / 'stat').read_text()) != before:
        raise ValueError(f'process identity changed during resource sample: {pid}')
    return dict(pid=pid, role=role, start_ticks=before, threads=status['Threads'],
                rss_bytes=status['VmRSS'], pss_bytes=memory['Pss'],
                virtual_bytes=status['VmSize'], lifetime_rss_high_water_bytes=status['VmHWM'])


def tree(roots, *, discover=children, limit=128):
    pending = list(roots)
    found = set()
    while pending:
        pid = pending.pop()
        if pid in found:
            continue
        found.add(pid)
        if len(found) > limit:
            raise ValueError('resource process count exceeds snapshot bound')
        pending.extend(discover(pid) - found)
    return found


def snapshot(supervisor, client):
    roots = {supervisor: 'installation_supervisor', client: 'console'}
    started = time.monotonic_ns()
    pids = tree(roots)
    samples = [process(pid, roots.get(pid, 'installation_child')) for pid in sorted(pids)]
    # A changing process set cannot establish a complete installation snapshot.
    if tree(roots) != pids:
        raise ValueError('process tree changed during resource sample')
    return dict(method='procfs sequential; outside timed calls; non-atomic',
                duration_ns=time.monotonic_ns() - started, processes=samples,
                process_count=len(samples), threads=sum(p['threads'] for p in samples),
                rss_bytes=sum(p['rss_bytes'] for p in samples),
                pss_bytes=sum(p['pss_bytes'] for p in samples))
