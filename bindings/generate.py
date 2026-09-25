"""Generate thin host declarations/resources; Zig owns every signature/schema."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
contracts = {name: (root / f"packages/zig/transit-{name}/abi-v1.json").read_bytes()
             for name in ("client", "station")}
outputs = {root / f"packages/python/transit-station/transit_station/{name}-abi.json": data
           for name, data in contracts.items()}
for path, content in outputs.items():
    if "--write" in sys.argv:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    elif not path.exists() or path.read_bytes() != content:
        raise SystemExit(f"Binding drift in {path.relative_to(root)}: run just bindings::generate")
print("Host binding declarations match shared Zig contracts.")
