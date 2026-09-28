//! Public serving semantics above Station; no sockets or raw storage authority.
pub const query = @import("transit_query");
pub const TableWatch = @import("TableWatch.zig");
pub const ReactiveWire = @import("ReactiveWire.zig");
pub const ReactiveAdapter = @import("ReactiveAdapter.zig");
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const Model = @import("Model.zig");
pub const Codec = @import("Codec.zig");
pub const Service = @import("Service.zig");
pub const Adapter = @import("Adapter.zig");
pub const ReactiveService = @import("ReactiveService.zig");
pub const ReactiveModel = @import("ReactiveModel.zig");
test {
    _ = @import("service_test.zig");
    _ = @import("watch_test.zig");
    _ = ReactiveModel;
    @import("std").testing.refAllDecls(@This());
}
