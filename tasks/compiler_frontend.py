#!/usr/bin/env python3
"""Build/check the deterministic pure frontend source distribution."""
import argparse
import gzip
import io
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ('transit-sql-frontend', 'transit-protocol', 'transit-memory', 'transit-spatial')
OUTPUT = ROOT / 'build/artifacts/transit-sql-frontend.tar.gz'
FINGERPRINT = '0xe6c548dd0390d0b7'


def archive():
    version = (ROOT / 'VERSION').read_text().strip()
    names = tuple(name.replace('-', '_') for name in PACKAGES)
    build = '''const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    inline for (.{ "transit_sql_frontend", "transit_protocol", "transit_memory", "transit_spatial" }) |name| {
        b.modules.put(b.allocator, name, b.dependency(name, .{ .target = target, .optimize = optimize }).module(name)) catch @panic("out of memory");
    }
}
'''
    zon = '.{\n    .name = .transit_sql_distribution,\n    .version = "'+version+'",\n    .fingerprint = '+FINGERPRINT+',\n    .minimum_zig_version = "0.17.0-dev.2267+48abf1a34",\n    .dependencies = .{\n'
    zon += ''.join('        .'+name+' = .{ .path = "packages/'+package+'" },\n' for package,name in zip(PACKAGES,names))
    zon += '    },\n    .paths = .{ "build.zig", "build.zig.zon", "packages", "NOTICE" },\n}\n'
    files = {'build.zig': build.encode(), 'build.zig.zon': zon.encode(), 'NOTICE': b'Transit SQL frontend source distribution. Source: https://github.com/spoke-sh/transit. Generated from authoritative package files by tasks/compiler_frontend.py; preserve source attribution.\n'}
    for package in PACKAGES:
        prefix = 'packages/zig/'+package+'/'
        paths = subprocess.check_output(['git', 'ls-files', '-z', '--', prefix], cwd=ROOT).decode().split('\0')
        for path in paths:
            if path:
                files[path.replace('packages/zig/', 'packages/', 1)] = (ROOT / path).read_bytes()
    output = io.BytesIO()
    with gzip.GzipFile(filename='', mode='wb', fileobj=output, mtime=0, compresslevel=9) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as tar:
            for name, data in sorted(files.items()):
                info = tarfile.TarInfo(name)
                info.size = len(data)
                info.mode = 0o644
                tar.addfile(info, io.BytesIO(data))
    return output.getvalue(), len(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    content, count = archive()
    if args.write:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(content)
    assert OUTPUT.read_bytes() == content, 'Frontend archive drift; review source and run tasks/compiler_frontend.py --write'
    print(f'Pure frontend distribution: {count} authoritative files; deterministic source archive verified')


if __name__ == '__main__': main()
