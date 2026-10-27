"""Physical-disk automatic flush, original WAL snapshots and current rows."""
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
    while True:
        observed = json.loads(call('inspect').stdout)
        for first, current in zip(original, observed):
            assert first['changed_lsn'] == current['changed_lsn']
            assert current['history_floor'] == 0
        if all(value['pending']['complete'] and value['pending']['rows'] == 0 for value in observed):
            break
        assert time.monotonic() < deadline, observed
        time.sleep(.1)
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
