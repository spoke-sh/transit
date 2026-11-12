//! Source resource kinds survive until the owning SQL binder checks the schema.
const std = @import("std");
const s = @import("Template.zig");
const types = @import("SourceTypes.zig");
const Operands = @import("TypedOperands.zig");

pub fn check(template: s.Syntax, bindings: []const types.Binding) !Operands.Checked {
    for (template.holes) |hole| {
        const value = for (bindings) |binding| {
            if (std.mem.eql(u8, binding.name, hole.name)) break binding.value;
        } else return error.UnknownSourceOperand;
        switch (hole.role) {
            .identifier => if (value != .identifier) return error.SourceTypeMismatch,
            .type => {
                if (value != .type) return error.SourceTypeMismatch;
                if (value.type.domain != null) return error.UnsupportedNominalLog;
            },
            .stream => if (value != .stream and value != .identifier) return error.SourceTypeMismatch,
            .queue => if (value != .queue and value != .identifier) return error.SourceTypeMismatch,
            .table => if (value != .table and value != .identifier) return error.SourceTypeMismatch,
            .value, .operand => if (value != .integer and value != .text and value != .boolean) return error.UnsupportedLogOperand,
        }
    }
    return .{ .table = "", .schema = @splat(0), .columns = &.{}, .operands = &.{} };
}
