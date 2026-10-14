//! Shared database adaptation above the public query and catalog owners.
pub const station = @import("transit_station");
pub const query = @import("transit_query");
pub const catalog = @import("transit_catalog");
pub const fuze = query.fuze;
pub const Authentication = @import("Authentication.zig");
pub const Limits = @import("Limits.zig");
pub const Client = @import("Client.zig");
pub const Coordinator = @import("Coordinator.zig");
pub const Statement = @import("Statement.zig");
pub const Behavior = @import("Behavior.zig");
pub const Control = @import("Control.zig");
pub const Terminal = @import("Terminal.zig");
pub const Ledger = @import("Ledger.zig");
pub const LedgerRecords = @import("LedgerRecords.zig");
pub const Upload = @import("Upload.zig");
pub const SavedStep = @import("SavedStep.zig");
pub const Type = @import("Type.zig");
pub const Bytes = @import("Bytes.zig");
test {
    _ = @import("upload_test.zig");
    _ = @import("ledger_test.zig");
    _ = @import("ledger_records_test.zig");
    @import("std").testing.refAllDecls(@This());
}
