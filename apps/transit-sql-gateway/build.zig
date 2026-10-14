const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize });
    inline for (.{ "transit_sql_gateway", "transit_postgres", "transit_mysql", "transit_tls_server", "transit_http_server" }) |name| module.addImport(name, b.dependency(name, .{ .target = target, .optimize = optimize }).module(name));
    const executable = b.addExecutable(.{ .name = "transit-sql-gateway", .root_module = module });
    b.installArtifact(executable);
    b.step("check", "Compile the database gateway").dependOn(&executable.step);
    b.step("test", "Check database application boundary diagnostics").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
