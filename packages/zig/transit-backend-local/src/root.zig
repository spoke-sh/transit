//! Native authority persistence through the shared local log/object boundaries.
pub const Backend = @import("Backend.zig");
pub const Store = @import("Store.zig");
pub const PageStore = @import("PageStore.zig");
pub const DataStore = @import("DataStore.zig");
pub const DataAuthority = @import("DataAuthority.zig");
pub const StorageCollection = @import("StorageCollection.zig");
pub const PayloadStore = @import("PayloadStore.zig");

test {
    _ = @import("native_test.zig");
    _ = @import("data_test.zig");
    _ = @import("collection_test.zig");
    _ = @import("payload_test.zig");
}
