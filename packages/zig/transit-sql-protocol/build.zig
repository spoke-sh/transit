const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sql_protocol", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") } } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test SQL session messages, logical cells and authentication").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile SQL session contract").dependOn(&tests.step);
    const generator = b.addExecutable(.{ .name = "transit-sql-contract", .root_module = b.createModule(.{ .root_source_file = b.path("src/schema.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_sql_protocol", .module = module }} }) });
    b.step("schema", "Write reflected SQL session contract to stdout").dependOn(&b.addRunArtifact(generator).step);
}
