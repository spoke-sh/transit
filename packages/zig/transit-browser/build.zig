const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_browser", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .link_libc = true });
    inline for (.{ "transit_http_server", "transit_sql_client", "transit_memory" }) |name| module.addImport(name, b.dependency(name, .{ .target = target, .optimize = optimize }).module(name));
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test browser authentication and origin boundaries").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the browser gateway").dependOn(&tests.step);
}
