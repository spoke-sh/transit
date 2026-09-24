const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_client", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_observability", .module = b.dependency("transit_observability", .{ .target = target, .optimize = optimize }).module("transit_observability") }, .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") } },
    });
    b.step("test", "Check the protocol client").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
