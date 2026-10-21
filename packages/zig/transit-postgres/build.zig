const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const gateway = b.dependency("transit_sql", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_postgres", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_sql", .module = gateway.module("transit_sql") }} });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check database frames and session admission").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the database adapter").dependOn(&tests.step);
}
