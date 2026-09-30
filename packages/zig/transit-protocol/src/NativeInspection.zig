//! Bounded inspection selectors carried by the native signed query envelope.
const std = @import("std");
const p = @import("root.zig");
const g = p.Growth;
pub const page_size = g.page_size;
pub const scan_limit = 128;
pub const Resource = enum { processes, process, mailbox, outbox, effects, payloads, history };
pub const Cut = struct { position: u64, policy_revision: u64, retained_from: u64 };
pub const Query = struct { resource: Resource, pid: ?u64 = null, cut: ?Cut = null, after: u64 = 0 };
pub const Event = struct {
    position: u64,
    pid: u64,
    kind: std.meta.Tag(g.Command),
    policy_revision: u64,
    input: ?u64 = null,
    effect: ?u64 = null,
    output: ?u64 = null,
    value: ?p.Value = null,
    failed: bool = false,
    generation: ?u64 = null,
    mailbox_status: ?enum { pending, consumed, cancelled } = null,
    admitted: bool = false,
    unix_ms: ?u64 = null,
    clock_error_ms: ?u32 = null,
};
pub const Page = struct {
    version: u32 = 1,
    realm: u64,
    resource: Resource,
    pid: ?u64,
    cut: Cut,
    reader: g.Identity,
    next: ?u64 = null,
    complete: bool = true,
    history: enum { retained, prefix_reclaimed },
    last_collection: ?u64 = null,
    scanned: u16 = 0,
    processes: [page_size]?g.Process = @splat(null),
    events: [page_size]?Event = @splat(null),
    outbox: [page_size]?g.Outbox = @splat(null),
    effects: [page_size]?g.Effect = @splat(null),
    payloads: [page_size]?g.Payload = @splat(null),
};
pub fn validate(q: Query) !void {
    if ((q.resource == .processes) != (q.pid == null) or q.after > p.max_counter) return error.InvalidRead;
    if (q.pid) |pid| if (pid == 0 or pid > p.max_counter) return error.InvalidRead;
    if (q.after != 0 and q.cut == null) return error.InvalidRead;
    if (q.resource == .process and q.after != 0) return error.InvalidRead;
    if (q.cut) |cut| if (cut.position > p.max_counter or cut.policy_revision >= cut.position or cut.retained_from >= cut.position) return error.InvalidRead;
}
pub fn validatePage(page: Page, query: g.Query, position: u64) !void {
    const q = query.kind.inspection;
    if (page.version != 1 or page.realm != query.realm or page.reader.principal != query.principal or page.pid != q.pid or page.resource != q.resource or
        page.cut.position != position or page.reader.policy_revision != page.cut.policy_revision or page.scanned > scan_limit or
        page.complete != (page.next == null) or page.reader.permissions & p.permission(.inspect) == 0 or page.reader.permissions & ~p.all_permissions != 0) return error.InvalidRead;
    if (q.cut) |cut| if (!std.meta.eql(cut, page.cut)) return error.InvalidRead;
    if (page.next) |next| if (next <= q.after) return error.InvalidRead;
    if (page.reader.pid) |scope| {
        if (q.pid) |pid| if (scope != pid) return error.InvalidRead;
        for (page.processes) |slot| if (slot) |process| if (process.pid != scope) return error.InvalidRead;
        for (page.outbox) |slot| if (slot) |out| if (out.source != scope or out.destination != scope) return error.InvalidRead;
    }
    inline for (.{ "processes", "events", "outbox", "effects", "payloads" }) |field| {
        var ended = false;
        for (@field(page, field)) |slot| {
            const entry = slot orelse {
                ended = true;
                continue;
            };
            if (ended) return error.InvalidRead;
            if (comptime !std.mem.eql(u8, field, "processes")) {
                const pid = if (comptime std.mem.eql(u8, field, "outbox")) entry.source else entry.pid;
                if (pid != q.pid) return error.InvalidRead;
            }
        }
    }
}
