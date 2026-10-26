#!/usr/bin/env python3
"""Isolated production-tree geometry/codec/root-partition experiment.

Generated variants never run a native authority or open an installation. Counts
measure private tree work; they do not qualify a new storage format or latency.
"""
from runner.paths import ROOT
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = ROOT
    source = (root / 'packages/zig/transit-core/src/pages.zig').read_text()
    report = {'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              'tree_sha256': hashlib.sha256(source.encode()).hexdigest(),
              'scope': '50 private synthetic turn candidates; retained roots and codec round trips checked; no provider I/O, authority validation or native latency',
              'variants': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='transit-page-layout-', dir=os.environ.get('TMPDIR', '/var/tmp')) as directory:
        work = Path(directory)
        (work / 'compact.zig').write_bytes((root / 'packages/zig/transit-core/src/PageCodec.zig').read_bytes())
        for name, leaves, branches, compact in [('current', 4, 5, False), ('compact', 4, 5, True),
                                               ('wide-branch', 4, 32, True), ('wide-leaf', 8, 32, True)]:
            candidate = re.sub(r'pub const leaf_entries = \d+;', f'pub const leaf_entries = {leaves};', source)
            candidate = re.sub(r'pub const branch_children = \d+;', f'pub const branch_children = {branches};', candidate)
            if compact:
                candidate = candidate.replace('const Layout = @This();', '')
                candidate = 'const Layout = @This();\n' + candidate.replace('//!', '//')
                start = candidate.index('    pub fn encode(self: *const Page,')
                end = candidate.index('    pub fn reference(self: *const Page)', start)
                candidate = candidate[:start] + '''    pub fn encode(self: *const Page, bytes: []u8) ![]const u8 {
        return @import("compact.zig").encode(self, bytes);
    }
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Page {
        _ = allocator;
        return @import("compact.zig").decode(Layout, bytes);
    }
''' + candidate[end:]
            else:
                start = candidate.index('    pub fn encode(self: *const Page,')
                end = candidate.index('    pub fn reference(self: *const Page)', start)
                candidate = candidate[:start] + """    pub fn encode(self: *const Page, bytes: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(bytes);
        try std.json.Stringify.value(self, .{}, &writer);
        return writer.buffered();
    }
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Page {
        if (bytes.len > max_encoded_bytes) return error.InvalidPage;
        const parsed = try std.json.parseFromSlice(Page, allocator, bytes, .{});
        defer parsed.deinit();
        try parsed.value.validate();
        return parsed.value;
    }
""" + candidate[end:]
            (work / 'pages.zig').write_text(candidate)
            binary = work / name
            subprocess.run(['zig', 'build-exe', '-OReleaseSafe', '--dep', 'pages',
                            '-Mroot=' + str(root / 'tests/performance/storage/page_layout.zig'), '-Mpages=' + str(work / 'pages.zig'),
                            '-femit-bin=' + str(binary)], check=True)
            results = [json.loads(line) for line in subprocess.check_output([binary], text=True).splitlines()]
            report['variants'].append({'name': name, 'compact': compact, 'generated_sha256': hashlib.sha256(candidate.encode()).hexdigest(), 'results': results})
            args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'report': str(args.output), 'variants': len(report['variants'])}))


if __name__ == '__main__':
    main()
