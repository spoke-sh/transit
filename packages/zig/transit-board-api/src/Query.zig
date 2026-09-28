//! Interpret framework query records; never decode SQL, Arrow rows or tickets.
const std = @import("std");
const api = @import("root.zig");
const p = api.protocol;
const q = @import("transit_station").GrowingQuery;
pub const Detail = union(enum) {
    capture: q.Job,
    manifest: q.Manifest,
};
pub const Lens = struct { version: u8 = 1, source: @FieldType(api.Lens, "source"), declaration: Detail };
pub fn decode(writer: u64, resource: u64, key: p.Value, value: p.Value) ?Detail {
    return checked(writer, resource, key, value) catch null;
}
fn checked(writer: u64, resource: u64, key: p.Value, value: p.Value) !?Detail {
    try p.State.key(key);
    try value.validate();
    if (key.len != 21 or !std.mem.eql(u8, key.slice()[0..2], &.{ 0, 'Q' })) return null;
    const identity = std.mem.readInt(u64, key.data[3..11], .big);
    if (!key.eql(q.records.key(key.data[2], identity, 0, 0))) return null;
    switch (key.data[2]) {
        'j' => {
            const job = try q.Job.decode(value);
            if (job.result != identity or job.source.pid != writer) return null;
            return .{ .capture = job };
        },
        'c', 'z' => {
            const manifest = try q.Manifest.decode(value);
            if (key.data[2] == 'c') {
                if (manifest.correlation != identity or manifest.destination != writer) return null;
            } else if (manifest.result != identity or manifest.basis.resource != resource) return null;
            return .{ .manifest = manifest };
        },
        else => return null,
    }
}
test "query lens requires canonical records and matching writer without reading result bodies" {
    const t = std.testing;
    const job: q.Job = .{ .result = 5, .destination = 8, .correlation = 3, .table = 1, .source = .{ .pid = 2, .input = 5, .index = 0 }, .policy_revision = 1, .phase = .denied };
    const key = q.records.key('j', 5, 0, 0);
    try t.expectEqualDeep(job, decode(2, 7, key, try job.encode()).?.capture);
    try t.expect(decode(3, 7, key, try job.encode()) == null);
    try t.expect(decode(2, 7, q.records.key('j', 6, 0, 0), try job.encode()) == null);
    try t.expect(decode(2, 7, q.records.key('d', 5, 0, 0), try job.encode()) == null);
    try t.expect(decode(2, 7, key, try p.Value.init("GQJ3 private data")) == null);
}
