const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_document_profiles", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }},
    });
    const filters = b.option([]const []const u8, "test-filter", "Run selected profile tests") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
    b.step("test", "Verify pure bounded Document profiles").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile Document profiles and their independent tests").dependOn(&tests.step);
}
