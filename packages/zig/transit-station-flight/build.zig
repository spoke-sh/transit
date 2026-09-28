const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_station_flight", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_flight", .module = b.dependency("transit_flight", .{ .target = target, .optimize = optimize }).module("transit_flight") },
        .{ .name = "transit_station_grpc", .module = b.dependency("transit_station_grpc", .{ .target = target, .optimize = optimize }).module("transit_station_grpc") },
    } });
    const unit = b.addTest(.{ .root_module = module });
    b.step("check", "Compile recorded Flight adapter").dependOn(&unit.step);
    b.step("test", "Test recorded Flight adapter").dependOn(&b.addRunArtifact(unit).step);
}
