//! Declarative metadata and conditional state creation above Station.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const Diagnostic = @import("Diagnostic.zig");
pub const Model = @import("Model.zig");
pub const Records = @import("Records.zig");
pub const Catalog = @import("Catalog.zig");
pub const Inspection = @import("Inspection.zig");
pub const Client = @import("Client.zig");
pub const Behavior = @import("Behavior.zig");
pub const Bridge = @import("Bridge.zig");
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
test {
    _ = @import("table_behavior_test.zig");
    _ = @import("table_upload_test.zig");
    _ = @import("table_command_test.zig");
    _ = @import("table_metadata_test.zig");
    _ = @import("table_catalog_test.zig");
    _ = @import("catalog_test.zig");
    _ = @import("client_test.zig");
    _ = @import("behavior_test.zig");
    _ = @import("bridge_test.zig");
    _ = @import("simulation_test.zig");
}
