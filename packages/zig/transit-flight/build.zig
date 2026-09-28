const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_flight", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_grpc", .module = b.dependency("transit_grpc", .{ .target = target, .optimize = optimize }).module("transit_grpc") },
        .{ .name = "transit_query", .module = b.dependency("transit_query", .{ .target = target, .optimize = optimize }).module("transit_query") },
        .{ .name = "transit_serving", .module = b.dependency("transit_serving", .{ .target = target, .optimize = optimize }).module("transit_serving") },
    } });
    const fixture = b.addExecutable(.{ .name = "flight-metadata-fixture", .root_module = b.createModule(.{ .root_source_file = b.path("src/metadata_fixture.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_flight", .module = module }} }) });
    b.installArtifact(fixture);
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Qualify Flight wire and finite gateway contracts").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the Flight package").dependOn(&tests.step);
}
