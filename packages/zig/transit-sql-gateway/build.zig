const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const query = b.dependency("transit_query", .{ .target = target, .optimize = optimize });
    const catalog = b.dependency("transit_catalog", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sql_gateway", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") } } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check common database wire boundaries").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the shared gateway library").dependOn(&tests.step);
}
