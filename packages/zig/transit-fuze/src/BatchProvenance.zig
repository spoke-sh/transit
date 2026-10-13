//! Original lane identity and location, independent of compute implementation.
pub const Location = struct { source: usize, record: u64, byte: u64, prefix_bytes: u8 };
/// One-based original source row, independent of selection/output positions.
row: u64,
/// Original validation boundary; pull adapters validate complete rows.
boundary: u64,
identity: ?@import("TableRow.zig").Identity = null,
location: ?Location = null,
