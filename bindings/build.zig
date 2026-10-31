//! Compose C/C++ package outputs without installing into shared zig-out paths.
const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const runtime_library_path = b.option([]const u8, "fixture-rpath", "Pinned runtime library directory for portable CI fixtures");
    const settings = .{ .target = target, .optimize = optimize };
    const client = b.dependency("client", settings);
    const station = b.dependency("station", settings);
    const examples_c = b.dependency("examples_c", settings);
    const examples_cpp = b.dependency("examples_cpp", settings);
    const Artifact = struct { path: []const u8, compile: *std.Build.Step.Compile };
    const artifacts = [_]Artifact{
        .{ .path = "lib/libtransit_sdk_client.so", .compile = client.artifact("transit_sdk_client") },
        .{ .path = "lib/libtransit_sdk_station.so", .compile = station.artifact("transit_sdk_station") },
        .{ .path = "lib/libtransit_sdk_examples_c.a", .compile = examples_c.artifact("transit_sdk_examples_c") },
        .{ .path = "bin/transit-c-counter", .compile = examples_c.artifact("transit-c-counter") },
        .{ .path = "bin/transit-cpp-counter", .compile = examples_cpp.artifact("transit-cpp-counter") },
    };
    const files = b.addWriteFiles();
    var names: std.array_list.Managed([]const u8) = .init(b.allocator);
    for (artifacts) |artifact| {
        if (runtime_library_path) |path| artifact.compile.root_module.addRPath(.{ .cwd_relative = path });
        _ = files.addCopyFile(artifact.compile.getEmittedBin(), artifact.path);
        names.append(artifact.path) catch @panic("OOM");
    }
    _ = files.addCopyFile(b.dependency("native_client", settings).path("abi-v1.json"), "contracts/client.json");
    _ = files.addCopyFile(b.dependency("native_station", settings).path("abi-v1.json"), "contracts/station.json");
    _ = files.add("build.json", std.json.Stringify.valueAlloc(b.allocator, .{
        .version = 1,
        .set = "c-sdk",
        .optimize = @tagName(optimize),
        .target = target.result.zigTriple(b.allocator) catch @panic("OOM"),
        .cpu = target.query.serializeCpuAlloc(b.allocator) catch @panic("OOM"),
        .resolved_cpu = std.Target.Query.fromTarget(&target.result).serializeCpuAlloc(b.allocator) catch @panic("OOM"),
        .compiler = builtin.zig_version_string,
        .runtime_library_path = runtime_library_path,
        .artifacts = names.items,
    }, .{ .whitespace = .indent_2 }) catch @panic("OOM"));
    const inspect = b.addSystemCommand(&.{ "python3", "-B", "../tests/runner/launch.py", "tests/harness/native_artifacts.py", "inspect" });
    inspect.addDirectoryArg(files.getDirectory());
    inspect.has_side_effects = true;
    inspect.stdio = .inherit;
    b.step("prefix", "Describe immutable C/C++ SDK and example outputs").dependOn(&inspect.step);
}
