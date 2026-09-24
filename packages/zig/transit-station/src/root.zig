//! Station behaviors run in callers over the public Transit client.
pub const client = @import("transit_client");
pub const protocol = client.protocol;
pub const Frame = @import("Frame.zig");
pub const Turn = @import("Turn.zig");
pub const GenServer = @import("GenServer.zig");
pub const Table = @import("Table.zig");
pub const Query = @import("Query.zig");
pub const Registry = @import("Registry.zig");
pub const Waiting = @import("Waiting.zig");
pub const Supervisor = @import("Supervisor.zig");
pub const Controller = @import("Controller.zig");
pub const Metadata = @import("Metadata.zig");
pub const fuze = @import("transit_fuze");
test {
    _ = Frame;
    _ = Turn;
    _ = GenServer;
    _ = Table;
    _ = Query;
    _ = Registry;
    _ = Waiting;
    _ = Supervisor;
    _ = Metadata;
}
