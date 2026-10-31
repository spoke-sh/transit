const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_sql_protocol", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_mysql", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_sql_protocol", .module = protocol.module("transit_sql_protocol") }} });
    @import("transit_sql_protocol").requireSansIo(b, module);
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check pure database frames and admission").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the database adapter").dependOn(&tests.step);
}
