//! The service acquires current authorization and retirement fencing and holds
//! it until release. Owners check observations and recheck after private staging
//! immediately before publication. A client-supplied lease is not this guard.
context: *anyopaque,
acquire: *const fn (*anyopaque) anyerror!Fence,
release: *const fn (*anyopaque) void,
pub const Fence = struct { writer_epoch: u64, policy_epoch: u64 };
