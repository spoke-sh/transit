//! Shared data callers over public operations, independent of Station bindings.
pub const catalog = @import("transit_catalog");
pub const Catalog = @import("Catalog.zig");

test {
    _ = Catalog;
    _ = @import("catalog_test.zig");
}
