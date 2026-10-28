"""Physical-disk automatic maintenance, fixed targets and retained rows."""
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import struct
import tempfile
import time


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


def exercise(caller, endpoint, profile, root, restart):
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
    assert not list((root / 'native').rglob('*.tseg')), 'Point acceptance unexpectedly required a segment'
    restart(False)
    call('wal')
    assert profile.read_bytes() == saved, 'WAL recovery replaced a saved source'
    original = json.loads(call('inspect').stdout)
    assert [value['pending']['rows'] for value in original] == [256, 1, 1], original
    before = time.monotonic()
    restart(True)
    deadline = time.monotonic() + 60
    small_tables_completed_first = False
    while True:
        observed = json.loads(call('inspect').stdout)
        for first, current in zip(original, observed):
            assert first['changed_lsn'] == current['changed_lsn']
            assert current['history_floor'] == 0
        if observed[0]['pending']['rows'] > 0 and all(value['pending']['rows'] == 0 for value in observed[1:]):
            small_tables_completed_first = True
        if all(value['pending']['complete'] and value['pending']['rows'] == 0 for value in observed):
            break
        assert time.monotonic() < deadline, observed
        time.sleep(.1)
    assert small_tables_completed_first, 'An eligible large Table monopolized physical maintenance'
    elapsed = time.monotonic() - before
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
