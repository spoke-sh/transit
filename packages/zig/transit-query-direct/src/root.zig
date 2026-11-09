//! Finite database query execution over authorized direct Table owners.
//! No actor turns, captured-job scheduler or application behavior dependencies.
pub const catalog = @import("transit_catalog");
pub const fuze = @import("transit_fuze");
pub const protocol = @import("transit_protocol");
pub const storage = catalog.storage;
pub const QueryMemory = fuze.MemoryBudget;
pub const DirectTableQuery = @import("DirectTableQuery.zig");
pub const DirectTablePrepared = @import("DirectTablePrepared.zig");
pub const DirectRelationalCompilation = @import("DirectRelationalCompilation.zig");
pub const DirectRelationalTables = @import("DirectRelationalTables.zig");
pub const DirectRelationalQuery = @import("DirectRelationalQuery.zig");
pub const RelationalSpill = @import("RelationalSpill.zig");
pub const ComputePool = @import("ComputePool.zig");
pub const RelationalBridge = @import("RelationalBridge.zig");
pub const TableChangeReader = @import("TableChangeReader.zig");
pub const ManagedTable = @import("ManagedTable.zig");
pub const ApplicationData = @import("ApplicationData.zig");
pub const ApplicationBinding = @import("ApplicationBinding.zig");
pub const ApplicationDeclaration = @import("ApplicationDeclaration.zig");
pub const ApplicationExecution = @import("ApplicationExecution.zig");
pub const ApplicationRecovery = @import("ApplicationRecovery.zig");
pub const ApplicationHost = @import("ApplicationHost.zig");
pub const ApplicationTransaction = @import("ApplicationTransaction.zig");
pub const ApplicationInvocation = @import("ApplicationInvocation.zig");
pub const ManagedApplication = @import("ManagedApplication.zig");
pub const ManagedInspection = @import("ManagedInspection.zig");
pub const ManagedRevision = @import("ManagedRevision.zig");
test {
    _ = @import("direct_table_count_range_test.zig");
    @import("std").testing.refAllDecls(@This());
}
