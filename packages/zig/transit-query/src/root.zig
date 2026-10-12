//! One bounded public query model, shared by Board and the signed CLI.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const wire = station.client;
pub const document = @import("transit_station_document");
pub const catalog = @import("transit_catalog");
pub const TableQuery = @import("TableQuery.zig");
pub const TableSource = @import("TableSource.zig");
pub const RelationalSpill = @import("RelationalSpill.zig");
pub const RelationalTables = @import("RelationalTables.zig");
pub const RelationalQuery = @import("RelationalQuery.zig");
pub const Bundle = @import("Bundle.zig");
pub const Basis = @import("Basis.zig");
pub const SqlTemplate = @import("SqlTemplate.zig");
pub const UnifiedClient = @import("UnifiedClient.zig");
pub const Interactive = @import("Interactive.zig");
pub const UnifiedBehavior = @import("UnifiedBehavior.zig");
pub const CatalogQueryOwner = @import("CatalogQueryOwner.zig");
pub const UnifiedRequest = @import("UnifiedRequest.zig");
pub const UnifiedUpload = @import("UnifiedUpload.zig");
pub const Draft = @import("Draft.zig");
pub const UnifiedResult = @import("UnifiedResult.zig");
pub const UnifiedCapture = @import("UnifiedCapture.zig");
pub const UnifiedRecords = @import("UnifiedRecords.zig");
pub const UnifiedSource = @import("UnifiedSource.zig");
pub const Decoder = @import("Decoder.zig");
pub const SourceDefinition = @import("SourceDefinition.zig");
test {
    _ = @import("table_source_test.zig");
    _ = @import("source_test.zig");
    _ = @import("sql_template_test.zig");
    _ = @import("sql_compilation_test.zig");
    _ = @import("unified_capture_test.zig");
    _ = @import("unified_upload_test.zig");
    _ = @import("unified_records_test.zig");
    _ = @import("catalog_query_owner_test.zig");
    @import("std").testing.refAllDecls(@This());
}

pub const Values = @import("Values.zig");
pub const Bridge = @import("Bridge.zig");
pub const Workspace = @import("Workspace.zig");
pub const Editor = @import("Editor.zig");
pub const TableAssistance = @import("TableAssistance.zig");
pub const Assistance = @import("Assistance.zig");
pub const SqlInspection = @import("SqlInspection.zig");
pub const SqlCompilation = @import("SqlCompilation.zig");

/// Test-only reference transactions; never a production authority or backend.
pub const testing = if (@import("builtin").is_test) struct {
    pub const Store = @import("source_store_test.zig");
} else struct {};

pub const SourceWitness = @import("SourceWitness.zig");
pub const RuntimeWitness = @import("RuntimeWitness.zig");
pub const ApiDiagnostic = @import("ApiDiagnostic.zig");
pub const ExecutionDiagnostic = @import("ExecutionDiagnostic.zig");
pub const QueryFailure = @import("QueryFailure.zig");
