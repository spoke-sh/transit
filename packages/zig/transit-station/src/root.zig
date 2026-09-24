//! Station behaviors run in callers over the public Transit client.
pub const client = @import("transit_client");
pub const protocol = client.protocol;
pub const Frame = @import("Frame.zig");
pub const Turn = @import("Turn.zig");
pub const GenServer = @import("GenServer.zig");
test {
    _ = Frame;
    _ = Turn;
    _ = GenServer;
}
