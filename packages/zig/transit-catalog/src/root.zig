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
test {
    _ = @import("table_metadata_test.zig");
    _ = @import("catalog_test.zig");
    _ = @import("client_test.zig");
    _ = @import("behavior_test.zig");
    _ = @import("bridge_test.zig");
    _ = @import("simulation_test.zig");
}
