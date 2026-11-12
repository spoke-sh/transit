const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    _ = b.addModule("station_frame", .{
        .root_source_file = b.path("src/Frame.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    });
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_station", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_client", .module = client.module("transit_client") }, .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") } },
    });
    const tests = b.addTest(.{ .root_module = module });
    const catalog = b.dependency("transit_catalog", .{ .target = target, .optimize = optimize });
    const data = b.dependency("transit_data_client", .{ .target = target, .optimize = optimize });
    // Private qualification composition only; the public Station root, ABI and
    // installed runtime do not expose a second writable behavior profile.
    const transactional = b.addModule("station_transaction_internal", .{
        .root_source_file = b.path("src/transactional/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_data_client", .module = data.module("transit_data_client") } },
    });
    const private_tests = b.addTest(.{ .root_module = transactional, .filters = &.{"private transactional"} });
    const private_run = b.addRunArtifact(private_tests);
    b.step("test-transactional", "Prove the private transactional behavior composition").dependOn(&private_run.step);
    const test_step = b.step("test", "Prove Station turns and mailbox protocols");
    const check_step = b.step("check", "Compile standalone package tests without executing them");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    test_step.dependOn(&private_run.step);
    check_step.dependOn(&tests.step);
    check_step.dependOn(&private_tests.step);
}
