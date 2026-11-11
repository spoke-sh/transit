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
                .domain => "DOMAIN",
                .variant => "VARIANT",
            }, def.name });
            if (def.kind == .module or def.kind == .interface) {
                try writer.writeByte('(');
                for (def.parameters, 0..) |param, n| {
                    if (n != 0) try writer.writeAll(", ");
                    try writer.print("{s} ", .{param.name});
                    try self.kind(param.kind);
                }
                try writer.writeByte(')');
            }
            if (def.domain) |domain| {
                try writer.print(" AS {s} IDENTITY ", .{scalarName(domain.base)});
                try self.string(domain.identity);
            } else if (def.kind == .variant) {
                try writer.writeAll(" AS (");
                for (def.constructors, 0..) |constructor, n| {
                    if (n != 0) try writer.writeAll(", ");
                    try writer.print("{s}(", .{constructor.name});
                    for (constructor.fields, 0..) |field, j| {
                        if (j != 0) try writer.writeAll(", ");
                        try writer.print("{s} ", .{field.name});
                        try self.kind(field.kind);
                    }
                    try writer.writeByte(')');
                }
                try writer.writeByte(')');
            } else if (def.kind != .interface) {
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
    if (value.constructor) |constructor| try self.w.print(".{s}", .{constructor});
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
        .named_type => |v| {
            try self.w.writeAll("TYPE ");
            try self.name(v);
        },
        .construct => |v| try self.callDepth(v, depth + 1),
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
    return self.callDepth(value, 0);
}
fn callDepth(self: Self, value: s.Call, depth: usize) anyerror!void {
    if (depth >= 64) return error.SourceDepthLimit;
    try self.name(value.name);
    try self.w.writeByte('(');
    for (value.arguments, 0..) |arg, i| {
        if (i != 0) try self.w.writeAll(", ");
        try self.expr(arg, depth + 1, 0, false);
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
                if (v.result) |result| try self.w.print(" AS {s}", .{result});
            },
            .table_export => |v| {
                try self.w.writeAll("EXPORT TABLE ");
                if (v.operand) try self.w.writeByte('$');
                try self.name(v.source);
                try self.w.print(" AS {s}", .{v.alias});
            },
            .match => |v| {
                try self.w.writeAll("MATCH ");
                try self.expr(v.value, 0, 0, false);
                try self.w.writeByte('\n');
                for (v.arms) |arm| {
                    try self.indent(depth);
                    try self.w.writeAll("WHEN ");
                    try self.name(arm.constructor);
                    try self.w.writeByte('(');
                    for (arm.names, 0..) |binder, i| {
                        if (i != 0) try self.w.writeAll(", ");
                        try self.w.writeAll(binder);
                    }
                    try self.w.writeAll(") THEN\n");
                    try self.body(arm.body, depth + 1);
                }
                try self.indent(depth);
                try self.w.writeAll("END MATCH");
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
        if (token.kind == .word and !s.Template.numericWord(self.text, token)) {
            for (raw) |byte| try self.w.writeByte(std.ascii.toUpper(byte));
        } else try self.w.writeAll(raw);
    }
}

fn scalarName(value: s.ScalarType) []const u8 {
    return switch (value) {
        .bigint => "BIGINT",
        .text => "TEXT",
        .boolean => "BOOLEAN",
    };
}
fn kind(self: Self, value: s.Kind) anyerror!void {
    switch (value) {
        .integer => try self.w.writeAll("BIGINT"),
        .text => try self.w.writeAll("TEXT"),
        .boolean => try self.w.writeAll("BOOLEAN"),
        .identifier => try self.w.writeAll("IDENTIFIER"),
        .type => try self.w.writeAll("TYPE"),
        .named => |v| try self.name(v),
        .module => |v| {
            try self.w.writeAll("MODULE ");
            try self.name(v);
        },
        .table => |columns| {
            try self.w.writeAll("TABLE(");
            for (columns, 0..) |column, i| {
                if (i != 0) try self.w.writeAll(", ");
                try self.w.print("{s} ", .{column.name});
                switch (column.type) {
                    .scalar => |v| try self.w.writeAll(scalarName(v)),
                    .named => |v| try self.name(v),
                }
                if (column.primary) try self.w.writeAll(" PRIMARY KEY") else if (!column.nullable) try self.w.writeAll(" NOT NULL");
                if (!std.mem.eql(u8, column.collation, "none")) try self.w.print(" COLLATE {s}", .{column.collation});
            }
            try self.w.writeByte(')');
        },
    }
}
