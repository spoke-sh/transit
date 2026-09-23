//! A different client application: concatenate arbitrary bytes, including NUL.
const Value = @import("transit_client").Value;
pub fn apply(state: Value, input: Value) !Value {
    if (state.len + input.len > Value.max_bytes) return error.LogFull;
    var bytes: [Value.max_bytes]u8 = undefined;
    @memcpy(bytes[0..state.len], state.slice());
    @memcpy(bytes[state.len..][0..input.len], input.slice());
    return Value.init(bytes[0 .. state.len + input.len]);
}
