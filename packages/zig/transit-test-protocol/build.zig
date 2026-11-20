const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_test_protocol", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_sql_frontend", .module = b.dependency("transit_sql_frontend", .{ .target = target, .optimize = optimize }).module("transit_sql_frontend") },
            .{ .name = "transit_protocol", .module = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol") },
        },
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check compiled-case protocol validation").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile compiled-case protocol tests").dependOn(&tests.step);
}
