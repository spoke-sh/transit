//! Action-bound configuration operations. Native authority checks the original
//! caller; a host can forward the signed check without acquiring a service key.
const std = @import("std");
const p = @import("transit_protocol");
const g = p.Growth;
const a = p.Authorization;
const R = @import("Registry.zig");
pub const max_bytes = 256 * 1024;
pub const page_size = 8;
pub const route = "/configuration/v1";
pub const inspect: a.Privileges = 1;
pub const provenance: a.Privileges = 2;
pub const reload: a.Privileges = 4;
pub const all_privileges = inspect | provenance | reload;

pub const Binding = struct {
    realm: u64,
    installation: [16]u8,
    object: a.ObjectRef,
    pub fn validate(self: Binding) !void {
        if (self.realm == 0 or self.realm > p.max_counter or std.mem.allEqual(u8, &self.installation, 0) or self.object.kind != .domain) return error.InvalidConfigurationBinding;
        try self.object.validate();
    }
    pub fn identity(installation: [16]u8) [32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.configuration.binding.v1\x00");
        hash.update(&installation);
        return hash.finalResult();
    }
};
pub const Cursor = struct { revision: u64, after: u64 };
pub const Action = union(enum) {
    settings: struct { name: ?[]const u8 = null, cursor: ?Cursor = null, origins: bool = false },
    reload: struct { expected_generation: u64 },
    reloads: struct { operation: ?[16]u8 = null, cursor: ?Cursor = null, origins: bool = false },
};
pub const Request = struct {
    definition: g.Definition,
    binding: Binding,
    operation: [16]u8,
    action: Action,
    pub fn validate(self: Request) !void {
        if (self.definition != g.current_definition) return error.IncompatibleDefinition;
        try self.binding.validate();
        if (std.mem.allEqual(u8, &self.operation, 0)) return error.InvalidConfigurationOperation;
        switch (self.action) {
            .settings => |value| {
                if (value.name) |name| try R.validateName(name);
                if (value.name != null and value.cursor != null) return error.InvalidConfigurationCursor;
                if (value.cursor) |cursor| try cursorValid(cursor);
            },
            .reload => |value| if (value.expected_generation == 0 or value.expected_generation > p.max_counter) return error.InvalidConfigurationGeneration,
            .reloads => |value| {
                if (value.operation != null and value.cursor != null) return error.InvalidConfigurationCursor;
                if (value.cursor) |cursor| try cursorValid(cursor);
            },
        }
    }
    pub fn privileges(self: Request) a.Privileges {
        return switch (self.action) {
            .settings => |value| inspect | if (value.origins) provenance else @as(a.Privileges, 0),
            .reload => reload,
            .reloads => |value| inspect | if (value.origins) provenance else @as(a.Privileges, 0),
        };
    }
    pub fn digest(self: Request, allocator: std.mem.Allocator) ![32]u8 {
        try self.validate();
        const bytes = try p.Json.valueAlloc(allocator, self);
        defer allocator.free(bytes);
        if (bytes.len > max_bytes) return error.ConfigurationTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.configuration.request.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
};
fn cursorValid(cursor: Cursor) !void {
    if (cursor.revision == 0 or cursor.revision > p.max_counter or cursor.after > p.max_counter) return error.InvalidConfigurationCursor;
}

pub const Signed = struct {
    configuration: Request,
    authority: g.SignedQuery,

    pub fn sign(request: Request, allocator: std.mem.Allocator, principal: u64, epoch: u64, role: ?u64, key: p.Ed25519.KeyPair) !Signed {
        const proof = try a.Proof.sign(.{ .definition = g.current_definition, .realm = request.binding.realm, .principal = principal, .credential_epoch = epoch, .role = role, .audience = request.binding.object.id, .context = try request.digest(allocator) }, key);
        var requirements: [a.max_requirements]?a.Requirement = @splat(null);
        requirements[0] = .{ .object = request.binding.object, .privileges = request.privileges() };
        return .{ .configuration = request, .authority = try g.signQuery(.{ .realm = request.binding.realm, .principal = principal, .kind = .{ .authorization = .{ .role = role, .kind = .{ .check = .{ .subject = .{ .signed = proof }, .requirements = requirements } } } } }, key) };
    }

    /// Structural/context validation only. Before effects or disclosure the host
    /// MUST forward authority to the current node and validate its response.
    pub fn validate(self: Signed, allocator: std.mem.Allocator, binding: Binding) !a.Proof {
        try self.configuration.validate();
        if (!std.meta.eql(binding, self.configuration.binding)) return error.ConfigurationDenied;
        const query = self.authority.query;
        if (query.realm != binding.realm or query.kind != .authorization or query.kind.authorization.kind != .check) return error.ConfigurationDenied;
        const guard = query.kind.authorization.kind.check;
        try guard.validate();
        if (guard.subject != .signed or guard.selectable != null) return error.ConfigurationDenied;
        const proof = guard.subject.signed;
        const claim = proof.claim;
        if (claim.principal != query.principal or claim.realm != binding.realm or claim.role != query.kind.authorization.role or claim.audience != binding.object.id or !std.mem.eql(u8, &claim.context, &try self.configuration.digest(allocator))) return error.ConfigurationDenied;
        if (guard.requirements[1] != null) return error.ConfigurationDenied;
        const required = guard.requirements[0].?;
        if (!required.object.eql(binding.object) or required.access != .all or required.privileges != self.configuration.privileges()) return error.ConfigurationDenied;
        return proof;
    }
};

pub const Row = struct {
    name: []const u8,
    value: ?[]const u8,
    default_value: ?[]const u8,
    configured_value: ?[]const u8,
    description: []const u8,
    owner: []const u8,
    instance: []const u8,
    kind: R.Kind,
    unit: ?[]const u8,
    minimum: ?u64,
    maximum: ?u64,
    enum_values: []const []const u8,
    scope: R.Scope,
    change: R.Change,
    session_mutable: bool,
    session_generation: ?u64,
    source: R.Source,
    configured_source: R.Source,
    source_name: ?[]const u8,
    source_line: ?u64,
    source_column: ?u64,
    generation: u64,
    pending_restart: bool,
    redacted: bool,
};
pub const Phase = enum { applying, applied, pending_restart, rejected, partial };
pub const Component = struct { owner: []const u8, generation: u64, phase: Phase, error_code: ?[]const u8 = null };
pub const Outcome = struct {
    operation: [16]u8,
    ordinal: u64,
    principal: u64,
    generation: u64,
    phase: Phase,
    components: []const Component,
    error_code: ?[]const u8 = null,
    error_field: ?[]const u8 = null,
    error_line: ?u64 = null,
    error_column: ?u64 = null,
};
pub const Response = struct {
    definition: g.Definition,
    binding: Binding,
    policy_revision: u64,
    result: union(enum) {
        settings: struct { generation: u64, rows: []const Row, next: ?Cursor },
        reload: Outcome,
        reloads: struct { revision: u64, rows: []const Outcome, next: ?Cursor },
    },
    pub fn validate(self: Response, request: Request) !void {
        if (self.definition != g.current_definition) return error.IncompatibleDefinition;
        if (!std.meta.eql(self.binding, request.binding) or self.policy_revision > p.max_counter or !std.mem.eql(u8, @tagName(self.result), @tagName(request.action))) return error.InvalidConfigurationResponse;
        switch (self.result) {
            .settings => |page| {
                if (page.generation == 0 or page.generation > p.max_counter or page.rows.len > page_size) return error.InvalidConfigurationResponse;
                if (page.next) |cursor| {
                    try cursorValid(cursor);
                    if (cursor.revision != page.generation) return error.InvalidConfigurationResponse;
                }
                for (page.rows) |row| {
                    try R.validateName(row.name);
                    if (row.generation != page.generation or row.owner.len == 0 or (row.redacted and (row.value != null or row.default_value != null or row.configured_value != null))) return error.InvalidConfigurationResponse;
                    if (request.action.settings.name) |name| if (!std.mem.eql(u8, name, row.name)) return error.InvalidConfigurationResponse;
                    if (!request.action.settings.origins and (row.source_name != null or row.source_line != null or row.source_column != null)) return error.InvalidConfigurationResponse;
                }
            },
            .reload => |outcome| {
                try validOutcome(outcome);
                if (!std.mem.eql(u8, &outcome.operation, &request.operation)) return error.InvalidConfigurationResponse;
            },
            .reloads => |page| {
                if (page.rows.len > page_size or page.revision > p.max_counter) return error.InvalidConfigurationResponse;
                if (page.next) |cursor| {
                    try cursorValid(cursor);
                    if (cursor.revision != page.revision) return error.InvalidConfigurationResponse;
                }
                for (page.rows) |outcome| {
                    try validOutcome(outcome);
                    if (!request.action.reloads.origins and (outcome.error_line != null or outcome.error_column != null)) return error.InvalidConfigurationResponse;
                }
            },
        }
    }
};
fn validOutcome(outcome: Outcome) !void {
    if (outcome.ordinal == 0 or outcome.ordinal > p.max_counter or outcome.generation == 0 or outcome.generation > p.max_counter or std.mem.allEqual(u8, &outcome.operation, 0) or outcome.components.len > 32) return error.InvalidConfigurationResponse;
}

test "configuration requests bind operation target action and required rights" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const binding: Binding = .{ .realm = 42, .installation = @splat(3), .object = .{ .kind = .domain, .id = 19 } };
    const request: Request = .{ .definition = g.current_definition, .binding = binding, .operation = @splat(4), .action = .{ .reload = .{ .expected_generation = 5 } } };
    const original = try Signed.sign(request, t.allocator, 11, 2, null, key);
    _ = try original.validate(t.allocator, binding);
    var changed = original;
    changed.configuration.action.reload.expected_generation += 1;
    try t.expectError(error.ConfigurationDenied, changed.validate(t.allocator, binding));
    changed = original;
    changed.authority.query.kind.authorization.kind.check.requirements[0].?.privileges = inspect;
    try t.expectError(error.ConfigurationDenied, changed.validate(t.allocator, binding));
    changed = original;
    changed.configuration.operation[0] ^= 1;
    try t.expectError(error.ConfigurationDenied, changed.validate(t.allocator, binding));
    changed = original;
    changed.authority.query.principal += 1;
    try t.expectError(error.ConfigurationDenied, changed.validate(t.allocator, binding));
    var foreign = binding;
    foreign.installation[0] ^= 1;
    try t.expectError(error.ConfigurationDenied, original.validate(t.allocator, foreign));
}
