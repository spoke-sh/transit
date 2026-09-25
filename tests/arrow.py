"""Read Fuze IPC with a separately implemented, pinned Arrow consumer."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import sys
import tempfile

import pyarrow as pa


def run(binary):
    with tempfile.TemporaryDirectory(prefix="transit-arrow-") as directory:
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
            assert len(data) <= 672
            with pa.ipc.open_stream(data) as reader:
                table = reader.read_all()
            if name in ("sum", "count"):
                assert table.schema == pa.schema([pa.field(name, pa.int64(), nullable=name == "sum")])
                assert table.to_pylist() == [{name: 9007199254740993 if name == "sum" else 2}]
            else:
                assert table.schema == pa.schema([pa.field("id", pa.int64(), nullable=False), pa.field("value", datatype)])
                assert table.to_pylist() == ([] if name == "empty" else
                    [{"id": 2, "value": None}] if name == "null" else
                    [{"id": -1, "value": cell}, {"id": 2, "value": None}])
        print("Fuze: all admitted Arrow types, filter, empty schema, count and exact integer sum passed independent validation")
        for name in ("int64", "bool", "text", "binary", "sum", "count", "null", "empty", "limit"):
            path = Path(directory) / f"stream-{name}.json"
            subprocess.run([binary, f"stream-{name}", str(path)], check=True, timeout=20)
            manifest = json.loads(path.read_text())
            assert manifest["representation"] == "arrow-ipc-segments-v1"
            progress = manifest["progress"]
            logical = json.dumps(manifest["plan"], ensure_ascii=False, separators=(",", ":")).encode()
            assert bytes(progress["plan"]) == hashlib.sha256(b"transit.fuze.stream.plan.v1\x00" + logical).digest()
            encoded = (b"FZS1" + struct.pack("<QQ", progress["basis"]["resource"], progress["basis"]["revision"])
                       + bytes(progress["basis"]["schema"]) + bytes(progress["plan"])
                       + struct.pack("<QQQQQ", *(progress[key] for key in ("pages", "scanned", "selected", "segments", "rows")))
                       + struct.pack("<BqBqB", progress["last_key"] is not None, progress["last_key"] or 0,
                                     progress["sum"] is not None, progress["sum"] or 0,
                                     {"source_end": 1, "limit": 2}[progress["finished"]]))
            assert len(encoded) == 143 and Path(f"{path}.progress").read_bytes() == encoded
            actual = []
            total_bytes = 0
            datatype = {"bool": pa.bool_(), "text": pa.string(), "binary": pa.binary()}.get(name, pa.int64())
            schema = (pa.schema([pa.field(name, pa.int64(), nullable=name == "sum")])
                      if name in ("count", "sum") else
                      pa.schema([pa.field("id", pa.int64(), nullable=False), pa.field("value", datatype)]))
            for ordinal, segment in enumerate(manifest["segments"]):
                assert segment["ordinal"] == ordinal
                data = Path(f"{path}.{ordinal}.arrow").read_bytes()
                assert segment["bytes"] == len(data)
                assert bytes(segment["digest"]) == hashlib.sha256(data).digest()
                # Each segment is its own IPC stream, not byte-concatenated IPC.
                with pa.ipc.open_stream(data) as reader:
                    batches = list(reader)
                    assert reader.schema == schema
                assert len(batches) == 1 and batches[0].num_rows == segment["rows"] <= 32
                actual.extend(batches[0].to_pylist())
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
