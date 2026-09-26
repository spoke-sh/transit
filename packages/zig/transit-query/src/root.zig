//! One bounded public query model, shared by Board and the signed CLI.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const wire = station.client;
pub const Model = @import("Model.zig");
pub const Request = @import("Request.zig");
pub const Behavior = @import("Behavior.zig");
pub const Client = @import("Client.zig");
test {
    @import("std").testing.refAllDecls(@This());
}
