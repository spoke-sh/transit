//! Artifact identity is captured at build configuration, never at runtime.
const std = @import("std");

pub const release = std.mem.trim(u8, @embedFile("../VERSION"), "\r\n");

pub fn options(b: *std.Build) *std.Build.Step.Options {
    _ = std.SemanticVersion.parse(release) catch @panic("invalid Transit VERSION");
    const revision = b.option([]const u8, "source-revision", "Source commit (40 lowercase hex digits, optionally -dirty), or unknown") orelse detectRevision(b);
    if (!validRevision(revision)) @panic("invalid -Dsource-revision: expected a full Git SHA, SHA-dirty, or unknown");
    const result = b.addOptions();
    result.addOption([]const u8, "release", release);
    result.addOption([]const u8, "revision", revision);
    return result;
}

fn validRevision(revision: []const u8) bool {
    if (std.mem.eql(u8, revision, "unknown")) return true;
    if (revision.len != 40 and !(revision.len == 46 and std.mem.endsWith(u8, revision, "-dirty"))) return false;
    for (revision[0..40]) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    return true;
}

fn git(b: *std.Build, args: []const []const u8) ?[]const u8 {
    const argv = std.mem.concat(b.allocator, []const u8, &.{ &.{ "git", "-C", (b.root.toString(b.allocator) catch @panic("OOM")) }, args }) catch @panic("OOM");
    return switch (b.runFallible(argv, .{ .stderr_behavior = .ignore })) {
        .success => |output| std.mem.trim(u8, output, "\r\n"),
        else => null,
    };
}

fn detectRevision(b: *std.Build) []const u8 {
    // Git refs, the index and untracked files are external configuration inputs.
    b.graph.poisonCache();
    // An unpacked source tree inside another repository must not inherit its SHA.
    const prefix = git(b, &.{ "rev-parse", "--show-prefix" }) orelse return "unknown";
    if (prefix.len != 0) return "unknown";
    const revision = git(b, &.{ "rev-parse", "--verify", "HEAD" }) orelse return "unknown";
    const status = git(b, &.{ "status", "--porcelain", "--untracked-files=normal" }) orelse return "unknown";
    return if (status.len == 0) revision else b.fmt("{s}-dirty", .{revision});
}
