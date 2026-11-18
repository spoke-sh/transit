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
    var df: usize = 0;
    var st: usize = 0;
    while (d < file.definitions.len or i < file.imports.len or p < file.dependencies.len or df < file.defaults.len or st < file.statements.len) {
        const da = if (d < file.definitions.len) file.definitions[d].span.start else std.math.maxInt(u32);
        const ia = if (i < file.imports.len) file.imports[i].span.start else std.math.maxInt(u32);
        const pa = if (p < file.dependencies.len) file.dependencies[p].span.start else std.math.maxInt(u32);
        const dfa = if (df < file.defaults.len) file.defaults[df].span.start else std.math.maxInt(u32);
        const sta = if (st < file.statements.len) file.statements[st].span.start else std.math.maxInt(u32);
        const min_at = @min(da, @min(ia, @min(pa, @min(dfa, sta))));
        if (ia == min_at) {
            const imp = file.imports[i];
            i += 1;
            try writer.print("IMPORT {s} FROM ", .{imp.alias});
            if (imp.package) |package| try writer.print("PACKAGE {s} FILE ", .{package});
            try self.string(imp.path);
            try writer.writeAll(";\n");
        } else if (pa == min_at) {
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
            try writer.writeAll(";\n");
        } else if (dfa == min_at) {
            const def_target = file.defaults[df];
            df += 1;
            try writer.print("EXPORT DEFAULT TARGET {s};\n", .{def_target.name});
        } else if (sta == min_at) {
            const stmt = file.statements[st];
            st += 1;
            try self.statement(stmt, 0);
        } else {
            const def = file.definitions[d];
            d += 1;
            try self.definition(def);
            try writer.writeAll(";\n");
        }
    }
}
fn migrationClause(self: Self, migration: s.Migration) !void {
    try self.w.writeAll(" FROM ");
    if (migration.basis) |path| try self.string(path) else try self.w.writeAll("EMPTY");
    try self.w.writeAll(" FOR DATABASE ");
    try self.string(migration.database);
    try self.w.writeAll(" SCHEMA ");
    try self.string(migration.schema);
    try self.w.writeAll(" VERSION ");
    try self.string(migration.version);
    try self.w.writeAll(" NAME ");
    try self.string(migration.name);
}
fn definition(self: Self, def: s.Definition) !void {
    const writer = self.w;
    if (def.kind == .target_alias) {
        try writer.print("EXPORT TARGET {s} = ", .{def.name});
        try self.name(def.target_ref.?);
        return;
    }
    if (def.kind == .test_suite) {
        try writer.print("EXPORT TEST SUITE {s} FROM ", .{def.name});
        try self.string(def.suite_path.?);
        return;
    }
    if (def.target_of) |instance_name| {
        switch (def.kind) {
            .target => {
                try writer.print("EXPORT TARGET {s} AS SQL OF {s}", .{ def.name, instance_name });
                if (def.output_path) |path| {
                    try writer.writeAll(" INTO ");
                    try self.string(path);
                }
            },
            .migration_target => {
                try writer.print("EXPORT TARGET {s} AS MIGRATIONS OF {s}", .{ def.name, instance_name });
                try self.migrationClause(def.migration.?);
                if (def.output_path) |path| {
                    try writer.writeAll(" INTO ");
                    try self.string(path);
                }
            },
            .test_target => {
                try writer.print("EXPORT TARGET {s} AS TESTS OF {s} USING SUITES (", .{ def.name, instance_name });
                for (def.suites, 0..) |suite, idx| {
                    if (idx != 0) try writer.writeAll(", ");
                    switch (suite) {
                        .path => |path| try self.string(path),
                        .symbol => |sym| try self.name(sym),
                    }
                }
                try writer.writeByte(')');
                if (def.target_options.len != 0) {
                    try writer.writeAll(" WITH (");
                    for (def.target_options, 0..) |opt, idx| {
                        if (idx != 0) try writer.writeAll(", ");
                        try writer.print("{s} = ", .{opt.name});
                        try self.expr(opt.value, 0, 0, false);
                    }
                    try writer.writeByte(')');
                }
            },
            else => unreachable,
        }
        return;
    }
    try writer.writeAll("CREATE ");
    if (def.public) try writer.writeAll("PUBLIC ");
    try writer.print("{s} ", .{switch (def.kind) {
        .module => "MODULE",
        .interface => "INTERFACE",
        .target => "TARGET",
        .migration_target => "MIGRATION TARGET",
        .test_target => "TEST TARGET",
        .domain => "DOMAIN",
        .variant => "VARIANT",
        .function => "FUNCTION",
        .guard => "GUARD",
        .procedure => "PROCEDURE",
        .target_alias, .test_suite => unreachable,
    }});
    if (def.schema) |s_name| try writer.print("{s}.{s}", .{ s_name, def.name }) else try writer.writeAll(def.name);
    if (def.kind == .module or def.kind == .interface or def.kind == .function or def.kind == .guard or def.kind == .procedure) {
        try writer.writeByte('(');
        for (def.parameters, 0..) |param, n| {
            if (n != 0) try writer.writeAll(", ");
            try writer.print("{s} ", .{param.name});
            try self.kind(param.kind);
        }
        try writer.writeByte(')');
    }
    if (def.migration) |migration| try self.migrationClause(migration);
    if (def.return_type) |ret| {
        try writer.writeAll(" RETURNS ");
        switch (ret) {
            .scalar => |v| try writer.writeAll(scalarName(v)),
            .named => |v| try self.name(v),
        }
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
    } else if (def.program) |prog| {
        if (prog.kind == .guard_requires) {
            try writer.writeAll(" AS ");
            try self.template(prog);
        } else {
            try writer.writeAll(if (def.kind == .procedure) " AS BEGIN ATOMIC\n" else " AS BEGIN\n");
            if (prog.tokens.len != 0) {
                try self.indent(1);
                try self.template(prog);
                try writer.writeByte('\n');
            }
            try writer.writeAll("END");
        }
    } else if (def.kind != .interface) {
        try writer.writeAll(" AS BEGIN\n");
        try self.body(def.body, 1);
        try writer.writeAll("END");
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
        .uuid => |v| {
            try self.w.writeAll("UUID ");
            try self.string(v);
        },
        .timestamptz => |v| {
            try self.w.writeAll("TIMESTAMP ");
            try self.string(v);
        },
        .bytes => |v| {
            try self.w.writeAll("X ");
            try self.string(v);
        },
        .identifier => |v| {
            try self.w.writeAll("NAME ");
            try self.string(v);
        },
        .schema_binding => |v| {
            try self.w.writeAll("SCHEMA_BINDING(");
            try self.string(v);
            try self.w.writeByte(')');
        },
        .type => |v| try self.w.print("TYPE {s}", .{scalarName(v)}),
        .reference => |v| try self.name(v),
        .named_type => |v| {
            try self.w.writeAll("TYPE ");
            try self.name(v);
        },
        .construct => |v| try self.callDepth(v, depth + 1),
        .row => |fields| {
            try self.w.writeAll("ROW(");
            for (fields, 0..) |field, idx| {
                if (idx != 0) try self.w.writeAll(", ");
                try self.w.print("{s} => ", .{field.name});
                try self.expr(field.value, depth + 1, 0, false);
            }
            try self.w.writeByte(')');
        },
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
    if (value.names.len != 0) {
        for (value.names, value.arguments, 0..) |arg_name, arg, i| {
            if (i != 0) try self.w.writeAll(", ");
            try self.w.print("{s} => ", .{arg_name});
            try self.expr(arg, depth + 1, 0, false);
        }
    } else {
        for (value.arguments, 0..) |arg, i| {
            if (i != 0) try self.w.writeAll(", ");
            try self.expr(arg, depth + 1, 0, false);
        }
    }
    try self.w.writeByte(')');
}
fn indent(self: Self, depth: usize) !void {
    for (0..depth) |_| try self.w.writeAll("  ");
}
fn body(self: Self, statements: []const s.Statement, depth: usize) anyerror!void {
    if (depth > 64) return error.SourceDepthLimit;
    for (statements) |stmt| try self.statement(stmt, depth);
}
fn statement(self: Self, item: s.Statement, depth: usize) anyerror!void {
    if (depth > 64) return error.SourceDepthLimit;
    try self.indent(depth);
    switch (item.value) {
        .sql => |v| try self.template(v),
        .use => |v| {
            if (v.let_binding) {
                try self.w.print("LET {s} = USE MODULE ", .{v.result.?});
                try self.call(v);
            } else {
                try self.w.writeAll("USE ");
                try self.call(v);
                if (v.result) |result| try self.w.print(" AS {s}", .{result});
            }
        },
        .use_module => |v| {
            try self.w.writeAll("USE MODULE ");
            try self.name(v);
        },
        .declare_from => |v| {
            try self.w.writeAll("DECLARE FROM ");
            try self.string(v);
        },
        .bind_schema => |v| {
            try self.w.print("BIND SCHEMA {s} TO ", .{v.name});
            try self.expr(v.target, 0, 0, false);
        },
        .table_export => |v| {
            try self.w.writeAll("EXPORT TABLE ");
            if (v.operand) try self.w.writeByte('$');
            try self.name(v.source);
            try self.w.print(" AS {s}", .{v.alias});
        },
        .log_export => |v| {
            try self.w.writeAll(if (v.kind == .stream) "EXPORT STREAM " else "EXPORT QUEUE ");
            if (v.operand) try self.w.writeByte('$');
            try self.name(v.source);
            try self.w.print(" AS {s}", .{v.alias});
        },
        .symbol_export => |v| {
            try self.w.print("EXPORT {s} ", .{switch (v.kind) {
                .function => "FUNCTION",
                .guard => "GUARD",
                .procedure => "PROCEDURE",
                .view => "VIEW",
                .dataflow => "DATAFLOW",
                .profile => "PROFILE",
            }});
            try self.name(v.source);
            try self.w.print(" AS {s}", .{v.alias});
        },
        .reference_export => |v| {
            try self.w.writeAll("EXPORT REFERENCE TABLE ");
            try self.name(v.source);
            try self.w.writeByte('(');
            for (v.columns, 0..) |col, i| {
                if (i != 0) try self.w.writeAll(", ");
                try self.w.writeAll(col);
            }
            try self.w.print(") AS {s}", .{v.alias});
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
                switch (setup) {
                    .call => |c| try self.call(c),
                    .reference => |n| try self.name(n),
                }
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
        .workflow => |v| {
            try self.w.writeAll("ASSERT WORKFLOW ");
            try self.expr(v.name, 0, 0, false);
            try self.w.print(" COMPLETED {d} REFUSED {d} WITHIN {d} OBSERVATIONS", .{ v.completed, v.refused, v.observations });
        },
    }
    try self.w.writeAll(";\n");
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
        .uuid => "UUID",
        .timestamptz => "TIMESTAMPTZ",
        .binary => "BINARY",
    };
}
fn kind(self: Self, value: s.Kind) anyerror!void {
    switch (value) {
        .integer => try self.w.writeAll("BIGINT"),
        .text => try self.w.writeAll("TEXT"),
        .boolean => try self.w.writeAll("BOOLEAN"),
        .uuid => try self.w.writeAll("UUID"),
        .timestamptz => try self.w.writeAll("TIMESTAMPTZ"),
        .binary => try self.w.writeAll("BINARY"),
        .identifier => try self.w.writeAll("IDENTIFIER"),
        .type => try self.w.writeAll("TYPE"),
        .schema_binding => try self.w.writeAll("SCHEMA_BINDING"),
        .named => |v| try self.name(v),
        .module => |v| {
            try self.w.writeAll("MODULE ");
            try self.name(v);
        },
        .module_of => |v| {
            try self.w.writeAll("MODULE OF ");
            try self.name(v);
        },
        .row => |fields| {
            try self.w.writeAll("ROW(");
            for (fields, 0..) |field, i| {
                if (i != 0) try self.w.writeAll(", ");
                try self.w.print("{s} ", .{field.name});
                try self.kind(field.kind);
            }
            try self.w.writeByte(')');
        },
        inline .table, .stream, .queue => |columns, tag| {
            try self.w.writeAll(switch (tag) {
                .table => "TABLE(",
                .stream => "STREAM(",
                .queue => "QUEUE(",
                else => unreachable,
            });
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
