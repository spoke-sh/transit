//! Complete immutable predecessors of accepted Table heads. A staged predecessor
//! is not a committed successor; only the current head's revision admits it.
const std = @import("std");
const p = @import("transit_client").protocol;
const Head = @import("TableHead.zig");
const Pages = @import("TablePages.zig");
const Turn = @import("Turn.zig");

pub const Record = struct {
    head: Head,
    /// Native revision of the entry that published this head, not the later
    /// resource cut used to read or archive it.
    committed: u64,
    pub fn validate(self: Record) !void {
        try self.head.validate();
        if (self.committed == 0 or self.committed > p.max_counter) return error.InvalidTableHistory;
    }
    pub fn encode(self: Record) !p.Value {
        try self.validate();
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("STJ1");
        try writer.writeInt(u64, self.committed, .little);
        try writer.writeAll((try self.head.encode()).slice());
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Record {
        try value.validate();
        if (value.len <= 12 or !std.mem.eql(u8, value.data[0..4], "STJ1")) return error.InvalidTableHistory;
        const result: Record = .{ .committed = std.mem.readInt(u64, value.data[4..12], .little), .head = try Head.decode(try p.Value.init(value.slice()[12..])) };
        try result.validate();
        if (!(try result.encode()).eql(value)) return error.InvalidTableHistory;
        return result;
    }
};
pub fn key(object: u64, head_revision: u64) p.Value {
    return Pages.key(object, 'j', head_revision);
}
/// One bounded public page supplies the current head and its native commit
/// coordinate. The head key ends in zero, so its strict prefix is its immediate
/// predecessor in the key order. Private writes must be excluded by the source.
pub fn current(source: anytype, object: u64) !Record {
    if (object == 0) return error.InvalidTableHistory;
    const address = Head.key(object);
    std.debug.assert(address.data[address.len - 1] == 0);
    const page = try source.page(try p.Value.init(address.slice()[0 .. address.len - 1]));
    const entry = page.entries[0] orelse return error.TableNotFound;
    if (!entry.key.eql(address)) return error.TableNotFound;
    if (entry.revision == 0 or entry.revision > source.view.revision) return error.InvalidTableHistory;
    const result: Record = .{ .head = try Head.decode(entry.value), .committed = entry.revision };
    try result.validate();
    if (result.head.object != object or result.head.resource != source.view.resource) return error.InvalidTableHistory;
    return result;
}
/// Archive before replacing a head. This operation can commit on an earlier
/// staging turn: until the head advances, the record has no successor meaning.
/// Repeated staging is exact and cannot overwrite conflicting history.
pub fn stage(head: Head, turn: *Turn) !Pages.Step {
    var committed = turn.committed();
    const observed = try current(&committed, head.object);
    if (!(try observed.head.encode()).eql(try head.encode())) return error.TableHeadChanged;
    const value = try observed.encode();
    const address = key(head.object, head.revision);
    var buffer: [p.Value.max_bytes]u8 = undefined;
    if (try turn.readBlock(address, &buffer)) |bytes| {
        const existing = try p.Value.init(bytes);
        _ = try Record.decode(existing);
        if (!existing.eql(value)) return error.TableHistoryConflict;
        return .ready;
    }
    try turn.writeBlock(address, value.slice());
    return .progress;
}
/// Resolve one accepted Table revision under an already captured current upper
/// bound. Missing predecessors are gaps, never an empty or reset history.
pub fn revision(source: anytype, upper: Record, requested: u64) !Record {
    try upper.validate();
    if (upper.head.resource != source.view.resource or upper.committed > source.view.revision) return error.InvalidTableHistory;
    if (requested == 0 or requested > upper.head.revision) return error.InvalidTableHistoryCursor;
    if (requested == upper.head.revision) return upper;
    var buffer: [p.Value.max_bytes]u8 = undefined;
    const value = try p.Value.init((try source.readBlock(key(upper.head.object, requested), &buffer)) orelse return error.TableHistoryGap);
    const result = try Record.decode(value);
    if (result.head.object != upper.head.object or result.head.resource != upper.head.resource or result.head.revision != requested or result.committed >= upper.committed or result.head.retired) return error.InvalidTableHistory;
    return result;
}
/// At most 64 history probes, independently of retained cardinality. The source
/// cut must cover the requested native position. This reconstructs a Table root,
/// not an authority snapshot or permission to execute against it.
pub fn at(source: anytype, upper: Record, native_revision: u64) !Record {
    if (native_revision == 0 or native_revision > source.view.revision) return error.InvalidTableHistoryCursor;
    try upper.validate();
    if (upper.head.resource != source.view.resource or upper.committed > source.view.revision) return error.InvalidTableHistory;
    if (upper.committed <= native_revision) return upper;
    var low: u64 = 1;
    var high: u64 = upper.head.revision;
    var selected: ?Record = null;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = try revision(source, upper, middle);
        if (candidate.committed <= native_revision) {
            selected = candidate;
            low = middle + 1;
        } else high = middle;
    }
    return selected orelse error.TableNotAtCut;
}
