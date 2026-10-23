//! Native authority persistence through the shared local log/object boundaries.
pub const Backend = @import("Backend.zig");
pub const Store = @import("Store.zig");
pub const PageStore = @import("PageStore.zig");

test {
    _ = @import("native_test.zig");
}
