//! Public serving semantics above Station; no sockets or raw storage authority.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const Model = @import("Model.zig");
pub const Codec = @import("Codec.zig");
pub const Service = @import("Service.zig");
pub const Adapter = @import("Adapter.zig");
test {
    _ = @import("service_test.zig");
    @import("std").testing.refAllDecls(@This());
}
