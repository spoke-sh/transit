//! Native Transit authority. Deterministic transitions use an injected journal,
//! immutable page store and explicit time samples.
pub const protocol = @import("transit_protocol");
pub const Value = protocol.Value;
pub const Ed25519 = protocol.Ed25519;
pub const Time = @import("Time.zig");
pub const Runtime = protocol.Runtime;
pub const pages = @import("pages.zig");
pub const catalog = @import("catalog.zig");
pub const authorization = @import("authorization.zig");
pub const growing = @import("growing.zig");
pub const Engine = growing.Engine;
pub const Genesis = growing.Genesis;
pub const Record = growing.Record;
pub const Entry = growing.Entry;
pub const Head = growing.Head;
pub const max_counter = protocol.max_counter;
pub const max_effect_observations = protocol.max_effect_observations;
pub const max_payload_bytes = protocol.max_payload_bytes;
pub const max_entry_bytes = protocol.max_entry_bytes;
pub const permission = protocol.permission;
pub const all_permissions = protocol.all_permissions;
pub const Command = protocol.Command;
pub const Request = protocol.Request;
pub const SignedRequest = protocol.SignedRequest;
pub const sign = protocol.sign;
pub const digest = protocol.digest;
pub const Payload = protocol.Payload;
test {
    _ = @import("pages_test.zig");
    _ = @import("catalog_test.zig");
    _ = @import("growing_test.zig");
    _ = @import("authorization_test.zig");
}
