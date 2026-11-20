//! Borrowed decoded rows shared by kernels and page codecs. No buffer ownership.
pub const Logical = struct { cells: []const @import("transit_sql_frontend").Types.Values.Cell };
pub const Native = struct { cells: []const @import("transit_sql_frontend").Scalar.Cell };
