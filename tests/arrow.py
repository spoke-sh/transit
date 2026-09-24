"""Read Fuze IPC with a separately implemented, pinned Arrow consumer."""
from pathlib import Path
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


if __name__ == "__main__":
    run(sys.argv[1])
