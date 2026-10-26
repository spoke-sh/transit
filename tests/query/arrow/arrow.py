"""Read Fuze IPC with a separately implemented, pinned Arrow consumer."""
from pathlib import Path
import hashlib
import copy
import json
import math
import struct
import subprocess
import sys
import tempfile

import pyarrow as pa


def field(name, datatype):
    alternative = pa.struct([pa.field("counter", pa.uint64(), nullable=False),
        pa.field("replica", pa.uint64(), nullable=False), pa.field("state", pa.uint8(), nullable=False),
        pa.field("kind", pa.uint8(), nullable=False), pa.field("value", datatype)])
    return pa.field(name, pa.struct([pa.field("state", pa.uint8(), nullable=False),
        pa.field("kind", pa.uint8(), nullable=False), pa.field("value", datatype),
        pa.field("alternatives", pa.list_(pa.field("item", alternative, nullable=False)), nullable=False)]), nullable=False)


def simple_rows(table):
    tags = {pa.int64(): 1, pa.uint64(): 2, pa.float64(): 3, pa.bool_(): 4, pa.string(): 5, pa.binary(): 6}
    result = []
    for row in table.to_pylist():
        for name, cell in row.items():
            tag = tags[table.schema.field(name).type.field("value").type]
            assert cell["alternatives"] == [] and cell["state"] in (1, 3), cell
            assert cell["kind"] == (7 if cell["state"] == 1 else tag), cell
            assert cell["state"] != 1 or cell["value"] is None, cell
        result.append({name: cell["value"] for name, cell in row.items()})
    return result


def run(binary):
    with tempfile.TemporaryDirectory(prefix="transit-arrow-") as directory:
        for aggregate in ("rows", "count", "sum"):
            path = Path(directory) / f"unified-stream-{aggregate}"
            subprocess.run([binary, f"unified-stream-{aggregate}", str(path)], check=True, timeout=20)
            expected = [i for i in range(70) if i % 5 and i >= 3][:37]
            for width in range(1, 9):
                progress = json.loads(Path(f"{path}-{width}.json").read_text())
                assert progress["selected"] == len(expected) and progress["scanned"] == expected[-1]+1
                assert progress["finished"] == "limit"
                actual = []
                for ordinal in range(progress["segments"]):
                    with pa.ipc.open_stream(Path(f"{path}-{width}-{ordinal}.arrow").read_bytes()) as reader:
                        table = reader.read_all()
                    actual.extend(row["value" if aggregate == "rows" else aggregate]["value"] for row in table.to_pylist())
                assert actual == (expected if aggregate == "rows" else [len(expected)] if aggregate == "count" else [sum(expected)]), (aggregate, width, actual)
                basis = progress["basis"]
                def octets(value): return value.encode() if isinstance(value, str) else bytes(value)
                wire = (b"FZS1\1" + struct.pack("<QQ", basis["resource"], basis["revision"])
                    + octets(basis["contract"]) + octets(basis["schema"]) + octets(progress["plan"])
                    + struct.pack("<QQQQQQBqB", *(progress[k] for k in ("pages", "scanned", "selected", "value_count", "segments", "rows")),
                        progress["sum"] is not None, progress["sum"] or 0, 2))
                assert len(wire) == 175 and Path(f"{path}-{width}.progress").read_bytes() == wire
        print("Unified execution: independent filter/limit/count/sum and checkpoint encoding across all eight page widths passed")
        for name in ("rows", "empty"):
            path = Path(directory) / f"unified-{name}.arrow"
            subprocess.run([binary, f"unified-{name}", str(path)], check=True, timeout=20)
            data = path.read_bytes()
            with pa.ipc.open_stream(data) as reader:
                table = reader.read_all()
            types = dict(int64=pa.int64(), uint64=pa.uint64(), float64=pa.float64(),
                         boolean=pa.bool_(), utf8=pa.string(), binary=pa.binary())
            values = dict(int64=-(2**63), uint64=2**64-1, float64=-0.0,
                          boolean=False, utf8="café é 🙂", binary=b"\0\xff\x80")
            fields = []
            for column, datatype in types.items():
                alternative = pa.struct([pa.field("counter", pa.uint64(), nullable=False),
                    pa.field("replica", pa.uint64(), nullable=False), pa.field("state", pa.uint8(), nullable=False),
                    pa.field("kind", pa.uint8(), nullable=False), pa.field("value", datatype)])
                fields.append(pa.field(column, pa.struct([pa.field("state", pa.uint8(), nullable=False),
                    pa.field("kind", pa.uint8(), nullable=False), pa.field("value", datatype),
                    pa.field("alternatives", pa.list_(pa.field("item", alternative, nullable=False)), nullable=False)]), nullable=False))
            assert table.schema == pa.schema(fields), table.schema
            actual = table.to_pylist()
            if name == "empty":
                assert actual == []
            else:
                assert len(actual) == 5
                for tag, (column, value) in enumerate(values.items(), 1):
                    expected = [dict(state=0, kind=0, value=None, alternatives=[]),
                        dict(state=1, kind=7, value=None, alternatives=[]),
                        dict(state=2, kind=8, value=None, alternatives=[]),
                        dict(state=3, kind=tag, value=value, alternatives=[]),
                        dict(state=4, kind=0, value=None, alternatives=[
                            dict(counter=2**64-1, replica=1, state=3, kind=tag, value=value),
                            dict(counter=2**64-1, replica=2, state=1, kind=7, value=None),
                            dict(counter=2**64-1, replica=3, state=2, kind=9, value=None)])]
                    assert [row[column] for row in actual] == expected
                assert math.copysign(1, actual[3]["float64"]["value"]) == -1
                assert math.copysign(1, actual[4]["float64"]["alternatives"][0]["value"]) == -1
            # The independently encoded stream must survive native semantic
            # validation and keep owned values after its Arrow workspace dies.
            encoded = Path(directory) / f"pyarrow-{name}.arrow"
            with pa.OSFile(str(encoded), "wb") as sink:
                with pa.ipc.new_stream(sink, table.schema) as writer:
                    writer.write_batch(table.combine_chunks().to_batches()[0] if name == "rows" else pa.record_batch([pa.array([], type=f.type) for f in table.schema], schema=table.schema))
            subprocess.run([binary, f"unified-validate-{name}", str(encoded)], check=True, timeout=20)
            if name == "rows":
                malformed = []
                def changed(label, edit):
                    rows = copy.deepcopy(actual)
                    edit(rows)
                    malformed.append((label, rows, table.schema))
                changed("state", lambda rows: rows[0]["int64"].update(state=255))
                changed("kind", lambda rows: rows[3]["int64"].update(kind=2))
                changed("hidden-value", lambda rows: rows[0]["int64"].update(value=17))
                changed("single-conflict", lambda rows: rows[4]["int64"].update(alternatives=rows[4]["int64"]["alternatives"][:1]))
                changed("conflict-order", lambda rows: rows[4]["int64"]["alternatives"].reverse())
                changed("conflict-zero", lambda rows: rows[4]["int64"]["alternatives"][0].update(replica=0))
                changed("conflict-missing", lambda rows: rows[4]["int64"]["alternatives"][0].update(state=0, kind=0, value=None))
                changed("hidden-alternatives", lambda rows: rows[0]["int64"].update(alternatives=rows[4]["int64"]["alternatives"]))
                changed("nan", lambda rows: rows[3]["float64"].update(value=float("nan")))
                changed("oversized-text", lambda rows: rows[3]["utf8"].update(value="x" * 4097))
                changed("outer-null", lambda rows: rows[0].update(int64=None))
                changed("nested-null", lambda rows: rows[3]["int64"].update(state=None))
                malformed.append(("schema", actual, table.schema.set(0, table.schema.field(0).with_name("renamed"))))
                for label, rows, schema in malformed:
                    bad = Path(directory) / f"bad-{label}.arrow"
                    with pa.OSFile(str(bad), "wb") as sink:
                        with pa.ipc.new_stream(sink, schema) as writer:
                            writer.write_batch(pa.RecordBatch.from_pylist(rows, schema=schema))
                    rejected = subprocess.run([binary, "unified-validate-rows", str(bad)], capture_output=True, timeout=20)
                    assert rejected.returncode == 1, (label, rejected.returncode, rejected.stderr.decode())
                    assert b"TestExpectedEqual" not in rejected.stderr, (label, "semantic validation accepted malformed data")
                print(f"Unified Arrow reader: independent producer round trip and {len(malformed)} malformed state/schema cases passed")
            assert len(data) <= 65536
            print(f"Unified Arrow {name}: {len(data)} bytes; six primitives, nested alternatives and five states verified")
        for name in ("rows", "empty"):
            path = Path(directory) / f"{name}.arrow"
            subprocess.run([binary, name, str(path)], check=True, timeout=20)
            data = path.read_bytes()
            with pa.ipc.open_stream(data) as reader:
                table = reader.read_all()
            assert table.schema == pa.schema([
                pa.field("id", pa.int64(), nullable=False),
                pa.field("label", pa.string(), nullable=True),
            ])
            assert table.to_pylist() == ([] if name == "empty" else [
                {"id": 1, "label": "ready"},
                {"id": 9007199254740993, "label": None},
                {"id": 9223372036854775807, "label": "東京"},
            ])
            # Three data keys and one manifest key share the four-key commit.
            assert len(data) <= 3 * 256, (name, len(data))
            print(f"Arrow {name}: {len(data)} bytes; independent schema/value validation passed")
        for name, datatype, cell in (("int64", pa.int64(), 9007199254740993),
                                     ("bool", pa.bool_(), True),
                                     ("text", pa.string(), "東京"),
                                     ("binary", pa.binary(), b"\x00\xff"),
                                     ("sum", pa.int64(), None),
                                     ("count", pa.int64(), None),
                                     ("null", pa.int64(), None),
                                     ("empty", pa.int64(), None)):
            path = Path(directory) / f"{name}.arrow"
            subprocess.run([binary, f"query-{name}", str(path)], check=True, timeout=20)
            data = path.read_bytes()
            assert len(data) <= 8192
            with pa.ipc.open_stream(data) as reader:
                table = reader.read_all()
            if name in ("sum", "count"):
                assert table.schema == pa.schema([field(name, pa.int64() if name == "sum" else pa.uint64())])
                assert simple_rows(table) == [{name: 9007199254740993 if name == "sum" else 2}]
            else:
                assert table.schema == pa.schema([field("id", pa.int64()), field("value", datatype)])
                assert simple_rows(table) == ([] if name == "empty" else
                    [{"id": 2, "value": None}] if name == "null" else
                    [{"id": -1, "value": cell}, {"id": 2, "value": None}])
        print("Fuze: all admitted Arrow types, filter, empty schema, count and exact integer sum passed independent validation")
        for name in ("int64", "bool", "text", "binary", "sum", "count", "null", "empty", "limit"):
            path = Path(directory) / f"stream-{name}.json"
            subprocess.run([binary, f"stream-{name}", str(path)], check=True, timeout=20)
            manifest = json.loads(path.read_text())
            assert manifest["representation"] == "arrow-ipc-segments-v1"
            progress = manifest["progress"]
            # Independent canonical plan, source basis and progress encoding.
            projection = [1] if name in ("count", "sum") else [0, 1]
            limit = 37 if name == "limit" else 0 if name == "empty" else None
            definition = hashlib.sha256(b'transit.fuze.plan.v1.boolean-programs.count-values.2026-10-01').digest()
            logical = (b"FZP1" + definition + bytes([{"count": 1, "sum": 2}.get(name, 0), len(projection), *projection])
                + bytes(len(projection)) + bytes([limit is not None])
                + struct.pack("<Q", limit or 0)
                + (bytes([1, 1, 1]) if name == "null" else bytes([2, 0, 5, 1]) + struct.pack("<q", 3) if name == "limit" else b"\0"))
            assert bytes(progress["plan"]) == hashlib.sha256(b"transit.fuze.plan.v1\0" + logical).digest()
            basis = progress["basis"]
            assert basis["kind"] == "table"
            encoded = (b"FZS1\2" + struct.pack("<QQ", basis["resource"], basis["revision"])
                       + octets(basis["contract"]) + octets(basis["schema"]) + octets(progress["plan"])
                       + struct.pack("<QQQQQQBqB", *(progress[key] for key in ("pages", "scanned", "selected", "value_count", "segments", "rows")),
                                     progress["sum"] is not None, progress["sum"] or 0,
                                     {"source_end": 1, "limit": 2}[progress["finished"]]))
            assert len(encoded) == 175 and Path(f"{path}.progress").read_bytes() == encoded
            actual = []
            total_bytes = 0
            datatype = {"bool": pa.bool_(), "text": pa.string(), "binary": pa.binary()}.get(name, pa.int64())
            schema = (pa.schema([field(name, pa.uint64() if name == "count" else pa.int64())])
                      if name in ("count", "sum") else
                      pa.schema([field("id", pa.int64()), field("value", datatype)]))
            for ordinal, segment in enumerate(manifest["segments"]):
                assert segment["ordinal"] == ordinal
                data = Path(f"{path}.{ordinal}.arrow").read_bytes()
                assert segment["bytes"] == len(data)
                assert bytes(segment["digest"]) == hashlib.sha256(data).digest()
                # Each segment is its own IPC stream, not byte-concatenated IPC.
                with pa.ipc.open_stream(data) as reader:
                    batches = list(reader)
                    assert reader.schema == schema
                assert len(batches) == 1 and batches[0].num_rows == segment["rows"] <= 8
                actual.extend(simple_rows(pa.Table.from_batches(batches)))
                total_bytes += len(data)
            keys = ([] if name == "empty" else range(3, 40) if name == "limit" else
                    range(0, 70, 5) if name == "null" else range(70))
            expected = []
            for key in keys:
                value = (key % 2 == 0 if name == "bool" else "x" * 220 if name == "text" else
                         bytes([0, 255, key]) if name == "binary" else 9007199254740993 + key)
                expected.append({"id": key, "value": None if key % 5 == 0 else value})
            if name == "count":
                expected = [{"count": 70}]
            if name == "sum":
                expected = [{"sum": sum(9007199254740993 + key for key in range(70) if key % 5)}]
            assert actual == expected, name
            assert len(actual) == progress["rows"]
            assert len(manifest["segments"]) == progress["segments"]
            assert manifest["bytes"] == total_bytes
            assert progress["finished"] == ("limit" if name in ("limit", "empty") else "source_end")
            if name == "text":
                assert progress["rows"] > 32 and total_bytes > 672
                print(f"Fuze incremental text: {progress['rows']} rows, {total_bytes} bytes in {progress['segments']} independently decoded segments")
        print("Fuze incremental: global limit/aggregates, exact integers, nulls and empty schema passed independent validation")


if __name__ == "__main__":
    run(sys.argv[1])
