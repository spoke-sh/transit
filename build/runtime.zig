//! Runtime applications and their shared build objects. No test or SDK source.
const std = @import("std");

pub const Context = struct {
    http_server: *std.Build.Dependency,
    serving_http: *std.Build.Dependency,
    application: *std.Build.Dependency,
    serving: *std.Build.Dependency,
    web_dependencies: *std.Build.Step.Run,
    document: *std.Build.Dependency,
    station_grpc: *std.Build.Dependency,
    station_flight: *std.Build.Dependency,
    flight: *std.Build.Dependency,
    grpc: *std.Build.Dependency,
    exchange: *std.Build.Dependency,
    station_http: *std.Build.Dependency,
    fuze: *std.Build.Dependency,
    query: *std.Build.Dependency,
    sql_client: *std.Build.Dependency,
    sql_gateway: *std.Build.Dependency,
    tls_server: *std.Build.Dependency,
    sql_gateway_app: *std.Build.Step.Compile,
    catalog: *std.Build.Dependency,
    station: *std.Build.Dependency,
    station_bindings: *std.Build.Dependency,
    observations: *std.Build.Dependency,
    telemetry: *std.Build.Dependency,
    storage: *std.Build.Dependency,
    local_backend: *std.Build.Dependency,
    adapter: *std.Build.Dependency,
    core: *std.Build.Dependency,
    protocol: *std.Build.Dependency,
    transit_board_api: *std.Build.Dependency,
    client: *std.Build.Dependency,
    sql_protocol: *std.Build.Dependency,
    board: *std.Build.Step.Compile,
    runtime: *std.Build.Dependency,
    node_artifact: *std.Build.Step.Compile,
    cli_artifact: *std.Build.Step.Compile,
    delivery_artifact: *std.Build.Step.Compile,
    controller_artifact: *std.Build.Step.Compile,
    kubectl_transit: *std.Build.Step.Compile,
    station_controller: *std.Build.Step.Compile,
    station_host: *std.Build.Step.Compile,
    client_host: *std.Build.Step.Compile,
    query_host: *std.Build.Step.Compile,
    document_worker: *std.Build.Step.Compile,
    grpc_worker: *std.Build.Step.Compile,
    http_worker: *std.Build.Step.Compile,
    grpc_bindings: *std.Build.Step.Compile,
    transit_cli: *std.Build.Step.Compile,
    flight_gateway: *std.Build.Step.Compile,
};

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Context {
    const http_server = b.dependency("transit_http_server", .{ .target = target, .optimize = optimize });
    const serving_http = b.dependency("transit_serving_http", .{ .target = target, .optimize = optimize });
    const application = b.dependency("transit_station_app", .{ .target = target, .optimize = optimize });
    const install_app = b.addInstallArtifact(application.artifact("transit-app"), .{});
    b.step("transit-app", "Install the bounded application declaration compiler").dependOn(&install_app.step);
    const serving = b.dependency("transit_serving", .{ .target = target, .optimize = optimize });
    const serving_api = b.addExecutable(.{ .name = "transit-serving-api", .root_module = b.createModule(.{
        .root_source_file = b.path("packages/zig/transit-serving/src/export.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_serving", .module = serving.module("transit_serving") }},
    }) });
    b.step("serving-api", "Export reflected OpenAPI and AsyncAPI descriptions").dependOn(&b.addInstallArtifact(serving_api, .{}).step);
    // All embedded frontends share one workspace install before Vite runs.
    // Recheck the lockfile on each build, including after manifests change.
    const web_dependencies = b.addSystemCommand(&.{ "vp", "install", "--frozen-lockfile" });
    web_dependencies.setCwd(b.path("."));
    web_dependencies.has_side_effects = true;
    web_dependencies.stdio = .inherit;
    const document = b.dependency("transit_station_document", .{ .target = target, .optimize = optimize });
    const station_grpc = b.dependency("transit_station_grpc", .{ .target = target, .optimize = optimize });
    const station_flight = b.dependency("transit_station_flight", .{ .target = target, .optimize = optimize });
    const flight = b.dependency("transit_flight", .{ .target = target, .optimize = optimize });
    const grpc = b.dependency("transit_grpc", .{ .target = target, .optimize = optimize });
    const exchange = b.dependency("transit_exchange", .{ .target = target, .optimize = optimize });
    const station_http = b.dependency("transit_station_http", .{ .target = target, .optimize = optimize });
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const query = b.dependency("transit_query", .{ .target = target, .optimize = optimize });
    const sql_client = b.dependency("transit_sql_client", .{ .target = target, .optimize = optimize });
    const sql_host = b.dependency("transit_sql_host", .{ .target = target, .optimize = optimize });
    const sql_gateway = b.dependency("transit_sql_service", .{ .target = target, .optimize = optimize });
    const tls_server = b.dependency("transit_tls_server", .{ .target = target, .optimize = optimize });
    const sql_gateway_app = b.dependency("transit_sql_gateway_app", .{ .target = target, .optimize = optimize }).artifact("transit-sql-gateway");
    const catalog = b.dependency("transit_catalog", .{ .target = target, .optimize = optimize });
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const station_bindings = b.dependency("transit_station_bindings", .{ .target = target, .optimize = optimize });
    const observations = b.dependency("transit_observability", .{ .target = target, .optimize = optimize });
    const telemetry = b.dependency("telemetry", .{ .target = target, .optimize = optimize });
    const storage = b.dependency("transit_storage", .{ .target = target, .optimize = optimize });
    const local_backend = b.dependency("transit_backend_local", .{ .target = target, .optimize = optimize });
    const adapter = b.dependency("transit_backend_ursula", .{ .target = target, .optimize = optimize });
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const transit_board_api = b.dependency("transit_board_api", .{ .target = target, .optimize = optimize });
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    const sql_protocol = b.dependency("transit_sql_protocol", .{ .target = target, .optimize = optimize });
    const sql_read_schema = b.addExecutable(.{ .name = "transit-sql-read-api", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-sql-client/src/read_schema.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_sql_client", .module = sql_client.module("transit_sql_client") }} }) });
    b.step("sql-read-api", "Export the shared browser statement reader").dependOn(&b.addRunArtifact(sql_read_schema).step);
    const asset_source: std.Build.LazyPath = if (b.option([]const u8, "board-assets", "Prebuilt closed Board asset module")) |path| .{ .cwd_relative = path } else assets: {
        const embed = b.addSystemCommand(&.{ "python3", "-B" });
        embed.addFileArg(b.path("tasks/embed_web.py"));
        const source = embed.addOutputFileArg("assets.zig");
        embed.addArgs(&.{ "apps/transit-board-web", "contracts/transit-board-v1.openapi.json" });
        // Vite owns its dependency graph; Zig caches the resulting asset bytes.
        embed.has_side_effects = true;
        embed.step.dependOn(&web_dependencies.step);
        break :assets source;
    };
    const asset_module = b.createModule(.{ .root_source_file = asset_source, .target = target, .optimize = optimize });
    const board = b.addExecutable(.{ .name = "transit-board", .root_module = b.addModule("transit_board_role", .{ .root_source_file = b.path("apps/transit-board/main.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_station_app", .module = application.module("transit_station_app") },
        .{ .name = "transit_serving_http", .module = serving_http.module("transit_serving_http") },
        .{ .name = "transit_http_server", .module = http_server.module("transit_http_server") },
        .{ .name = "transit_query", .module = query.module("transit_query") },
        .{ .name = "transit_client", .module = client.module("transit_client") },
        .{ .name = "transit_board_api", .module = transit_board_api.module("transit_board_api") },
        .{ .name = "transit_sql_client", .module = sql_client.module("transit_sql_client") },
        .{ .name = "assets", .module = asset_module },
        .{ .name = "telemetry", .module = telemetry.module("telemetry") },
    } }) });
    const install_board = b.addInstallArtifact(board, .{});
    b.step("transit-board", "Build the standalone Board API and embedded UI").dependOn(&install_board.step);
    b.getInstallStep().dependOn(&install_board.step);
    const runtime = b.dependency("transit_runtime_substrate", .{ .target = target, .optimize = optimize });
    var node_artifact: *std.Build.Step.Compile = undefined;
    var cli_artifact: *std.Build.Step.Compile = undefined;
    var delivery_artifact: *std.Build.Step.Compile = undefined;
    var controller_artifact: *std.Build.Step.Compile = undefined;
    const apps_step = b.step("apps", "Install platform executables");
    const kubectl_transit = b.addExecutable(.{ .name = "kubectl-transit", .root_module = b.createModule(.{
        .root_source_file = b.path("apps/kubectl-transit/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    const install_plugin = b.addInstallArtifact(kubectl_transit, .{});
    apps_step.dependOn(&install_plugin.step);
    b.getInstallStep().dependOn(&install_plugin.step);
    b.step("kubectl-transit", "Install the Kubernetes inspection plugin").dependOn(&install_plugin.step);
    var station_controller: *std.Build.Step.Compile = undefined;
    var station_host: *std.Build.Step.Compile = undefined;
    var client_host: *std.Build.Step.Compile = undefined;
    for ([_][]const u8{ "transit-node", "transit-admin", "transit-runtime-controller", "transit-delivery", "transit-station-controller", "transit-station-host", "transit-client-host" }) |name| {
        const app = b.addExecutable(.{ .name = name, .root_module = b.addModule(name, .{
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
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_catalog", catalog.module("transit_catalog"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_memory", b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_io", b.dependency("transit_io", .{ .target = target, .optimize = optimize }).module("transit_io"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_backend_ursula", adapter.module("transit_backend_ursula"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_backend_local", local_backend.module("transit_backend_local"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_http_server", http_server.module("transit_http_server"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_serving_http", serving_http.module("transit_serving_http"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_sql_host", sql_host.module("transit_sql_host"));
        if (std.mem.eql(u8, name, "transit-node")) node_artifact = app;
        if (std.mem.eql(u8, name, "transit-admin")) app.root_module.addImport("transit_catalog", catalog.module("transit_catalog"));
        if (std.mem.eql(u8, name, "transit-admin")) cli_artifact = app;
        if (std.mem.eql(u8, name, "transit-delivery")) delivery_artifact = app;
        if (std.mem.eql(u8, name, "transit-runtime-controller")) controller_artifact = app;
        const install = b.addInstallArtifact(app, .{});
        b.getInstallStep().dependOn(&install.step);
        apps_step.dependOn(&install.step);
        b.step(name, b.fmt("Install {s}", .{name})).dependOn(&install.step);
        if (std.mem.eql(u8, name, "transit-runtime-controller")) app.root_module.addImport("transit_runtime_substrate", runtime.module("transit_runtime_substrate"));
        if (std.mem.eql(u8, name, "transit-station-controller")) {
            app.root_module.addImport("transit_station", station.module("transit_station"));
            station_controller = app;
        }
        if (std.mem.eql(u8, name, "transit-station-host")) {
            station_host = app;
            app.root_module.addImport("transit_station", station.module("transit_station"));
            app.root_module.addImport("station_abi", station_bindings.module("station_abi"));
            app.root_module.addImport("client_abi", client.module("client_abi"));
        }
        if (std.mem.eql(u8, name, "transit-client-host")) {
            client_host = app;
            app.root_module.addImport("client_abi", client.module("client_abi"));
        }
        if (std.mem.eql(u8, name, "transit-node") and target.result.os.tag == .linux) {
            const clock_c = b.addTranslateC(.{ .root_source_file = b.path("apps/transit-node/clock.h"), .target = target, .optimize = optimize });
            app.root_module.addImport("clock_c", clock_c.createModule());
        }
    }
    var query_host: *std.Build.Step.Compile = undefined;
    const document_worker = b.addExecutable(.{ .name = "transit-station-document-worker", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-station-document-worker/main.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_document", .module = document.module("transit_station_document") }, .{ .name = "telemetry", .module = telemetry.module("telemetry") } } }) });
    const install_document_worker = b.addInstallArtifact(document_worker, .{});
    b.getInstallStep().dependOn(&install_document_worker.step);
    apps_step.dependOn(&install_document_worker.step);
    b.step("transit-station-document-worker", "Install the growing Document writer").dependOn(&install_document_worker.step);
    const grpc_worker = b.addExecutable(.{ .name = "transit-station-grpc-worker", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-station-grpc-worker/main.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }, .{ .name = "telemetry", .module = telemetry.module("telemetry") } } }) });
    const install_grpc_worker = b.addInstallArtifact(grpc_worker, .{});
    b.getInstallStep().dependOn(&install_grpc_worker.step);
    apps_step.dependOn(&install_grpc_worker.step);
    b.step("transit-station-grpc-worker", "Install the finite growing RPC worker").dependOn(&install_grpc_worker.step);
    const http_worker = b.addExecutable(.{ .name = "transit-station-http-worker", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-station-http-worker/main.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_http", .module = station_http.module("transit_station_http") }, .{ .name = "telemetry", .module = telemetry.module("telemetry") } } }) });
    const install_http_worker = b.addInstallArtifact(http_worker, .{});
    b.getInstallStep().dependOn(&install_http_worker.step);
    apps_step.dependOn(&install_http_worker.step);
    b.step("transit-station-http-worker", "Install the finite growing HTTP worker").dependOn(&install_http_worker.step);
    const grpc_bindings = b.addExecutable(.{ .name = "transit-grpc-bindings", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-station-grpc/src/generate.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }} }) });
    const install_grpc_bindings = b.addInstallArtifact(grpc_bindings, .{});
    b.getInstallStep().dependOn(&install_grpc_bindings.step);
    b.step("grpc-bindings", "Install offline RPC request helper generator").dependOn(&install_grpc_bindings.step);
    var transit_cli: *std.Build.Step.Compile = undefined;
    inline for (.{ .{ "transit-query-host", "transit-query-host" }, .{ "transit", "transit-cli" } }) |entry| {
        const app = b.addExecutable(.{ .name = entry[0], .root_module = b.addModule(entry[0], .{
            .root_source_file = b.path("apps/" ++ entry[1] ++ "/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "transit_query", .module = query.module("transit_query") }},
        }) });
        if (comptime std.mem.eql(u8, entry[0], "transit-query-host")) app.root_module.addImport("transit_serving", serving.module("transit_serving"));
        app.root_module.addImport("transit_catalog", catalog.module("transit_catalog"));
        if (comptime std.mem.eql(u8, entry[0], "transit")) {
            app.root_module.addOptions("build_version", @import("version.zig").options(b));
            // The native debug linker reserves large sparse section gaps in
            // this executable. Pack ELF output with pinned LLVM/LLD while
            // retaining debug information and the executable admission bound.
            if (optimize == .debug and target.result.ofmt == .elf) {
                app.use_llvm = true;
                app.use_lld = true;
            }
            app.root_module.addImport("transit_http_server", http_server.module("transit_http_server"));
            app.root_module.addImport("transit_sql_service", sql_gateway.module("transit_sql_service"));
            app.root_module.addImport("transit_sql_client", sql_client.module("transit_sql_client"));
            app.root_module.addImport("transit_tls_server", tls_server.module("transit_tls_server"));
        }
        if (comptime std.mem.eql(u8, entry[0], "transit-query-host")) query_host = app else transit_cli = app;
        const install = b.addInstallArtifact(app, .{});
        b.getInstallStep().dependOn(&install.step);
        apps_step.dependOn(&install.step);

        b.step(entry[0], "Install " ++ entry[0]).dependOn(&install.step);
    }
    // One implementation module per role is shared by the standalone artifact
    // and the local executable. Process isolation and acceptance owners stay
    // unchanged; `transit` dispatches only the selected private role at startup.
    transit_cli.root_module.addImport("transit_node_role", node_artifact.root_module);
    transit_cli.root_module.addImport("transit_io", b.dependency("transit_io", .{ .target = target, .optimize = optimize }).module("transit_io"));
    transit_cli.root_module.addImport("transit_query_host_role", query_host.root_module);
    transit_cli.root_module.addImport("transit_board_role", board.root_module);
    transit_cli.root_module.addImport("transit_sql_gateway_role", sql_gateway_app.root_module);
    transit_cli.root_module.addImport("transit_serving_http", serving_http.module("transit_serving_http"));
    transit_cli.root_module.addImport("transit_sql_host", sql_host.module("transit_sql_host"));
    const flight_gateway = b.dependency("transit_flight_gateway", .{ .target = target, .optimize = optimize }).artifact("transit-flight-gateway");
    b.step("transit-flight-gateway", "Install the finite Flight gateway").dependOn(&b.addInstallArtifact(flight_gateway, .{}).step);
    const install_sql_gateway = b.addInstallArtifact(sql_gateway_app, .{});
    b.step("transit-sql-gateway", "Install the database wire gateway").dependOn(&install_sql_gateway.step);
    b.getInstallStep().dependOn(&install_sql_gateway.step);
    apps_step.dependOn(&install_sql_gateway.step);
    return .{
        .http_server = http_server,
        .serving_http = serving_http,
        .application = application,
        .serving = serving,
        .web_dependencies = web_dependencies,
        .document = document,
        .station_grpc = station_grpc,
        .station_flight = station_flight,
        .flight = flight,
        .grpc = grpc,
        .exchange = exchange,
        .station_http = station_http,
        .fuze = fuze,
        .query = query,
        .sql_client = sql_client,
        .sql_gateway = sql_gateway,
        .tls_server = tls_server,
        .sql_gateway_app = sql_gateway_app,
        .catalog = catalog,
        .station = station,
        .station_bindings = station_bindings,
        .observations = observations,
        .telemetry = telemetry,
        .storage = storage,
        .local_backend = local_backend,
        .adapter = adapter,
        .core = core,
        .protocol = protocol,
        .transit_board_api = transit_board_api,
        .client = client,
        .sql_protocol = sql_protocol,
        .board = board,
        .runtime = runtime,
        .node_artifact = node_artifact,
        .cli_artifact = cli_artifact,
        .delivery_artifact = delivery_artifact,
        .controller_artifact = controller_artifact,
        .kubectl_transit = kubectl_transit,
        .station_controller = station_controller,
        .station_host = station_host,
        .client_host = client_host,
        .query_host = query_host,
        .document_worker = document_worker,
        .grpc_worker = grpc_worker,
        .http_worker = http_worker,
        .grpc_bindings = grpc_bindings,
        .transit_cli = transit_cli,
        .flight_gateway = flight_gateway,
    };
}
