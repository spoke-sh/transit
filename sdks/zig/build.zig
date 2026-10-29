const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Re-export the exact shared module instances. Wrapping their source files
    // would create distinct Zig types and duplicate implementation ownership.
    inline for (.{
        "transit_client",
        "transit_protocol",
        "transit_station",
        "transit_station_document",
        "transit_station_http",
        "transit_station_grpc",
        "transit_query",
        "transit_catalog",
        "transit_sql_client",
        "transit_fuze",
        "transit_station_app",
    }) |name| {
        const dependency = b.dependency(name, .{ .target = target, .optimize = optimize });
        b.modules.put(b.allocator, b.dupe(name), dependency.module(name)) catch @panic("out of memory");
    }
    const consumer = b.createModule(.{
        .root_source_file = b.path("tests/consumer.zig"),
        .target = target,
        .optimize = optimize,
    });
    var exports = b.modules.iterator();
    while (exports.next()) |entry| consumer.addImport(entry.key_ptr.*, entry.value_ptr.*);
    const tests = b.addTest(.{ .root_module = consumer });
    b.step("check", "Compile a consumer of the public Zig SDK").dependOn(&tests.step);
    b.step("test", "Check shared type identity across SDK modules").dependOn(&b.addRunArtifact(tests).step);
}
