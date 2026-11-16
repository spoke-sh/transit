"""Guard the extracted HTTP foundation's transitive package boundary."""
from pathlib import Path
import re
import tempfile

from paths import ROOT


ROOTS = ("packages/zig/transit-http", "packages/zig/transit-http-server")
FORBIDDEN = {"transit-exchange", "transit-query", "transit-serving",
             "transit-serving-http", "transit-board-api"}


def violations(root, roots=ROOTS):
    root = root.resolve()
    visited, errors = set(), []

    def visit(directory, chain):
        directory = directory.resolve()
        if not directory.is_relative_to(root):
            errors.append(f"{' -> '.join(chain)}: dependency outside repository")
            return
        relative = directory.relative_to(root)
        name = directory.name
        chain = (*chain, str(relative))
        if name.startswith('transit-station') or name in FORBIDDEN or 'sdks' in relative.parts:
            errors.append(' -> '.join(chain))
            return
        if directory in visited:
            return
        visited.add(directory)
        manifest = directory / 'build.zig.zon'
        if not manifest.is_file():
            errors.append(f"{' -> '.join(chain)}: missing manifest")
            return
        # Local dependencies in ZON are literal paths. Remote dependencies keep
        # their pinned upstream owner and cannot resolve a local Station package.
        for path in re.findall(r'\.path\s*=\s*"([^"\n]+)"', manifest.read_text()):
            visit(directory / path, chain)
        if relative.parts[:2] != ('packages', 'zig'):
            return
        sources = [directory / 'build.zig', *directory.glob('src/**/*.zig')]
        for source in sources:
            for path in re.findall(r'@import\("([^"\n]+)"\)', source.read_text()):
                normalized = path.replace('_', '-')
                if normalized.startswith('transit-station') or normalized in FORBIDDEN:
                    errors.append(f'{source.relative_to(root)}: forbidden import {path}')
                if path.endswith('.zig') and not (source.parent / path).resolve().is_relative_to(directory):
                    errors.append(f'{source.relative_to(root)}: cross-package source import {path}')

    for name in roots:
        visit(root / name, ())
    return errors


def controls():
    with tempfile.TemporaryDirectory(prefix='transit-http-boundary-') as directory:
        root = Path(directory)
        def package(name, dependencies=''):
            path = root / 'packages/zig' / name
            path.mkdir(parents=True, exist_ok=True)
            (path / 'build.zig.zon').write_text('.{ .dependencies = .{' + dependencies + '} }')
            (path / 'build.zig').write_text('const std = @import("std");')
            return path

        package('transit-http-server')
        http = package('transit-http')
        assert not violations(root)
        package('middle', '.hidden = .{ .path = "../transit-station" }')
        (http / 'build.zig.zon').write_text('.{ .dependencies = .{ .neutral = .{ .path = "../middle" } } }')
        assert any('middle -> packages/zig/transit-station' in value for value in violations(root))
        package('middle', '.query = .{ .path = "../transit-query" }')
        assert any('transit-query' in value for value in violations(root))
        package('middle', '.again = .{ .path = "../transit-http" }')
        assert not violations(root), 'graph traversal must terminate on a cycle'
        (http / 'build.zig').write_text('@import("../middle/src/root.zig");')
        assert any('cross-package' in value for value in violations(root))
        (http / 'build.zig').write_text('@import("transit_station");')
        assert any('forbidden import' in value for value in violations(root))
        (http / 'build.zig').write_text('')
        package('middle', '.sdk = .{ .path = "../../../sdks/zig" }')
        assert any('sdks/zig' in value for value in violations(root))
        package('middle', '.missing = .{ .path = "../absent" }')
        assert any('missing manifest' in value for value in violations(root))


def main():
    errors = violations(ROOT)
    assert not errors, '\n'.join(errors)
    controls()
    print('HTTP foundation: transitive Station/Exchange/query/SDK dependencies and source bypasses rejected')


if __name__ == '__main__':
    main()
