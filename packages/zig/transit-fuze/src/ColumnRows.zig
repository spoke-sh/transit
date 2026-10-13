//! Borrowed decoded rows shared by kernels and page codecs. No buffer ownership.
pub const Logical = struct { cells: []const @import("Types.zig").Values.Cell };
pub const Native = struct { cells: []const @import("Scalar.zig").Cell };
