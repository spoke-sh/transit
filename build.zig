const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const observations = b.dependency("transit_observability", .{ .target = target, .optimize = optimize });
    const telemetry = b.dependency("telemetry", .{ .target = target, .optimize = optimize });
    const adapter = b.dependency("transit_backend_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_backend_ursula") });
    const test_step = b.step("test", "Run Zig unit and protocol tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = telemetry.module("telemetry") })).step);
    const telemetry_proof = b.addExecutable(.{ .name = "telemetry-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/telemetry.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "telemetry", .module = telemetry.module("telemetry") }},
    }) });
    const telemetry_test = b.addSystemCommand(&.{ "python3", "-B" });
    telemetry_test.addFileArg(b.path("tests/telemetry.py"));
    telemetry_test.addArtifactArg(telemetry_proof);
    telemetry_test.has_side_effects = true;
    telemetry_test.stdio = .inherit;
    b.step("test-telemetry", "Prove bounded telemetry under stalled and closed sinks").dependOn(&telemetry_test.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = observations.module("transit_observability") })).step);
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const exporter = b.addExecutable(.{ .name = "transit-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-protocol/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }} }) });
    b.step("contract", "Export public contract JSON Schema to stdout").dependOn(&b.addRunArtifact(exporter).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = protocol.module("transit_protocol") })).step);
    const transit_board_api = b.dependency("transit_board_api", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = transit_board_api.module("transit_board_api") })).step);
    const board_contract = b.addExecutable(.{ .name = "transit-board-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-board-api/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_board_api", .module = transit_board_api.module("transit_board_api") }} }) });
    b.step("transit-board-contract", "Export Board OpenAPI to stdout").dependOn(&b.addRunArtifact(board_contract).step);
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("transit_client") })).step);
    const embed = b.addSystemCommand(&.{ "python3", "-B" });
    embed.addFileArg(b.path("apps/transit-board/embed.py"));
    const asset_source = embed.addOutputFileArg("assets.zig");
    // Vite owns its dependency graph. Always rebuild the closed asset manifest;
    // Zig still caches compilation by the resulting bytes.
    embed.has_side_effects = true;
    const asset_module = b.createModule(.{ .root_source_file = asset_source, .target = target, .optimize = optimize });
    const board = b.addExecutable(.{ .name = "transit-board", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-board/main.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_client", .module = client.module("transit_client") },
        .{ .name = "transit_board_api", .module = transit_board_api.module("transit_board_api") },
        .{ .name = "assets", .module = asset_module },
        .{ .name = "telemetry", .module = telemetry.module("telemetry") },
    } }) });
    const install_board = b.addInstallArtifact(board, .{});
    b.step("transit-board", "Build the standalone Board API and embedded UI").dependOn(&install_board.step);
    b.getInstallStep().dependOn(&install_board.step);
    b.step("test-transit-board-unit", "Test Board ingress and route boundaries").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = board.root_module })).step);
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
                .{ .name = "transit_observability", .module = observations.module("transit_observability") },
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
    const board_tests = b.addSystemCommand(&.{ "python3", "-B" });
    board_tests.addFileArg(b.path("tests/board.py"));
    board_tests.addArtifactArg(node_artifact);
    board_tests.addArtifactArg(cli_artifact);
    board_tests.addArtifactArg(board);
    if (b.option(bool, "transit-board-browser", "Include real browser qualification") orelse false) board_tests.addArg("--browser");
    board_tests.has_side_effects = true;
    board_tests.stdio = .inherit;
    b.step("test-transit-board", "Qualify Board against disk-backed Transit").dependOn(&board_tests.step);
    const observation_tests = b.addSystemCommand(&.{ "python3", "-B" });
    observation_tests.addFileArg(b.path("tests/observability.py"));
    observation_tests.addArtifactArg(node_artifact);
    observation_tests.addArtifactArg(cli_artifact);
    observation_tests.addArtifactArg(board);
    observation_tests.has_side_effects = true;
    observation_tests.stdio = .inherit;
    b.step("test-observability", "Prove cross-service correlation and diagnostic semantics").dependOn(&observation_tests.step);
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
