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
    var committed = turn.committed();
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
    const inline_key = key(self.object, 'i', record.revision);
    const small = try turn.read(inline_key);
    const large = try turn.read(key(self.object, 'r', record.revision));
    if (bytes.len <= p.Value.max_bytes) {
        if (large != null) return error.CatalogIdentityConflict;
        const value = try p.Value.init(bytes);
        if (small) |existing| {
            if (!existing.eql(value)) return error.CatalogIdentityConflict;
        } else try turn.write(inline_key, value);
        return .ready;
    }
    if (small != null) return error.CatalogIdentityConflict;
    const ready = self.publication().stage(turn, record.revision, spec, bytes) catch |err| return switch (err) {
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
    const small = try source.read(key(self.object, 'i', revision));
    const large = try source.read(key(self.object, 'r', revision));
    if (small != null and large != null) return error.InvalidCatalogDefinition;
    const spec = if (small) |value| try Pub.Digest.of(Meta.format, value.slice()) else if (large) |value| blk: {
        const descriptor = try Pub.Descriptor.decode(value);
        try checkReference(.{ .id = revision, .spec = descriptor.spec });
        if (descriptor.spec.length <= p.Value.max_bytes) return error.InvalidCatalogDefinition;
        if (descriptor.state != .published) return null;
        break :blk descriptor.spec;
    } else return null;
    const ref: Reference = .{ .id = revision, .spec = spec };
    try checkReference(ref);
    return ref;
}
pub fn read(self: Self, source: anytype, ref: Reference) !Meta.Record {
    try self.check(source);
    try checkReference(ref);
    var buffer: [Meta.max_bytes]u8 = undefined;
    const bytes = if (ref.spec.length <= p.Value.max_bytes) blk: {
        const value = (try source.read(key(self.object, 'i', ref.id))) orelse return error.CatalogDefinitionMissing;
        @memcpy(buffer[0..value.len], value.slice());
        break :blk buffer[0..value.len];
    } else blk: {
        const pubn = self.publication();
        var cursor = try pubn.open(source, ref.id);
        if (!std.meta.eql(cursor.spec, ref.spec)) return error.CatalogDefinitionChanged;
        var offset: usize = 0;
        while (true) {
            const part = try pubn.read(source, cursor);
            if (part.bytes.len > buffer.len - offset) return error.InvalidCatalogDefinition;
            @memcpy(buffer[offset..][0..part.bytes.len], part.bytes.slice());
            offset += part.bytes.len;
            cursor = part.next orelse break;
        }
        break :blk buffer[0..offset];
    };
    if (!std.meta.eql(try Pub.Digest.of(Meta.format, bytes), ref.spec)) return error.CatalogDefinitionChanged;
    const record = try Meta.Record.decode(bytes);
    if (!std.meta.eql(record.scope, self.scope) or record.object != self.object or record.revision != ref.id) return error.CatalogDefinitionChanged;
    return record;
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
    if (try turn.read(key(self.object, 'i', ref.id))) |value| {
        if (!std.meta.eql(try Pub.Digest.of(Meta.format, value.slice()), ref.spec) or try turn.read(key(self.object, 'r', ref.id)) != null) return error.CatalogIdentityConflict;
        _ = try Meta.Record.decode(value.slice());
        try turn.write(key(self.object, 'i', ref.id), null);
        return .ready;
    }
    const descriptor = try Pub.Descriptor.decode((try turn.read(key(self.object, 'r', ref.id))) orelse return .ready);
    if (!std.meta.eql(descriptor.spec, ref.spec)) return error.CatalogIdentityConflict;
    const pubn = self.publication();
    switch (descriptor.state) {
        .staging => _ = try pubn.abandon(turn, ref.id),
        .published => _ = try pubn.retire(turn, ref.id),
        .abandoned, .retired => return if (try pubn.collect(turn, ref.id)) .ready else .progress,
    }
    return .progress;
}
