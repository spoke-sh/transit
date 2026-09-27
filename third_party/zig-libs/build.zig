const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const entries = .{
        .{ "testkit", .{} },
        .{ "montint", .{} },
        .{ "rsa", .{"montint"} },
        .{ "slhdsa", .{} },
        .{ "x509", .{ "rsa", "slhdsa" } },
        .{ "http", .{} },
        .{ "protobuf", .{} },
        .{ "grpc", .{ "http", "protobuf" } },
    };
    const tests = b.step("test", "Check selected pinned dependency modules");
    const rpc_tests = b.step("test-rpc", "Check HTTP/2 client, protobuf and gRPC modules");
    inline for (entries) |entry| {
        const module = b.addModule(entry[0], .{ .root_source_file = b.path("modules/" ++ entry[0] ++ "/src/root.zig"), .target = target, .optimize = optimize });
        inline for (entry[1]) |dependency| module.addImport(dependency, b.modules.get(dependency).?);
        if (!std.mem.eql(u8, entry[0], "testkit")) module.addImport("testkit", b.modules.get("testkit").?);
        const suite = &b.addRunArtifact(b.addTest(.{ .root_module = module })).step;
        tests.dependOn(suite);
        if (std.mem.eql(u8, entry[0], "http") or std.mem.eql(u8, entry[0], "protobuf") or std.mem.eql(u8, entry[0], "grpc")) rpc_tests.dependOn(suite);
    }
}
