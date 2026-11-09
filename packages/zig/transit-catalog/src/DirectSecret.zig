//! Versioned references to private mounted secret bytes. Metadata lives in a
//! canonical direct KV resource and participates in ordinary serializable read
//! guards. The reference, content commitment and file name confer no authority.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const f = c.fuze;
const d = p.DataLifecycle;
const Cell = f.Types.Values.Cell;
pub const kind: f.NativeBinding.Kind = .secret_references;
pub const max_secret_bytes = 65536;
pub const max_revision_bytes = 2048;

pub const Declaration = struct {
    name: []const u8,
    file: []const u8,
    content_sha256: [32]u8,
    enabled: bool,

    pub fn validate(self: Declaration) !void {
        try label(self.name);
        try label(self.file);
        if (std.mem.allEqual(u8, &self.content_sha256, 0)) return error.InvalidSecretReference;
    }
    /// File bytes are exact: no implicit whitespace trimming, environment
    /// substitution or reinterpretation of a changed mounted version.
    pub fn verifyContent(self: Declaration, bytes: []const u8) !void {
        try self.validate();
        if (!self.enabled) return error.SecretDisabled;
        if (bytes.len == 0 or bytes.len > max_secret_bytes) return error.InvalidSecretContent;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        if (!std.crypto.timing_safe.eql([32]u8, self.content_sha256, digest)) return error.SecretContentChanged;
    }
    /// The returned cell borrows this declaration's strings until encoding.
    pub fn value(self: Declaration, output: std.mem.Allocator) !Cell {
        try self.validate();
        const cells = try output.alloc(Cell, 4);
        cells[0..4].* = .{
            .{ .value = .{ .atom = .{ .bytes = self.name } } },
            .{ .value = .{ .atom = .{ .bytes = self.file } } },
            .{ .value = .{ .atom = .{ .bytes = try output.dupe(u8, &self.content_sha256) } } },
            .{ .value = .{ .atom = .{ .boolean = self.enabled } } },
        };
        return .{ .value = .{ .structure = cells } };
    }
    pub fn fromValue(cell: Cell) !Declaration {
        const spec = try c.NativeBindingSchema.kvSpec(kind);
        try cell.validate(.{ .name = "value", .type = spec.typeOf(), .nullable = false }, .{});
        const fields = cell.value.structure;
        const commitment = fields[2].value.atom.bytes;
        if (commitment.len != 32) return error.InvalidSecretReference;
        const result: Declaration = .{ .name = fields[0].value.atom.bytes, .file = fields[1].value.atom.bytes, .content_sha256 = commitment[0..32].*, .enabled = fields[3].value.atom.boolean };
        try result.validate();
        return result;
    }
};

pub const Binding = struct {
    interpretation: d.Definition,
    namespace: u64,
    pub fn validate(self: Binding) !void {
        try self.interpretation.validate();
        try c.Model.nativeId(self.namespace);
    }
};
pub const Revision = struct {
    definition: p.Growth.Definition,
    binding: Binding,
    name: []const u8,
    row: f.TableRow.Identity,
    pub fn validate(self: Revision) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.binding.validate();
        try label(self.name);
        try self.row.validate();
    }
    pub fn encode(self: Revision, output: std.mem.Allocator) ![]u8 {
        try self.validate();
        return p.Json.valueAllocBounded(output, self, max_revision_bytes);
    }
    pub fn decode(output: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Revision) {
        if (bytes.len > max_revision_bytes) return error.InvalidSecretReference;
        const parsed = try p.Json.parseFromSliceOwned(Revision, output, bytes);
        errdefer parsed.deinit();
        try parsed.value.validate();
        return parsed;
    }
};
pub const Read = struct { declaration: Declaration, revision: Revision };

pub fn key(name: []const u8) ![32]u8 {
    try label(name);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.secret-reference.name.v1\x00");
    hash.update(name);
    return hash.finalResult();
}
fn label(value: []const u8) !void {
    if (value.len == 0 or value.len > 255 or !std.ascii.isAlphanumeric(value[0])) return error.InvalidSecretReference;
    for (value) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '.' and byte != '_' and byte != '-') return error.InvalidSecretReference;
}

/// Discovery is a public control-plane read. Executable definitions must retain
/// the returned immutable binding before activation, not resolve it per turn.
pub fn discover(client: c.DirectTableClient, namespace: u64) !Binding {
    if (client.transaction != null) return error.InvalidTransactionGuard;
    const response = try client.call(.{ .native_binding = .{ .namespace = namespace, .kind = kind } });
    defer response.deinit();
    const metadata = response.value.result.native_binding orelse return error.SecretReferencesUnavailable;
    if (metadata.native_binding != kind or metadata.interpretation.kind != .kv or metadata.interpretation.retired or metadata.namespace != namespace) return error.InvalidSecretReference;
    const result: Binding = .{ .namespace = namespace, .interpretation = metadata.interpretation.interpretation };
    try result.validate();
    return result;
}
/// Output owns the result and its strings. The native read registers the KV
/// source in the current transaction, including absence and disabled entries.
pub fn read(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, binding: Binding, name: []const u8) !?Read {
    try binding.validate();
    try client.connection.object(binding.interpretation.object);
    // Validate the canonical metadata owner under current namespace/resource
    // rights. A caller-created KV with the same columns is not a secret owner.
    // Its binding is immutable after initialization; data remains read through
    // the original private transaction below, never through this control read.
    var control = client;
    control.transaction = null;
    if (!std.meta.eql(binding, try discover(control, binding.namespace))) return error.TableDefinitionChanged;
    const digest = try key(name);
    const found = (try c.DirectKVClient.apply(output, client, .{ .get = .{ .object = binding.interpretation.object, .key = &digest } })).value;
    if (!std.meta.eql(found.interpretation.interpretation, binding.interpretation) or found.interpretation.retired) return error.TableDefinitionChanged;
    const spec = try c.NativeBindingSchema.kvSpec(kind);
    if (found.spec.nullable or !try spec.typeOf().eql(found.spec.typeOf())) return error.InvalidNativeBindingSchema;
    if (client.transaction != null and (found.workspace == null or found.workspace.?.cut.begin.mode != .serializable)) return error.InvalidTransactionGuard;
    const cell = found.value orelse {
        if (found.revision != null) return error.InvalidKVResponse;
        return null;
    };
    const declaration = try Declaration.fromValue(cell);
    if (!std.mem.eql(u8, declaration.name, name)) return error.InvalidSecretReference;
    const revision: Revision = .{ .definition = p.Growth.current_definition, .binding = binding, .name = declaration.name, .row = found.revision orelse return error.InvalidKVResponse };
    try revision.validate();
    return .{ .declaration = declaration, .revision = revision };
}
pub fn current(client: c.DirectTableClient, revision: Revision) !bool {
    try revision.validate();
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    const found = try read(&output, client, revision.binding, revision.name) orelse return false;
    return found.declaration.enabled and std.meta.eql(found.revision.row, revision.row);
}

test "native secret references contain metadata only and require exact private content" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var commitment: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("mounted-bytes", &commitment, .{});
    const declaration: Declaration = .{ .name = "browser.cookie_key", .file = "cookie-key.2026-11-09", .content_sha256 = commitment, .enabled = true };
    try t.expectEqualDeep(declaration, try Declaration.fromValue(try declaration.value(arena.allocator())));
    try declaration.verifyContent("mounted-bytes");
    try t.expectError(error.SecretContentChanged, declaration.verifyContent("mounted-bytes\n"));
    try t.expectError(error.InvalidSecretContent, declaration.verifyContent(""));
    var disabled = declaration;
    disabled.enabled = false;
    try t.expectError(error.SecretDisabled, disabled.verifyContent("mounted-bytes"));
    for ([_][]const u8{ "", ".", "..", "../secret", "/secret", "a/b", "a\\b", "a\x00b", "a\r\nb" }) |bad| {
        var invalid = declaration;
        invalid.file = bad;
        try t.expectError(error.InvalidSecretReference, invalid.validate());
    }
    try t.expect(!std.mem.eql(u8, &try key("browser.cookie_key"), &try key("browser-cookie_key")));
    const spec = try c.NativeBindingSchema.kvSpec(kind);
    var columns: [2]f.TableSchema.Column = undefined;
    try c.NativeBindingSchema.validate(kind, spec.schema(7, &columns), true);
    var fields = spec.fields[0..4].*;
    fields[0].nullable = true;
    const nullable: c.storage.KVDeclaration.Spec = .{ .value_type = .row, .nullable = false, .fields = &fields };
    try t.expectError(error.InvalidNativeBindingSchema, c.NativeBindingSchema.validate(kind, nullable.schema(7, &columns), true));
}

test "native secret revisions own their labels and reject missing or foreign definitions" {
    const t = std.testing;
    const revision: Revision = .{
        .definition = p.Growth.current_definition,
        .binding = .{ .namespace = 1, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(3) } },
        .name = "browser.cookie_key",
        .row = .{ .origin = 2, .operation = 10, .ordinal = 0 },
    };
    const encoded = try revision.encode(t.allocator);
    defer t.allocator.free(encoded);
    var decoded = try Revision.decode(t.allocator, encoded);
    defer decoded.deinit();
    try t.expectEqualDeep(revision, decoded.value);
    const native = @tagName(p.Growth.current_definition);
    const position = std.mem.indexOf(u8, encoded, native).?;
    encoded[position] = if (encoded[position] == '0') '1' else '0';
    try t.expectError(error.InvalidJsonShape, Revision.decode(t.allocator, encoded));
    @memset(encoded, 'x');
    try t.expectEqualStrings(revision.name, decoded.value.name);
    try t.expectError(error.MissingField, Revision.decode(t.allocator, "{}"));
}
