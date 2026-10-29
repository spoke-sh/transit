"""Build the real metadata owner across Git changes, worktrees and source archives."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(args, cwd):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    assert result.returncode == 0, (args, result.stderr)
    return result.stdout.strip()


with tempfile.TemporaryDirectory(prefix='transit-version-build-') as temporary:
    root = Path(temporary) / 'source'
    (root / 'build').mkdir(parents=True)
    shutil.copy2(ROOT / 'build/version.zig', root / 'build/version.zig')
    shutil.copy2(ROOT / 'VERSION', root / 'VERSION')
    (root / '.gitignore').write_text('.zig-cache/\nzig-out/\n')
    (root / 'build.zig').write_text('''const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const module = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = target });
    module.addOptions("version", @import("build/version.zig").options(b));
    b.installArtifact(b.addExecutable(.{ .name = "identity", .root_module = module }));
}
''')
    (root / 'main.zig').write_text('''const std = @import("std");
const version = @import("version");
pub fn main(init: std.process.Init) !void {
    try std.Io.File.stdout().writeStreamingAll(init.io, version.release ++ " " ++ version.revision);
}
''')

    def build(directory=root, *options):
        run(['zig', 'build', *options], directory)
        return run([str(directory / 'zig-out/bin/identity')], Path(temporary))

    version = (ROOT / 'VERSION').read_text().strip()
    assert build() == f'{version} unknown'
    run(['git', 'init', '-q'], root)
    run(['git', 'config', 'user.email', 'fixture@example.invalid'], root)
    run(['git', 'config', 'user.name', 'Version fixture'], root)
    run(['git', 'add', '.'], root)
    run(['git', '-c', 'commit.gpgSign=false', 'commit', '-qm', 'test(release): create source'], root)
    first = run(['git', 'rev-parse', 'HEAD'], root)
    assert build() == f'{version} {first}'
    (root / 'untracked').write_text('new source')
    assert build() == f'{version} {first}-dirty'
    run(['git', 'add', '.'], root)
    run(['git', '-c', 'commit.gpgSign=false', 'commit', '-qm', 'test(release): advance source'], root)
    second = run(['git', 'rev-parse', 'HEAD'], root)
    assert second != first and build() == f'{version} {second}'
    (root / 'main.zig').write_text((root / 'main.zig').read_text() + '// modified\n')
    assert build() == f'{version} {second}-dirty'
    worktree = Path(temporary) / 'worktree'
    run(['git', 'worktree', 'add', '--detach', str(worktree), first], root)
    assert build(worktree) == f'{version} {first}'
    assert build(root, '-Dsource-revision=' + 'b' * 40) == f'{version} ' + 'b' * 40
    nightly = version + '-nightly.20261029.gbbbbbbbbbbbb'
    assert build(root, '-Dsource-revision=' + 'b' * 40, '-Drelease-version=' + nightly) == nightly + ' ' + 'b' * 40
    invalid = subprocess.run(['zig', 'build', '-Dsource-revision=not-a-sha'], cwd=root, capture_output=True)
    assert invalid.returncode and b'invalid -Dsource-revision' in invalid.stderr
    nested = root / 'archive'
    shutil.copytree(worktree, nested, ignore=shutil.ignore_patterns('.git', '.zig-cache', 'zig-out'))
    assert build(nested) == f'{version} unknown', 'source archive inherited an unrelated parent Git identity'
print('Build identity: archive, clean/dirty Git, cached rebuilds, worktree, override and invalid metadata passed')
