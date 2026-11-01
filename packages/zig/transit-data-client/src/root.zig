//! Shared data callers over public operations, independent of Station bindings.
pub const catalog = @import("transit_catalog");
pub const Catalog = @import("Catalog.zig");
pub const Context = @import("Context.zig");
pub const Admission = @import("Admission.zig");
pub const LocalRecoveryStore = @import("LocalRecoveryStore.zig");
pub const sql = @import("transit_sql_client");
pub const SqlRecovery = @import("SqlRecovery.zig");
pub const KVRecovery = @import("KVRecovery.zig");
pub const DirectMigration = catalog.DirectMigration;

test {
    _ = Catalog;
    _ = Context;
    _ = Admission;
    _ = LocalRecoveryStore;
    _ = SqlRecovery;
    _ = KVRecovery;
    _ = DirectMigration;
    _ = @import("catalog_test.zig");
    _ = @import("sql_recovery_test.zig");
}
