//! Stream payload, consumer progress and retained-read owner. The shared log
//! implementation supplies the serialized WAL and immutable payload boundary.
pub const Owner = @import("LogPartition.zig").Owner(.stream);
