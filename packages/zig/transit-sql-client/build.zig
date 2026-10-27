const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_sql_protocol", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sql_client", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .link_libc = true, .imports = &.{.{ .name = "transit_sql_protocol", .module = protocol.module("transit_sql_protocol") }} });
    module.addImport("transit_sql_results", b.dependency("transit_sql_results", .{ .target = target, .optimize = optimize }).module("transit_sql_results"));
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test native SQL session client and local discovery").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the native SQL client").dependOn(&tests.step);
}
