"""Disk input larger than the enforced cgroup RAM/cache budget, with swap off."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
import performance.query.run as run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rows', type=int, default=10000)
    parser.add_argument('--memory-mib', type=int, default=256)
    args = parser.parse_args()
    if not 1000 <= args.rows <= 50000 or not 64 <= args.memory_mib <= 1024: parser.error('Invalid proof budget')
    memory = args.memory_mib * 1024 * 1024
    if args.rows * 60000 <= memory * 2: parser.error('Source must exceed twice the RAM/cache ceiling')
    args.binary = args.binary.resolve()
    report = dict(definition=run.DEFINITION, completed=False, status='running', samples=[],
        revision=run.git('rev-parse', 'HEAD'), dirty=bool(run.git('status', '--porcelain')),
        binary_sha256=run.digest(args.binary), lock_sha256=run.digest(run.ROOT/'flake.lock'),
        driver_sha256=run.digest(Path(__file__)), rows=args.rows, memory_max=memory,
        memory_swap_max=0, cpu=min(os.sched_getaffinity(0)))
    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    save()
    try:
        with tempfile.TemporaryDirectory(prefix='transit-fuze-large-', dir='/var/tmp') as work:
            directory = Path(work); source = directory/'input.csv'
            with source.open('wb') as out:
                out.write(b'id,payload\n')
                payload = b',' + b'x'*60000 + b'\n'
                for row in range(args.rows): out.write(str(row).encode() + payload)
                out.flush(); os.fsync(out.fileno())
            report['fixture'] = dict(bytes=source.stat().st_size, sha256=run.digest(source))
            fixture = dict(shape='large', format='csv', paths=[source], fields=[run.field('id', {'int64': {}}), run.field('payload', {'utf8': {}})])
            for mode in ('explicit', 'sampled', 'full', 'raw'):
                config = run.config(fixture, mode, args.rows, 1, False)
                path = directory/'request.json'; path.write_text(json.dumps(config))
                pages = run.condition([source], 'cold_input')
                unit = 'transit-fuze-proof-' + uuid.uuid4().hex
                command = ['systemd-run', '--user', '--wait', '--pipe', '--collect', '--unit', unit,
                    '-p', f'MemoryMax={memory}', '-p', 'MemorySwapMax=0', '-p', f'CPUAffinity={report["cpu"]}',
                    shutil.which('env'), f'TMPDIR={directory}', str(args.binary), str(path)]
                try:
                    process = subprocess.run(command, capture_output=True, text=True, timeout=600)
                except BaseException:
                    subprocess.run(['systemctl', '--user', 'stop', unit], check=False, capture_output=True)
                    raise
                sample = dict(mode=mode, config=config, input_pages=pages, command=command, exit_code=process.returncode,
                    stdout=process.stdout, stderr=process.stderr)
                report['samples'].append(sample); save()
                if process.returncode: raise RuntimeError(f'{mode} cgroup proof failed: {process.stderr}')
                records = [json.loads(line) for line in process.stdout.splitlines()]
                run.checked(records, config, 'transit')
                identity = next(r for r in records if 'source' in r)
                assert identity['digest'] == report['fixture']['sha256'] and identity['length'] == report['fixture']['bytes']
                group = records[-1]['cgroup']
                assert unit in group['path'] and int(group['memory_max']) == memory and group['memory_swap_max'] == '0'
                peak = int(group['memory_peak'])
                # Kernel charge batches can transiently cross memory.max before
                # reclaim. Record actual bytes and allow at most a 2% margin.
                assert peak <= memory * 1.02 and report['fixture']['bytes'] > peak * 2
                events = dict(line.split() for line in group['memory_events'].splitlines())
                assert int(events['oom']) == int(events['oom_kill']) == 0
                sample['records'] = records; sample['verified'] = True; save()
                print(f'{mode}: {report["fixture"]["bytes"]} input bytes under {memory} RAM/cache bytes, peak {peak}, no swap/OOM', flush=True)
        report.update(completed=True, status='passed')
    except BaseException as error:
        report.update(status='failed', error=str(error)); raise
    finally: save()


if __name__ == '__main__': main()
