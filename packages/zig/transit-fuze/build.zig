const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol");
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
    const compute_dependency = b.dependency("zarrow_compute", .{ .target = target, .optimize = optimize });
    const compute = compute_dependency.module("zarrow_compute");
    // Compute and IPC must share one Arrow type universe, including Fuze's
    // guarded writer patches. Replace the upstream core-only module import.
    compute.addImport("zarrow-core", arrow);
    const module = b.addModule("transit_fuze", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_protocol", .module = protocol }, .{ .name = "zarrow", .module = arrow }, .{ .name = "zarrow_compute", .module = compute } },
    });
    const tests = b.step("test", "Qualify Fuze and the pinned Arrow compute dependency");
    const contract = b.addExecutable(.{ .name = "transit-logical-contract", .root_module = b.createModule(.{
        .root_source_file = b.path("src/logical_contract.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = module }},
    }) });
    b.installArtifact(contract);
    b.step("logical-contract", "Reflect recursive logical JSON schemas").dependOn(&b.addRunArtifact(contract).step);
    const own_tests = b.addTest(.{ .root_module = module });
    const compute_tests = b.addTest(.{ .root_module = compute });
    const compute_run = b.addRunArtifact(compute_tests);
    tests.dependOn(&b.addRunArtifact(own_tests).step);
    tests.dependOn(&compute_run.step);
    b.step("test-compute", "Qualify the pinned compute dependency with Fuze's Arrow configuration").dependOn(&compute_run.step);
    const check = b.step("check", "Compile standalone Fuze and compute tests without executing them");
    check.dependOn(&own_tests.step);
    check.dependOn(&compute_tests.step);
}
