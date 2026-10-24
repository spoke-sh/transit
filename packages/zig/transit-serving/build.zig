const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_serving", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_query", .module = b.dependency("transit_query", .{ .target = target, .optimize = optimize }).module("transit_query") } } });
    const filters = b.option([]const []const u8, "test-filter", "Run matching service tests") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
    b.step("test", "Qualify service admission and scoped recovery").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the serving package").dependOn(&tests.step);
}
