//! Named immutable single-Table branches. The catalog owns admission, retention
//! and publication; the selected Table remains the data and policy owner.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
pub const format: u32 = 0x42524331;
pub const max_bytes = 8192;

pub const Intent = struct {
    connection: w.Connection,
    namespace: u64,
    operation: u64,
    name: c.TableAuthority.Name,
    source: d.SourceCut,
    mode: p.Branch.Mode,

    pub fn identity(self: Intent) d.Operation {
        return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
    }
    pub fn validate(self: Intent) !void {
        try self.connection.validate();
        try c.Model.nativeId(self.namespace);
        try self.identity().validate();
        try self.name.validate();
        try self.source.validate();
        try self.connection.object(self.source.interpretation.object);
        if (self.source.manifest != null or self.source.checkpoint_lsn != 0 or self.source.accepted.next_lsn == 0) return error.InvalidBranchCreation;
    }
    pub fn digest(self: Intent) ![32]u8 {
        try self.validate();
        var bytes: [4096]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.table-branch.v1\x00");
        hash.update(writer.buffered());
        return hash.finalResult();
    }
};

pub const Phase = enum { admitted, published, abandoning, cancelled };
pub const State = struct {
    definition: p.Growth.Definition,
    branch: p.Branch.Identity,
    phase: Phase,
    head: ?p.Branch.Head,

    pub fn initial(receipt: c.DirectClientToken.Receipt) State {
        return .{ .definition = p.Growth.current_definition, .branch = .{ .scope = receipt.binding.key.connection.scope, .branch = receipt.position.next_lsn }, .phase = .admitted, .head = null };
    }
    pub fn validate(self: State, progress: c.DirectClientToken.Progress) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.branch.validate();
        if (progress.receipt.binding.intent != .branch or !std.meta.eql(self.branch, initial(progress.receipt).branch) or
            (self.phase == .published) != (self.head != null) or
            progress.pending != (self.phase == .admitted or self.phase == .abandoning) or
            progress.cancel != (self.phase == .abandoning or self.phase == .cancelled)) return error.InvalidBranchState;
        if (self.head) |head| {
            try head.validate();
            if (!std.meta.eql(head.reference.identity, self.branch) or head.reference.version != 1 or head.generation != 1) return error.InvalidBranchState;
        }
    }
    pub fn stage(self: State, objects: c.storage.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !c.DirectRecord.Reference {
        try self.validate(progress);
        var bytes: [max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        return c.DirectRecord.store(objects, progress.receipt.binding.key.scope(), format, writer.buffered());
    }
    pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !State {
        try progress.validate();
        const reference = progress.record orelse {
            const value = initial(progress.receipt);
            try value.validate(progress);
            return value;
        };
        if (reference.format != format or reference.content.bytes > max_bytes) return error.InvalidBranchState;
        const bytes = try c.DirectRecord.load(allocator, objects, reference);
        defer allocator.free(bytes);
        const parsed = try p.Json.parseFromSlice(State, allocator, bytes);
        defer parsed.deinit();
        try parsed.value.validate(progress);
        return parsed.value;
    }
};

pub const Status = struct { receipt: c.DirectClientToken.Receipt, revision: d.Position, state: State };
pub const Read = struct {
    head: p.Branch.Head,
    after: ?c.storage.TablePartition.SnapshotCursor,
    limits: c.storage.TablePartition.ReadLimits,
};
pub const Source = struct { head: p.Branch.Head, source: d.SourceCut, mode: p.Branch.Mode, interpretation: c.storage.TableDeclaration.Stored, rows: u64, schema: w.Binary };
pub const Page = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 8 };
    head: p.Branch.Head,
    source: d.SourceCut,
    total_rows: u64,
    rows: []const w.Binary,
    encoded_bytes: u32,
    next: ?c.storage.TablePartition.SnapshotCursor,
};
pub const Request = union(enum) {
    create: struct { key: c.DirectClientToken.Key, intent: Intent, budget: c.DirectClientToken.Budget = .{} },
    inspect: c.DirectClientToken.Key,
    advance: c.DirectClientToken.Key,
    cancel: c.DirectClientToken.Key,
    lookup: struct { namespace: u64, name: c.TableAuthority.Name },
    source: p.Branch.Head,
    scan: Read,

    pub fn mutation(self: Request) bool {
        return self == .create or self == .advance or self == .cancel;
    }
    pub fn validate(self: Request, connection: w.Connection) !void {
        switch (self) {
            .create => |value| {
                try value.key.validate();
                try value.intent.validate();
                try value.budget.validate();
                if (!std.meta.eql(value.key.connection, connection) or !std.meta.eql(value.intent.connection, connection)) return error.BranchIdentityConflict;
            },
            inline .inspect, .advance, .cancel => |key| {
                try key.validate();
                if (!std.meta.eql(key.connection, connection)) return error.BranchIdentityConflict;
            },
            .lookup => |value| {
                try c.Model.nativeId(value.namespace);
                try value.name.validate();
            },
            .source => |head| {
                try head.validate();
                try head.reference.identity.requireScope(connection.scope);
            },
            .scan => |value| {
                try value.head.validate();
                try value.head.reference.identity.requireScope(connection.scope);
                try value.limits.validate();
                if (value.limits.encoded_bytes > w.max_page_bytes) return error.InvalidTableReadBudget;
            },
        }
    }
};
pub const Result = union(enum) { status: ?Status, source: Source, page: Page };

/// Returned variable bytes belong to the parsed response. Retain it until all
/// rows/schema have been consumed, then deinit; a page is not a whole result.
pub fn call(client: c.DirectTableClient, request: Request) !std.json.Parsed(w.Response) {
    return client.call(.{ .branch = request });
}

pub fn validateResult(allocator: std.mem.Allocator, connection: w.Connection, request: Request, result: Result) !void {
    try request.validate(connection);
    switch (request) {
        .create, .inspect, .advance, .cancel, .lookup => {
            if (result != .status) return error.InvalidBranchResponse;
            const status = result.status orelse {
                if (request != .inspect and request != .lookup) return error.InvalidBranchResponse;
                return;
            };
            try status.receipt.validate();
            try status.revision.validate();
            const progress: c.DirectClientToken.Progress = .{ .receipt = status.receipt, .revision = status.revision, .pending = status.state.phase == .admitted or status.state.phase == .abandoning, .cancel = status.state.phase == .abandoning or status.state.phase == .cancelled, .record = null };
            try progress.validate();
            try status.state.validate(progress);
            const intent = status.receipt.binding.intent.branch;
            if (!std.meta.eql(intent.connection.scope, connection.scope) or intent.connection.branch != connection.branch or intent.connection.audience != connection.audience or intent.connection.principal != connection.principal) return error.InvalidBranchResponse;
            switch (request) {
                .create => |value| {
                    try value.key.requireSame(status.receipt.binding.key);
                    if (!std.meta.eql(value.intent, intent)) return error.InvalidBranchResponse;
                },
                inline .inspect, .advance, .cancel => |key| try key.requireSame(status.receipt.binding.key),
                .lookup => |value| if (value.namespace != intent.namespace or !std.meta.eql(value.name, intent.name) or status.state.phase != .published) return error.InvalidBranchResponse,
                else => unreachable,
            }
        },
        .source => |head| {
            if (result != .source) return error.InvalidBranchResponse;
            const value = result.source;
            try head.requireSame(value.head);
            try value.source.validate();
            try connection.object(value.source.interpretation.object);
            try value.interpretation.validate();
            if (!std.meta.eql(value.source.interpretation, value.interpretation.interpretation) or (value.mode == .schema_only and value.rows != 0)) return error.InvalidBranchResponse;
            const bytes = try value.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
            defer allocator.free(bytes);
            var decoded = try c.fuze.TableSchema.decode(allocator, bytes);
            defer decoded.deinit();
            if (decoded.schema.object != value.source.interpretation.object.object or !std.mem.eql(u8, &try decoded.schema.fingerprint(), &value.interpretation.schema_fingerprint)) return error.InvalidBranchResponse;
        },
        .scan => |read| {
            if (result != .page) return error.InvalidBranchResponse;
            const page = result.page;
            try read.head.requireSame(page.head);
            try page.source.validate();
            try connection.object(page.source.interpretation.object);
            if (page.rows.len > read.limits.rows or page.rows.len > page.total_rows or page.encoded_bytes > read.limits.encoded_bytes) return error.InvalidBranchResponse;
            var total: usize = 0;
            for (page.rows) |row| {
                const bytes = try row.decode(allocator, c.fuze.TableRow.max_bytes);
                defer allocator.free(bytes);
                total = try std.math.add(usize, total, bytes.len);
            }
            if (total != page.encoded_bytes) return error.InvalidBranchResponse;
            if (page.next) |next| {
                if (page.rows.len == 0) return error.InvalidBranchResponse;
                if (read.after) |previous| if (!std.meta.eql(next.source, previous.source) or std.mem.order(u8, &next.after, &previous.after) != .gt) return error.InvalidBranchResponse;
            } else if (read.after == null and page.rows.len != page.total_rows) return error.InvalidBranchResponse;
        },
    }
}

test "direct branch independent signature binds exact full-width source and mode" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, std.testing.allocator, @embedFile("fixtures/direct-branch-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(std.testing.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    try std.testing.expectEqual(fixture.intent_digest, try fixture.request.action.branch.create.intent.digest());
    var changed = fixture.request;
    changed.action.branch.create.intent.mode = .schema_only;
    try std.testing.expectError(error.InvalidAuthorizationCredential, changed.validate(std.testing.allocator));
}
