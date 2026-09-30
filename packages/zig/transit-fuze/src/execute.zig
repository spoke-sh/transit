//! Shared bounded execution workspace and cancellation. All finite plans run
//! through Unified.Stream; source adapters retain their own pagination cursors.
const std = @import("std");
pub const Cancellation = std.atomic.Value(bool);
pub const working_bytes = @import("UnifiedArrow.zig").working_bytes;
