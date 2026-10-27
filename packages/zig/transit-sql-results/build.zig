const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_sql_results", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_fuze", .module = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize }).module("transit_fuze") },
            .{ .name = "transit_protocol", .module = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol") },
        },
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Verify logical result invariants and communication independence").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the standalone result model").dependOn(&tests.step);
}
