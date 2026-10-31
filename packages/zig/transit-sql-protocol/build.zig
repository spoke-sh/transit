const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const results = b.dependency("transit_sql_results", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sql_protocol", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") } } });
    const tests = b.addTest(.{ .root_module = module });
    module.addImport("transit_sql_results", results.module("transit_sql_results"));
    module.addImport("transit_memory", b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory"));
    requireSansIo(b, module);
    b.step("test", "Test SQL session messages, logical cells and authentication").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile SQL session contract").dependOn(&tests.step);
    const generator = b.addExecutable(.{ .name = "transit-sql-contract", .root_module = b.createModule(.{ .root_source_file = b.path("src/schema.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_sql_protocol", .module = module }} }) });
    b.installArtifact(generator);
    b.step("schema", "Write reflected SQL session contract to stdout").dependOn(&b.addRunArtifact(generator).step);
}

/// Pure codecs may share logical types and byte storage, never runtime owners.
/// Walk imports directly: caching the module graph during dependency setup can
/// hide imports that the enclosing build still needs to add.
pub fn requireSansIo(b: *std.Build, root: *std.Build.Module) void {
    var modules: std.AutoArrayHashMapUnmanaged(*std.Build.Module, void) = .empty;
    modules.put(b.allocator, root, {}) catch @panic("OOM");
    var index: usize = 0;
    while (index < modules.count()) : (index += 1) {
        const module = modules.keys()[index];
        for (module.import_table.keys(), module.import_table.values()) |name, dependency| {
            inline for (.{ "transit_station", "transit_storage", "transit_client", "transit_data_client", "transit_io", "transit_tls", "transit_http", "transit_sql_service", "transit_sql_host", "transit_query_direct", "transit_catalog" }) |forbidden| {
                if (std.mem.startsWith(u8, name, forbidden))
                    @panic("sans-I/O wire codecs must not depend on runtime or transport owners");
            }
            if (std.mem.eql(u8, name, "transit_sql"))
                @panic("sans-I/O wire codecs must not depend on SQL execution");
            modules.put(b.allocator, dependency, {}) catch @panic("OOM");
        }
    }
}
