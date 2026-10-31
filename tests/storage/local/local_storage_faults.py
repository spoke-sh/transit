"""Kill real local owners at publication boundaries; independently check recovery."""
from runner.paths import ROOT
import hashlib
import json
from pathlib import Path
import selectors
import signal
import struct
import subprocess
import sys
import tempfile


def run(binary):
    binary = str(Path(binary).resolve())
    definition = bytes.fromhex(json.loads(
        (ROOT / "contracts/transit-v1.schema.json").read_text()
    )["x-transit"]["definition"])
    schedules = 0

    def call(directory, mode, point="none"):
        result = subprocess.run([binary, str(directory), mode, point],
                                capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, (mode, point, result.stderr)
        assert not result.stderr, result.stderr
        return json.loads(result.stdout)

    def kill(directory, mode, point):
        nonlocal schedules
        with subprocess.Popen([binary, str(directory), mode, point], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as child:
            try:
                with selectors.DefaultSelector() as ready:
                    ready.register(child.stdout, selectors.EVENT_READ)
                    assert ready.select(30), (mode, point, "boundary not reached")
                line = child.stdout.readline()
                assert line == '{"stopped":true}\n', (mode, point, line,
                    child.stderr.read() if child.poll() is not None else "child still running")
                assert child.poll() is None, (mode, point, "owner exited instead of waiting")
                if mode.startswith("wal-"):
                    assert call(directory, "wal-locked") == {"locked": True}
                child.kill()
                assert child.wait(timeout=10) == -signal.SIGKILL
                assert child.stdout.read() == "" and child.stderr.read() == ""
                schedules += 1
            finally:
                if child.poll() is None:
                    child.kill()
                    child.wait(timeout=10)

    def metadata(directory):
        raw = (directory / "part-17.meta").read_bytes()
        assert len(raw) == 128 and raw[:8] == b"LWMT\x01\0\0\0"
        assert raw[8:40] == definition and raw[88:96] == bytes(8)
        assert hashlib.sha256(raw[:96]).digest() == raw[96:]
        partition, writer, policy, floor, frontier, cleaned = struct.unpack_from("<6Q", raw, 40)
        assert partition == 17
        assert cleaned <= floor <= frontier
        return dict(writer=writer, policy=policy, floor=floor, frontier=frontier, cleaned=cleaned)

    def rows(directory, floor, payloads):
        result = call(directory, "wal-inspect", str(floor))
        assert result["tail"] == len(payloads), result
        assert result["trimmed"] == (floor != 0), result
        expected = [dict(lsn=i, writer=7 if payload == "successor" else 3,
                         policy=9 if payload == "successor" else 5, payload=payload)
                    for i, payload in enumerate(payloads) if i >= floor]
        assert result["rows"] == expected, (result, expected)

    points = {
        "append": ["write", "sync-1", "sync-2", "sync-3", "publish", "sync-4", "ack"],
        "fence": ["sync-1", "publish", "sync-2", "ack"],
        "trim": ["sync-1", "publish", "sync-2", "delete-1", "delete-2", "sync-3", "sync-4", "sync-5", "publish-2", "sync-6", "ack"],
        "trim-all": ["sync-1", "publish", "sync-2", "delete-1", "delete-2", "delete-3", "sync-3", "sync-4", "sync-5", "sync-6", "publish-2", "sync-7", "ack"],
    }
    with tempfile.TemporaryDirectory(prefix="transit-local-crashes-", dir="/var/tmp") as temporary:
        root = Path(temporary)
        for operation, boundaries in points.items():
            for point in boundaries:
                directory = root / f"wal-{operation}-{point}"
                assert call(directory, "wal-init") == {"tail": 3}
                kill(directory, f"wal-{operation}", point)
                meta = metadata(directory)
                payloads = [f"accepted-{i}" for i in range(3)]
                if operation == "append" and point != "write":
                    payloads.append("uncertain")
                trimming = operation in ("trim", "trim-all")
                trim_floor = 3 if operation == "trim-all" else 2
                floor = trim_floor if trimming and point != "sync-1" else 0
                fenced = operation == "fence" and point != "sync-1"
                published_append = operation == "append" and point in ("publish", "sync-4", "ack")
                completed_trim = trimming and point in (
                    "publish-2", "sync-7" if operation == "trim-all" else "sync-6", "ack")
                assert meta == dict(writer=7 if fenced else 3, policy=9 if fenced else 5,
                                    floor=floor, frontier=4 if published_append else 3,
                                    cleaned=trim_floor if completed_trim else 0), meta
                rows(directory, floor, payloads)
                if fenced:
                    assert call(directory, "wal-stale") == {"fenced": True}
                if trimming:
                    # Repeating the authorized boundary must finish interrupted
                    # physical removal even when its floor was already saved.
                    assert call(directory, f"wal-{operation}") == {"tail": 3}
                    assert metadata(directory)["cleaned"] == trim_floor
                    for lsn in range(3):
                        assert (directory / f"part-17-{lsn}.twal").exists() == (lsn >= trim_floor), point
                    floor = trim_floor
                    rows(directory, floor, payloads)
                assert call(directory, "wal-advance") == {"tail": len(payloads) + 1}
                rows(directory, floor, [*payloads, "successor"])

        # Small objects derive chunk checksums from their descriptor; larger
        # objects also publish a checks file. Cover every barrier in both paths.
        for scale in (1, 16384):
            large = scale != 1
            suffix = "-large" if large else ""
            def object_call(directory, operation, point="none"):
                return call(directory, f"objects-{operation}{suffix}", point)
            for operation in ("replace", "immutable"):
                for point in [*(f"sync-{i}" for i in range(1, 6 if large else 5)), *(f"content-link-{i}" for i in range(1, 3 if large else 2)), "publish", "ack"]:
                    directory = root / f"objects-{scale}-{operation}-{point}"
                    assert object_call(directory, "init") == {"initialized": True}
                    kill(directory, f"objects-{operation}{suffix}", point)
                    published = point in ("sync-5" if large else "sync-4", "publish", "ack")
                    key = "head" if operation == "replace" else "new.tseg"
                    expected = ("after" if published else "before") if operation == "replace" else (
                        "immutable" if published else None)
                    expected = expected * scale if expected is not None else None
                    result = object_call(directory, "inspect", key)
                    assert result["value"] == expected, (operation, point, result)
                    if expected is None:
                        assert result["meta"] is None
                    else:
                        assert result["meta"]["size"] == len(expected)
                        assert bytes(result["meta"]["sha256"]) == hashlib.sha256(expected.encode()).digest()
                    # Recover using the same content/condition, not an unconditional
                    # overwrite. Immutable retries must verify previously linked bytes.
                    retried = object_call(directory, operation)
                    assert retried == {"accepted": operation == "immutable" or not published}
                    assert object_call(directory, "inspect", key)["value"] == (
                        "after" if operation == "replace" else "immutable") * scale
                    if operation == "immutable":
                        assert object_call(directory, "conflict") == {"conflict": True}
            for point in [*(f"sync-{i}" for i in range(1, 9 if large else 7)),
                          *(f"content-link-{i}" for i in range(1, 5 if large else 3)),
                          "publish", "publish-2", "ack"]:
                directory = root / f"objects-{scale}-batch-{point}"
                assert object_call(directory, "init") == {"initialized": True}
                kill(directory, f"objects-batch{suffix}", point)
                for index, (key, value) in enumerate((("batch-a", "first"), ("batch-b", "second"))):
                    visible = point in ({f"sync-{7 if large else 5}", f"sync-{8 if large else 6}", "publish", "publish-2", "ack"}
                                        if index == 0 else {f"sync-{8 if large else 6}", "publish-2", "ack"})
                    result = object_call(directory, "inspect", key)
                    assert result["value"] == (value * scale if visible else None), (point, key, result)
                assert object_call(directory, "batch") == {"accepted": True}
                for key, value in (("batch-a", "first"), ("batch-b", "second")):
                    result = object_call(directory, "inspect", key)
                    assert result["value"] == value * scale, (point, key, result)
                    assert bytes(result["meta"]["sha256"]) == hashlib.sha256((value * scale).encode()).digest()

        def table_rows(directory, archived, next_segment=1):
            result = call(directory, "table-inspect")
            assert result == dict(archived=archived, tail=3 + archived, rows=2,
                                  pinned=1, receipt=1, history=2, current=[1, 2], next_segment=next_segment), result

        def staging_points(operation, initialize="init"):
            directory = root / f"staging-probe-{operation}"
            assert call(directory, f"table-{initialize}") == {"tail": 3}
            # Discover only the physical cut points, never the expected result.
            # The child exits at the second guard, before WAL acceptance.
            count = call(directory, f"table-{operation}", "staging-boundaries")["syncs"]
            assert 0 < count <= 32, (operation, count)
            table_rows(directory, 0, next_segment=3 if initialize == "compact-init" else 1)
            return [f"stage-sync-{i}" for i in range(1, count + 1)]

        archive_staging = staging_points("archive")
        archive_points = [*archive_staging,
                          "before-accept", "accept-write", "accept-sync-1",
                          "accept-sync-2", "accept-sync-3", "accept-publish",
                          "accept-sync-4", "ack"]
        for point in archive_points:
            directory = root / f"table-archive-{point}"
            assert call(directory, "table-init") == {"tail": 3}
            kill(directory, "table-archive", point)
            accepted = int(point in {"accept-sync-1", "accept-sync-2", "accept-sync-3",
                                    "accept-publish", "accept-sync-4", "ack"})
            table_rows(directory, accepted)
            assert metadata(directory / "wal")["floor"] == 0
            assert call(directory, "table-archive-all") == {"archived": 3}
            assert call(directory, "table-trim") == {"archived": 3}
            table_rows(directory, 3)
            assert metadata(directory / "wal")["floor"] == 3

        for point in ["sync-1", "publish", "sync-2", "delete-1", "delete-2", "delete-3", "sync-3", "ack"]:
            directory = root / f"table-trim-{point}"
            assert call(directory, "table-init") == {"tail": 3}
            assert call(directory, "table-archive-all") == {"archived": 3}
            kill(directory, "table-trim", point)
            assert metadata(directory / "wal")["floor"] == (0 if point == "sync-1" else 3)
            table_rows(directory, 3)
            assert call(directory, "table-trim") == {"archived": 3}
            for lsn in range(3):
                assert not (directory / "wal" / f"part-17-{lsn}.twal").exists()
            table_rows(directory, 3)

        # Staging and WAL acceptance have separate fault selectors.
        # Keep the last two staging barriers before any acceptance frame exists.
        compact_staging = staging_points("compact", "compact-init")
        compact_points = [*compact_staging, "before-accept", "accept-write",
                          "accept-sync-1", "accept-sync-2", "accept-sync-3",
                          "accept-publish", "accept-sync-4", "ack"]
        for point in compact_points:
            directory = root / f"table-compact-{point}"
            assert call(directory, "table-compact-init") == {"tail": 3}
            kill(directory, "table-compact", point)
            accepted = int(point in {"accept-sync-1", "accept-sync-2", "accept-sync-3",
                                    "accept-publish", "accept-sync-4", "ack"})
            expected = dict(archived=0, tail=3 + accepted, rows=2, pinned=1,
                            receipt=1, history=2, current=[1, 2], next_segment=3 + accepted)
            observed = call(directory, "table-compact-inspect")
            assert observed == expected, (point, observed, expected)
            assert call(directory, "table-compact") == dict(next_segment=4, rows=0 if accepted else 2)
            expected.update(tail=4, next_segment=4)
            assert call(directory, "table-compact-inspect") == expected
            assert call(directory, "table-compact") == dict(next_segment=4, rows=0)
            assert call(directory, "table-compact-inspect") == expected
        checkpoint_staging = staging_points("checkpoint")
        checkpoint_points = [*checkpoint_staging, "before-accept",
                             "accept-write", "accept-sync-1", "accept-sync-2",
                             "accept-sync-3", "accept-publish", "accept-sync-4", "ack"]
        for point in checkpoint_points:
            directory = root / f"table-checkpoint-{point}"
            assert call(directory, "table-init") == {"tail": 3}
            kill(directory, "table-checkpoint", point)
            accepted = int(point in {"accept-sync-1", "accept-sync-2", "accept-sync-3",
                                    "accept-publish", "accept-sync-4", "ack"})
            expected = dict(archived=0, tail=3 + accepted, rows=2, pinned=1, receipt=1,
                            history=2, current=[1, 2], checkpoint=3 if accepted else 0,
                            replayed=1 if accepted else 3)
            assert call(directory, "table-checkpoint-inspect") == expected
            assert metadata(directory / "wal")["floor"] == 0
            for _ in range(2):
                assert call(directory, "table-checkpoint") == dict(checkpoint=3, tail=4)
                expected.update(tail=4, checkpoint=3, replayed=1)
                assert call(directory, "table-checkpoint-inspect") == expected
            # Checkpointing did not expire old data. Archive/trim remains an
            # independent operation with its own accepted prefix coverage.
            assert call(directory, "table-archive-all") == {"archived": 3}
            assert call(directory, "table-trim") == {"archived": 3}
            expected.update(archived=3, tail=7, replayed=4)
            assert call(directory, "table-checkpoint-inspect") == expected
        # Independent finite oracle: begin, skip each one-row dense input, then
        # complete. Each unit has one acceptance; row/segment identities stay put.
        def maintenance_state(steps):
            return dict(archived=0, tail=3 + steps, rows=2, pinned=1, receipt=1,
                        history=2, current=[1, 2], next_segment=3,
                        target=(dict(before_segment=3, source_lsn=3, after_segment=steps - 1)
                                if 1 <= steps <= 3 else None),
                        completed=3 if steps == 4 else 0)

        maintenance_points = ["before-accept", "accept-write", "accept-sync-1",
                              "accept-sync-2", "accept-sync-3", "accept-publish",
                              "accept-sync-4", "ack"]
        for stage in range(4):
            for point in maintenance_points:
                directory = root / f"table-maintenance-{stage}-{point}"
                assert call(directory, "table-compact-init") == {"tail": 3}
                for step in range(stage):
                    assert call(directory, "table-maintenance") == dict(worked=True, tail=4 + step)
                assert call(directory, "table-maintenance-inspect") == maintenance_state(stage)
                kill(directory, "table-maintenance", point)
                accepted = int(point not in {"before-accept", "accept-write"})
                steps = stage + accepted
                assert call(directory, "table-maintenance-inspect") == maintenance_state(steps)
                while steps < 4:
                    steps += 1
                    assert call(directory, "table-maintenance") == dict(worked=True, tail=3 + steps)
                    assert call(directory, "table-maintenance-inspect") == maintenance_state(steps)
                assert call(directory, "table-maintenance") == dict(worked=False, tail=7)
                assert call(directory, "table-maintenance-inspect") == maintenance_state(4)
        # Archive/checkpoint I/O is covered above. Independently kill publication
        # of the fixed automatic target and its completion after that coverage.
        def archive_state(steps):
            return dict(archived=3 if steps >= 2 else 0, tail=3 + steps,
                        rows=2, pinned=1, receipt=1, history=2, current=[1, 2],
                        next_segment=1,
                        target=(dict(through_lsn=3, source_lsn=3,
                                     checkpoint_lsn=5 if steps >= 2 else None)
                                if 1 <= steps <= 3 else None),
                        completed=3 if steps == 4 else 0,
                        checkpoint=5 if steps >= 3 else 0)

        for stage in (0, 3):
            for point in maintenance_points:
                directory = root / f"table-archive-maintenance-{stage}-{point}"
                assert call(directory, "table-init") == {"tail": 3}
                for step in range(stage):
                    assert call(directory, "table-archive-maintenance") == dict(worked=True, tail=4 + step)
                assert call(directory, "table-archive-maintenance-inspect") == archive_state(stage)
                kill(directory, "table-archive-maintenance", point)
                steps = stage + int(point not in {"before-accept", "accept-write"})
                assert call(directory, "table-archive-maintenance-inspect") == archive_state(steps)
                while steps < 4:
                    steps += 1
                    assert call(directory, "table-archive-maintenance") == dict(worked=True, tail=3 + steps)
                    assert call(directory, "table-archive-maintenance-inspect") == archive_state(steps)
                assert call(directory, "table-archive-maintenance") == dict(worked=False, tail=7)
                assert call(directory, "table-archive-maintenance-inspect") == archive_state(4)
                assert metadata(directory / "wal")["floor"] == 0
    # Both small and multi-chunk object publication schedules are required.
    assert schedules == 173 + len(archive_staging) + len(compact_staging) + len(checkpoint_staging), schedules
    print(f"Local storage: {schedules} SIGKILL schedules preserve acknowledged WAL data, "
          "fences, resumable trim, complete object descriptors, exact immutable retries "
          "and Table archival/compaction/checkpoints, including automatic targets and skip progress, "
          "with original receipts, snapshots and logical history.")


if __name__ == "__main__":
    run(sys.argv[1])
