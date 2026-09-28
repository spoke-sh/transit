const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_flight", .module = b.dependency("transit_flight", .{ .target = target, .optimize = optimize }).module("transit_flight") }} });
    const executable = b.addExecutable(.{ .name = "transit-flight-gateway", .root_module = module });
    b.installArtifact(executable);
    b.step("check", "Compile the Flight gateway entry point").dependOn(&executable.step);
}
