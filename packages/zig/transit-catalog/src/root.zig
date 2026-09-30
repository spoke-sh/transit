//! Declarative metadata and conditional state creation above Station.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const Model = @import("Model.zig");
pub const Records = @import("Records.zig");
pub const Catalog = @import("Catalog.zig");
pub const Client = @import("Client.zig");
pub const Behavior = @import("Behavior.zig");
pub const Bridge = @import("Bridge.zig");
test {
    _ = @import("catalog_test.zig");
    _ = @import("client_test.zig");
    _ = @import("behavior_test.zig");
    _ = @import("bridge_test.zig");
}
