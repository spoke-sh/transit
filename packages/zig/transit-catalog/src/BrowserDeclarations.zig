//! Typed declarations and durable browser lifecycle records. The serving host
//! owns I/O; these types confer no native privilege and contain no credentials.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const ingress = c.DeclarativeIngress;
pub const Store = c.BrowserRecordStore;
pub const Digest = [32]u8;
pub const Mutation = [16]u8;
pub const definition = "transit.browser.v1.2026-10-30";
pub const max_record_bytes = 64 * 1024;

pub fn name(value: []const u8) !void {
    if (value.len == 0 or value.len > 63) return error.InvalidBrowserName;
    for (value) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '_' and ch != '-') return error.InvalidBrowserName;
}

/// A reference into the host's private secret directory. The directory is
/// deployment trust; enabled/revisioned references are catalog declarations.
pub const Secret = struct {
    name: []const u8,
    enabled: bool,
    file: []const u8,
    pub fn validate(self: Secret) !void {
        try name(self.name);
        try name(self.file); // one basename; no traversal or ambient environment
    }
};
pub const Provider = struct {
    enabled: bool,
    profile: ingress.IdentityProviderDeclaration,
    secret: []const u8,
    /// Facebook's web Login uses a confidential client, not S256 PKCE. This
    /// choice is explicit; the state/cookie claim remains mandatory in both.
    pkce: enum { s256, confidential_client },
    jwks_endpoint: ?[]const u8,
    jwks_ttl_ms: u32 = 300_000,
    retired_kids: []const []const u8 = &.{},
    pub fn validate(self: Provider, development: bool) !void {
        try self.profile.validate(development);
        try name(self.profile.provider_name);
        try name(self.secret);
        if (self.profile.cached_jwks_json != null or self.profile.issuer_profile.jwks_keys.len != 0) return error.JwksMustBeAcquired;
        if (self.profile.verification_mode == .oidc_rs256_id_token) {
            const url = self.jwks_endpoint orelse return error.MissingJwksEndpoint;
            if (!std.mem.startsWith(u8, url, "https://") and !(development and std.mem.startsWith(u8, url, "http://127.0.0.1:"))) return error.InvalidJwksEndpoint;
            if (self.pkce != .s256) return error.PkceRequired;
        } else if (self.jwks_endpoint != null) return error.InvalidJwksEndpoint;
        if (self.profile.verification_mode == .oauth2_user_profile_json and self.pkce != .s256) return error.PkceRequired;
        if (self.jwks_ttl_ms < 1000 or self.jwks_ttl_ms > 3_600_000 or self.retired_kids.len > 32) return error.InvalidJwksPolicy;
        if (self.profile.issuer_profile.expected_audiences.len != 1 or !std.mem.eql(u8, self.profile.issuer_profile.expected_audiences[0], self.profile.client_id)) return error.InvalidProviderAudience;
    }
};
/// Operators bind an identity to an existing native reader, using its actual
/// signing key by secret reference. The host never impersonates that principal
/// with its own key. Provisioning the principal/grants remains a native operation.
pub const Credential = struct {
    principal: u64,
    role: ?u64,
    secret: []const u8,
    pub fn validate(self: Credential) !void {
        if (self.principal <= ingress.bootstrap_owner_principal_id or self.principal > p.max_counter or self.role == p.Authorization.root_role) return error.BootstrapBindingForbidden;
        try name(self.secret);
    }
};
pub const Binding = struct {
    identity: Digest,
    enabled: bool,
    restricted: bool,
    reader: ?Credential,
    pub fn validate(self: Binding) !void {
        if (std.mem.allEqual(u8, &self.identity, 0)) return error.InvalidBrowserIdentity;
        if (self.reader) |reader| try reader.validate();
    }
};
pub const Publication = struct {
    descriptor: c.PublishedResource.PublishedResourceDescriptor,
    audience: enum { public, bound_identity },
    source: p.DataLifecycle.Definition,
    source_name: []const u8,
    publisher: Credential,
    /// Total response budget; exceeding it refuses the entire snapshot.
    max_rows: u32 = 1000,
    max_bytes: u32 = 1024 * 1024,
    pub fn validate(self: Publication) !void {
        try self.descriptor.validate();
        try name(self.descriptor.canonical_name);
        try self.source.validate();
        try self.publisher.validate();
        if (self.descriptor.parameters.len != 0 or self.descriptor.backing_kind != .compiled_sql_plan or self.descriptor.dependencies.len != 1 or self.descriptor.tzdb_version != null) return error.UnsupportedBrowserPublication;
        const dependency = self.descriptor.dependencies[0];
        if (dependency.source_object != self.source.object.object or dependency.source_revision != self.source.revision or self.descriptor.branch_id != self.source.object.branch) return error.PublicationSourceMismatch;
        for (self.descriptor.result_schema.columns) |column| switch (column.type) {
            .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64, .boolean, .utf8, .decimal => {},
            else => return error.UnsupportedBrowserColumn,
        };
        if (self.source_name.len == 0 or self.source_name.len > 255 or self.max_rows == 0 or self.max_rows > 10_000 or self.max_bytes < 1024 or self.max_bytes > 4 * 1024 * 1024) return error.InvalidPublicationBudget;
    }
};
pub const Declaration = union(enum) {
    provider: Provider,
    secret: Secret,
    binding: Binding,
    publication: Publication,
    pub fn validate(self: Declaration, development: bool) !void {
        switch (self) {
            .provider => |v| try v.validate(development),
            inline else => |v| try v.validate(),
        }
    }
    pub fn kind(self: Declaration) Store.Kind {
        return switch (self) {
            inline else => |_, tag| @field(Store.Kind, @tagName(tag)),
        };
    }
    pub fn key(self: Declaration) Digest {
        return switch (self) {
            .provider => |v| Store.digest(v.profile.provider_name),
            .secret => |v| Store.digest(v.name),
            .binding => |v| v.identity,
            .publication => |v| Store.digest(v.descriptor.canonical_name),
        };
    }
};
pub const Change = struct {
    definition: []const u8,
    namespace: u64,
    mutation: Mutation,
    expected: ?Store.Revision,
    declaration: Declaration,
    pub fn apply(self: Change, store: Store, development: bool) !Store.Accepted {
        if (!std.mem.eql(u8, self.definition, definition)) return error.IncompatibleDefinition;
        if (self.namespace != store.namespace) return error.BrowserNamespaceMismatch;
        try self.declaration.validate(development);
        const bytes = try p.Json.valueAlloc(store.client.allocator, self.declaration);
        defer store.client.allocator.free(bytes);
        if (self.declaration == .publication) {
            const publication = self.declaration.publication;
            try store.client.connection.object(publication.source.object);
            if (publication.descriptor.namespace_id != store.namespace) return error.BrowserNamespaceMismatch;
            var previous = try read(Declaration, store, .publication, self.declaration.key());
            defer if (previous) |*value| value.deinit();
            if (previous) |value| {
                if (std.mem.eql(u8, &value.record.value().mutation, &self.mutation))
                    return store.put(self.declaration.kind(), self.declaration.key(), self.mutation, self.expected, bytes);
                if (value.value() != .publication) return error.InvalidBrowserRecord;
                const prior = value.value().publication;
                if (prior.descriptor.state == .retired) return error.PublishedResourceRetired;
                if (publication.descriptor.resource_object != prior.descriptor.resource_object) return error.PublicationIdentityChanged;
                if (publication.descriptor.publication_revision != prior.descriptor.publication_revision) {
                    if (publication.descriptor.previous_revision != prior.descriptor.publication_revision) return error.InvalidPublishedResourceRevisionLineage;
                } else {
                    var without_state = publication;
                    without_state.descriptor.state = prior.descriptor.state;
                    const old_bytes = try p.Json.valueAlloc(store.client.allocator, prior);
                    defer store.client.allocator.free(old_bytes);
                    const new_bytes = try p.Json.valueAlloc(store.client.allocator, without_state);
                    defer store.client.allocator.free(new_bytes);
                    if (!std.mem.eql(u8, old_bytes, new_bytes)) return error.PublicationRevisionRequired;
                }
            } else if (publication.descriptor.publication_revision != 1) return error.InvalidPublishedResourceRevisionLineage;
        }
        return store.put(self.declaration.kind(), self.declaration.key(), self.mutation, self.expected, bytes);
    }
};

pub const Identity = struct {
    provider: []const u8,
    subject: []const u8,
    pub fn digest(issuer: []const u8, client_id: []const u8, subject: []const u8) Digest {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.browser.identity.v1\x00");
        for ([_][]const u8{ issuer, client_id, subject }) |part| {
            var length: [8]u8 = undefined;
            std.mem.writeInt(u64, &length, part.len, .little);
            hash.update(&length);
            hash.update(part);
        }
        return hash.finalResult();
    }
};
pub const Challenge = struct {
    provider: []const u8,
    provider_revision: Store.Revision,
    secret_revision: Store.Revision,
    secret_commitment: Digest,
    cookie_digest: Digest,
    pkce_digest: Digest,
    nonce_digest: Digest,
    expires_ms: u64,
    state: union(enum) {
        issued,
        /// Acceptance is durable before exchange. A crash or lost response
        /// leaves this identity uncertain; activation never redispatches it.
        claimed: struct { effect: Mutation, code_digest: Digest },
        complete: struct { effect: Mutation, identity: Digest },
        failed: struct { effect: Mutation },
    },
    pub fn claim(self: Challenge, cookie: []const u8, verifier: []const u8, nonce: []const u8, code: []const u8, now_ms: u64, effect: Mutation) !Challenge {
        if (self.state != .issued) return error.CallbackAlreadyClaimed;
        if (now_ms >= self.expires_ms) return error.LoginExpired;
        if (cookie.len != 43 or verifier.len != 43 or nonce.len != 43 or code.len == 0 or code.len > 4096 or std.mem.allEqual(u8, &effect, 0)) return error.InvalidCallback;
        inline for (.{ .{ cookie, self.cookie_digest }, .{ verifier, self.pkce_digest }, .{ nonce, self.nonce_digest } }) |pair| {
            if (!std.crypto.timing_safe.eql(Digest, Store.digest(pair[0]), pair[1])) return error.InvalidCallbackBinding;
        }
        var next = self;
        next.state = .{ .claimed = .{ .effect = effect, .code_digest = Store.digest(code) } };
        return next;
    }
};
pub const Session = struct {
    identity: Digest,
    provider: []const u8,
    provider_revision: Store.Revision,
    created_ms: u64,
    expires_ms: u64,
    revoked: bool,
    pub fn requireLive(self: Session, now_ms: u64) !void {
        if (self.revoked or now_ms < self.created_ms or now_ms >= self.expires_ms) return error.SessionExpired;
    }
};
pub fn Owned(comptime T: type) type {
    return struct {
        record: Store.Read,
        parsed: std.json.Parsed(T),
        pub fn deinit(self: *@This()) void {
            self.parsed.deinit();
            self.record.deinit();
        }
        pub fn value(self: @This()) T {
            return self.parsed.value;
        }
    };
}
pub fn read(comptime T: type, store: Store, kind: Store.Kind, key: Digest) !?Owned(T) {
    var record = try store.read(kind, key) orelse return null;
    errdefer record.deinit();
    const parsed = try std.json.parseFromSlice(T, store.client.allocator, record.value().payload, .{ .allocate = .alloc_always, .duplicate_field_behavior = .@"error" });
    return .{ .record = record, .parsed = parsed };
}
pub fn save(store: Store, kind: Store.Kind, key: Digest, mutation: Mutation, expected: ?Store.Revision, value: anytype) !Store.Accepted {
    const bytes = try p.Json.valueAlloc(store.client.allocator, value);
    defer store.client.allocator.free(bytes);
    return store.put(kind, key, mutation, expected, bytes);
}

test "browser claim binds cookie PKCE nonce expiry and refuses replay without retaining credentials" {
    const t = std.testing;
    const cookie = &@as([43]u8, @splat('c'));
    const verifier = &@as([43]u8, @splat('v'));
    const nonce = &@as([43]u8, @splat('n'));
    const challenge: Challenge = .{ .provider = "example", .provider_revision = .{ .partition = 1, .next_lsn = 2 }, .secret_revision = .{ .partition = 1, .next_lsn = 3 }, .secret_commitment = @splat(7), .cookie_digest = Store.digest(cookie), .pkce_digest = Store.digest(verifier), .nonce_digest = Store.digest(nonce), .expires_ms = 100, .state = .issued };
    try t.expectError(error.InvalidCallbackBinding, challenge.claim(&@as([43]u8, @splat('x')), verifier, nonce, "code", 99, @splat(1)));
    try t.expectError(error.InvalidCallbackBinding, challenge.claim(cookie, &@as([43]u8, @splat('x')), nonce, "code", 99, @splat(1)));
    try t.expectError(error.InvalidCallbackBinding, challenge.claim(cookie, verifier, &@as([43]u8, @splat('x')), "code", 99, @splat(1)));
    try t.expectError(error.LoginExpired, challenge.claim(cookie, verifier, nonce, "code", 100, @splat(1)));
    const claimed = try challenge.claim(cookie, verifier, nonce, "secret-code", 99, @splat(1));
    try t.expectError(error.CallbackAlreadyClaimed, claimed.claim(cookie, verifier, nonce, "secret-code", 99, @splat(2)));
    const bytes = try p.Json.valueAlloc(t.allocator, claimed);
    defer t.allocator.free(bytes);
    try t.expect(std.mem.indexOf(u8, bytes, "secret-code") == null);
    try t.expect(std.mem.indexOf(u8, bytes, verifier) == null);
}
test "browser native binding cannot select bootstrap owner or root role" {
    const t = std.testing;
    try t.expectError(error.BootstrapBindingForbidden, (Credential{ .principal = 1, .role = null, .secret = "reader" }).validate());
    try t.expectError(error.BootstrapBindingForbidden, (Credential{ .principal = 2, .role = 0, .secret = "reader" }).validate());
    try (Credential{ .principal = 2, .role = null, .secret = "reader" }).validate();
    try t.expectError(error.InvalidBrowserName, (Secret{ .name = "oauth", .enabled = true, .file = "../key" }).validate());
    try t.expect(!std.mem.eql(u8, &Identity.digest("a", "bc", "d"), &Identity.digest("ab", "c", "d")));
}
