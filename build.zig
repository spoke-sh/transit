const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const checks = b.option(bool, "checks", "Register cross-component checks, examples and development exporters") orelse true;
    const runtime = @import("build/runtime.zig").register(b, target, optimize);
    if (checks) @import("build/checks.zig").register(b, target, optimize, runtime);
}
