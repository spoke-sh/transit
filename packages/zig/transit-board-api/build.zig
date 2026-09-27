const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_board_api", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_grpc", .module = b.dependency("transit_station_grpc", .{ .target = target, .optimize = optimize }).module("transit_station_grpc") }, .{ .name = "transit_station_http", .module = b.dependency("transit_station_http", .{ .target = target, .optimize = optimize }).module("transit_station_http") }, .{ .name = "transit_exchange", .module = b.dependency("transit_exchange", .{ .target = target, .optimize = optimize }).module("transit_exchange") }, .{ .name = "transit_query", .module = b.dependency("transit_query", .{ .target = target, .optimize = optimize }).module("transit_query") }, .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }, .{ .name = "transit_station", .module = station.module("transit_station") } } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test Board projections and lenses").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile standalone package tests without executing them").dependOn(&tests.step);
}
