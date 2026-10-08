//! Bounded native controls around typed command bodies. All controls carry the
//! single current definition; record decoding never supplies caller authority.
const std = @import("std");
const c = @import("root.zig");
const m = c.TableCatalogRecords;
const p = c.protocol;
const s = c.station;
pub const Policy = struct {
    expected_revision: u64,
    policy: m.Policy,
    pub fn validate(self: Policy) !void {
        try self.policy.validate();
        if (self.policy.revision != (std.math.add(u64, self.expected_revision, 1) catch return error.InvalidCatalogPolicy)) return error.InvalidCatalogPolicy;
    }
};
pub const Dependency = struct {
    dependency: m.Dependency,
    present: bool,
    pub fn validate(self: Dependency) !void {
        try self.dependency.validate();
    }
};
pub const Ddl = struct {
    scope: m.Scope,
    principal: u64,
    operation: u64,
    digest: [32]u8,
    pub fn validate(self: Ddl) !void {
        try self.scope.validate();
        if (self.principal > p.max_counter or self.operation == 0) return error.InvalidCatalogIdentity;
    }
};
pub const Dml = struct {
    scope: m.Scope,
    reference: s.TableWrite.Reference,
    pub fn validate(self: Dml) !void {
        try self.scope.validate();
        try self.reference.validate();
        if (self.reference.resource != self.scope.resource) return error.CatalogScopeChanged;
    }
};
pub const Upload = struct {
    scope: m.Scope,
    namespace: u64,
    pub fn validate(self: Upload) !void {
        try self.scope.validate();
        if (self.namespace == 0) return error.InvalidTableUpload;
    }
};
pub const Begin = struct {
    header: [c.TableCommand.header_bytes]u8,
    namespace: u64,
    spec: s.Publication.Spec,
    pub fn validate(self: Begin) !void {
        try (c.TableUpload.Status{ .header = try c.TableCommand.inspect(&self.header), .namespace = self.namespace, .spec = self.spec, .admitted_input = 1 }).validate();
    }
};
pub const Part = struct {
    upload: Upload,
    offset: u32,
    length: u8,
    bytes: [c.TableUpload.part_bytes]u8,
    pub fn init(upload: Upload, offset: u32, bytes: []const u8) !Part {
        if (bytes.len == 0 or bytes.len > c.TableUpload.part_bytes) return error.InvalidTableUploadPart;
        var result: Part = .{ .upload = upload, .offset = offset, .length = @intCast(bytes.len), .bytes = @splat(0) };
        @memcpy(result.bytes[0..bytes.len], bytes);
        try result.validate();
        return result;
    }
    pub fn validate(self: Part) !void {
        try self.upload.validate();
        if (self.length == 0 or self.length > self.bytes.len or self.offset % c.TableUpload.part_bytes != 0) return error.InvalidTableUploadPart;
        for (self.bytes[self.length..]) |byte| if (byte != 0) return error.InvalidTableUploadPart;
    }
};
pub const Command = union(enum(u8)) {
    initialize: m.Configuration = 'I',
    policy: Policy = 'P',
    dependency: Dependency = 'D',
    cancel_ddl: Ddl = 'X',
    cleanup_ddl: Ddl = 'Y',
    cancel_dml: Dml = 'M',
    cleanup_dml: Dml = 'N',
    begin: Begin = 'B',
    part: Part = 'A',
    seal: Upload = 'S',
    drive: Upload = 'V',
    cancel_upload: Upload = 'K',
    collect_upload: Upload = 'G',
    pub fn scope(self: Command) !m.Scope {
        return switch (self) {
            .initialize => |value| value.scope,
            .policy => |value| value.policy.scope,
            .dependency => |value| value.dependency.scope,
            .cancel_ddl, .cleanup_ddl => |value| value.scope,
            .cancel_dml, .cleanup_dml => |value| value.scope,
            .begin => |value| (try c.TableCommand.inspect(&value.header)).scope,
            .part => |value| value.upload.scope,
            .seal, .drive, .cancel_upload, .collect_upload => |value| value.scope,
        };
    }
    pub fn encode(self: Command) !p.Value {
        const result = switch (self) {
            inline else => |value, tag| try c.Records.encode(@backingInt(tag), value),
        };
        if (result.len > s.Frame.max_payload) return error.MessageTooLarge;
        return result;
    }
    pub fn decode(value: p.Value) !Command {
        try value.validate();
        if (value.len < 37 or value.len > s.Frame.max_payload) return error.InvalidCatalogCommand;
        const tag = std.enums.fromInt(std.meta.Tag(Command), value.data[4]) orelse return error.InvalidCatalogCommand;
        return switch (tag) {
            inline else => |which| @unionInit(Command, @tagName(which), try c.Records.decode(@FieldType(Command, @tagName(which)), @backingInt(which), value)),
        };
    }
};
/// A transport/control disposition is not an SQL operation receipt.
pub const Disposition = struct {
    scope: m.Scope,
    origin: enum(u8) { external = 1, process = 2, effect = 3 },
    principal: u64,
    input: u64,
    payload: [32]u8,
    outcome: enum(u8) { initialized = 1, policy_applied = 2, dependency_applied = 3, invalid_command = 4, denied = 5, identity_conflict = 6, stale_policy = 7, blocked = 8 },
    pub fn validate(self: Disposition) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.input);
        if (self.principal > p.max_counter or (self.origin != .external and self.principal != 0)) return error.InvalidCatalogDisposition;
    }
};
