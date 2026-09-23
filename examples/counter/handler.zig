//! A client application: decimal-text integers are this application's format.
const std = @import("std");
const Value = @import("transit_client").Value;
pub fn apply(state: Value, input: Value) !Value {
    return Value.integer(try std.math.add(i64, try state.asInteger(), try input.asInteger()));
}
