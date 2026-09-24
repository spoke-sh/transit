"""Build with Vite+ and embed a closed, bounded static asset set into one module."""
import json
import mimetypes
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[2]
output = Path(sys.argv[1]).resolve()
output.parent.mkdir(parents=True, exist_ok=True)
# Separate launcher builds can run together. Each embeds its own complete build,
# rather than racing over Vite's shared, emptied dist directory.
with tempfile.TemporaryDirectory(prefix="board-assets-", dir=output.parent) as directory:
    dist = Path(directory)
    subprocess.run(["vp", "build", "--outDir", str(dist)], cwd=repo / "apps/transit-board-web", check=True)
    assets = sorted(path for path in dist.rglob("*") if path.is_file())
    assert (dist / "index.html") in assets and len(assets) <= 128
    assert sum(path.stat().st_size for path in assets) <= 8 * 1024 * 1024
    output.parent.mkdir(parents=True, exist_ok=True)
    lines = ['const std = @import("std");', 'pub const Asset = struct { bytes: []const u8, mime: []const u8 };']
    for index, path in enumerate(assets):
        name = f"asset-{index}"
        shutil.copyfile(path, output.parent / name)
        lines.append(f'const a{index} = @embedFile("{name}");')
        if path.name == "index.html":
            lines.append(f'pub const index = a{index};')
    shutil.copyfile(repo / "contracts/transit-board-v1.openapi.json", output.parent / "openapi.json")
    lines.append('pub const openapi = @embedFile("openapi.json");')
    lines.append('pub fn get(path: []const u8) ?Asset {')
    for index, path in enumerate(assets):
        name = "/" + path.relative_to(dist).as_posix()
        mime = {".js": "text/javascript", ".css": "text/css", ".html": "text/html; charset=utf-8"}.get(path.suffix) or mimetypes.guess_type(path)[0] or "application/octet-stream"
        lines.append(f'if (std.mem.eql(u8, path, {json.dumps(name)})) return .{{ .bytes = a{index}, .mime = {json.dumps(mime)} }};')
    lines.extend(['return null;', '}'])
    output.write_text("\n".join(lines) + "\n")
