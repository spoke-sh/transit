//! Shared database-wire values and bounds. This namespace has no SQL service,
//! transport, credential store or execution authority.
pub const fuze = @import("root.zig").fuze;
pub const results = @import("root.zig").results;
pub const Completion = results.Command;
pub const Authentication = @import("root.zig").Authentication;
pub const Limits = @import("WireLimits.zig");
pub const ReadBatch = @import("WireReadBatch.zig");
pub const Type = @import("WireType.zig");
pub const Bytes = @import("WireBytes.zig");
pub const Input = @import("WireInput.zig").Decoder;
test {
    @import("std").testing.refAllDecls(@This());
}
