const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transitc_compiler", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize });
    if (!(b.option(bool, "embedded", "Caller supplies canonical SQL, protocol and memory modules") orelse false)) {
        const shared = b.lazyDependency("transit_shared", .{ .target = target, .optimize = optimize }) orelse return;
        inline for (.{ "transit_sql_frontend", "transit_protocol", "transit_memory" }) |name| module.addImport(name, shared.module(name));
    }
    const tests = b.addTest(.{ .root_module = module });
    b.step("check", "Compile pure compiler tests").dependOn(&tests.step);
    b.step("test", "Run compiler ownership, bounds and equivalence checks").dependOn(&b.addRunArtifact(tests).step);
}
