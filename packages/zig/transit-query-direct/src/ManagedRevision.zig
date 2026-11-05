//! Bounded reads of one committed immutable managed Table revision. The mutable
//! output Table is never used as historical result storage. No read starts work.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const f = q.fuze;
const M = q.ManagedTable;
const Self = @This();

pub const Limits = struct {
    rows: u64 = 10000,
    bytes: u64 = 16 * 1024 * 1024,
};
manager: M,
root: c.DirectRecord.Reference,
manifest: std.json.Parsed(M.Revision),
declaration: std.json.Parsed(M.Declaration),
schema: f.TableSchema.Owned,
decision: p.Transaction.Decision,
scratch: std.heap.ArenaAllocator,
limits: Limits,
next_page: ?c.DirectRecord.Reference,
previous_page: ?c.DirectRecord.Reference = null,
sequence: u64 = 0,
page_offset: u32 = 0,
remaining: u64,
read_rows: u64 = 0,
read_bytes: u64 = 0,
complete: bool = false,
failed: bool = false,

pub fn open(manager: M, declaration: M.Declaration, revision: u64, limits: Limits) !Self {
    if (limits.rows == 0 or limits.bytes == 0) return error.InvalidQueryBudget;
    const root = try manager.revisionReference(declaration, revision);
    if (root.content.bytes > limits.bytes) return error.ManagedTableResultBudget;
    const manifest = try manager.load(M.Revision, root, M.revision_format);
    errdefer manifest.deinit();
    const value = manifest.value;
    try value.validate();
    if (value.metadata.revision != revision or !std.meta.eql(value.metadata.computation, try declaration.interpretation(manager.client.allocator)) or
        !std.meta.eql(value.metadata.source, declaration.source.interpretation.interpretation) or
        !std.meta.eql(value.metadata.output, declaration.output.interpretation.interpretation) or
        !std.mem.eql(u8, &root.scope.account, &value.transaction.account)) return error.DataflowIdentityConflict;
    const retained = try manager.load(M.Declaration, value.declaration, M.declaration_format);
    errdefer retained.deinit();
    if (!std.meta.eql(try retained.value.interpretation(manager.client.allocator), value.metadata.computation)) return error.DataflowIdentityConflict;
    const tx: c.DirectTransactionClient = .{ .catalog = manager.client };
    const status = try tx.inspect(value.transaction);
    if (status.observation != .decided or status.cut == null or !std.meta.eql(status.cut.?, value.metadata.cut)) return error.IncompleteDataflowCoverage;
    try value.metadata.requireDecision(status.observation.decided);
    var schema = try c.ManagedInspection.verifyRevision(manager.client.allocator, declaration, .{ .manifest = root, .revision = value, .decision = status.observation.decided });
    errdefer schema.deinit();
    var result: Self = .{ .manager = manager, .root = root, .manifest = manifest, .declaration = retained, .schema = schema, .decision = status.observation.decided, .scratch = .init(manager.client.allocator), .limits = limits, .next_page = value.pages, .remaining = value.metadata.rows, .read_bytes = root.content.bytes };
    errdefer result.scratch.deinit();
    try result.validateDisclosure();
    return result;
}

/// Recheck after buffering and before disclosing schema, metadata, rows or
/// terminal counts. Even repeated terminal calls recheck all three resources.
pub fn validateDisclosure(self: *Self) !void {
    _ = self.scratch.reset(.retain_capacity);
    const current = try self.manager.revisionReferenceInto(self.declaration.value, self.manifest.value.metadata.revision, &self.scratch);
    try self.root.requireSame(current);
}

/// Each successful row belongs to output and survives subsequent scratch reuse.
/// The caller resets output per page/batch; this reader retains no row backlog.
/// Rows follow ascending evaluation ordinal. A SQL query over the mutable
/// output Table still declares ORDER BY when it needs a particular order.
pub fn next(self: *Self, output: *std.heap.ArenaAllocator) !?f.TableRow.Row {
    if (self.failed) return error.FailedManagedRevision;
    return self.nextInner(output) catch |err| {
        self.failed = true;
        self.complete = false;
        return err;
    };
}
fn nextInner(self: *Self, output: *std.heap.ArenaAllocator) !?f.TableRow.Row {
    try self.validateDisclosure();
    if (self.remaining == 0) {
        if (self.next_page != null or self.page_offset != 0) return error.IncompleteDataflowCoverage;
        self.complete = true;
        return null;
    }
    const reference = self.next_page orelse return error.IncompleteDataflowCoverage;
    if (self.read_rows == self.limits.rows or (self.page_offset == 0 and reference.content.bytes > self.limits.bytes - self.read_bytes)) return error.ManagedTableResultBudget;
    if (reference.format != c.DirectTransactionRecord.format or !std.meta.eql(reference.scope, self.root.scope)) return error.InvalidManagedTableRecord;
    var client = self.manager.client;
    client.allocator = self.scratch.allocator();
    const manager: M = .{ .client = client };
    const linked = try manager.load(M.PageLink, reference, M.page_link_format);
    const link = linked.value;
    if (link.definition != p.Growth.current_definition or !std.meta.eql(link.transaction, self.manifest.value.transaction) or
        link.page.format != c.DirectTransactionRecord.format or !std.meta.eql(link.page.scope, self.root.scope)) return error.InvalidManagedTableRecord;
    if (link.next) |following| if (following.format != c.DirectTransactionRecord.format or !std.meta.eql(following.scope, self.root.scope)) return error.InvalidManagedTableRecord;
    const page_bytes = try std.math.add(u64, reference.content.bytes, link.page.content.bytes);
    if (self.page_offset == 0 and page_bytes > self.limits.bytes - self.read_bytes) return error.ManagedTableResultBudget;
    const parsed = try manager.load(M.Page, link.page, M.page_format);
    // Parsed storage uses the reusable scratch arena and cannot escape this call.
    const page = parsed.value;
    if (page.definition != p.Growth.current_definition or !std.meta.eql(page.transaction, self.manifest.value.transaction) or
        page.rows.len == 0 or page.rows.len > M.max_page_rows or self.page_offset >= page.rows.len or
        page.sequence != self.sequence or page.first_ordinal != self.read_rows - self.page_offset or
        page.rows.len - self.page_offset > self.remaining or
        !std.meta.eql(page.previous, self.previous_page) or
        (link.next == null) != (page.rows.len - self.page_offset == self.remaining)) return error.IncompleteDataflowCoverage;
    const row_index = self.page_offset;
    const encoded = try page.rows[row_index].decode(self.scratch.allocator(), f.TableRow.max_bytes);
    const decoded = try f.TableRow.decodeInto(output.allocator(), self.schema.schema, encoded);
    if (decoded.identity.ordinal != page.first_ordinal + row_index) return error.IncompleteDataflowCoverage;
    const following = link.next;
    const current_page = link.page;
    const page_len = page.rows.len;
    // Authorization may have changed during I/O or decode. Do not advance the
    // cursor or report a complete empty/last page before this disclosure check.
    try self.validateDisclosure();
    if (self.page_offset == 0) self.read_bytes += page_bytes;
    if (self.page_offset + 1 == page_len) {
        self.next_page = following;
        self.previous_page = current_page;
        self.sequence += 1;
        self.page_offset = 0;
    } else self.page_offset += 1;
    self.remaining -= 1;
    self.read_rows += 1;
    self.complete = self.remaining == 0;
    return decoded.row();
}

pub fn deinit(self: *Self) void {
    self.scratch.deinit();
    self.schema.deinit();
    self.declaration.deinit();
    self.manifest.deinit();
    self.* = undefined;
}
