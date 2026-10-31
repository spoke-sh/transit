//! Shared data callers over public operations, independent of Station bindings.
pub const catalog = @import("transit_catalog");
pub const Catalog = @import("Catalog.zig");
pub const DirectMigration = catalog.DirectMigration;

test {
    _ = Catalog;
    _ = DirectMigration;
    _ = @import("catalog_test.zig");
}
