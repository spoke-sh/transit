//! Compose the exact upstream compiler package with Transit's canonical types.
const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("transitc", .{ .target = target, .optimize = optimize, .embedded = true });
    const compiler = upstream.module("transitc_compiler");
    const workspace = upstream.module("transitc_workspace");
    inline for (.{ "transit_sql_frontend", "transit_protocol", "transit_memory" }) |name| {
        const module = b.dependency(name, .{ .target = target, .optimize = optimize }).module(name);
        compiler.addImport(name, module);
        workspace.addImport(name, module);
    }
    b.modules.put(b.allocator, "transit_compiler", compiler) catch @panic("out of memory");
    b.modules.put(b.allocator, "transit_workspace", workspace) catch @panic("out of memory");
    const check = b.step("check", "Compile the pinned compiler and workspace tests");
    const run = b.step("test", "Run the pinned compiler and workspace tests with Transit types");
    for ([_]*std.Build.Module{ compiler, workspace }) |module| {
        const tests = b.addTest(.{ .root_module = module });
        check.dependOn(&tests.step);
        run.dependOn(&b.addRunArtifact(tests).step);
    }
}
