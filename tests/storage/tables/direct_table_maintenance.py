"""Physical-disk automatic maintenance, fixed targets and retained rows."""
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import struct
import tempfile
import threading
import time

from harness.http_probe import TABLE_ACTIONS
from runner.capture import identity, provenance
from runner.paths import ROOT


class RequestMemory:
    """Finite operation labels and numeric observations; never request values."""
    fields = ('alloc_attempts', 'growing_resize_attempts', 'remap_attempts',
              'acquired_bytes', 'live_bytes', 'peak_bytes')

    def __init__(self):
        self.lock = threading.Lock()
        self.reset()

    def reset(self):
        with self.lock:
            self.operations = {}
            self.invalid = 0

    def observe(self, action, header):
        tag = action if isinstance(action, str) else next(iter(action)) if isinstance(action, dict) and len(action) == 1 else None
        label = tag if tag in TABLE_ACTIONS else 'other'
        try:
            values = json.loads(header)['request_memory']
            assert set(values) == set(self.fields)
            assert all(type(values[name]) is int and 0 <= values[name] < 2**64 for name in self.fields)
            assert values['live_bytes'] <= values['peak_bytes'] <= values['acquired_bytes']
        except (AssertionError, ValueError, TypeError, KeyError):
            with self.lock:
                self.invalid += 1
            return
        with self.lock:
            row = self.operations.setdefault(label, dict(responses=0,
                    totals={name: 0 for name in self.fields[:4]},
                    maximum={name: 0 for name in self.fields}))
            row['responses'] += 1
            for name in row['totals']:
                row['totals'][name] += values[name]
            for name in self.fields:
                row['maximum'][name] = max(row['maximum'][name], values[name])

    def snapshot(self):
        with self.lock:
            assert self.invalid == 0, f'{self.invalid} missing or invalid request-memory observations'
            assert self.operations, 'No direct request memory observed'
            # Every phase includes actual retained reads; inspection alone is
            # not a substitute. Live-at-response bytes include buffered output.
            reads = self.operations['scan']
            assert reads['totals']['alloc_attempts'] > 0
            assert reads['maximum']['live_bytes'] > 0
            return json.loads(json.dumps(self.operations))


@contextmanager
def directory():
    root = Path(tempfile.mkdtemp(prefix='transit-table-maintenance-', dir='/var/tmp'))
    print(f'Direct Table maintenance proof: {root}', flush=True)
    try:
        yield str(root)
    except BaseException:
        print(f'Failed Table maintenance evidence retained at {root}', flush=True)
        raise
    else:
        shutil.rmtree(root)


def process_usage(child):
    """Whole node counters, not the allocator or logical object-byte budget."""
    assert child.poll() is None, 'Storage owner exited during measurement'
    proc = Path(f'/proc/{child.pid}')
    # stat's command can contain spaces and parentheses. Fields after the last
    # closing parenthesis begin at field 3; starttime detects owner replacement.
    stat = (proc / 'stat').read_text().rsplit(')', 1)[1].split()
    status = dict(line.split(':', 1) for line in (proc / 'status').read_text().splitlines())
    io = dict(line.split(':', 1) for line in (proc / 'io').read_text().splitlines())
    return dict(pid=child.pid, start_ticks=int(stat[19]),
                user_ticks=int(stat[11]), system_ticks=int(stat[12]),
                minor_faults=int(stat[7]), major_faults=int(stat[9]),
                rss_bytes=int(status['VmRSS'].split()[0]) * 1024,
                lifetime_peak_rss_bytes=int(status['VmHWM'].split()[0]) * 1024,
                read_bytes=int(io['read_bytes']), write_bytes=int(io['write_bytes']),
                rchar=int(io['rchar']), wchar=int(io['wchar']))


@contextmanager
def foreground(caller, endpoint, profile, root, phase, owner, records, request_memory):
    """Join every reader and retain incomplete samples when a phase fails."""
    out = root / f'foreground-{phase}.jsonl'
    err = root / f'foreground-{phase}.stderr'
    started = time.monotonic()
    before = process_usage(owner())
    request_memory.reset()
    settings = json.loads((root / 'node.json').read_text())
    configuration = dict(resident_pages=settings['resident_pages'],
                         request_timeout_ms=settings['request_timeout_ms'],
                         request_metrics=settings['request_metrics'],
                         storage=settings['storage'],
                         maintenance_interval_ms=settings['maintenance']['interval_ms'],
                         maintenance_timeout_ms=settings['maintenance']['operation_timeout_ms'])
    with out.open('w') as output, err.open('w') as errors:
        child = subprocess.Popen([caller, endpoint, 'maintenance-foreground', str(profile)],
                                 stdout=output, stderr=errors)
        try:
            yield child
            child.wait(timeout=max(.001, 180 - (time.monotonic() - started)))
            assert child.returncode == 0, err.read_text()[-12000:]
            after = process_usage(owner())
            assert (before['pid'], before['start_ticks']) == (after['pid'], after['start_ticks'])
            samples = [json.loads(line) for line in out.read_text().splitlines()]
            assert len(samples) == 16, samples
            assert all(row['sample'] == i and row['rows'] == 258 and row['elapsed_ns'] > 0
                       for i, row in enumerate(samples)), samples
            records.append(dict(phase=phase, configuration=configuration,
                                elapsed_seconds=time.monotonic() - started,
                                node_before=before, node_after=after, reads=samples,
                                request_memory=request_memory.snapshot()))
        finally:
            if child.poll() is None:
                child.kill()
                child.wait(timeout=15)


def exercise(caller, endpoint, profile, root, restart, owner, node, request_memory):
    measurements = dict(source=provenance(ROOT), binaries=[identity(Path(path)) for path in (node, caller)],
                        drivers=[identity(Path(__file__)), identity(Path(__file__).with_suffix('.zig'))],
                        platform=platform.platform(), clock_ticks_per_second=os.sysconf('SC_CLK_TCK'),
                        cache='uncontrolled host page cache; owner restarted before each arm',
                        phases=[])
    def call(phase):
        result = subprocess.run([caller, endpoint, f'maintenance-{phase}', str(profile)],
                                timeout=180, capture_output=True, text=True)
        (root / f'caller-{phase}.stderr').write_text(result.stderr)
        (root / f'caller-{phase}.stdout').write_text(result.stdout)
        if result.returncode:
            raise AssertionError(f'{phase}: {result.stderr[-12000:]}')
        return result

    call('prepare')
    saved = profile.read_bytes()
    measurements['fixture'] = dict(table_rows=[256, 1, 1], page_rows=7,
                                   retained_profile_sha256=hashlib.sha256(saved).hexdigest())
    assert not list((root / 'native').rglob('*.tseg')), 'Point acceptance unexpectedly required a segment'
    restart(False)
    call('wal')
    assert profile.read_bytes() == saved, 'WAL recovery replaced a saved source'
    original = json.loads(call('inspect').stdout)
    assert [value['pending']['rows'] for value in original] == [256, 1, 1], original
    # Both arms read exactly the same three retained cuts, through the same
    # signed service. Keep inspection traffic concurrent in the control too.
    with foreground(caller, endpoint, profile, root, 'table_maintenance_disabled', owner, measurements['phases'], request_memory) as reader:
        deadline = time.monotonic() + 180
        while reader.poll() is None:
            assert json.loads(call('inspect').stdout) == original
            assert time.monotonic() < deadline, 'Foreground control did not complete'
            time.sleep(.1)
    assert profile.read_bytes() == saved, 'Foreground control changed retained identities'
    before = time.monotonic()
    restart(True)
    deadline = time.monotonic() + 60
    small_tables_completed_first = False
    overlap = False
    with foreground(caller, endpoint, profile, root, 'automatic_flush', owner, measurements['phases'], request_memory) as reader:
        while True:
            observed = json.loads(call('inspect').stdout)
            for first, current in zip(original, observed):
                assert first['changed_lsn'] == current['changed_lsn']
                assert current['history_floor'] == 0
            pending = any(value['pending']['rows'] > 0 for value in observed)
            completed_reads = (root / 'foreground-automatic_flush.jsonl').read_text().count('\n')
            overlap |= (pending and reader.poll() is None and completed_reads > 0
                        and sum(value['pending']['rows'] for value in observed) < 258)
            if observed[0]['pending']['rows'] > 0 and all(value['pending']['rows'] == 0 for value in observed[1:]):
                small_tables_completed_first = True
            if all(value['pending']['complete'] and value['pending']['rows'] == 0 for value in observed):
                elapsed = time.monotonic() - before
                break
            assert time.monotonic() < deadline, observed
            time.sleep(.1)
    assert overlap, 'No reader overlapped pending physical work'
    assert profile.read_bytes() == saved, 'Concurrent reads changed retained identities'
    assert small_tables_completed_first, 'An eligible large Table monopolized physical maintenance'
    # The runner keeps stdout as an immutable run artifact even when the private
    # installation is removed on success. This contains no request or row bytes.
    print('Table maintenance resource observations: ' + json.dumps(measurements, sort_keys=True), flush=True)
    segments = list((root / 'native').rglob('*.tseg'))
    assert len(segments) >= 3, segments
    definition = bytes.fromhex(json.loads(profile.read_text())['definition'])
    physical_rows = {}
    for path in segments:
        data = path.read_bytes()
        assert data[:8] == b'TSEG\x01\0\0\0' and data[-4:] == b'TSEG', path.name
        segment, object_id, revision, rows, groups, columns = struct.unpack_from('<QQQIHH', data, 8)
        offset, size = struct.unpack_from('<QI', data, len(data) - 16)
        assert (offset, size) == struct.unpack_from('<QI', data, 40)
        assert offset % 64 == 0 and offset + size == len(data) - 16 and groups > 0 and columns == 1
        footer = data[offset:offset + size]
        assert footer[:36] == b'TSF1' + definition
        assert hashlib.sha256(footer[:-32]).digest() == footer[-32:]
        assert (segment, object_id, revision) == struct.unpack_from('<QQQ', footer, 36)
        assert (rows, groups, columns) == struct.unpack_from('<IHH', footer, 92)
        assert hashlib.sha256(data).hexdigest() in path.name, path.name
        physical_rows[object_id] = physical_rows.get(object_id, 0) + rows
    assert physical_rows == {7: 256, 71: 1, 8: 1}, physical_rows
    # The public storage owner establishes accepted coverage. Independent row
    # expectations below qualify both pre-flush and new segment-backed cuts.
    call('flushed')
    saved = profile.read_bytes()
    restart(True)
    call('flushed')
    assert profile.read_bytes() == saved, 'Restart replaced original retained cuts'
    print(f'Automatic Table flush: 258 WAL rows across three competing Tables; '
          f'{len(segments)} segment objects; original and current rows survive restart; '
          f'convergence including owner restart {elapsed:.3f}s.', flush=True)
    packed = json.loads(call('inspect').stdout)
    packed_files = {path.relative_to(root): hashlib.sha256(path.read_bytes()).digest()
                    for path in segments}

    def inspect():
        observed = json.loads(call('inspect').stdout)
        with (root / 'maintenance-observations.jsonl').open('a') as record:
            record.write(json.dumps(observed) + '\n')
        for first, current in zip(original, observed):
            assert current['interpretation'] == first['interpretation']
            assert current['changed_lsn'] == first['changed_lsn']
            assert current['live_rows'] == first['live_rows']
            assert current['history_floor'] == 0
            assert current['pending']['complete'] and current['pending']['rows'] == 0
        return observed

    def settled(observed):
        for current in observed:
            work = current['maintenance']
            if (work['archive_target'] is not None or work['compaction_target'] is not None
                    or work['archived_source_lsn'] != work['archive_source_lsn']
                    or work['compacted_source_lsn'] != work['compaction_source_lsn']):
                return False
            assert work['archived_source_lsn'] > 0 and work['compacted_source_lsn'] > 0
            assert current['archive_through'] > 0
            assert current['recovery_through'] >= current['archive_through']
        return True

    def converge(kill_pending=False):
        deadline = time.monotonic() + 60
        killed = False
        while True:
            observed = inspect()
            if kill_pending and not killed and any(
                    value['maintenance']['archive_target'] is not None
                    or value['maintenance']['compaction_target'] is not None for value in observed):
                # Stop at observed accepted work, then reopen with these classes
                # disabled to inspect recovery before allowing further progress.
                restart(True, False)
                recovered = inspect()
                for before, after in zip(observed, recovered):
                    assert after['position']['next_lsn'] >= before['position']['next_lsn']
                    for field, completed in (('archive_target', 'archived_source_lsn'),
                                             ('compaction_target', 'compacted_source_lsn')):
                        target = before['maintenance'][field]
                        if target is None or after['maintenance'][completed] >= target['source_lsn']:
                            continue
                        resumed = after['maintenance'][field]
                        assert resumed is not None, (field, before, after)
                        assert resumed['source_lsn'] == target['source_lsn'], (field, before, after)
                        cut = 'through_lsn' if field == 'archive_target' else 'before_segment'
                        assert resumed[cut] == target[cut], (field, before, after)
                        if field == 'compaction_target':
                            assert resumed['after_segment'] >= target['after_segment'], (before, after)
                restart(True, True)
                killed = True
                continue
            if settled(observed):
                assert not kill_pending or killed, 'No pending maintenance was interrupted'
                return observed
            assert time.monotonic() < deadline, observed
            time.sleep(.1)

    before = time.monotonic()
    restart(True, True)
    converge(kill_pending=True)
    # Preserve original WAL, post-flush and post-compaction cuts independently.
    call('maintained')
    saved = profile.read_bytes()
    converged = converge()  # New retention pins also need archive coverage.
    restart(True, True)
    call('maintained')
    assert profile.read_bytes() == saved, 'Maintenance restart replaced retained cuts'
    for _ in range(12):
        assert inspect() == converged, 'Completed maintenance kept publishing work'
        time.sleep(.2)
    assert [value['next_segment'] for value in converged] == [value['next_segment'] for value in packed], \
        'Compaction rewrote already packed inputs or lone dense segments'
    after_files = {path.relative_to(root): hashlib.sha256(path.read_bytes()).digest()
                   for path in (root / 'native').rglob('*.tseg')}
    assert after_files == packed_files, 'Compaction created or changed healthy segment bytes'
    print(f'Automatic Table archive/checkpoint and compaction: three Tables settle '
          f'after SIGKILL during accepted work; original, flushed and maintained '
          f'rows survive restart; zero segment rewrites for packed inputs; no further publications while idle; '
          f'convergence and verification {time.monotonic() - before:.3f}s.', flush=True)
