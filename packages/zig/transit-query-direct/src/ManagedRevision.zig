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
    const encoded = try value.schema.decode(manager.client.allocator, f.TableSchema.max_bytes);
    defer manager.client.allocator.free(encoded);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &digest, .{});
    if (encoded.len != value.metadata.schema.bytes or !std.mem.eql(u8, &digest, &value.metadata.schema.sha256)) return error.InvalidManagedTableRecord;
    var schema = try f.TableSchema.decode(manager.client.allocator, encoded);
    errdefer schema.deinit();
    if (schema.schema.object != value.metadata.output.object.object or schema.schema.revision != value.metadata.output.revision) return error.DataflowIdentityConflict;
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
/// Rows follow descending staging ordinal; this adds no SQL ordering promise.
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
        if (self.next_page != null) return error.IncompleteDataflowCoverage;
        self.complete = true;
        return null;
    }
    const reference = self.next_page orelse return error.IncompleteDataflowCoverage;
    if (self.read_rows == self.limits.rows or reference.content.bytes > self.limits.bytes - self.read_bytes) return error.ManagedTableResultBudget;
    if (reference.format != M.page_format or !std.meta.eql(reference.scope, self.root.scope)) return error.InvalidManagedTableRecord;
    var client = self.manager.client;
    client.allocator = self.scratch.allocator();
    const manager: M = .{ .client = client };
    const parsed = try manager.load(M.Page, reference, M.page_format);
    // Parsed storage uses the reusable scratch arena and cannot escape this call.
    const page = parsed.value;
    if (page.definition != p.Growth.current_definition or !std.meta.eql(page.transaction, self.manifest.value.transaction) or
        page.ordinal != self.remaining - 1 or (page.previous == null) != (page.ordinal == 0)) return error.IncompleteDataflowCoverage;
    const encoded = try page.row.decode(self.scratch.allocator(), f.TableRow.max_bytes);
    const decoded = try f.TableRow.decodeInto(output.allocator(), self.schema.schema, encoded);
    if (decoded.identity.ordinal != page.ordinal) return error.IncompleteDataflowCoverage;
    const previous = page.previous;
    // Authorization may have changed during I/O or decode. Do not advance the
    // cursor or report a complete empty/last page before this disclosure check.
    try self.validateDisclosure();
    self.next_page = previous;
    self.remaining -= 1;
    self.read_rows += 1;
    self.read_bytes += reference.content.bytes;
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
