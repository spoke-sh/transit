const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const adapter = b.dependency("transit_backend_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_backend_ursula") });
    const test_step = b.step("test", "Run Zig unit and protocol tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const exporter = b.addExecutable(.{ .name = "transit-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-protocol/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }} }) });
    b.step("contract", "Export public contract JSON Schema to stdout").dependOn(&b.addRunArtifact(exporter).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = protocol.module("transit_protocol") })).step);
    const board_api = b.dependency("board_api", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = board_api.module("board_api") })).step);
    const board_contract = b.addExecutable(.{ .name = "board-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/board-api/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "board_api", .module = board_api.module("board_api") }} }) });
    b.step("board-contract", "Export Board OpenAPI to stdout").dependOn(&b.addRunArtifact(board_contract).step);
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("transit_client") })).step);
    const runtime = b.dependency("transit_runtime_substrate", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = runtime.module("transit_runtime_substrate") })).step);
    var node_artifact: *std.Build.Step.Compile = undefined;
    var cli_artifact: *std.Build.Step.Compile = undefined;
    const services = b.addSystemCommand(&.{ "python3", "-B" });
    const apps_step = b.step("apps", "Install platform executables");
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
    for ([_][]const u8{ "transit-node", "rey-cli", "transit-runtime-controller" }) |name| {
        const app = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("apps/{s}/main.zig", .{name})),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "transit_client", .module = client.module("transit_client") },
            },
        }) });
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_core", core.module("transit_core"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_backend_ursula", adapter.module("transit_backend_ursula"));
        if (std.mem.eql(u8, name, "transit-node")) node_artifact = app;
        if (std.mem.eql(u8, name, "rey-cli")) cli_artifact = app;
        const install = b.addInstallArtifact(app, .{});
        b.getInstallStep().dependOn(&install.step);
        apps_step.dependOn(&install.step);
        if (std.mem.eql(u8, name, "transit-runtime-controller")) app.root_module.addImport("transit_runtime_substrate", runtime.module("transit_runtime_substrate"));
        if (std.mem.eql(u8, name, "transit-node") and target.result.os.tag == .linux) {
            const clock_c = b.addTranslateC(.{ .root_source_file = b.path("apps/transit-node/clock.h"), .target = target, .optimize = optimize });
            app.root_module.addImport("clock_c", clock_c.createModule());
        }
        test_step.dependOn(&app.step);
    }
    const examples_step = b.step("examples", "Install runnable example applications");
    var example_artifacts: [2]*std.Build.Step.Compile = undefined;
    inline for (.{ "counter", "byte-log" }, 0..) |name, index| {
        const example = b.addExecutable(.{ .name = "example-" ++ name, .root_module = b.createModule(.{
            .root_source_file = b.path("examples/" ++ name ++ "/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
        }) });
        example_artifacts[index] = example;
        examples_step.dependOn(&b.addInstallArtifact(example, .{}).step);
        test_step.dependOn(&example.step);
    }
    services.addArtifactArg(node_artifact);
    services.addArtifactArg(example_artifacts[0]);
    services.addArtifactArg(cli_artifact);
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
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = core.module("transit_core") })).step);
    const integration = b.addSystemCommand(&.{ "python3", "-B" });
    integration.addFileArg(b.path("tests/storage.py"));
    const proofs_step = b.step("proofs", "Install disk conformance proof executables");
    for ([_][]const u8{ "storage", "kernel", "effects", "lifetime", "outbox", "runtime", "deletion" }) |name| {
        const proof = b.addExecutable(.{
            .name = b.fmt("transit-{s}-proof", .{name}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("tests/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "transit_core", .module = core.module("transit_core") },
                    .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
                },
            }),
        });
        proofs_step.dependOn(&b.addInstallArtifact(proof, .{}).step);
        integration.addArtifactArg(proof);
        if (std.mem.eql(u8, name, "deletion")) services.addArtifactArg(proof);
    }
    integration.has_side_effects = true;
    integration.stdio = .inherit;
    b.step("test-storage", "Prove conditional writes and disk recovery against Ursula").dependOn(&integration.step);
    const inspection = b.addSystemCommand(&.{ "python3", "-B" });
    inspection.addFileArg(b.path("tests/inspection.py"));
    inspection.addArtifactArg(node_artifact);
    inspection.addArtifactArg(cli_artifact);
    inspection.has_side_effects = true;
    inspection.stdio = .inherit;
    b.step("test-inspection", "Prove scoped public inspection against disk Ursula").dependOn(&inspection.step);
    const callers = b.addSystemCommand(&.{ "python3", "-B", "-c", "import sys; sys.path.insert(0, 'tests'); from pathlib import Path; from callers import run; run(*[Path(p).resolve() for p in sys.argv[1:]])" });
    // Both callers use the exact same authority and public CLI artifacts.
    callers.addArtifactArg(node_artifact);
    callers.addArtifactArg(cli_artifact);
    for (example_artifacts) |example| callers.addArtifactArg(example);
    const client_probe = b.addExecutable(.{ .name = "client-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/client_probe.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    callers.addArtifactArg(client_probe);
    test_step.dependOn(&client_probe.step);
    callers.has_side_effects = true;
    callers.stdio = .inherit;
    b.step("test-callers", "Prove two independent Zig applications against one generic node").dependOn(&callers.step);
    const capacity = b.addExecutable(.{ .name = "transit-capacity-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/capacity.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_core", .module = core.module("transit_core") },
            .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
        },
    }) });
    b.step("capacity-proof", "Install the physical storage pressure proof driver").dependOn(&b.addInstallArtifact(capacity, .{}).step);
    test_step.dependOn(&capacity.step);
}
