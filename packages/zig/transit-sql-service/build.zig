const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_sql_service", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_sql", .module = b.dependency("transit_sql", .{ .target = target, .optimize = optimize }).module("transit_sql") },
        .{ .name = "transit_query", .module = b.dependency("transit_query", .{ .target = target, .optimize = optimize }).module("transit_query") },
        .{ .name = "transit_memory", .module = b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory") },
    } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("check", "Compile SQL sessions and source composition").dependOn(&tests.step);
    b.step("test", "Test SQL sessions and source composition").dependOn(&b.addRunArtifact(tests).step);
}
