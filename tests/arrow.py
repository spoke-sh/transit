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


if __name__ == "__main__":
    run(sys.argv[1])
