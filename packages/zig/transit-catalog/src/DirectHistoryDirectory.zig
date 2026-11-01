//! Immutable selected catalog bindings and their retained Table cuts. Staging
//! does not publish a snapshot, acquire pins, or establish current permission.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const r = @import("DirectCatalogRecords.zig");
const s = c.storage;
const pages = s.TreeStore.pages;
const Self = @This();
pub const max_bytes = 16 * 1024;
const header_bytes = 40;
pub const Kind = enum { selection, retained };
pub const Entry = struct {
    namespace: c.TableAuthority.Schema,
    properties: r.Properties,
    declaration: s.TableDeclaration.Stored,
    source: d.SourceCut,
    /// Observation of catalog metadata, distinct from the Table data frontier.
    catalog: d.Position,
    pin: ?s.TablePartition.SnapshotHandle,

    pub fn validate(self: Entry, owner: d.Operation, branch: u64, kind: Kind) !void {
        try self.namespace.validate();
        try self.properties.validate();
        try self.declaration.validate();
        try self.source.validate();
        try self.catalog.validate();
        const object = self.source.interpretation.object;
        if (!std.meta.eql(self.namespace.scope, owner.scope) or !std.meta.eql(object.scope, owner.scope) or object.branch != branch or
            self.namespace.retired or self.namespace.id != self.properties.namespace or self.declaration.retired or self.declaration.kind != .table or
            !std.meta.eql(self.declaration.interpretation, self.source.interpretation) or self.source.manifest != null or self.source.checkpoint_lsn != 0 or
            self.source.accepted.next_lsn == 0 or self.catalog.next_lsn == 0 or (self.pin != null) != (kind == .retained)) return error.InvalidHistoricalBinding;
        if (self.pin) |pin| {
            try pin.owner.validate();
            try pin.content.validate();
            if (!std.meta.eql(pin.owner, owner)) return error.HistoricalIdentityConflict;
        }
    }
    /// Verify immutable interpretation artifacts without acquiring data or
    /// authority. The owner separately checks live pin state and current grants.
    pub fn verify(self: Entry, allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore) !void {
        var declaration = try s.TableDeclaration.load(allocator, objects, self.declaration);
        defer declaration.deinit();
        const properties = try r.Properties.decode(allocator, declaration.definition.properties);
        if (!std.meta.eql(properties, self.properties)) return error.InvalidHistoricalBinding;
        if (self.pin) |pin| {
            var snapshot = try s.TableSnapshot.load(allocator, objects, pin);
            defer snapshot.deinit();
            if (!std.meta.eql(snapshot.root.declared(), self.declaration) or !std.meta.eql(snapshot.position(), self.source.accepted)) return error.InvalidHistoricalBinding;
        }
    }
};
/// Immutable metadata selection. Its dependencies name exact Table definitions;
/// retained data is represented only by the separate Table source directory.
pub const DescriptorEntry = struct {
    namespace: c.TableAuthority.Schema,
    declaration: c.CatalogDefinition.Stored,
    catalog: d.Position,
    pub fn validate(self: DescriptorEntry, owner: d.Operation, branch: u64) !void {
        try self.namespace.validate();
        try self.declaration.validate();
        try self.catalog.validate();
        const identity = self.declaration.interpretation.object;
        if (!std.meta.eql(identity.scope, owner.scope) or identity.branch != branch or !std.meta.eql(self.namespace.scope, owner.scope) or self.namespace.retired or self.declaration.retired or self.namespace.id != self.declaration.properties.namespace or self.catalog.next_lsn == 0) return error.InvalidHistoricalBinding;
    }
};
pub const Root = struct {
    definition: p.Growth.Definition,
    owner: d.Operation,
    branch: u64,
    kind: Kind,
    objects: ?pages.Reference,
    names: ?pages.Reference,
    namespaces: ?pages.Reference,
    namespace_names: ?pages.Reference,
    count: u64,
    namespace_count: u64,
    descriptors: ?pages.Reference,
    descriptor_names: ?pages.Reference,
    descriptor_namespaces: ?pages.Reference,
    descriptor_namespace_names: ?pages.Reference,
    descriptor_count: u64,
    descriptor_namespace_count: u64,
    pub fn validate(self: Root) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.owner.validate();
        if (self.branch == 0 or self.namespace_count > self.count or
            self.descriptor_namespace_count > self.descriptor_count or (self.descriptor_count == 0) != (self.descriptors == null) or (self.descriptor_count == 0) != (self.descriptor_names == null) or (self.descriptor_count == 0) != (self.descriptor_namespace_count == 0) or (self.descriptor_namespace_count == 0) != (self.descriptor_namespaces == null) or (self.descriptor_namespace_count == 0) != (self.descriptor_namespace_names == null) or
            (self.count == 0) != (self.objects == null) or (self.count == 0) != (self.names == null) or
            (self.count == 0) != (self.namespace_count == 0) or (self.namespace_count == 0) != (self.namespaces == null) or
            (self.namespace_count == 0) != (self.namespace_names == null)) return error.InvalidHistoricalDirectory;
    }
};
pub const Reference = struct {
    content: d.Content,
    count: u64,
    descriptors: u64,
    pub fn total(self: Reference) !u64 {
        return std.math.add(u64, self.count, self.descriptors);
    }
};
/// A continuation selects an exact immutable directory. It establishes no
/// evidence that a consumer has read the preceding pages.
pub const Cursor = struct { directory: Reference, after: u64 };
pub const DescriptorPage = struct { entries: [pages.page_entries]?DescriptorEntry = @splat(null), next: ?Cursor = null };
pub const Page = struct { entries: [pages.page_entries]?Entry = @splat(null), next: ?Cursor = null };

objects: s.TransitObjectStore.ObjectStore,
index: s.TreeStore,
root: Root,
object_limit: u64,
index_work_bytes: usize,

pub fn init(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, owner: d.Operation, branch: u64, kind: Kind, object_limit: u64, resident_pages: usize, index_work_bytes: usize) !Self {
    const root: Root = .{ .definition = p.Growth.current_definition, .owner = owner, .branch = branch, .kind = kind, .objects = null, .names = null, .namespaces = null, .namespace_names = null, .count = 0, .namespace_count = 0, .descriptors = null, .descriptor_names = null, .descriptor_namespaces = null, .descriptor_namespace_names = null, .descriptor_count = 0, .descriptor_namespace_count = 0 };
    try root.validate();
    if (object_limit == 0 or index_work_bytes == 0) return error.InvalidHistoricalLimits;
    return .{ .objects = objects, .index = try s.TreeStore.init(allocator, objects, resident_pages), .root = root, .object_limit = object_limit, .index_work_bytes = index_work_bytes };
}
pub fn deinit(self: *Self) void {
    self.index.deinit();
    self.* = undefined;
}
fn tree(self: *Self) pages.Tree(s.TreeStore) {
    return .{ .store = &self.index };
}
pub fn objectKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidHistoricalArtifact;
    return std.fmt.bufPrint(output, "catalog-history/{x}.data", .{&content.sha256});
}
fn idKey(id: u64) !pages.Key {
    if (id == 0) return error.InvalidHistoricalDirectory;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, id, .big);
    return pages.Key.init(&bytes);
}
fn schemaNameKey(name: c.TableAuthority.Name) !pages.Key {
    try name.validate();
    return pages.Key.init(&r.hash(name.slice()));
}
fn encode(comptime T: type, value: T, output: *[max_bytes]u8) ![]const u8 {
    output[0..8].* = if (T == Root) "THCDIR01".* else if (T == Entry) "THCENT01".* else if (T == DescriptorEntry) "THCDEF01".* else @compileError("Unknown historical artifact");
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return output[0 .. header_bytes + writer.end];
}
fn stage(self: *Self, comptime T: type, value: T) !d.Content {
    var bytes: [max_bytes]u8 = undefined;
    const encoded = try encode(T, value, &bytes);
    const content: d.Content = .{ .bytes = encoded.len, .sha256 = r.hash(encoded) };
    var name: [96]u8 = undefined;
    const stored = try self.objects.putImmutable(try objectKey(content, &name), encoded, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidHistoricalArtifact;
    return content;
}
pub fn load(objects: s.TransitObjectStore.ObjectStore, comptime T: type, content: d.Content) !T {
    var name: [96]u8 = undefined;
    const key = try objectKey(content, &name);
    const metadata = try objects.head(key) orelse return error.HistoricalArtifactUnavailable;
    if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.InvalidHistoricalArtifact;
    var bytes: [max_bytes]u8 = undefined;
    const encoded = try objects.getRange(key, 0, @intCast(content.bytes), &bytes);
    if (encoded.len != content.bytes or !std.mem.eql(u8, &r.hash(encoded), &content.sha256)) return error.InvalidHistoricalArtifact;
    if (!std.mem.eql(u8, encoded[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const value = try std.json.parseFromSliceLeaky(T, fixed.allocator(), encoded[header_bytes..], .{});
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, encoded, try encode(T, value, &canonical))) return error.InvalidHistoricalArtifact;
    return value; // Root and Entry own all fields, including names.
}
fn reference(content: d.Content) !pages.Value {
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], content.bytes, .little);
    bytes[8..40].* = content.sha256;
    return pages.Value.init(&bytes);
}
pub fn contentOf(value: pages.Value) !d.Content {
    if (value.len != 40) return error.InvalidHistoricalDirectory;
    const content: d.Content = .{ .bytes = std.mem.readInt(u64, value.data[0..8], .little), .sha256 = value.data[8..40].* };
    var name: [96]u8 = undefined;
    _ = try objectKey(content, &name);
    return content;
}
fn entry(self: *Self, value: pages.Value) !Entry {
    const result = try load(self.objects, Entry, try contentOf(value));
    try result.validate(self.root.owner, self.root.branch, self.root.kind);
    return result;
}
pub fn get(self: *Self, object: u64) !?Entry {
    const result = try self.entry(try self.tree().get(self.root.objects, try idKey(object)) orelse return null);
    if (result.source.interpretation.object.object != object) return error.InvalidHistoricalDirectory;
    return result;
}
pub fn lookup(self: *Self, namespace_id: u64, name: c.TableAuthority.Name) !?Entry {
    const result = try self.entry(try self.tree().get(self.root.names, try r.nameKey(namespace_id, name)) orelse return null);
    if (result.namespace.id != namespace_id or !std.meta.eql(result.properties.name, name)) return error.InvalidHistoricalDirectory;
    return result;
}
pub fn namespace(self: *Self, id: u64) !?c.TableAuthority.Schema {
    const stored = try self.tree().get(self.root.namespaces, try idKey(id)) orelse {
        const descriptor = try self.descriptorEntry(try self.tree().get(self.root.descriptor_namespaces, try idKey(id)) orelse return null);
        if (descriptor.namespace.id != id) return error.InvalidHistoricalDirectory;
        return descriptor.namespace;
    };
    const result = try self.entry(stored);
    if (result.namespace.id != id) return error.InvalidHistoricalDirectory;
    return result.namespace;
}
pub fn namespaceByName(self: *Self, name: c.TableAuthority.Name) !?c.TableAuthority.Schema {
    const stored = try self.tree().get(self.root.namespace_names, try schemaNameKey(name)) orelse {
        const descriptor = try self.descriptorEntry(try self.tree().get(self.root.descriptor_namespace_names, try schemaNameKey(name)) orelse return null);
        if (!std.meta.eql(descriptor.namespace.name, name)) return error.InvalidHistoricalDirectory;
        return descriptor.namespace;
    };
    const result = try self.entry(stored);
    if (!std.meta.eql(result.namespace.name, name)) return error.InvalidHistoricalDirectory;
    return result.namespace;
}
/// Four private directory roots advance together. A failed write may leave
/// unreferenced immutable objects; it never advances any visible/private root.
pub fn put(self: *Self, value: Entry) !void {
    try value.validate(self.root.owner, self.root.branch, self.root.kind);
    const object = value.source.interpretation.object.object;
    if (try self.get(object)) |known| {
        if (!std.meta.eql(known, value)) return error.HistoricalIdentityConflict;
        return;
    }
    if (try std.math.add(u64, self.root.count, self.root.descriptor_count) >= self.object_limit) return error.HistoricalObjectLimit;
    if (try self.lookup(value.namespace.id, value.properties.name) != null or try self.lookupDescriptor(value.namespace.id, value.properties.name) != null) return error.HistoricalNameConflict;
    if (try self.namespace(value.namespace.id)) |known| if (!std.meta.eql(known, value.namespace)) return error.HistoricalNamespaceConflict;
    if (try self.namespaceByName(value.namespace.name)) |known| if (!std.meta.eql(known, value.namespace)) return error.HistoricalNamespaceConflict;
    const known_namespace = if (try self.tree().get(self.root.namespaces, try idKey(value.namespace.id))) |stored| (try self.entry(stored)).namespace else null;
    if (known_namespace) |known| {
        if (!std.meta.eql(known, value.namespace)) return error.HistoricalNamespaceConflict;
    }
    const stored = try reference(try self.stage(Entry, value));
    try self.index.begin(self.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.objects = try self.tree().put(next.objects, try idKey(object), stored);
    next.names = try self.tree().put(next.names, try r.nameKey(value.namespace.id, value.properties.name), stored);
    if (known_namespace == null) {
        next.namespaces = try self.tree().put(next.namespaces, try idKey(value.namespace.id), stored);
        next.namespace_names = try self.tree().put(next.namespace_names, try schemaNameKey(value.namespace.name), stored);
        next.namespace_count += 1;
    }
    next.count += 1;
    self.root = next;
}
pub fn commitment(self: *const Self) !Reference {
    try self.root.validate();
    var bytes: [max_bytes]u8 = undefined;
    const encoded = try encode(Root, self.root, &bytes);
    return .{ .content = .{ .bytes = encoded.len, .sha256 = r.hash(encoded) }, .count = self.root.count, .descriptors = self.root.descriptor_count };
}
pub fn seal(self: *Self) !Reference {
    try self.root.validate();
    return .{ .content = try self.stage(Root, self.root), .count = self.root.count, .descriptors = self.root.descriptor_count };
}
pub fn restore(self: *Self, selected: Reference) !void {
    const root = try load(self.objects, Root, selected.content);
    try root.validate();
    if (!std.meta.eql(root.owner, self.root.owner) or root.branch != self.root.branch or root.kind != self.root.kind or root.count != selected.count or root.descriptor_count != selected.descriptors) return error.HistoricalIdentityConflict;
    if (try selected.total() > self.object_limit) return error.HistoricalObjectLimit;
    for ([_]?pages.Reference{ root.objects, root.names, root.namespaces, root.namespace_names, root.descriptors, root.descriptor_names, root.descriptor_namespaces, root.descriptor_namespace_names }) |maybe| if (maybe) |ref| {
        _ = try self.index.load(ref);
    };
    self.root = root;
}
pub fn page(self: *Self, after: ?Cursor) !Page {
    const selected = try self.commitment();
    if (after) |cursor| {
        if (!std.meta.eql(cursor.directory, selected) or try self.get(cursor.after) == null) return error.InvalidHistoricalCursor;
    }
    const batch = try self.tree().scan(self.root.objects, if (after) |cursor| try idKey(cursor.after) else null);
    var result: Page = .{};
    for (batch.entries, &result.entries) |slot, *out| if (slot) |item| {
        const value = try self.entry(item.value);
        if (!std.meta.eql(item.key, try idKey(value.source.interpretation.object.object))) return error.InvalidHistoricalDirectory;
        out.* = value;
    };
    if (batch.next) |last| {
        if (last.len != 8) return error.InvalidHistoricalDirectory;
        result.next = .{ .directory = selected, .after = std.mem.readInt(u64, last.data[0..8], .big) };
    }
    return result;
}

test {
    _ = @import("direct_history_directory_test.zig");
}

fn descriptorEntry(self: *Self, value: pages.Value) !DescriptorEntry {
    const result = try load(self.objects, DescriptorEntry, try contentOf(value));
    try result.validate(self.root.owner, self.root.branch);
    return result;
}
pub fn getDescriptor(self: *Self, object: u64) !?DescriptorEntry {
    const result = try self.descriptorEntry(try self.tree().get(self.root.descriptors, try idKey(object)) orelse return null);
    if (result.declaration.interpretation.object.object != object) return error.InvalidHistoricalDirectory;
    return result;
}
pub fn lookupDescriptor(self: *Self, namespace_id: u64, name: c.TableAuthority.Name) !?DescriptorEntry {
    const result = try self.descriptorEntry(try self.tree().get(self.root.descriptor_names, try r.nameKey(namespace_id, name)) orelse return null);
    if (result.namespace.id != namespace_id or !std.meta.eql(result.declaration.properties.name, name)) return error.InvalidHistoricalDirectory;
    return result;
}
pub fn putDescriptor(self: *Self, value: DescriptorEntry) !void {
    try value.validate(self.root.owner, self.root.branch);
    if (self.root.kind != .selection) return error.InvalidHistoricalBinding;
    const object = value.declaration.interpretation.object.object;
    if (try self.getDescriptor(object)) |known| {
        if (!std.meta.eql(known, value)) return error.HistoricalIdentityConflict;
        return;
    }
    if (try std.math.add(u64, self.root.count, self.root.descriptor_count) >= self.object_limit) return error.HistoricalObjectLimit;
    const name = value.declaration.properties.name;
    if (try self.lookup(value.namespace.id, name) != null or try self.lookupDescriptor(value.namespace.id, name) != null) return error.HistoricalNameConflict;
    if (try self.namespace(value.namespace.id)) |known| if (!std.meta.eql(known, value.namespace)) return error.HistoricalNamespaceConflict;
    if (try self.namespaceByName(value.namespace.name)) |known| if (!std.meta.eql(known, value.namespace)) return error.HistoricalNamespaceConflict;
    const known_namespace = try self.tree().get(self.root.descriptor_namespaces, try idKey(value.namespace.id));
    const stored = try reference(try self.stage(DescriptorEntry, value));
    try self.index.begin(self.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.descriptors = try self.tree().put(next.descriptors, try idKey(object), stored);
    next.descriptor_names = try self.tree().put(next.descriptor_names, try r.nameKey(value.namespace.id, name), stored);
    if (known_namespace == null) {
        next.descriptor_namespaces = try self.tree().put(next.descriptor_namespaces, try idKey(value.namespace.id), stored);
        next.descriptor_namespace_names = try self.tree().put(next.descriptor_namespace_names, try schemaNameKey(value.namespace.name), stored);
        next.descriptor_namespace_count += 1;
    }
    next.descriptor_count += 1;
    self.root = next;
}
pub fn descriptorPage(self: *Self, after: ?Cursor) !DescriptorPage {
    const selected = try self.commitment();
    if (after) |cursor| if (!std.meta.eql(cursor.directory, selected) or try self.getDescriptor(cursor.after) == null) return error.InvalidHistoricalCursor;
    const batch = try self.tree().scan(self.root.descriptors, if (after) |cursor| try idKey(cursor.after) else null);
    var result: DescriptorPage = .{};
    for (batch.entries, 0..) |maybe, i| if (maybe) |item| {
        const value = try self.descriptorEntry(item.value);
        if (!std.meta.eql(item.key, try idKey(value.declaration.interpretation.object.object))) return error.InvalidHistoricalDirectory;
        result.entries[i] = value;
    };
    if (batch.next) |last| {
        if (last.len != 8) return error.InvalidHistoricalCursor;
        result.next = .{ .directory = selected, .after = std.mem.readInt(u64, last.data[0..8], .big) };
    }
    return result;
}
