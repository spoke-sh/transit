//! Shared database adaptation above the public query and catalog owners.
pub const query = @import("transit_query");
pub const catalog = @import("transit_catalog");
pub const fuze = query.fuze;
pub const Authentication = @import("Authentication.zig");
pub const Limits = @import("Limits.zig");
pub const Type = @import("Type.zig");
test {
    @import("std").testing.refAllDecls(@This());
}
