//! Direct Document collection declaration and metadata over the Direct Data Plane.
const std = @import("std");
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const f = c.fuze;

pub const Policy = f.DocumentDdl.Policy;

pub const Definition = struct {
    definition: w.Definition,
    policy: Policy,
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
