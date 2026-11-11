//! Source formatting over the production AST. The caller bounds output storage.
const std = @import("std");
const s = @import("Syntax.zig");
const Self = @This();
text: []const u8,
w: *std.Io.Writer,

pub fn write(text: []const u8, file: s.File, writer: *std.Io.Writer) !void {
    var self: Self = .{ .text = text, .w = writer };
    // Syntax retains separate symbol collections; spans restore source order.
    var d: usize = 0;
    var i: usize = 0;
    var p: usize = 0;
    while (d < file.definitions.len or i < file.imports.len or p < file.dependencies.len) {
        const da = if (d < file.definitions.len) file.definitions[d].span.start else std.math.maxInt(u32);
        const ia = if (i < file.imports.len) file.imports[i].span.start else std.math.maxInt(u32);
        const pa = if (p < file.dependencies.len) file.dependencies[p].span.start else std.math.maxInt(u32);
        if (ia < da and ia < pa) {
            const imp = file.imports[i];
            i += 1;
            try writer.print("IMPORT {s} FROM ", .{imp.alias});
            if (imp.package) |package| try writer.print("PACKAGE {s} FILE ", .{package});
            try self.string(imp.path);
        } else if (pa < da) {
            const dep = file.dependencies[p];
            p += 1;
            try writer.print("DEPENDENCY {s} FROM ", .{dep.name});
            try self.string(dep.repository);
            try writer.writeAll(" REVISION ");
            try self.string(dep.revision);
            if (dep.subdirectory.len != 0) {
                try writer.writeAll(" SUBDIRECTORY ");
                try self.string(dep.subdirectory);
            }
        } else {
            const def = file.definitions[d];
            d += 1;
            try writer.writeAll("CREATE ");
            if (def.public) try writer.writeAll("PUBLIC ");
            try writer.print("{s} {s}", .{ switch (def.kind) {
                .module => "MODULE",
                .interface => "INTERFACE",
                .target => "TARGET",
                .test_target => "TEST TARGET",
            }, def.name });
            if (def.kind == .module or def.kind == .interface) {
                try writer.writeByte('(');
                for (def.parameters, 0..) |param, n| {
                    if (n != 0) try writer.writeAll(", ");
                    try writer.print("{s} ", .{param.name});
                    switch (param.kind) {
                        .integer => try writer.writeAll("BIGINT"),
                        .text => try writer.writeAll("TEXT"),
                        .boolean => try writer.writeAll("BOOLEAN"),
                        .identifier => try writer.writeAll("IDENTIFIER"),
                        .type => try writer.writeAll("TYPE"),
                        .module => |module_name| {
                            try writer.writeAll("MODULE ");
                            try self.name(module_name);
                        },
                    }
                }
                try writer.writeByte(')');
            }
            if (def.kind != .interface) {
                try writer.writeAll(" AS BEGIN\n");
                try self.body(def.body, 1);
                try writer.writeAll("END");
            }
        }
        try writer.writeAll(";\n");
    }
}
fn string(self: Self, value: []const u8) !void {
    try self.w.writeByte('\'');
    for (value) |byte| {
        try self.w.writeByte(byte);
        if (byte == '\'') try self.w.writeByte(byte);
    }
    try self.w.writeByte('\'');
}
fn name(self: Self, value: s.Name) !void {
    if (value.qualifier) |qualifier| try self.w.print("{s}.", .{qualifier});
    try self.w.writeAll(value.member);
}
fn precedence(op: s.Binary) u8 {
    return switch (op) {
        .or_ => 1,
        .and_ => 2,
        .equal, .not_equal, .less, .less_equal, .greater, .greater_equal => 3,
        .add, .subtract => 4,
        .multiply => 5,
    };
}
fn expr(self: Self, value: *s.Expr, depth: usize, parent: u8, right: bool) anyerror!void {
    if (depth == 64) return error.SourceDepthLimit;
    switch (value.value) {
        .integer => |v| try self.w.print("{d}", .{v}),
        .text => |v| try self.string(v),
        .boolean => |v| try self.w.writeAll(if (v) "TRUE" else "FALSE"),
        .identifier => |v| {
            try self.w.writeAll("NAME ");
            try self.string(v);
        },
        .type => |v| try self.w.print("TYPE {s}", .{switch (v) {
            .bigint => "BIGINT",
            .text => "TEXT",
            .boolean => "BOOLEAN",
        }}),
        .reference => |v| try self.name(v),
        .unary => |v| {
            try self.w.writeAll(if (v.negative) "- " else "NOT ");
            // Preserve the distinction between a signed literal and unary negation.
            const parentheses = v.negative and v.operand.value == .integer and v.operand.value.integer >= 0;
            if (parentheses) try self.w.writeByte('(');
            try self.expr(v.operand, depth + 1, 6, false);
            if (parentheses) try self.w.writeByte(')');
        },
        .binary => |v| {
            const level = precedence(v.op);
            const parentheses = level < parent or (level == parent and right);
            if (parentheses) try self.w.writeByte('(');
            try self.expr(v.left, depth + 1, level, false);
            try self.w.print(" {s} ", .{switch (v.op) {
                .add => "+",
                .subtract => "-",
                .multiply => "*",
                .equal => "=",
                .not_equal => "<>",
                .less => "<",
                .less_equal => "<=",
                .greater => ">",
                .greater_equal => ">=",
                .and_ => "AND",
                .or_ => "OR",
            }});
            try self.expr(v.right, depth + 1, level, true);
            if (parentheses) try self.w.writeByte(')');
        },
    }
}
fn call(self: Self, value: s.Call) !void {
    try self.name(value.name);
    try self.w.writeByte('(');
    for (value.arguments, 0..) |arg, i| {
        if (i != 0) try self.w.writeAll(", ");
        try self.expr(arg, 0, 0, false);
    }
    try self.w.writeByte(')');
}
fn indent(self: Self, depth: usize) !void {
    for (0..depth) |_| try self.w.writeAll("  ");
}
fn body(self: Self, statements: []const s.Statement, depth: usize) anyerror!void {
    if (depth > 64) return error.SourceDepthLimit;
    for (statements) |statement| {
        try self.indent(depth);
        switch (statement.value) {
            .sql => |v| try self.template(v),
            .use => |v| {
                try self.w.writeAll("USE ");
                try self.call(v);
            },
            .conditional => |v| {
                try self.w.writeAll("IF ");
                try self.expr(v.condition, 0, 0, false);
                try self.w.writeAll(" THEN\n");
                try self.body(v.yes, depth + 1);
                if (v.no.len != 0) {
                    try self.indent(depth);
                    try self.w.writeAll("ELSE\n");
                    try self.body(v.no, depth + 1);
                }
                try self.indent(depth);
                try self.w.writeAll("END IF");
            },
            .test_case => |v| {
                try self.w.writeAll("TEST ");
                try self.string(v.name);
                try self.w.writeAll(" USING MODULES (");
                for (v.setup, 0..) |setup, i| {
                    if (i != 0) try self.w.writeAll(", ");
                    try self.call(setup);
                }
                try self.w.writeAll(") AS BEGIN\n");
                try self.body(v.body, depth + 1);
                try self.indent(depth);
                try self.w.writeAll("END");
            },
            .assertion => |v| {
                try self.w.print("ASSERT {s} (", .{switch (v.expected) {
                    .rows => "ROWS",
                    .command => "COMMAND",
                    .refusal => "STATEMENT",
                }});
                try self.template(v.sql);
                try self.w.writeAll(") ");
                switch (v.expected) {
                    .rows => |rows| {
                        try self.w.writeAll("EQUAL (");
                        try self.template(rows);
                        try self.w.writeByte(')');
                    },
                    .command => |counts| try self.w.print("MATCHED {d} CHANGED {d}", .{ counts.matched, counts.changed }),
                    .refusal => |reason| {
                        try self.w.writeAll("FAILS WITH ");
                        try self.string(@tagName(reason));
                    },
                }
            },
        }
        try self.w.writeAll(";\n");
    }
}
fn template(self: Self, value: s.Template.Syntax) !void {
    for (value.tokens, 0..) |token, i| {
        // Retain adjacency of SQL lexical components (e.g. decimals and ::).
        // Other original adjacency is harmless and makes formatting idempotent.
        if (i != 0 and value.tokens[i - 1].end != token.start) try self.w.writeByte(' ');
        const raw = self.text[token.start..token.end];
        if (token.kind == .word) {
            for (raw) |byte| try self.w.writeByte(std.ascii.toUpper(byte));
        } else try self.w.writeAll(raw);
    }
}
