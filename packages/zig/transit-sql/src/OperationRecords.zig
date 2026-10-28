//! SQL projections of database-owned operations, never a storage protocol.
pub const Phase = enum { ready, terminal };
pub const Summary = enum { none, applied, rejected, cancelled, unchanged };
pub const Operation = struct {
    id: u64,
    nonce: [16]u8,
    resource: u64,
    catalog: u64,
    owner: u64,
    namespace: u64,
    role_present: u8,
    role: u64,
    phase: Phase,
    cancel: u8,
    blocked: u8 = 0,
    pub fn selectedRole(self: Operation) ?u64 {
        return if (self.role_present == 1) self.role else null;
    }
};
