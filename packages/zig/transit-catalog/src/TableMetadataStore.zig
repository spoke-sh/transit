//! Bounded immutable metadata records. Visibility belongs to a catalog's atomic
//! live-object/name decision, not completion of these private staging calls.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const Meta = @import("TableMetadata.zig");
const Pub = c.station.Publication;
const Turn = c.station.Turn;
const Self = @This();
scope: Meta.Scope,
object: u64,
pub const Reference = c.station.TablePages.Reference;
pub const Step = enum { ready, progress };
const limits: Pub.Limits = .{ .record_bytes = Meta.max_bytes, .staging_bytes = Meta.max_bytes, .staging_records = 1 };
pub fn key(object: u64, tag: u8, revision: u64) p.Value {
    return Pub.key(.catalog, object, tag, revision, 0);
}
fn publication(self: Self) Pub {
    return .{ .resource = self.scope.resource, .domain = .catalog, .namespace = self.object };
}
fn validate(self: Self, source: anytype) !void {
    try self.scope.validate();
    if (self.object == 0) return error.InvalidCatalogIdentity;
    if (source.view.resource != self.scope.resource) return error.CrossResourceTransaction;
}
fn manifest(self: Self) !p.Value {
    var bytes: [68]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try out.writeAll("TCB1");
    try out.writeAll(&Meta.definition());
    try Meta.scopeWrite(&out, self.scope);
    try out.writeInt(u64, self.object, .little);
    return p.Value.init(out.buffered());
}
fn check(self: Self, source: anytype) !void {
    try self.validate(source);
    const found = (try source.read(key(self.object, 'd', 0))) orelse return error.CatalogStorageNotFound;
    if (!found.eql(try self.manifest())) return error.IncompatibleDefinition;
}
pub fn create(self: Self, turn: *Turn) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.validate(turn);
    if (try turn.read(key(self.object, 'd', 0)) != null) {
        try self.check(turn);
        if (!std.meta.eql((try self.publication().budget(turn)).limits, limits)) return error.PublicationLimitsChanged;
        return;
    }
    const full = key(self.object, 0, 0);
    const prefix = try p.Value.init(full.data[0..14]);
    for (turn.decision.mutations) |slot| if (slot) |entry| {
        if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.QueryAfterMutation;
    };
    for (turn.decision.blocks.mutations) |slot| if (slot) |entry| {
        if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.QueryAfterMutation;
    };
    var committed = turn.committed();
    const blocks = try committed.blockPage(prefix);
    for (blocks.entries) |slot| if (slot) |entry| {
        if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.CatalogAlreadyPopulated;
    };
    const page = try committed.page(prefix);
    try c.Inspection.validatePage(page, prefix, turn.view.revision);
    if (page.entries[0]) |entry| if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.CatalogAlreadyPopulated;
    _ = try Pub.create(turn, .catalog, self.object, limits);
    try turn.write(key(self.object, 'd', 0), try self.manifest());
}
fn checkReference(ref: Reference) !void {
    if (ref.id == 0 or ref.spec.format != Meta.format or ref.spec.length == 0 or ref.spec.length > Meta.max_bytes) return error.InvalidCatalogDefinition;
}
pub fn stage(self: Self, turn: *Turn, record: Meta.Record) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.check(turn);
    try record.validate();
    if (!std.meta.eql(record.scope, self.scope) or record.object != self.object) return error.CatalogScopeChanged;
    var buffer: [Meta.max_bytes]u8 = undefined;
    const bytes = try record.encode(&buffer);
    const spec = try Pub.Digest.of(Meta.format, bytes);
    const ready = (c.station.BlockRecord{ .publication = self.publication() }).stage(turn, record.revision, spec, bytes) catch |err| return switch (err) {
        error.PublicationIdentityConflict => error.CatalogIdentityConflict,
        else => err,
    };
    return if (ready) .ready else .progress;
}
/// Find retained bytes by revision without treating their private publication as
/// catalog acceptance. The caller must still verify the original durable decision.
pub fn referenceAt(self: Self, source: anytype, revision: u64) !?Reference {
    try self.check(source);
    if (revision == 0) return error.InvalidCatalogIdentity;
    var buffer: [p.Blocks.max_block_bytes]u8 = undefined;
    const bytes = (try source.readBlock(key(self.object, 'c', revision), &buffer)) orelse return null;
    const spec = try c.station.BlockRecord.specification(bytes);
    const ref: Reference = .{ .id = revision, .spec = spec };
    try checkReference(ref);
    return ref;
}
pub fn read(self: Self, source: anytype, ref: Reference) !Meta.Record {
    try self.validate(source);
    try checkReference(ref);
    try prefetch(source, &.{ key(self.object, 'd', 0), key(self.object, 'b', 0) }, key(self.object, 'c', ref.id));
    try self.check(source);
    var buffer: [Meta.max_bytes]u8 = undefined;
    const bytes = (c.station.BlockRecord{ .publication = self.publication() }).read(source, ref.id, ref.spec, &buffer) catch |err| return switch (err) {
        error.MissingPublicationChunk => error.CatalogDefinitionMissing,
        error.InvalidPublicationChunk, error.InvalidPublicationDigest => error.CatalogDefinitionChanged,
        else => err,
    };
    if (!std.meta.eql(try Pub.Digest.of(Meta.format, bytes), ref.spec)) return error.CatalogDefinitionChanged;
    const record = try Meta.Record.decode(bytes);
    if (!std.meta.eql(record.scope, self.scope) or record.object != self.object or record.revision != ref.id) return error.CatalogDefinitionChanged;
    return record;
}
fn prefetch(source: anytype, keys: []const p.Value, block: p.Value) !void {
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetchRecord")) return source.prefetchRecord(keys, block);
    if (comptime @hasDecl(Source, "prefetch")) try source.prefetch(keys);
}

/// The caller proves that this exact revision was never accepted and retains
/// its closed receipt. Collection is bounded; permanent descriptors survive.
pub fn collect(self: Self, turn: *Turn, ref: Reference) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.validate(turn);
    try checkReference(ref);
    if (try turn.read(key(self.object, 'd', 0)) == null) {
        const full = key(self.object, 0, 0);
        const prefix = try p.Value.init(full.data[0..14]);
        var committed = turn.committed();
        const page = try committed.page(prefix);
        try c.Inspection.validatePage(page, prefix, turn.view.revision);
        if (page.entries[0]) |entry| if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.CatalogAlreadyPopulated;
        return .ready;
    }
    try self.check(turn);
    if (try self.referenceAt(turn, ref.id)) |actual| {
        if (!std.meta.eql(actual.spec, ref.spec)) return error.CatalogIdentityConflict;
        _ = try self.read(turn, ref);
        try turn.writeBlock(key(self.object, 'c', ref.id), null);
    }
    return .ready;
}
