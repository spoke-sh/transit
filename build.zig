const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Standalone consumers select only the shared pure language/value modules.
    // No runtime registration or executable is reachable through this profile.
    if (b.option(bool, "frontend-only", "Export pure SQL and value modules only") orelse false) {
        inline for (.{ "transit_sql_frontend", "transit_protocol", "transit_memory", "transit_spatial" }) |name| {
            b.modules.put(b.allocator, b.dupe(name), b.dependency(name, .{ .target = target, .optimize = optimize }).module(name)) catch @panic("out of memory");
        }
        return;
    }
    const checks = b.option(bool, "checks", "Register cross-component checks, examples and development exporters") orelse true;
    const runtime = @import("build/runtime.zig").register(b, target, optimize);
    if (checks) @import("build/checks.zig").register(b, target, optimize, runtime);
}
