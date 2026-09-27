const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exchange = b.dependency("transit_exchange", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_station_http", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_exchange", .module = exchange.module("transit_exchange") }, .{ .name = "transit_tls", .module = b.dependency("transit_tls", .{ .target = target, .optimize = optimize }).module("transit_tls") } } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check HTTP framing, capture and scope").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile HTTP connector").dependOn(&tests.step);
}
