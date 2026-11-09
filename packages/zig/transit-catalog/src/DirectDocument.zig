//! Direct Document collection declaration and metadata over the Direct Data Plane.
const std = @import("std");
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const f = c.fuze;
const p = c.protocol;

pub const Policy = f.DocumentDdl.Policy;

pub const Definition = struct {
    definition: w.Definition,
    policy: Policy,
};

/// Revision of the current SQL row Document profile. This descriptor does not
/// authorize reads or retain a snapshot. Its physical owner is TablePartition;
/// ordered/tree DocumentPartition participants remain a separate interface.
pub const Revision = struct {
    definition: p.Growth.Definition,
    policy: Policy,
    guard: p.Transaction.StateGuard,

    pub const max_bytes = 2048;

    pub fn validate(self: Revision) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.policy.validate();
        if (self.policy.profile != .versioned) return error.UnsupportedTransactionParticipant;
        try self.guard.validate();
        if (self.guard.source.accepted.next_lsn == 0) return error.InvalidTransactionGuard;
    }

    /// Use metadata returned with the read, never a subsequent independent
    /// lookup. Private workspace mutations have no public revision yet.
    pub fn fromRead(metadata: w.Definition) !Revision {
        try metadata.interpretation.validate();
        if (metadata.workspace != null or metadata.interpretation.kind != .table or metadata.interpretation.retired)
            return error.InvalidTransactionGuard;
        const result: Revision = .{
            .definition = p.Growth.current_definition,
            .policy = metadata.document orelse return error.UnsupportedTransactionParticipant,
            .guard = .{ .source = .{ .interpretation = metadata.interpretation.interpretation, .accepted = metadata.position }, .changed_lsn = metadata.changed_lsn },
        };
        try result.validate();
        return result;
    }

    /// Explicitly select the existing SQL row Document's physical state owner.
    /// This does not select a partitioned tree Document under another name.
    pub fn target(self: Revision) !p.Transaction.Target {
        try self.validate();
        return .{ .object = self.guard.source.interpretation.object, .kind = .table, .partition = null };
    }

    /// Compare the prior observation with the transaction's retained source,
    /// before using it in a decision. The serializable coordinator subsequently
    /// checks this read participant again under its final publication fence.
    pub fn requireWorkspace(self: Revision, metadata: w.Definition) !void {
        try self.validate();
        const workspace = metadata.workspace orelse return error.InvalidTransactionGuard;
        try workspace.validate();
        if (workspace.cut.begin.mode != .serializable or metadata.interpretation.kind != .table or
            !std.meta.eql(metadata.document, @as(?Policy, self.policy)) or
            !std.meta.eql(metadata.interpretation.interpretation, workspace.source.source.interpretation))
            return error.TransactionConflict;
        try self.guard.requireUnchanged(workspace.source);
    }

    pub fn encode(self: Revision, buffer: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(buffer[0..@min(buffer.len, max_bytes)]);
        var json: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &json);
        return writer.buffered();
    }

    pub fn decode(bytes: []const u8) !Revision {
        if (bytes.len > max_bytes) return error.InvalidTransactionGuard;
        var scratch: [8 * max_bytes]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(&scratch);
        // All fields have fixed ownership. Decode directly rather than also
        // materializing an intermediate JSON tree in this bounded scratch area.
        const value = try std.json.parseFromSliceLeaky(Revision, fixed.allocator(), bytes, .{ .max_value_len = max_bytes });
        try value.validate();
        var canonical: [max_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try value.encode(&canonical))) return error.InvalidTransactionGuard;
        return value;
    }
};

pub const Declaration = struct {
    ddl: w.Ddl,
    policy: Policy,

    pub fn intent(self: Declaration, allocator: std.mem.Allocator) !c.DirectCatalog.Intent {
        return .{
            .kind = .table,
            .namespace = self.ddl.namespace,
            .name = try .init(self.ddl.name),
            .action = switch (self.ddl.action) {
                .create => |value| .{ .create = .{ .owner = value.owner, .schema = (try f.TableSchema.decode(allocator, try value.schema.decode(allocator, f.TableSchema.max_bytes))).schema } },
                .alter => |value| .{ .alter = try value.native(allocator) },
                .rename => |value| .{ .rename = try .init(value) },
                .drop => .drop,
            },
            .document = self.policy,
        };
    }

    pub fn digest(self: Declaration, allocator: std.mem.Allocator) ![32]u8 {
        return (try self.intent(allocator)).digest(allocator);
    }

    pub fn request(self: Declaration, allocator: std.mem.Allocator) !c.DirectCatalog.Request {
        const decoded = try self.intent(allocator);
        try decoded.validate(self.ddl.binding);
        if (!std.mem.eql(u8, &try decoded.digest(allocator), &self.ddl.binding.intent)) return error.DataIdentityConflict;
        return .{ .binding = self.ddl.binding, .intent = decoded };
    }

    pub fn validate(self: Declaration, allocator: std.mem.Allocator, connection: w.Connection) !void {
        try connection.binding(self.ddl.binding);
        _ = try self.request(allocator);
    }
};

pub const DeclarationRequest = struct {
    declaration: Declaration,
    command: enum { preview, admit, inspect, execute, cancel },
    steps: u16 = 16,

    pub fn mutation(self: DeclarationRequest) bool {
        return self.command == .admit or self.command == .execute or self.command == .cancel;
    }

    pub fn control(self: DeclarationRequest) bool {
        return self.command == .inspect or self.command == .cancel;
    }

    pub fn validate(self: DeclarationRequest, allocator: std.mem.Allocator, connection: w.Connection) !void {
        if (self.steps == 0 or self.steps > 256) return error.InvalidCatalogStepBudget;
        try self.declaration.validate(allocator, connection);
    }
};

pub const DeclarationResult = c.DirectKV.DeclarationResult;
