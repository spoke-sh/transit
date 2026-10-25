//! Explicit application data role, separate from native worker ownership.
//! Provisioning owns its grants; starting a worker only selects the role.
const std = @import("std");
const q = @import("transit_query");
const p = q.protocol;
const Self = @This();
client: q.wire.AuthorizationClient,
data: @import("Data.zig").Binding,

pub const Configuration = struct {
    role: u64,
    data: @import("Data.zig").Binding,
};
pub fn prepare(self: Self, turn: *q.station.Turn, body: []const u8) !q.QueryAuthorization {
    return q.QueryAuthorization.prepare(self.client, turn.delivery.pid, turn.delivery.pid, turn.view.resource, body);
}
pub fn bind(self: Self, turn: *q.station.Turn, proof: q.QueryAuthorization, body: []const u8) !void {
    try proof.caller(self.client.principal, self.client.role);
    try turn.bindAuthorizationSubject(try proof.subject(turn.delivery.pid, turn.delivery.pid, turn.view.resource, body));
}
pub fn encode(proof: q.QueryAuthorization) !p.Value {
    var bytes: [1 + q.QueryAuthorization.encoded_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try q.QueryAuthorization.write(proof, &writer);
    return p.Value.init(writer.buffered());
}
pub fn decode(value: p.Value) !q.QueryAuthorization {
    var reader: std.Io.Reader = .fixed(value.slice());
    const proof = (try q.QueryAuthorization.read(&reader)) orelse return error.InvalidLedgerWork;
    if (reader.bufferedLen() != 0) return error.InvalidLedgerWork;
    return proof;
}
