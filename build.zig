const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const adapter = b.dependency("transit_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_ursula") });
    const test_step = b.step("test", "Run Zig unit and protocol tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const transit = b.dependency("transit", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const exporter = b.addExecutable(.{ .name = "transit-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-protocol/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }} }) });
    b.step("contract", "Export public contract JSON Schema to stdout").dependOn(&b.addRunArtifact(exporter).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = protocol.module("transit_protocol") })).step);
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("transit_client") })).step);
    const runtime = b.dependency("runtime_substrate", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = runtime.module("runtime_substrate") })).step);
    const counter = b.createModule(.{
        .root_source_file = b.path("examples/counter.zig"),
        .target = target,
        .optimize = optimize,
    });
    var node_artifact: *std.Build.Step.Compile = undefined;
    var cli_artifact: *std.Build.Step.Compile = undefined;
    const services = b.addSystemCommand(&.{ "python3", "-B" });
    const apps_step = b.step("apps", "Install application executables without storage proof binaries");
    const probe = b.addExecutable(.{ .name = "isolation-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/isolation.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) });
    const install_probe = b.addInstallArtifact(probe, .{});
    b.step("probe", "Install the adversarial reference sandbox executable").dependOn(&install_probe.step);
    test_step.dependOn(&probe.step);
    services.addFileArg(b.path("tests/service.py"));
    for ([_][]const u8{ "transit-node", "transit-worker", "rey-cli", "runtime-controller" }) |name| {
        const app = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("apps/{s}/main.zig", .{name})),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "transit_client", .module = client.module("transit_client") },
            },
        }) });
        if (std.mem.eql(u8, name, "transit-worker")) app.root_module.addImport("counter", counter);
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit", transit.module("transit"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_ursula", adapter.module("transit_ursula"));
        if (std.mem.eql(u8, name, "transit-node")) node_artifact = app;
        if (std.mem.eql(u8, name, "rey-cli")) cli_artifact = app;
        const install = b.addInstallArtifact(app, .{});
        b.getInstallStep().dependOn(&install.step);
        apps_step.dependOn(&install.step);
        if (std.mem.eql(u8, name, "runtime-controller")) app.root_module.addImport("runtime_substrate", runtime.module("runtime_substrate")) else services.addArtifactArg(app);
        if (std.mem.eql(u8, name, "transit-node") and target.result.os.tag == .linux) {
            const clock_c = b.addTranslateC(.{ .root_source_file = b.path("apps/transit-node/clock.h"), .target = target, .optimize = optimize });
            app.root_module.addImport("clock_c", clock_c.createModule());
        }
        test_step.dependOn(&app.step);
    }
    services.has_side_effects = true;
    services.stdio = .inherit;
    const executor = b.addExecutable(.{ .name = "effect-executor", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/effect_executor.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    services.addArtifactArg(executor);
    test_step.dependOn(&executor.step);
    b.step("test-service", "Prove signed ingress and worker recovery over HTTP").dependOn(&services.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = transit.module("transit") })).step);
    const integration = b.addSystemCommand(&.{ "python3", "-B" });
    integration.addFileArg(b.path("tests/storage.py"));
    for ([_][]const u8{ "storage", "kernel", "effects", "lifetime", "outbox", "runtime", "deletion" }) |name| {
        const proof = b.addExecutable(.{
            .name = b.fmt("transit-{s}-proof", .{name}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("tests/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "transit", .module = transit.module("transit") },
                    .{ .name = "transit_ursula", .module = adapter.module("transit_ursula") },
                },
            }),
        });
        b.installArtifact(proof);
        integration.addArtifactArg(proof);
        if (std.mem.eql(u8, name, "deletion")) services.addArtifactArg(proof);
    }
    integration.has_side_effects = true;
    integration.stdio = .inherit;
    b.step("test-storage", "Prove conditional writes and disk recovery against Ursula").dependOn(&integration.step);
    const callers = b.addSystemCommand(&.{ "python3", "-B", "-c", "import sys; sys.path.insert(0, 'tests'); from pathlib import Path; from callers import run; run(*[Path(p).resolve() for p in sys.argv[1:]])" });
    // Both callers use the exact same authority and public CLI artifacts.
    callers.addArtifactArg(node_artifact);
    callers.addArtifactArg(cli_artifact);
    inline for (.{ "accumulator", "byte_log" }) |name| {
        const application = b.createModule(.{ .root_source_file = b.path("examples/" ++ name ++ ".zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }} });
        const caller = b.addExecutable(.{ .name = name ++ "-caller", .root_module = b.createModule(.{ .root_source_file = b.path("tests/caller.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_client", .module = client.module("transit_client") }, .{ .name = "application", .module = application } } }) });
        callers.addArtifactArg(caller);
        test_step.dependOn(&caller.step);
    }
    callers.has_side_effects = true;
    callers.stdio = .inherit;
    b.step("test-callers", "Prove two independent Zig applications against one generic node").dependOn(&callers.step);
    const capacity = b.addExecutable(.{ .name = "transit-capacity-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/capacity.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit", .module = transit.module("transit") },
            .{ .name = "transit_ursula", .module = adapter.module("transit_ursula") },
        },
    }) });
    b.step("capacity-proof", "Install the physical storage pressure proof driver").dependOn(&b.addInstallArtifact(capacity, .{}).step);
    test_step.dependOn(&capacity.step);
}
