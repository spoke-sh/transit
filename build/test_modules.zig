//! Explicit shared fixture modules. Scenario assertions stay with their owners.
const std = @import("std");

pub const Id = enum {
    catalog_query_support,
    direct_captured_query,
    direct_dependencies,
    direct_exchange_workers,
    direct_follow_query,
    direct_maintained_query,
    direct_named_resources,
    direct_queue,
    direct_relational_capacity,
    direct_relational_exchanges,
    direct_relational_failures,
    direct_sql_conditions,
    direct_sql_read_recovery,
    direct_table_authorization,
    direct_table_collations,
    direct_table_count_ranges,
    direct_table_delegation,
    direct_table_growth,
    direct_table_history,
    direct_table_lifecycle,
    direct_table_maintenance,
    direct_table_predicates,
    direct_table_prepared,
    direct_table_projection,
    direct_unified_boundaries,
    direct_worker_handoff,
    fixtures_grpc_methods,
    growing_capacity,
    growing_support,
    growing_views,
    http_caller,
    http_registry,
    native_disk,
    native_proof_files,
    operations_app_options,
    operations_application,
    operations_authorization,
    operations_catalog_options,
    operations_diagnostic,
    operations_direct_authorization,
    operations_file_capture,
    operations_file_codes,
    operations_file_diagnostic,
    operations_file_query,
    operations_recovery_files,
    operations_recovery_tests,
    operations_structured_diagnostic,
    operations_unified,
    public_query_catalog,
    sql_catalog_native,
    sql_session_sources,
    table_authorization_support,
    table_query_writer_support,
    unified_query,
    work_items,
};

const Spec = struct {
    id: Id,
    path: []const u8,
    fixtures: []const Id = &.{},
    packages: []const []const u8 = &.{},
};

const specs = [_]Spec{
    .{ .id = .catalog_query_support, .path = "tests/query/tables/catalog_query_support.zig", .fixtures = &.{ .growing_support, .table_authorization_support }, .packages = &.{ "transit_query", "transit_station" } },
    .{ .id = .direct_captured_query, .path = "tests/query/execution/direct_captured_query.zig", .fixtures = &.{.direct_maintained_query}, .packages = &.{ "transit_query", "transit_station_app" } },
    .{ .id = .direct_dependencies, .path = "tests/catalog/tables/direct_dependencies.zig", .packages = &.{"transit_catalog"} },
    .{ .id = .direct_exchange_workers, .path = "tests/query/execution/direct_exchange_workers.zig", .fixtures = &.{ .direct_captured_query, .direct_maintained_query, .direct_relational_exchanges }, .packages = &.{"transit_query"} },
    .{ .id = .direct_follow_query, .path = "tests/query/execution/direct_follow_query.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{ "transit_query", "transit_serving" } },
    .{ .id = .direct_maintained_query, .path = "tests/query/execution/direct_maintained_query.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{ "transit_query", "transit_station_app" } },
    .{ .id = .direct_named_resources, .path = "tests/catalog/tables/direct_named_resources.zig", .packages = &.{ "transit_catalog", "transit_station_app" } },
    .{ .id = .direct_queue, .path = "tests/storage/tables/direct_queue.zig", .packages = &.{ "transit_catalog", "transit_data_client" } },
    .{ .id = .direct_relational_capacity, .path = "tests/query/execution/direct_relational_capacity.zig", .fixtures = &.{ .direct_captured_query, .direct_relational_exchanges, .native_proof_files }, .packages = &.{"transit_query"} },
    .{ .id = .direct_relational_exchanges, .path = "tests/query/execution/direct_relational_exchanges.zig", .fixtures = &.{ .direct_captured_query, .direct_maintained_query, .direct_worker_handoff, .native_proof_files }, .packages = &.{"transit_query"} },
    .{ .id = .direct_relational_failures, .path = "tests/query/execution/direct_relational_failures.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{"transit_query"} },
    .{ .id = .direct_sql_conditions, .path = "tests/query/execution/direct_sql_conditions.zig", .packages = &.{ "transit_query", "transit_sql_service" } },
    .{ .id = .direct_sql_read_recovery, .path = "tests/query/execution/direct_sql_read_recovery.zig", .packages = &.{ "transit_sql_service", "transit_station" } },
    .{ .id = .direct_table_authorization, .path = "tests/catalog/authorization/direct_table_authorization.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{"transit_query"} },
    .{ .id = .direct_table_collations, .path = "tests/query/tables/direct_table_collations.zig", .packages = &.{"transit_query"} },
    .{ .id = .direct_table_count_ranges, .path = "tests/query/tables/direct_table_count_ranges.zig", .packages = &.{"transit_query"} },
    .{ .id = .direct_table_delegation, .path = "tests/catalog/authorization/direct_table_delegation.zig", .packages = &.{"transit_catalog"} },
    .{ .id = .direct_table_growth, .path = "tests/storage/tables/direct_table_growth.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{"transit_query"} },
    .{ .id = .direct_table_maintenance, .path = "tests/storage/tables/direct_table_maintenance.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{"transit_query"} },
    .{ .id = .direct_table_history, .path = "tests/storage/tables/direct_table_history.zig", .packages = &.{ "transit_catalog", "transit_query" } },
    .{ .id = .direct_table_lifecycle, .path = "tests/catalog/tables/direct_table_lifecycle.zig", .fixtures = &.{.direct_table_delegation}, .packages = &.{ "transit_catalog", "transit_query", "transit_sql_service" } },
    .{ .id = .direct_table_predicates, .path = "tests/query/tables/direct_table_predicates.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{"transit_query"} },
    .{ .id = .direct_table_prepared, .path = "tests/catalog/tables/direct_table_prepared.zig", .packages = &.{"transit_query"} },
    .{ .id = .direct_table_projection, .path = "tests/query/tables/direct_table_projection.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{"transit_query"} },
    .{ .id = .direct_unified_boundaries, .path = "tests/query/execution/direct_unified_boundaries.zig", .fixtures = &.{.direct_captured_query}, .packages = &.{"transit_query"} },
    .{ .id = .direct_worker_handoff, .path = "tests/query/execution/direct_worker_handoff.zig", .fixtures = &.{ .direct_captured_query, .native_proof_files }, .packages = &.{"transit_query"} },
    .{ .id = .fixtures_grpc_methods, .path = "tests/fixtures/grpc/methods.zig", .packages = &.{"transit_station_grpc"} },
    .{ .id = .growing_capacity, .path = "tests/storage/providers/growing_capacity.zig", .packages = &.{ "transit_backend_ursula", "transit_core" } },
    .{ .id = .growing_support, .path = "tests/runtime/station/growing_support.zig", .packages = &.{"transit_station"} },
    .{ .id = .growing_views, .path = "tests/runtime/application/growing_views.zig", .fixtures = &.{.growing_support}, .packages = &.{"transit_station"} },
    .{ .id = .http_caller, .path = "tests/runtime/effects/http_caller.zig", .fixtures = &.{.growing_support}, .packages = &.{ "transit_station", "transit_station_http" } },
    .{ .id = .http_registry, .path = "tests/runtime/effects/http_registry.zig", .fixtures = &.{.growing_support}, .packages = &.{"transit_station"} },
    .{ .id = .native_disk, .path = "tests/storage/providers/native_disk.zig", .packages = &.{ "transit_backend_ursula", "transit_core" } },
    .{ .id = .native_proof_files, .path = "tests/runtime/delivery/native_proof_files.zig", .packages = &.{"transit_station"} },
    .{ .id = .operations_app_options, .path = "tests/runtime/application/operations/AppOptions.zig", .packages = &.{"cli_support"} },
    .{ .id = .operations_application, .path = "tests/runtime/application/operations/Application.zig", .fixtures = &.{.operations_app_options}, .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .operations_authorization, .path = "tests/catalog/authorization/operations/Authorization.zig", .fixtures = &.{.operations_recovery_files}, .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .operations_catalog_options, .path = "tests/catalog/authorization/operations/CatalogOptions.zig", .packages = &.{ "cli_support", "transit_catalog" } },
    .{ .id = .operations_diagnostic, .path = "tests/interfaces/cli/operations/Diagnostic.zig", .fixtures = &.{ .operations_file_diagnostic, .operations_structured_diagnostic }, .packages = &.{"cli_support"} },
    .{ .id = .operations_direct_authorization, .path = "tests/catalog/authorization/operations/DirectAuthorization.zig", .fixtures = &.{ .operations_catalog_options, .operations_recovery_files }, .packages = &.{ "cli_support", "transit_catalog" } },
    .{ .id = .operations_file_capture, .path = "tests/query/files/operations/FileCapture.zig", .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .operations_file_codes, .path = "tests/interfaces/cli/operations/FileCodes.zig", .packages = &.{"transit_query"} },
    .{ .id = .operations_file_diagnostic, .path = "tests/interfaces/cli/operations/FileDiagnostic.zig", .fixtures = &.{ .operations_file_capture, .operations_file_codes, .operations_structured_diagnostic }, .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .operations_file_query, .path = "tests/query/files/operations/FileQuery.zig", .fixtures = &.{ .operations_file_capture, .operations_file_diagnostic }, .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .operations_recovery_files, .path = "tests/harness/operations/RecoveryFiles.zig" },
    .{ .id = .operations_recovery_tests, .path = "tests/query/unified/operations/RecoveryTests.zig", .fixtures = &.{ .operations_diagnostic, .operations_unified }, .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .operations_structured_diagnostic, .path = "tests/interfaces/cli/operations/StructuredDiagnostic.zig", .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .operations_unified, .path = "tests/query/unified/operations/Unified.zig", .fixtures = &.{.operations_diagnostic}, .packages = &.{ "cli_support", "transit_query" } },
    .{ .id = .public_query_catalog, .path = "tests/query/execution/public_query_catalog.zig", .fixtures = &.{.table_authorization_support}, .packages = &.{"transit_query"} },
    .{ .id = .sql_catalog_native, .path = "tests/interfaces/sql/sql_catalog_native.zig", .fixtures = &.{ .catalog_query_support, .growing_support, .native_proof_files, .table_authorization_support }, .packages = &.{ "transit_sql_service", "transit_station" } },
    .{ .id = .sql_session_sources, .path = "tests/interfaces/sql/sql_session_sources.zig", .fixtures = &.{ .catalog_query_support, .growing_support, .native_proof_files, .sql_catalog_native, .unified_query }, .packages = &.{ "transit_sql_service", "transit_station" } },
    .{ .id = .table_authorization_support, .path = "tests/catalog/authorization/table_authorization_support.zig" },
    .{ .id = .table_query_writer_support, .path = "tests/query/tables/table_query_writer_support.zig", .fixtures = &.{ .catalog_query_support, .growing_support }, .packages = &.{ "transit_query", "transit_station" } },
    .{ .id = .unified_query, .path = "tests/query/unified/unified_query.zig", .fixtures = &.{ .catalog_query_support, .growing_support, .table_query_writer_support }, .packages = &.{ "transit_query", "transit_station" } },
    .{ .id = .work_items, .path = "tests/runtime/application/work_items.zig", .fixtures = &.{ .growing_support, .table_authorization_support }, .packages = &.{"work_items"} },
};

pub const Set = struct {
    modules: [specs.len]*std.Build.Module,

    pub fn init(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Set {
        var result: Set = undefined;
        for (specs) |spec| {
            result.modules[@backingInt(spec.id)] = b.createModule(.{
                .root_source_file = b.path(spec.path),
                .target = target,
                .optimize = optimize,
            });
        }
        return result;
    }

    pub fn get(self: *const Set, id: Id) *std.Build.Module {
        return self.modules[@backingInt(id)];
    }

    // Create every module before wiring imports, preserving cycles and one
    // shared type identity within each fixture graph. Packages come from the
    // composing build's actual modules, including its CLI and example modules.
    pub fn wire(self: *const Set, packages: []const std.Build.Module.Import) void {
        inline for (specs) |spec| {
            const module = self.get(spec.id);
            inline for (spec.fixtures) |dependency| {
                module.addImport("fixture_" ++ @tagName(dependency), self.get(dependency));
            }
            for (spec.packages) |name| {
                for (packages) |package| {
                    if (std.mem.eql(u8, name, package.name)) {
                        module.addImport(name, package.module);
                        break;
                    }
                } else std.debug.panic("Missing fixture package import: {s}", .{name});
            }
        }
    }
};
