const std = @import("std");
pub fn build(b: *std.Build) void {
    const options = .{ .target = b.standardTargetOptions(.{}), .optimize = b.standardOptimizeOption(.{}) };
    const module = b.addModule("transit_observability", .{
        .root_source_file = b.path("src/root.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "telemetry", .module = b.dependency("telemetry", options).module("telemetry") },
            .{ .name = "transit_protocol", .module = b.dependency("transit_protocol", options).module("transit_protocol") },
        },
    });
    b.step("test", "Test Transit instrumentation semantics").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
