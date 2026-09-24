const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dependency = b.dependency("zarrow", .{ .target = target, .optimize = optimize });
    const arrow = dependency.module("zarrow");
    try @import("patches.zig").apply(b, dependency, arrow);
    // Upstream's IPC module requires these symbols even for an uncompressed
    // writer. Keep its pinned codec implementation and flags together.
    arrow.addIncludePath(dependency.path("vendor/zstd"));
    arrow.addIncludePath(dependency.path("vendor/lz4"));
    arrow.addCSourceFile(.{ .file = dependency.path("vendor/zstd/zstd.c"), .flags = &.{"-DZSTD_LEGACY_SUPPORT=0"} });
    arrow.addCSourceFile(.{ .file = dependency.path("vendor/lz4/lz4_all.c"), .flags = &.{} });
    arrow.link_libc = true;
    // The compatibility-patched compute sources share this exact Arrow module. Upstream's
    // build script uses pre-0.17 I/O and selects a moving zarrow archive.
    const compute = b.createModule(.{
        .root_source_file = b.path("vendor/zarrow-compute/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zarrow-core", .module = arrow }},
    });
    const module = b.addModule("transit_fuze", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "zarrow", .module = arrow }, .{ .name = "zarrow_compute", .module = compute } },
    });
    const tests = b.step("test", "Qualify Fuze and the pinned Arrow compute dependency");
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
    tests.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = compute })).step);
}
