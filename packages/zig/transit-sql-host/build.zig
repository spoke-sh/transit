const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_sql_host", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize });
    inline for (.{ "transit_memory", "transit_io", "transit_sql_client", "transit_sql_service", "transit_postgres", "transit_mysql", "transit_tls_server", "transit_http_server" }) |name| module.addImport(name, b.dependency(name, .{ .target = target, .optimize = optimize }).module(name));
    const tests = b.addTest(.{ .root_module = module });
    b.step("check", "Compile shared SQL hosting").dependOn(&tests.step);
    b.step("test", "Verify shared SQL hosting and ownership").dependOn(&b.addRunArtifact(tests).step);
}
