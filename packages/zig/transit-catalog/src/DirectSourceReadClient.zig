//! Typed capture reader transport. Each result owns its one bounded byte batch;
//! original pin/release identities are always supplied by the caller.
const std = @import("std");
const c = @import("root.zig");
pub fn apply(output: *std.heap.ArenaAllocator, caller: c.DirectTableClient, request: c.DirectSourceRead.Request) !c.DirectSourceRead.Result {
    const response = try caller.call(.{ .capture_read = request });
    defer response.deinit();
    if (response.value.result != .capture_read) return error.InvalidSourceCaptureReader;
    var result = response.value.result.capture_read;
    if (result == .page) result.page.bytes.base64 = try output.allocator().dupe(u8, result.page.bytes.base64);
    return result;
}
