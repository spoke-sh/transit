const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_sql_frontend", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    inline for (.{ "transit_memory", "transit_protocol", "transit_spatial" }) |name| {
        module.addImport(name, b.dependency(name, .{ .target = target, .optimize = optimize }).module(name));
    }
    const tests = b.addTest(.{ .root_module = module });
    b.step("check", "Compile shared SQL frontend tests").dependOn(&tests.step);
    b.step("test", "Check pure SQL syntax, types and binding").dependOn(&b.addRunArtifact(tests).step);
}
