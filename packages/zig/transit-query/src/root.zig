//! One bounded public query model, shared by Board and the signed CLI.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const wire = station.client;
pub const document = @import("transit_station_document");
pub const Bundle = @import("Bundle.zig");
pub const SqlTemplate = @import("SqlTemplate.zig");
pub const UnifiedClient = @import("UnifiedClient.zig");
pub const Interactive = @import("Interactive.zig");
pub const UnifiedBehavior = @import("UnifiedBehavior.zig");
pub const TableQueryWriter = @import("TableQueryWriter.zig");
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
    _ = @import("source_test.zig");
    _ = @import("sql_template_test.zig");
    _ = @import("unified_capture_test.zig");
    _ = @import("unified_upload_test.zig");
    _ = @import("unified_records_test.zig");
    _ = @import("table_mutation_request_test.zig");
    _ = @import("table_mutation_admission_test.zig");
    _ = @import("table_mutation_client_test.zig");
    _ = @import("table_mutation_writer_test.zig");
    _ = @import("table_query_writer_test.zig");
    _ = @import("table_mutation_bridge_test.zig");
    @import("std").testing.refAllDecls(@This());
}

pub const Values = @import("Values.zig");
pub const Bridge = @import("Bridge.zig");
pub const Workspace = @import("Workspace.zig");
pub const Editor = @import("Editor.zig");
pub const Assistance = @import("Assistance.zig");
pub const SqlInspection = @import("SqlInspection.zig");
pub const TableMutationRequest = @import("TableMutationRequest.zig");
pub const TableMutationRecords = @import("TableMutationRecords.zig");
pub const TableMutationAdmission = @import("TableMutationAdmission.zig");
pub const TableMutationClient = @import("TableMutationClient.zig");
pub const TableMutationWriter = @import("TableMutationWriter.zig");

/// Test-only reference transactions; never a production authority or backend.
pub const testing = if (@import("builtin").is_test) struct {
    pub const Store = @import("source_store_test.zig");
} else struct {};

pub const TableMutationBridge = @import("TableMutationBridge.zig");
