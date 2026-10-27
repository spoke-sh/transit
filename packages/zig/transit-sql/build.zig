const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_sql_protocol", .{ .target = target, .optimize = optimize });
    const query = b.dependency("transit_query", .{ .target = target, .optimize = optimize });
    const catalog = b.dependency("transit_catalog", .{ .target = target, .optimize = optimize });
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sql", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_sql_results", .module = b.dependency("transit_sql_results", .{ .target = target, .optimize = optimize }).module("transit_sql_results") }, .{ .name = "transit_sql_protocol", .module = protocol.module("transit_sql_protocol") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") } } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test shared SQL sessions and account recovery").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the shared SQL runtime").dependOn(&tests.step);
}
