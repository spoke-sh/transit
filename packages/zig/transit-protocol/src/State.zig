//! State v1 permissions and resource values owned by the native protocol.
const p = @import("root.zig");
pub const version = 1;
pub const Permission = enum(u3) { inspect, read, write };
pub const all_permissions: u8 = 7;
pub fn permission(value: Permission) u8 {
    return @as(u8, 1) << @backingInt(value);
}
pub const key = p.Growth.validateKey;
pub const Entry = p.Growth.Entry;
pub const Resource = p.Growth.Resource;
pub const View = p.Growth.View;
pub const Association = p.Growth.Association;
