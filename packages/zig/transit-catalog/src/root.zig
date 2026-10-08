//! Declarative metadata and conditional state creation above Station.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const Model = @import("Model.zig");
pub const Records = @import("Records.zig");
pub const Inspection = @import("Inspection.zig");
pub const TableMetadata = @import("TableMetadata.zig");
pub const TableMetadataStore = @import("TableMetadataStore.zig");
pub const TableCatalogRecords = @import("TableCatalogRecords.zig");
pub const TableCatalog = @import("TableCatalog.zig");
pub const TableDdlRequest = @import("TableDdlRequest.zig");
pub const TableDmlRequest = @import("TableDmlRequest.zig");
pub const TableCommand = @import("TableCommand.zig");
pub const TableUpload = @import("TableUpload.zig");
pub const TableControl = @import("TableControl.zig");
pub const TableBehavior = @import("TableBehavior.zig");
pub const TableIntent = @import("TableIntent.zig");
pub const TableClient = @import("TableClient.zig");
pub const TableDiagnostic = @import("TableDiagnostic.zig");
pub const TableValues = @import("TableValues.zig");
pub const TableTyped = @import("TableTyped.zig");
pub const TableBridge = @import("TableBridge.zig");
pub const TableAttempt = @import("TableAttempt.zig");
test {
    _ = TableAttempt;
    _ = @import("table_bridge_test.zig");
    _ = @import("table_values_test.zig");
    _ = @import("table_client_test.zig");
    _ = @import("table_intent_test.zig");
    _ = @import("table_behavior_test.zig");
    _ = @import("table_upload_test.zig");
    _ = @import("table_command_test.zig");
    _ = @import("table_metadata_test.zig");
    _ = @import("table_catalog_test.zig");
    _ = @import("simulation_test.zig");
}
