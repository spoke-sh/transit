const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_spatial", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_protocol", .module = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol") }},
    });
    const filters = b.option([]const []const u8, "test-filter", "Run matching spatial tests") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
    b.step("test", "Verify spatial interpretation and deterministic geometry").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile standalone spatial tests").dependOn(&tests.step);
}
