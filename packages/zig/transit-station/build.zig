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
    const test_step = b.step("test", "Prove Station turns and mailbox protocols");
    const check_step = b.step("check", "Compile standalone package tests without executing them");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    check_step.dependOn(&tests.step);
}
