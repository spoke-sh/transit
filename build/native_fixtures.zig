//! Immutable native fixture prefixes owned by Zig's content-addressed build cache.
const std = @import("std");
const builtin = @import("builtin");
const Runtime = @import("runtime.zig").Context;

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, runtime: Runtime) void {
    const Artifact = struct { path: []const u8, compile: *std.Build.Step.Compile };
    const clients = [_]Artifact{
        .{ .path = "lib/libtransit_client.so", .compile = runtime.client.artifact("transit_client") },
        .{ .path = "lib/libtransit_station.so", .compile = runtime.station_bindings.artifact("transit_station") },
        .{ .path = "bin/transit-client-host", .compile = runtime.client_host },
        .{ .path = "bin/transit-station-host", .compile = runtime.station_host },
        .{ .path = "bin/transit-admin", .compile = runtime.cli_artifact },
        .{ .path = "bin/transit-station-http-worker", .compile = runtime.http_worker },
        .{ .path = "bin/transit-station-grpc-worker", .compile = runtime.grpc_worker },
    };
    const authority = [_]Artifact{.{ .path = "bin/transit-node", .compile = runtime.node_artifact }};
    inline for (.{ .{ "clients", &clients }, .{ "authority", &authority } }) |set| {
        const files = b.addWriteFiles();
        var names: std.array_list.Managed([]const u8) = .init(b.allocator);
        for (set[1]) |artifact| {
            _ = files.addCopyFile(artifact.compile.getEmittedBin(), artifact.path);
            names.append(artifact.path) catch @panic("OOM");
        }
        _ = files.addCopyFile(b.path("packages/zig/transit-client/abi-v1.json"), "contracts/client.json");
        _ = files.addCopyFile(b.path("packages/zig/transit-station-bindings/abi-v1.json"), "contracts/station.json");
        const metadata = std.json.Stringify.valueAlloc(b.allocator, .{
            .version = 1,
            .set = set[0],
            .optimize = @tagName(optimize),
            .target = target.result.zigTriple(b.allocator) catch @panic("OOM"),
            .cpu = target.query.serializeCpuAlloc(b.allocator) catch @panic("OOM"),
            .resolved_cpu = std.Target.Query.fromTarget(&target.result).serializeCpuAlloc(b.allocator) catch @panic("OOM"),
            .compiler = builtin.zig_version_string,
            .artifacts = names.items,
        }, .{ .whitespace = .indent_2 }) catch @panic("OOM");
        _ = files.add("build.json", metadata);
        const inspect = b.addSystemCommand(&.{ "python3", "-B" });
        inspect.addFileArg(b.path("tests/runner/launch.py"));
        inspect.addFileArg(b.path("tests/harness/native_artifacts.py"));
        inspect.addArg("inspect");
        inspect.addDirectoryArg(files.getDirectory());
        inspect.has_side_effects = true;
        inspect.stdio = .inherit;
        b.step(b.fmt("fixture-{s}", .{set[0]}), "Describe immutable native fixture artifacts").dependOn(&inspect.step);
    }
}
