//! Source syntax only. File and repository I/O stay with the caller.
const std = @import("std");
const f = @import("transit_fuze");
const SourceDiagnostic = @import("SourceDiagnostic.zig");
pub const Template = @import("Template.zig");
pub const Token = f.SqlInput.CompilerScan.Token;
pub const Span = struct { start: u32, end: u32 };
pub const Name = struct { qualifier: ?[]const u8 = null, member: []const u8, constructor: ?[]const u8 = null };
pub const Kind = union(enum) {
    integer,
    text,
    boolean,
    uuid,
    timestamptz,
    binary,
    identifier,
    type,
    schema_binding,
    module: Name,
    module_of: Name,
    row: []const Parameter,
    named: Name,
    table: []const Column,
    stream: []const Column,
    queue: []const Column,
};
pub const Parameter = struct { name: []const u8, kind: Kind };
pub const ScalarType = enum { bigint, text, boolean, uuid, timestamptz, binary };
pub const TypeRef = union(enum) { scalar: ScalarType, named: Name };
pub const Column = struct { name: []const u8, type: TypeRef, nullable: bool = true, primary: bool = false, collation: []const u8 = "none" };
pub const Constructor = struct { name: []const u8, fields: []const Parameter };
pub const Domain = struct { base: ScalarType, identity: []const u8 };
pub const Binary = enum { add, subtract, multiply, equal, not_equal, less, less_equal, greater, greater_equal, and_, or_ };
pub const RowField = struct { name: []const u8, value: *Expr };
pub const Expr = struct {
    span: Span,
    value: union(enum) {
        integer: i64,
        text: []const u8,
        boolean: bool,
        uuid: []const u8,
        timestamptz: []const u8,
        bytes: []const u8,
        identifier: []const u8,
        schema_binding: []const u8,
        type: ScalarType,
        named_type: Name,
        reference: Name,
        construct: Call,
        row: []const RowField,
        binary: struct { op: Binary, left: *Expr, right: *Expr },
        unary: struct { negative: bool, operand: *Expr },
    },
};
pub const Call = struct { name: Name, arguments: []const *Expr, names: []const []const u8 = &.{}, result: ?[]const u8 = null, let_binding: bool = false };
pub const Arm = struct { constructor: Name, names: []const []const u8, body: []const Statement, span: Span };
pub const CaseModule = union(enum) { call: Call, reference: Name };
pub const Case = struct { name: []const u8, setup: []const CaseModule, body: []const Statement };
pub const Assertion = struct {
    sql: Template.Syntax,
    expected: union(enum) {
        rows: Template.Syntax,
        command: struct { matched: u64, changed: u64 },
        refusal: enum { duplicate_key, check_violation },
    },
};
pub const Workflow = struct { name: *Expr, completed: u64, refused: u64, observations: u64 };
pub const ExportKind = enum { function, guard, procedure, view, dataflow, profile };
pub const Statement = struct {
    span: Span,
    value: union(enum) {
        use: Call,
        use_module: Name,
        declare_from: []const u8,
        bind_schema: struct { name: []const u8, target: *Expr },
        table_export: struct { source: Name, operand: bool, alias: []const u8 },
        log_export: struct { kind: enum { stream, queue }, source: Name, operand: bool, alias: []const u8 },
        symbol_export: struct { kind: ExportKind, source: Name, alias: []const u8 },
        reference_export: struct { source: Name, columns: []const []const u8, alias: []const u8 },
        match: struct { value: *Expr, arms: []const Arm },
        conditional: struct { condition: *Expr, yes: []const Statement, no: []const Statement },
        sql: Template.Syntax,
        test_case: Case,
        assertion: Assertion,
        workflow: Workflow,
    },
};
pub const Migration = struct { basis: ?[]const u8, database: []const u8, schema: []const u8, version: []const u8, name: []const u8 };
pub const SuiteRef = union(enum) { symbol: Name, path: []const u8 };
pub const TargetOption = struct { name: []const u8, value: *Expr };
pub const Definition = struct {
    name: []const u8,
    public: bool,
    kind: enum { module, interface, target, migration_target, test_target, target_alias, test_suite, domain, variant, function, guard, procedure },
    parameters: []const Parameter,
    body: []const Statement,
    span: Span,
    domain: ?Domain = null,
    constructors: []const Constructor = &.{},
    return_type: ?TypeRef = null,
    program: ?Template.Syntax = null,
    migration: ?Migration = null,
    target_of: ?[]const u8 = null,
    target_ref: ?Name = null,
    output_path: ?[]const u8 = null,
    suite_path: ?[]const u8 = null,
    suites: []const SuiteRef = &.{},
    target_options: []const TargetOption = &.{},
    schema: ?[]const u8 = null,
};
pub const Import = struct { alias: []const u8, package: ?[]const u8, path: []const u8, span: Span };
pub const Dependency = struct { name: []const u8, repository: []const u8, revision: []const u8, subdirectory: []const u8, span: Span };
pub const DefaultTarget = struct { name: []const u8, span: Span };
pub const File = struct {
    definitions: []const Definition,
    imports: []const Import,
    dependencies: []const Dependency,
    defaults: []const DefaultTarget = &.{},
    statements: []const Statement = &.{},
};
const Self = @This();
a: std.mem.Allocator,
text: []const u8,
tokens: []const Token,
index: usize = 0,
location: *usize,
report: ?*SourceDiagnostic.Report = null,
file_index: ?usize = null,
depth: usize = 0,

pub fn parse(a: std.mem.Allocator, text: []const u8, location: *usize) !File {
    return parseReported(a, text, location, null, null);
}
pub fn parseReported(a: std.mem.Allocator, text: []const u8, location: *usize, file_index: ?usize, report: ?*SourceDiagnostic.Report) !File {
    // Shared framing is a prerequisite, not semantic acceptance.
    var framed = f.SqlScript.Compiler.init(text) catch |err| {
        if (report) |r| r.setSpan(file_index, 0, 0);
        return err;
    };
    while (framed.next() catch |err| {
        location.* = framed.scan.position;
        if (report) |r| r.setSpan(file_index, framed.scan.position, @min(text.len, framed.scan.position + 1));
        return err;
    }) |_| {}
    var scan = try f.SqlInput.CompilerScan.init(text);
    var tokens: std.ArrayList(Token) = .empty;
    while (try scan.next()) |token| {
        if (token.kind == .space or token.kind == .comment) continue;
        try tokens.append(a, token);
    }
    var self: Self = .{ .a = a, .text = text, .tokens = try tokens.toOwnedSlice(a), .location = location, .report = report, .file_index = file_index };
    var definitions: std.ArrayList(Definition) = .empty;
    var imports: std.ArrayList(Import) = .empty;
    var dependencies: std.ArrayList(Dependency) = .empty;
    var defaults: std.ArrayList(DefaultTarget) = .empty;
    var statements: std.ArrayList(Statement) = .empty;
    while (self.index < self.tokens.len) {
        if (self.take(";")) continue;
        const start = self.at();
        const saved = self.index;
        if (self.take("IMPORT")) {
            const alias = if (self.take("MODULE")) blk: {
                if (self.is("FROM") and !(self.index + 1 < self.tokens.len and std.ascii.eqlIgnoreCase(self.text[self.tokens[self.index + 1].start..self.tokens[self.index + 1].end], "FROM"))) {
                    break :blk try self.a.dupe(u8, "module");
                }
                break :blk try self.identifier();
            } else try self.identifier();
            try self.require("FROM");
            const package = if (self.take("PACKAGE")) try self.identifier() else null;
            if (package != null) try self.require("FILE");
            const path = try self.string();
            try self.require(";");
            try imports.append(a, .{ .alias = alias, .package = package, .path = path, .span = self.span(start) });
        } else if (self.take("DEPENDENCY")) {
            const name = try self.identifier();
            try self.require("FROM");
            const repository = try self.string();
            try self.require("REVISION");
            const revision = try self.string();
            const subdirectory = if (self.take("SUBDIRECTORY")) try self.string() else "";
            try self.require(";");
            try dependencies.append(a, .{ .name = name, .repository = repository, .revision = revision, .subdirectory = subdirectory, .span = self.span(start) });
        } else if (self.take("EXPORT")) {
            if (self.take("DEFAULT")) {
                try self.require("TARGET");
                const target_name = try self.identifier();
                try self.require(";");
                try defaults.append(a, .{ .name = target_name, .span = self.span(start) });
            } else if (self.take("MODULE")) {
                const name = try self.identifier();
                const parameters = try self.parseParameters(false);
                try self.require("AS");
                const begin_span = self.currentSpan();
                try self.require("BEGIN");
                const body = self.parseBody(.end) catch |err| {
                    if (err == error.InvalidSourceSyntax and self.index == self.tokens.len) {
                        if (self.report) |r| r.addNote(self.file_index, begin_span, "'BEGIN' block opened here", .{});
                    }
                    return err;
                };
                try self.require("END");
                try self.require(";");
                try definitions.append(a, .{ .name = name, .public = true, .kind = .module, .parameters = parameters, .body = body, .span = self.span(start) });
            } else if (self.take("TEST")) {
                try self.require("SUITE");
                const name = try self.identifier();
                try self.require("FROM");
                const path = try self.string();
                try self.require(";");
                try definitions.append(a, .{ .name = name, .public = true, .kind = .test_suite, .parameters = &.{}, .body = &.{}, .span = self.span(start), .suite_path = path });
            } else if (self.take("TARGET")) {
                try definitions.append(a, try self.parseExportTarget(start));
            } else {
                self.index = saved;
                try statements.append(a, try self.parseStatement());
            }
        } else if (self.is("CREATE")) {
            if (self.isCreateTemplate()) {
                try statements.append(a, try self.parseStatement());
            } else {
                try definitions.append(a, try self.parseCreateDefinition(start));
            }
        } else {
            try statements.append(a, try self.parseStatement());
        }
    }
    return .{
        .definitions = try definitions.toOwnedSlice(a),
        .imports = try imports.toOwnedSlice(a),
        .dependencies = try dependencies.toOwnedSlice(a),
        .defaults = try defaults.toOwnedSlice(a),
        .statements = try statements.toOwnedSlice(a),
    };
}
fn isCreateTemplate(self: *const Self) bool {
    if (self.index + 1 >= self.tokens.len) return false;
    const second = self.tokens[self.index + 1];
    if (second.kind != .word) return false;
    if (std.ascii.eqlIgnoreCase(self.text[second.start..second.end], "SCHEMA")) return true;
    if (self.index + 2 >= self.tokens.len) return false;
    const third = self.tokens[self.index + 2];
    if (third.kind != .word) return false;
    if (!std.ascii.eqlIgnoreCase(self.text[second.start..second.end], "PUBLIC")) return false;
    const kw = self.text[third.start..third.end];
    return std.ascii.eqlIgnoreCase(kw, "TABLE") or std.ascii.eqlIgnoreCase(kw, "STREAM") or
        std.ascii.eqlIgnoreCase(kw, "QUEUE") or std.ascii.eqlIgnoreCase(kw, "DATAFLOW");
}
fn parseMigrationClause(self: *Self, allow_shorthand: bool) !Migration {
    try self.require("FROM");
    const basis = if (self.take("EMPTY")) null else try self.string();
    var database: []const u8 = undefined;
    var schema: []const u8 = undefined;
    if (self.take("FOR")) {
        try self.require("DATABASE");
        database = try self.string();
        if (self.take("SCHEMA")) {
            schema = try self.string();
        } else if (allow_shorthand) {
            schema = try self.a.dupe(u8, "public");
        } else {
            try self.require("SCHEMA");
            unreachable;
        }
    } else if (allow_shorthand) {
        database = try self.a.dupe(u8, "transit");
        schema = try self.a.dupe(u8, "public");
    } else {
        self.failExpected("'FOR DATABASE <db> SCHEMA <schema>' in migration target");
        if (self.report) |r| r.addNote(null, null, "migration targets require explicit 'FOR DATABASE <db> SCHEMA <schema> VERSION <ver> NAME <name>' bindings", .{});
        return error.InvalidSourceSyntax;
    }
    try self.require("VERSION");
    const version_span = self.currentSpan();
    const raw_version = try self.string();
    if (self.take("NAME")) {
        return .{ .basis = basis, .database = database, .schema = schema, .version = raw_version, .name = try self.string() };
    }
    if (!allow_shorthand) {
        try self.require("NAME");
        unreachable;
    }
    const dash = std.mem.indexOfScalar(u8, raw_version, '-') orelse 0;
    if (dash == 0 or dash + 1 >= raw_version.len) {
        self.location.* = version_span.start;
        if (self.report) |r| {
            r.setSpan(self.file_index, version_span.start, version_span.end);
            r.setHeadline("expected 'VERSION <ver> NAME <name>' or combined 'VERSION ''<ver>-<name>'''", .{});
        }
        return error.InvalidMigrationVersion;
    }
    return .{
        .basis = basis,
        .database = database,
        .schema = schema,
        .version = try self.a.dupe(u8, raw_version[0..dash]),
        .name = try self.a.dupe(u8, raw_version[dash + 1 ..]),
    };
}
fn parseExportTarget(self: *Self, start: u32) !Definition {
    const name = try self.identifier();
    if (self.take("=")) {
        const qualifier = try self.identifier();
        try self.require(".");
        const member = try self.identifier();
        try self.require(";");
        return .{ .name = name, .public = true, .kind = .target_alias, .parameters = &.{}, .body = &.{}, .span = self.span(start), .target_ref = .{ .qualifier = qualifier, .member = member } };
    }
    try self.require("AS");
    if (self.take("SQL")) {
        try self.require("OF");
        const instance_name = try self.identifier();
        const output_path = if (self.take("INTO")) try self.string() else null;
        try self.require(";");
        return .{ .name = name, .public = true, .kind = .target, .parameters = &.{}, .body = &.{}, .span = self.span(start), .target_of = instance_name, .output_path = output_path };
    }
    if (self.take("MIGRATIONS")) {
        try self.require("OF");
        const instance_name = try self.identifier();
        const migration = try self.parseMigrationClause(true);
        const output_path = if (self.take("INTO")) try self.string() else null;
        try self.require(";");
        return .{ .name = name, .public = true, .kind = .migration_target, .parameters = &.{}, .body = &.{}, .span = self.span(start), .migration = migration, .target_of = instance_name, .output_path = output_path };
    }
    if (self.take("TESTS")) {
        try self.require("OF");
        const instance_name = try self.identifier();
        try self.require("USING");
        try self.require("SUITES");
        try self.require("(");
        var suites: std.ArrayList(SuiteRef) = .empty;
        if (self.take(")")) {
            self.failExpected("at least one test suite in 'USING SUITES (...)'");
            return error.InvalidSourceSyntax;
        }
        while (true) {
            if (suites.items.len == 64) return error.SourceParameterLimit;
            if (self.index < self.tokens.len and self.tokens[self.index].kind == .string) {
                try suites.append(self.a, .{ .path = try self.string() });
            } else {
                try suites.append(self.a, .{ .symbol = try self.parseTwoPartName() });
            }
            if (self.take(")")) break;
            try self.require(",");
        }
        var options: std.ArrayList(TargetOption) = .empty;
        if (self.take("WITH")) {
            try self.require("(");
            if (self.take(")")) {
                self.failExpected("option in 'WITH (...)'");
                return error.InvalidSourceSyntax;
            }
            while (true) {
                if (options.items.len == 64) return error.SourceParameterLimit;
                const opt_span = self.currentSpan();
                const opt_name = try self.identifier();
                for (options.items) |prior| if (std.mem.eql(u8, prior.name, opt_name)) {
                    if (self.report) |r| {
                        r.setSpan(self.file_index, opt_span.start, opt_span.end);
                        r.setHeadline("duplicate target option '{s}'", .{opt_name});
                    }
                    return error.DuplicateSourceName;
                };
                try self.require("=");
                try options.append(self.a, .{ .name = opt_name, .value = try self.expression(0) });
                if (self.take(")")) break;
                try self.require(",");
            }
        }
        try self.require(";");
        return .{
            .name = name,
            .public = true,
            .kind = .test_target,
            .parameters = &.{},
            .body = &.{},
            .span = self.span(start),
            .target_of = instance_name,
            .suites = try suites.toOwnedSlice(self.a),
            .target_options = try options.toOwnedSlice(self.a),
        };
    }
    self.failExpected("'SQL', 'MIGRATIONS' or 'TESTS' after 'EXPORT TARGET <name> AS'");
    return error.InvalidSourceSyntax;
}
fn parseCreateDefinition(self: *Self, start: u32) !Definition {
    _ = self.take("CREATE");
    const public = self.take("PUBLIC");
    const kind: @FieldType(Definition, "kind") = if (self.take("DOMAIN")) .domain else if (self.take("VARIANT")) .variant else if (self.take("MODULE")) .module else if (self.take("INTERFACE")) .interface else if (self.take("FUNCTION")) .function else if (self.take("GUARD")) .guard else if (self.take("PROCEDURE")) .procedure else if (self.take("MIGRATION")) blk: {
        try self.require("TARGET");
        break :blk .migration_target;
    } else if (self.take("TARGET")) .target else if (self.take("TEST")) blk: {
        try self.require("TARGET");
        break :blk .test_target;
    } else {
        const private_resource = !public and (self.is("TABLE") or self.is("STREAM") or self.is("QUEUE") or self.is("DATAFLOW"));
        self.failExpected("declaration ('MODULE', 'TARGET', 'TEST TARGET', 'MIGRATION TARGET', 'DOMAIN', 'VARIANT', 'INTERFACE', 'FUNCTION', 'GUARD' or 'PROCEDURE')");
        if (private_resource) {
            if (self.report) |r| r.addNote(null, null, "resource declarations require 'CREATE PUBLIC ...' until runtime-private module enforcement lands", .{});
            return error.RuntimePrivateOrUnsupportedDeclaration;
        }
        return error.UnsupportedSourceDeclaration;
    };
    var def_schema: ?[]const u8 = null;
    const name = if (kind == .function or kind == .guard or kind == .procedure) blk: {
        const qn = try self.parseTwoPartName();
        def_schema = qn.qualifier;
        break :blk qn.member;
    } else try self.identifier();
    const parameters = if (kind == .module or kind == .interface or kind == .function or kind == .guard or kind == .procedure) try self.parseParameters(false) else &.{};
    const return_type: ?TypeRef = if (kind == .function or (kind == .procedure and self.is("RETURNS"))) blk: {
        try self.require("RETURNS");
        break :blk try self.typeRef();
    } else null;
    const migration: ?Migration = if (kind == .migration_target) try self.parseMigrationClause(false) else null;
    var domain: ?Domain = null;
    var constructors: std.ArrayList(Constructor) = .empty;
    var program: ?Template.Syntax = null;
    if (kind == .domain) {
        try self.require("AS");
        const base = try self.scalarType();
        try self.require("IDENTITY");
        const id_span = self.currentSpan();
        domain = .{ .base = base, .identity = try self.string() };
        if (domain.?.identity.len == 0 or domain.?.identity.len > 128) {
            if (self.report) |r| r.setSpan(self.file_index, id_span.start, id_span.end);
            return error.InvalidDomainIdentity;
        }
    } else if (kind == .variant) {
        try self.require("AS");
        try self.require("(");
        while (true) {
            if (constructors.items.len == 64) return error.SourceConstructorLimit;
            const ctor_span = self.currentSpan();
            const constructor = try self.identifier();
            for (constructors.items) |prior| if (std.mem.eql(u8, prior.name, constructor)) {
                if (self.report) |r| {
                    r.setSpan(self.file_index, ctor_span.start, ctor_span.end);
                    r.setHeadline("duplicate variant constructor '{s}'", .{constructor});
                }
                return error.DuplicateSourceName;
            };
            try constructors.append(self.a, .{ .name = constructor, .fields = try self.parseParameters(false) });
            if (!self.take(",")) break;
        }
        try self.require(")");
    } else if (kind == .function or kind == .guard or kind == .procedure) {
        try self.require("AS");
        if (kind == .guard and self.is("REQUIRE")) {
            const req_begin = self.index;
            var script: f.SqlScript.Compiler = .{ .scan = .{ .text = self.text, .position = start } };
            const frame = (try script.next()) orelse {
                self.failExpected("';'");
                return error.InvalidSourceSyntax;
            };
            while (self.index < self.tokens.len and self.tokens[self.index].end <= frame.end) self.index += 1;
            const req_end: u32 = if (self.index < self.tokens.len) self.tokens[self.index].start else @intCast(self.text.len);
            program = try Template.parseGuardRequiresReported(self.a, self.text, self.tokens[req_begin..self.index], req_end, self.location, self.report);
        } else {
            const begin_span = self.currentSpan();
            try self.require("BEGIN");
            if (kind == .procedure) {
                if (!self.take("ATOMIC")) {
                    const sp = self.currentSpan();
                    if (self.report) |r| r.setSpan(self.file_index, sp.start, sp.end);
                    return error.ProcedureOutsideAtomic;
                }
            } else if (self.is("ATOMIC")) {
                const sp = self.currentSpan();
                if (self.report) |r| r.setSpan(self.file_index, sp.start, sp.end);
                return if (kind == .function) error.ImpureSourceFunction else error.MutationInsideGuard;
            }
            const body_begin = self.index;
            var script: f.SqlScript.Compiler = .{ .scan = .{ .text = self.text, .position = start } };
            const frame = (try script.next()) orelse {
                self.failExpected("'END'");
                if (self.report) |r| r.addNote(self.file_index, begin_span, "'BEGIN' block opened here", .{});
                return error.InvalidSourceSyntax;
            };
            while (self.index < self.tokens.len and self.tokens[self.index].end <= frame.end) self.index += 1;
            if (self.index == body_begin) {
                self.failExpected("'END'");
                return error.InvalidSourceSyntax;
            }
            const end_token = self.tokens[self.index - 1];
            if (!std.ascii.eqlIgnoreCase(self.text[end_token.start..end_token.end], "END")) {
                self.failExpected("'END'");
                if (self.report) |r| r.addNote(self.file_index, begin_span, "'BEGIN' block opened here", .{});
                return error.InvalidSourceSyntax;
            }
            program = try Template.parseHelperReported(self.a, self.text, self.tokens[body_begin .. self.index - 1], end_token.start, switch (kind) {
                .function => .function,
                .guard => .guard,
                .procedure => .procedure,
                else => unreachable,
            }, return_type != null, self.location, self.report);
        }
    }
    const body: []const Statement = if (kind == .interface or kind == .domain or kind == .variant or kind == .function or kind == .guard or kind == .procedure) &.{} else blk: {
        try self.require("AS");
        const begin_span = self.currentSpan();
        try self.require("BEGIN");
        const result = self.parseBody(.end) catch |err| {
            if (err == error.InvalidSourceSyntax and self.index == self.tokens.len) {
                if (self.report) |r| r.addNote(self.file_index, begin_span, "'BEGIN' block opened here", .{});
            }
            return err;
        };
        try self.require("END");
        break :blk result;
    };
    try self.require(";");
    return .{ .name = name, .public = public, .kind = kind, .parameters = parameters, .body = body, .span = self.span(start), .domain = domain, .constructors = try constructors.toOwnedSlice(self.a), .return_type = return_type, .program = program, .migration = migration, .schema = def_schema };
}
fn currentSpan(self: *const Self) SourceDiagnostic.Span {
    const end_pos: u32 = @intCast(self.text.len);
    return if (self.index < self.tokens.len) .{ .start = self.tokens[self.index].start, .end = self.tokens[self.index].end } else .{ .start = end_pos, .end = end_pos };
}
fn found(self: *const Self, buf: *[96]u8) []const u8 {
    return if (self.index < self.tokens.len) Template.describeToken(self.text, self.tokens[self.index], buf) else "end of file";
}
fn failExpected(self: *Self, expected: []const u8) void {
    const r = self.report orelse return;
    if (r.headline_len != 0) return;
    var buf: [96]u8 = undefined;
    const sp = self.currentSpan();
    r.setSpan(self.file_index, sp.start, sp.end);
    r.setHeadline("expected {s}, found {s}", .{ expected, self.found(&buf) });
}
fn at(self: *Self) u32 {
    const offset: u32 = if (self.index < self.tokens.len) self.tokens[self.index].start else @intCast(self.text.len);
    self.location.* = offset;
    return offset;
}
fn span(self: *Self, start: u32) Span {
    return .{ .start = start, .end = if (self.index > 0) self.tokens[self.index - 1].end else start };
}
fn is(self: *Self, value: []const u8) bool {
    _ = self.at();
    if (self.index == self.tokens.len) return false;
    const token = self.tokens[self.index];
    if (token.kind != .word and token.kind != .symbol) return false;
    return std.ascii.eqlIgnoreCase(self.text[token.start..token.end], value);
}
fn take(self: *Self, value: []const u8) bool {
    if (!self.is(value)) return false;
    self.index += 1;
    return true;
}
fn isArrowAt(self: *const Self, idx: usize) bool {
    if (idx + 1 >= self.tokens.len) return false;
    const first = self.tokens[idx];
    const second = self.tokens[idx + 1];
    return first.kind == .symbol and second.kind == .symbol and first.end == second.start and
        self.text[first.start] == '=' and self.text[second.start] == '>';
}
fn isNamedArgument(self: *const Self) bool {
    return self.index < self.tokens.len and self.tokens[self.index].kind == .word and self.isArrowAt(self.index + 1);
}
fn requireArrow(self: *Self) !void {
    _ = self.at();
    if (!self.isArrowAt(self.index)) {
        self.failExpected("'=>'");
        return error.InvalidSourceSyntax;
    }
    self.index += 2;
}
fn require(self: *Self, value: []const u8) !void {
    if (!self.take(value)) {
        var q: [72]u8 = undefined;
        const label = std.fmt.bufPrint(&q, "'{s}'", .{value}) catch value;
        self.failExpected(label);
        return error.InvalidSourceSyntax;
    }
}
fn identifier(self: *Self) ![]const u8 {
    _ = self.at();
    if (self.index == self.tokens.len or self.tokens[self.index].kind != .word) {
        self.failExpected("identifier");
        return error.InvalidSourceName;
    }
    const token = self.tokens[self.index];
    self.index += 1;
    if (token.end - token.start > 63) {
        if (self.report) |r| {
            r.setSpan(self.file_index, token.start, token.end);
            r.setHeadline("identifier exceeds 63-byte maximum length", .{});
        }
        return error.InvalidSourceName;
    }
    return std.ascii.allocLowerString(self.a, self.text[token.start..token.end]);
}
fn parseName(self: *Self) !Name {
    const first = try self.identifier();
    if (!self.take(".")) return .{ .member = first };
    const second = try self.identifier();
    return .{ .qualifier = first, .member = second, .constructor = if (self.take(".")) try self.identifier() else null };
}
fn parseTwoPartName(self: *Self) !Name {
    const first = try self.identifier();
    if (!self.take(".")) return .{ .member = first };
    return .{ .qualifier = first, .member = try self.identifier() };
}
fn takeKeywordBeforeName(self: *Self, word: []const u8) bool {
    if (!self.is(word) or self.index + 1 >= self.tokens.len) return false;
    if (self.tokens[self.index + 1].kind != .word) return false;
    self.index += 1;
    return true;
}
fn scalarType(self: *Self) !ScalarType {
    if (self.take("BIGINT")) return .bigint;
    if (self.take("TEXT")) return .text;
    if (self.take("BOOLEAN")) return .boolean;
    if (self.take("UUID")) return .uuid;
    if (self.take("TIMESTAMPTZ")) return .timestamptz;
    if (self.take("BINARY")) return .binary;
    self.failExpected("scalar type ('BIGINT', 'TEXT', 'BOOLEAN', 'UUID', 'TIMESTAMPTZ' or 'BINARY')");
    return error.UnsupportedSourceType;
}
fn typeRef(self: *Self) !TypeRef {
    if (self.is("BIGINT") or self.is("TEXT") or self.is("BOOLEAN") or self.is("UUID") or self.is("TIMESTAMPTZ") or self.is("BINARY")) return .{ .scalar = try self.scalarType() };
    return .{ .named = try self.parseName() };
}
fn tableSignature(self: *Self) ![]const Column {
    try self.require("(");
    var columns: std.ArrayList(Column) = .empty;
    while (true) {
        if (columns.items.len == f.TableSchema.max_columns) return error.SourceParameterLimit;
        const col_span = self.currentSpan();
        const name = try self.identifier();
        for (columns.items) |prior| if (std.mem.eql(u8, prior.name, name)) {
            if (self.report) |r| {
                r.setSpan(self.file_index, col_span.start, col_span.end);
                r.setHeadline("duplicate column '{s}' in resource signature", .{name});
            }
            return error.DuplicateSourceName;
        };
        var column: Column = .{ .name = name, .type = try self.typeRef() };
        var explicit_null = false;
        if (self.take("NOT")) {
            try self.require("NULL");
            column.nullable = false;
        } else explicit_null = self.take("NULL");
        if (self.take("PRIMARY")) {
            try self.require("KEY");
            if (explicit_null) {
                if (self.report) |r| {
                    r.setSpan(self.file_index, col_span.start, col_span.end);
                    r.setHeadline("primary key column '{s}' cannot be declared NULL", .{name});
                }
                return error.NullablePrimaryKey;
            }
            column.primary = true;
            column.nullable = false;
        }
        if (self.take("COLLATE")) column.collation = try self.identifier();
        try columns.append(self.a, column);
        if (!self.take(",")) break;
    }
    try self.require(")");
    return columns.toOwnedSlice(self.a);
}
fn string(self: *Self) ![]const u8 {
    _ = self.at();
    if (self.index == self.tokens.len or self.tokens[self.index].kind != .string) {
        self.failExpected("string literal");
        return error.InvalidSourceSyntax;
    }
    const token = self.tokens[self.index];
    self.index += 1;
    return decodeString(self.a, self.text[token.start..token.end]);
}
pub fn decodeString(a: std.mem.Allocator, text: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    var i: usize = 1;
    while (i + 1 < text.len) : (i += 1) {
        try result.append(a, text[i]);
        if (text[i] == '\'') i += 1;
    }
    return result.toOwnedSlice(a);
}
fn takeSignature(self: *Self, word: []const u8) bool {
    if (!self.is(word) or self.index + 1 == self.tokens.len) return false;
    const next = self.tokens[self.index + 1];
    if (!std.mem.eql(u8, self.text[next.start..next.end], "(")) return false;
    self.index += 1;
    return true;
}
fn parseParameters(self: *Self, require_non_empty: bool) anyerror![]const Parameter {
    self.depth += 1;
    defer self.depth -= 1;
    if (self.depth > 64) return error.SourceDepthLimit;
    try self.require("(");
    var result: std.ArrayList(Parameter) = .empty;
    if (self.take(")")) {
        if (require_non_empty) {
            self.failExpected("at least one field in 'ROW(...)'");
            return error.InvalidSourceSyntax;
        }
        return &.{};
    }
    while (true) {
        if (result.items.len == 64) return error.SourceParameterLimit;
        const param_span = self.currentSpan();
        const parameter_name = try self.identifier();
        for (result.items) |prior| if (std.mem.eql(u8, prior.name, parameter_name)) {
            if (self.report) |r| {
                r.setSpan(self.file_index, param_span.start, param_span.end);
                r.setHeadline("duplicate parameter '{s}'", .{parameter_name});
            }
            return error.DuplicateSourceName;
        };
        const kind: Kind = if (self.take("BIGINT")) .integer else if (self.take("TEXT")) .text else if (self.take("BOOLEAN")) .boolean else if (self.take("UUID")) .uuid else if (self.take("TIMESTAMPTZ")) .timestamptz else if (self.take("BINARY")) .binary else if (self.take("IDENTIFIER")) .identifier else if (self.take("TYPE")) .type else if (self.take("SCHEMA_BINDING")) .schema_binding else if (self.take("MODULE")) (if (self.takeKeywordBeforeName("OF")) .{ .module_of = try self.parseName() } else .{ .module = try self.parseName() }) else if (self.takeSignature("ROW")) .{ .row = try self.parseParameters(true) } else if (self.take("TABLE")) .{ .table = try self.tableSignature() } else if (self.takeSignature("STREAM")) .{ .stream = try self.tableSignature() } else if (self.takeSignature("QUEUE")) .{ .queue = try self.tableSignature() } else .{ .named = try self.parseName() };
        try result.append(self.a, .{ .name = parameter_name, .kind = kind });
        if (self.take(")")) break;
        try self.require(",");
    }
    return result.toOwnedSlice(self.a);
}
fn parseBody(self: *Self, stop: enum { end, conditional, arm }) anyerror![]const Statement {
    self.depth += 1;
    defer self.depth -= 1;
    if (self.depth > 64) return error.SourceDepthLimit;
    var result: std.ArrayList(Statement) = .empty;
    while (!self.is("END") and !(stop == .conditional and self.is("ELSE")) and !(stop == .arm and self.is("WHEN"))) {
        if (self.index == self.tokens.len) {
            self.failExpected("'END'");
            return error.InvalidSourceSyntax;
        }
        try result.append(self.a, try self.parseStatement());
    }
    return result.toOwnedSlice(self.a);
}
fn parseStatement(self: *Self) anyerror!Statement {
    const start = self.at();
    const value: @FieldType(Statement, "value") = if (self.take("LET")) blk: {
        const result_name = try self.identifier();
        try self.require("=");
        try self.require("USE");
        _ = self.takeKeywordBeforeName("MODULE");
        var call = try self.parseCall();
        call.result = result_name;
        call.let_binding = true;
        try self.require(";");
        break :blk .{ .use = call };
    } else if (self.take("USE")) blk: {
        if (self.takeKeywordBeforeName("MODULE")) {
            const mod_name = try self.parseName();
            if (self.is("(")) {
                var call = try self.callAfterName(mod_name);
                if (self.take("AS")) call.result = try self.identifier();
                try self.require(";");
                break :blk .{ .use = call };
            }
            try self.require(";");
            break :blk .{ .use_module = mod_name };
        }
        var call = try self.parseCall();
        if (self.take("AS")) call.result = try self.identifier();
        try self.require(";");
        break :blk .{ .use = call };
    } else if (self.take("DECLARE")) blk: {
        try self.require("FROM");
        const path = try self.string();
        try self.require(";");
        break :blk .{ .declare_from = path };
    } else if (self.take("BIND")) blk: {
        try self.require("SCHEMA");
        const logical_name = try self.identifier();
        try self.require("TO");
        const target = try self.expression(0);
        try self.require(";");
        break :blk .{ .bind_schema = .{ .name = logical_name, .target = target } };
    } else if (self.take("EXPORT")) blk: {
        if (self.take("REFERENCE")) {
            try self.require("TABLE");
            const source = try self.parseTwoPartName();
            try self.require("(");
            var cols: std.ArrayList([]const u8) = .empty;
            if (self.take(")")) {
                self.failExpected("column name in 'EXPORT REFERENCE TABLE'");
                return error.InvalidSourceSyntax;
            }
            while (true) {
                if (cols.items.len == 64) return error.SourceParameterLimit;
                const col_span = self.currentSpan();
                const col_name = try self.identifier();
                for (cols.items) |prior| if (std.mem.eql(u8, prior, col_name)) {
                    if (self.report) |r| {
                        r.setSpan(self.file_index, col_span.start, col_span.end);
                        r.setHeadline("duplicate column '{s}' in reference export", .{col_name});
                    }
                    return error.DuplicateSourceName;
                };
                try cols.append(self.a, col_name);
                if (self.take(")")) break;
                try self.require(",");
            }
            const alias = if (self.take("AS")) try self.identifier() else source.member;
            try self.require(";");
            break :blk .{ .reference_export = .{ .source = source, .columns = try cols.toOwnedSlice(self.a), .alias = alias } };
        }
        if (self.take("TABLE") or self.is("STREAM") or self.is("QUEUE")) {
            const kind: enum { table, stream, queue } = if (self.take("STREAM")) .stream else if (self.take("QUEUE")) .queue else .table;
            const operand = self.take("$");
            const source = try self.parseTwoPartName();
            const alias = if (self.take("AS")) try self.identifier() else if (!operand) source.member else {
                self.failExpected("'AS <alias>' after '$parameter' export");
                return error.InvalidSourceSyntax;
            };
            try self.require(";");
            break :blk if (kind == .table) .{ .table_export = .{ .source = source, .operand = operand, .alias = alias } } else .{ .log_export = .{ .kind = if (kind == .stream) .stream else .queue, .source = source, .operand = operand, .alias = alias } };
        }
        const sym_kind: ExportKind = if (self.take("FUNCTION")) .function else if (self.take("GUARD")) .guard else if (self.take("PROCEDURE")) .procedure else if (self.take("VIEW")) .view else if (self.take("DATAFLOW")) .dataflow else if (self.take("PROFILE")) .profile else {
            self.failExpected("'TABLE', 'STREAM', 'QUEUE', 'FUNCTION', 'GUARD', 'PROCEDURE', 'VIEW', 'DATAFLOW', 'PROFILE' or 'REFERENCE' after 'EXPORT'");
            return error.InvalidSourceSyntax;
        };
        const source = try self.parseTwoPartName();
        const alias = if (self.take("AS")) try self.identifier() else source.member;
        try self.require(";");
        break :blk .{ .symbol_export = .{ .kind = sym_kind, .source = source, .alias = alias } };
    } else if (self.take("MATCH")) blk: {
        const value = try self.expression(0);
        var arms: std.ArrayList(Arm) = .empty;
        while (self.is("WHEN")) {
            const arm_start = self.at();
            try self.require("WHEN");
            if (arms.items.len == 64) return error.SourceConstructorLimit;
            const constructor = try self.parseName();
            try self.require("(");
            var names: std.ArrayList([]const u8) = .empty;
            if (!self.take(")")) while (true) {
                if (names.items.len == 64) return error.SourceParameterLimit;
                const bind_span = self.currentSpan();
                const name = try self.identifier();
                for (names.items) |prior| if (std.mem.eql(u8, prior, name)) {
                    if (self.report) |r| {
                        r.setSpan(self.file_index, bind_span.start, bind_span.end);
                        r.setHeadline("duplicate pattern binding '{s}'", .{name});
                    }
                    return error.DuplicateSourceName;
                };
                try names.append(self.a, name);
                if (self.take(")")) break;
                try self.require(",");
            };
            try self.require("THEN");
            const body = try self.parseBody(.arm);
            try arms.append(self.a, .{ .constructor = constructor, .names = try names.toOwnedSlice(self.a), .body = body, .span = self.span(arm_start) });
        }
        if (arms.items.len == 0) {
            self.failExpected("'WHEN' arm in 'MATCH' statement");
            return error.InvalidSourceSyntax;
        }
        try self.require("END");
        try self.require("MATCH");
        try self.require(";");
        break :blk .{ .match = .{ .value = value, .arms = try arms.toOwnedSlice(self.a) } };
    } else if (self.take("TEST")) blk: {
        const name_span = self.currentSpan();
        const name = try self.string();
        if (name.len == 0 or name.len > 128 or !std.unicode.utf8ValidateSlice(name)) {
            if (self.report) |r| r.setSpan(self.file_index, name_span.start, name_span.end);
            return error.InvalidTestName;
        }
        for (name) |byte| if (std.ascii.isControl(byte)) {
            if (self.report) |r| r.setSpan(self.file_index, name_span.start, name_span.end);
            return error.InvalidTestName;
        };
        try self.require("USING");
        try self.require("MODULES");
        try self.require("(");
        var setup: std.ArrayList(CaseModule) = .empty;
        if (!self.take(")")) while (true) {
            if (setup.items.len == 64) return error.SourceParameterLimit;
            const item_name = try self.parseName();
            try setup.append(self.a, if (self.is("(")) .{ .call = try self.callAfterName(item_name) } else .{ .reference = item_name });
            if (self.take(")")) break;
            try self.require(",");
        };
        try self.require("AS");
        const test_begin = self.currentSpan();
        try self.require("BEGIN");
        const body = self.parseBody(.end) catch |err| {
            if (err == error.InvalidSourceSyntax and self.index == self.tokens.len) {
                if (self.report) |r| r.addNote(self.file_index, test_begin, "'BEGIN' block opened here", .{});
            }
            return err;
        };
        try self.require("END");
        try self.require(";");
        break :blk .{ .test_case = .{ .name = name, .setup = try setup.toOwnedSlice(self.a), .body = body } };
    } else if (self.take("ASSERT")) blk: {
        if (self.take("WORKFLOW")) {
            const name = try self.expression(0);
            try self.require("COMPLETED");
            const completed = try self.count();
            try self.require("REFUSED");
            const refused = try self.count();
            try self.require("WITHIN");
            const observations = try self.count();
            try self.require("OBSERVATIONS");
            try self.require(";");
            break :blk .{ .workflow = .{ .name = name, .completed = completed, .refused = refused, .observations = observations } };
        }
        const kind: enum { rows, command, refusal } = if (self.take("ROWS")) .rows else if (self.take("COMMAND")) .command else if (self.take("STATEMENT")) .refusal else {
            self.failExpected("'ROWS', 'COMMAND', 'STATEMENT' or 'WORKFLOW' after 'ASSERT'");
            return error.UnsupportedTestAssertion;
        };
        const sql = try self.template(try self.parenthesized(), if (self.index > 0) self.tokens[self.index - 1].start else self.at(), false);
        // Assertions contain simple statements in the reference grammar.
        // An empty compound body can otherwise pass shared SQL framing.
        if (sql.kind == .program) {
            if (self.report) |r| {
                r.setSpan(self.file_index, start, self.span(start).end);
                r.setHeadline("dataflow program declarations are not allowed inside 'ASSERT (...)'", .{});
            }
            return error.UnsupportedTestAssertion;
        }
        const expected: @FieldType(Assertion, "expected") = switch (kind) {
            .rows => rows: {
                try self.require("EQUAL");
                const rows_tokens = try self.parenthesized();
                break :rows .{ .rows = try self.template(rows_tokens, if (self.index > 0) self.tokens[self.index - 1].start else self.at(), true) };
            },
            .command => command: {
                try self.require("MATCHED");
                const matched = try self.count();
                try self.require("CHANGED");
                break :command .{ .command = .{ .matched = matched, .changed = try self.count() } };
            },
            .refusal => refusal: {
                try self.require("FAILS");
                try self.require("WITH");
                const reason_span = self.currentSpan();
                const reason_text = try self.string();
                break :refusal .{ .refusal = std.meta.stringToEnum(@FieldType(@FieldType(Assertion, "expected"), "refusal"), reason_text) orelse {
                    if (self.report) |r| {
                        r.setSpan(self.file_index, reason_span.start, reason_span.end);
                        r.setHeadline("unsupported refusal reason; expected 'duplicate_key' or 'check_violation'", .{});
                    }
                    return error.UnsupportedTestRefusal;
                } };
            },
        };
        try self.require(";");
        break :blk .{ .assertion = .{ .sql = sql, .expected = expected } };
    } else if (self.take("IF")) blk: {
        const if_span = SourceDiagnostic.Span{ .start = start, .end = start + 2 };
        const condition = try self.expression(0);
        try self.require("THEN");
        const yes = self.parseBody(.conditional) catch |err| {
            if (err == error.InvalidSourceSyntax and self.index == self.tokens.len) {
                if (self.report) |r| r.addNote(self.file_index, if_span, "'IF' statement opened here", .{});
            }
            return err;
        };
        const no = if (self.take("ELSE")) try self.parseBody(.end) else &.{};
        try self.require("END");
        try self.require("IF");
        try self.require(";");
        break :blk .{ .conditional = .{ .condition = condition, .yes = yes, .no = no } };
    } else blk: {
        const begin = self.index;
        var script: f.SqlScript.Compiler = .{ .scan = .{ .text = self.text, .position = start } };
        const frame = (try script.next()) orelse {
            self.failExpected("statement");
            return error.InvalidSourceSyntax;
        };
        while (self.index < self.tokens.len and self.tokens[self.index].end <= frame.end) self.index += 1;
        const sql = self.tokens[begin..self.index];
        const sql_end: u32 = if (self.index < self.tokens.len) self.tokens[self.index].start else @intCast(self.text.len);
        const parsed = try self.template(sql, sql_end, false);
        try self.require(";");
        break :blk .{ .sql = parsed };
    };
    return .{ .span = self.span(start), .value = value };
}
fn template(self: *Self, tokens: []const Token, end: u32, rows: bool) !Template.Syntax {
    const parsed = Template.parseReported(self.a, self.text, tokens, end, rows, self.location, self.report) catch |err| {
        if (self.report) |r| if (r.file == null) {
            r.file = self.file_index;
        };
        return err;
    };
    return parsed;
}
fn parseCall(self: *Self) !Call {
    return self.callAfterName(try self.parseName());
}
fn callAfterName(self: *Self, name: Name) !Call {
    try self.require("(");
    var arguments: std.ArrayList(*Expr) = .empty;
    var names: std.ArrayList([]const u8) = .empty;
    if (!self.take(")")) {
        const named_mode = self.isNamedArgument();
        while (true) {
            if (arguments.items.len == 64) return error.SourceParameterLimit;
            if (named_mode) {
                if (!self.isNamedArgument()) {
                    self.failExpected("'name => expression' named argument");
                    return error.InvalidSourceSyntax;
                }
                const arg_span = self.currentSpan();
                const arg_name = try self.identifier();
                for (names.items) |prior| if (std.mem.eql(u8, prior, arg_name)) {
                    if (self.report) |r| {
                        r.setSpan(self.file_index, arg_span.start, arg_span.end);
                        r.setHeadline("duplicate named argument '{s}'", .{arg_name});
                    }
                    return error.DuplicateSourceName;
                };
                try self.requireArrow();
                try names.append(self.a, arg_name);
                try arguments.append(self.a, try self.expression(0));
            } else {
                if (self.isNamedArgument()) {
                    self.index += 1;
                    _ = self.at();
                    self.failExpected("',' or ')' (cannot mix positional and named arguments)");
                    return error.InvalidSourceSyntax;
                }
                try arguments.append(self.a, try self.expression(0));
            }
            if (self.take(")")) break;
            try self.require(",");
        }
    }
    return .{ .name = name, .arguments = try arguments.toOwnedSlice(self.a), .names = try names.toOwnedSlice(self.a) };
}
fn parseRowFields(self: *Self) ![]const RowField {
    try self.require("(");
    var fields: std.ArrayList(RowField) = .empty;
    if (self.take(")")) {
        self.failExpected("field in 'ROW(...)'");
        return error.InvalidSourceSyntax;
    }
    while (true) {
        if (fields.items.len == 64) return error.SourceParameterLimit;
        const field_span = self.currentSpan();
        const field_name = try self.identifier();
        for (fields.items) |prior| if (std.mem.eql(u8, prior.name, field_name)) {
            if (self.report) |r| {
                r.setSpan(self.file_index, field_span.start, field_span.end);
                r.setHeadline("duplicate field '{s}' in 'ROW(...)'", .{field_name});
            }
            return error.DuplicateSourceName;
        };
        try self.requireArrow();
        try fields.append(self.a, .{ .name = field_name, .value = try self.expression(0) });
        if (self.take(")")) break;
        try self.require(",");
    }
    return fields.toOwnedSlice(self.a);
}
fn parenthesized(self: *Self) ![]const Token {
    const open_span = self.currentSpan();
    try self.require("(");
    const start = self.index;
    var depth: usize = 1;
    while (self.index < self.tokens.len) {
        if (self.take("(")) {
            depth += 1;
            if (depth > 64) return error.SourceDepthLimit;
        } else if (self.take(")")) {
            depth -= 1;
            if (depth == 0) return self.tokens[start .. self.index - 1];
        } else {
            if (self.is(";")) {
                const semi = self.currentSpan();
                if (self.report) |r| r.setSpan(self.file_index, semi.start, semi.end);
                return error.InvalidTestStatement;
            }
            self.index += 1;
        }
    }
    self.failExpected("')'");
    if (self.report) |r| r.addNote(self.file_index, open_span, "opening '(' here", .{});
    return error.InvalidSourceSyntax;
}
fn count(self: *Self) !u64 {
    _ = self.at();
    if (self.index == self.tokens.len) {
        self.failExpected("non-negative integer count");
        return error.InvalidTestCount;
    }
    const token = self.tokens[self.index];
    const bytes = self.text[token.start..token.end];
    for (bytes) |byte| if (!std.ascii.isDigit(byte)) {
        self.failExpected("non-negative integer count");
        return error.InvalidTestCount;
    };
    self.index += 1;
    return std.fmt.parseInt(u64, bytes, 10) catch {
        if (self.report) |r| {
            r.setSpan(self.file_index, token.start, token.end);
            r.setHeadline("integer count overflows 64-bit unsigned range", .{});
        }
        return error.InvalidTestCount;
    };
}
fn expression(self: *Self, minimum: u8) anyerror!*Expr {
    self.depth += 1;
    defer self.depth -= 1;
    if (self.depth > 64) return error.SourceDepthLimit;
    const start = self.at();
    const value: @FieldType(Expr, "value") = if (self.take("-")) blk: {
        if (self.index < self.tokens.len and self.tokens[self.index].kind == .number) {
            const token = self.tokens[self.index];
            const magnitude = try std.fmt.parseInt(u64, self.text[token.start..token.end], 10);
            if (magnitude > @as(u64, std.math.maxInt(i64)) + 1) return error.Overflow;
            self.index += 1;
            break :blk .{ .integer = if (magnitude == @as(u64, std.math.maxInt(i64)) + 1) std.math.minInt(i64) else -@as(i64, @intCast(magnitude)) };
        }
        break :blk .{ .unary = .{ .negative = true, .operand = try self.expression(6) } };
    } else if (self.take("NOT")) .{ .unary = .{ .negative = false, .operand = try self.expression(6) } } else if (self.take("(")) blk: {
        const inner = try self.expression(0);
        try self.require(")");
        break :blk inner.value;
    } else if ((self.index + 1 < self.tokens.len and self.tokens[self.index + 1].kind == .string and self.take("NAME"))) .{ .identifier = try self.string() } else if (self.takeSignature("SCHEMA_BINDING")) blk: {
        try self.require("(");
        const binding_name = try self.string();
        try self.require(")");
        break :blk .{ .schema_binding = binding_name };
    } else if (self.takeSignature("ROW")) .{ .row = try self.parseRowFields() } else if (self.take("TYPE")) blk: {
        const kind = try self.typeRef();
        break :blk switch (kind) {
            .scalar => |scalar| .{ .type = scalar },
            .named => |name| .{ .named_type = name },
        };
    } else if (self.take("TRUE")) .{ .boolean = true } else if (self.take("FALSE")) .{ .boolean = false } else if (self.index + 1 < self.tokens.len and self.tokens[self.index + 1].kind == .string and self.take("UUID")) .{ .uuid = try self.string() } else if (self.index + 1 < self.tokens.len and self.tokens[self.index + 1].kind == .string and (self.take("TIMESTAMPTZ") or self.take("TIMESTAMP"))) .{ .timestamptz = try self.string() } else if (self.index + 1 < self.tokens.len and self.tokens[self.index + 1].kind == .string and self.take("X")) .{ .bytes = try self.string() } else if (self.index < self.tokens.len and self.tokens[self.index].kind == .string) .{ .text = try self.string() } else if (self.index < self.tokens.len and self.tokens[self.index].kind == .number) blk: {
        const token = self.tokens[self.index];
        self.index += 1;
        break :blk .{ .integer = try std.fmt.parseInt(i64, self.text[token.start..token.end], 10) };
    } else blk: {
        const name = try self.parseName();
        break :blk if (self.is("(")) .{ .construct = try self.callAfterName(name) } else .{ .reference = name };
    };
    var left = try self.a.create(Expr);
    left.* = .{ .span = self.span(start), .value = value };
    while (true) {
        const saved = self.index;
        const op: Binary = if (self.take("OR")) .or_ else if (self.take("AND")) .and_ else if (self.take("=")) .equal else if (self.take("<")) (if (self.take("=")) .less_equal else if (self.take(">")) .not_equal else .less) else if (self.take(">")) (if (self.take("=")) .greater_equal else .greater) else if (self.take("+")) .add else if (self.take("-")) .subtract else if (self.take("*")) .multiply else break;
        const precedence: u8 = switch (op) {
            .or_ => 1,
            .and_ => 2,
            .equal, .not_equal, .less, .less_equal, .greater, .greater_equal => 3,
            .add, .subtract => 4,
            .multiply => 5,
        };
        if (precedence < minimum) {
            self.index = saved;
            break;
        }
        const right = try self.expression(precedence + 1);
        const combined = try self.a.create(Expr);
        combined.* = .{ .span = self.span(start), .value = .{ .binary = .{ .op = op, .left = left, .right = right } } };
        left = combined;
    }
    return left;
}
