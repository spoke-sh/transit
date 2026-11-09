//! Canonical native state schemas. Bindings confer no grants. The browser binding
//! Table's intrinsic CHECK is retained in its definition and enforced by every
//! Table mutation path, including predicate DML and private transactions.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
pub const Kind = f.NativeBinding.Kind;
const Field = f.Types.Field;
const Constraint = f.TableConstraints;
const credential_check = "transit_browser_credentials";

fn field(comptime name: []const u8, comptime typ: f.Types.Type) Field {
    return .{ .name = name, .type = typ, .nullable = true };
}
const identity = Field{ .name = "id", .type = .utf8, .nullable = false, .max_characters = 64 };
const identity_ref = Field{ .name = "identity_id", .type = .utf8, .nullable = true, .max_characters = 64 };
const identities = [_]Field{ identity, field("provider", .utf8), field("issuer", .utf8), field("client_id", .utf8), field("subject", .utf8) };
const bindings = [_]Field{ identity_ref, field("principal", .int64), field("role", .int64), field("signing_key_reference", .utf8), field("enabled", .boolean), field("restricted", .boolean) };
const challenges = [_]Field{ field("provider", .utf8), field("policy_revision", .binary), field("secret_revision", .binary), field("secret_commitment", .binary), field("cookie_key_revision", .binary), field("browser_commitment", .binary), field("expires_at", .{ .timestamp = .utc }), field("state", .utf8), field("effect_id", .uuid), field("code_commitment", .binary), identity_ref };
const sessions = [_]Field{ identity_ref, field("provider", .utf8), field("policy_revision", .binary), field("created_at", .{ .timestamp = .utc }), field("expires_at", .{ .timestamp = .utc }), field("revoked", .boolean) };
const secrets = [_]Field{
    .{ .name = "name", .type = .utf8, .max_characters = 255 },
    .{ .name = "file", .type = .utf8, .max_characters = 255 },
    .{ .name = "content_sha256", .type = .binary },
    .{ .name = "enabled", .type = .boolean },
};

fn fields(kind: Kind) []const Field {
    return switch (kind) {
        .browser_identities => &identities,
        .browser_bindings => &bindings,
        .browser_challenges => &challenges,
        .browser_sessions => &sessions,
        .secret_references => &secrets,
    };
}
/// Native KV owners use the same exact field layout as independent admission.
/// The returned descriptor borrows immutable schema storage.
pub fn kvSpec(kind: Kind) !c.storage.KVDeclaration.Spec {
    if (!kind.isKV()) return error.InvalidNativeBindingKind;
    return .{ .value_type = .row, .nullable = false, .fields = fields(kind) };
}
fn sameField(actual: Field, expected: Field, nullable: bool) !void {
    if (!std.mem.eql(u8, actual.name, expected.name) or !try actual.type.eql(expected.type) or
        actual.nullable != nullable or actual.optional or actual.max_characters != expected.max_characters)
        return error.InvalidNativeBindingSchema;
}

fn credentialAtoms(schema: f.TableSchema.Schema) [5]Constraint.CheckAtom {
    return .{
        .{ .compare_literal = .{ .column = schema.columns[1].id, .op = .gt, .literal = .{ .signed = 1 } } },
        .{ .compare_literal = .{ .column = schema.columns[1].id, .op = .lte, .literal = .{ .signed = c.protocol.max_counter } } },
        .{ .compare_literal = .{ .column = schema.columns[2].id, .op = .gt, .literal = .{ .signed = 0 } } },
        .{ .compare_literal = .{ .column = schema.columns[2].id, .op = .lte, .literal = .{ .signed = c.protocol.max_counter } } },
        .{ .compare_literal = .{ .column = schema.columns[3].id, .op = .neq, .literal = .{ .bytes = "" } } },
    };
}

/// Validate the exact public columns independently of the proposed name and
/// stable object/column IDs. The current binding profile fixes field order.
pub fn validateShape(kind: Kind, schema: f.TableSchema.Schema, is_kv: bool) !void {
    try schema.validate();
    if (kind.isKV() != is_kv) return error.InvalidNativeBindingKind;
    const expected = fields(kind);
    if (is_kv) {
        const spec = try c.storage.KVDeclaration.validateSchema(schema);
        if (spec.value_type != .row or spec.nullable or spec.fields.len != expected.len) return error.InvalidNativeBindingSchema;
        for (spec.fields, expected) |actual, wanted| try sameField(actual, wanted, wanted.nullable);
    } else {
        if (schema.columns.len != expected.len or schema.primary_key.len != 1 or schema.primary_key[0] != schema.columns[0].id) return error.InvalidNativeBindingSchema;
        for (schema.columns, expected) |column, wanted| {
            try sameField(column.field(), wanted, false);
            if ((column.collation != .none and column.collation != .utf8_binary) or column.default != null) return error.InvalidNativeBindingSchema;
        }
    }
}

pub fn validate(kind: Kind, schema: f.TableSchema.Schema, is_kv: bool) !void {
    try validateShape(kind, schema, is_kv);
    if (kind != .browser_bindings) return;
    const atoms = credentialAtoms(schema);
    for (schema.integrity.checks) |check| if (std.mem.eql(u8, check.name, credential_check)) {
        if (!check.validated or check.atoms.len != atoms.len) return error.InvalidNativeBindingConstraint;
        for (check.atoms, atoms) |actual, expected| {
            if (actual != .compare_literal or actual.compare_literal.column != expected.compare_literal.column or actual.compare_literal.op != expected.compare_literal.op) return error.InvalidNativeBindingConstraint;
            const value = actual.compare_literal.literal;
            const want = expected.compare_literal.literal;
            if (value == .bytes and want == .bytes) {
                if (!std.mem.eql(u8, value.bytes, want.bytes)) return error.InvalidNativeBindingConstraint;
            } else if (value != .signed or want != .signed or value.signed != want.signed) return error.InvalidNativeBindingConstraint;
        }
        return;
    };
    return error.InvalidNativeBindingConstraint;
}

/// SQL/native preparation calls this before hashing an intent. The server
/// independently requires the same constraint; it never rewrites accepted work.
pub fn prepare(allocator: std.mem.Allocator, kind: Kind, schema: *f.TableSchema.Schema) !void {
    try validateShape(kind, schema.*, false);
    if (kind == .browser_bindings) {
        for (schema.integrity.checks) |check| if (std.mem.eql(u8, check.name, credential_check)) return validate(kind, schema.*, false);
        const checks = try allocator.alloc(Constraint.CheckConstraint, schema.integrity.checks.len + 1);
        @memcpy(checks[0..schema.integrity.checks.len], schema.integrity.checks);
        const atoms = credentialAtoms(schema.*);
        checks[checks.len - 1] = .{ .id = schema.integrity.next_id, .name = credential_check, .validated = true, .atoms = try allocator.dupe(Constraint.CheckAtom, &atoms) };
        schema.integrity = .{ .next_id = try std.math.add(u32, schema.integrity.next_id, 1), .checks = checks, .foreign_keys = schema.integrity.foreign_keys };
    }
    try validate(kind, schema.*, false);
}

test "canonical browser binding schema retains bootstrap exclusions as intrinsic constraints" {
    const t = std.testing;
    var compiled = try f.TableDdl.compile(t.allocator, "CREATE TABLE bindings (identity_id VARCHAR(64) PRIMARY KEY, principal BIGINT NOT NULL, role BIGINT NOT NULL, signing_key_reference TEXT NOT NULL, enabled BOOLEAN NOT NULL, restricted BOOLEAN NOT NULL) WITH (native_binding = 'browser.bindings')", null, null);
    defer compiled.deinit();
    const kind = compiled.statement.create.native_binding.?;
    var schema = try compiled.statement.create.bind(9);
    try t.expectError(error.InvalidNativeBindingConstraint, validate(kind, schema, false));
    try prepare(compiled.arena.allocator(), kind, &schema);
    var row = [_]f.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .bytes = "identity" } } },
        .{ .value = .{ .atom = .{ .signed = 2 } } },
        .{ .value = .{ .atom = .{ .signed = 2 } } },
        .{ .value = .{ .atom = .{ .bytes = "reader-key" } } },
        .{ .value = .{ .atom = .{ .boolean = true } } },
        .{ .value = .{ .atom = .{ .boolean = false } } },
    };
    try schema.validateWrite(&row);
    for ([_]i64{ -1, 0, 1, c.protocol.max_counter + 1 }) |principal| {
        row[1].value.atom.signed = principal;
        try t.expectError(error.CheckConstraintViolation, schema.validateWrite(&row));
    }
    row[1].value.atom.signed = 2;
    row[2].value.atom.signed = 0;
    try t.expectError(error.CheckConstraintViolation, schema.validateWrite(&row));
    row[2].value.atom.signed = 2;
    row[3].value.atom.bytes = "";
    try t.expectError(error.CheckConstraintViolation, schema.validateWrite(&row));
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    var decoded = try f.TableSchema.decode(t.allocator, try schema.encode(&bytes));
    defer decoded.deinit();
    try validate(kind, decoded.schema, false);
    var invalid = decoded.schema;
    invalid.integrity = .{};
    try t.expectError(error.InvalidNativeBindingConstraint, validate(kind, invalid, false));
}
