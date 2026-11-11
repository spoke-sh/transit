//! Private projection of production syntax and products; no parser/evaluator here.
const std = @import("std");
const c = @import("transit_compiler");
const p = @import("transit_protocol");
const memory = @import("transit_memory");
const Request = struct { name: []const u8, source: []const u8, compile: ?enum { build, test_suite } = null, files: []const c.Source = &.{} };
const View = struct {
    text: []const u8,
    file: c.Syntax.File,
    pub fn jsonStringify(self: View, out: *std.json.Stringify) !void {
        try project(out, self.text, self.file, 0);
    }
};
fn project(out: *std.json.Stringify, text: []const u8, value: anytype, depth: usize) std.json.Stringify.Error!void {
    if (depth > 512) return error.WriteFailed;
    const T = @TypeOf(value);
    if (T == c.Syntax.Token) {
        try out.beginObject();
        try out.objectField("kind");
        try out.write(@tagName(value.kind));
        try out.objectField("text");
        const raw = text[value.start..value.end];
        if (value.kind == .word and !c.Syntax.Template.numericWord(text, value)) {
            // Names are bounded by source bytes, not a fixed word-size truncation.
            try out.beginWriteRaw();
            try out.writer.writeByte('"');
            for (raw) |byte| try out.writer.writeByte(std.ascii.toUpper(byte));
            try out.writer.writeByte('"');
            out.endWriteRaw();
        } else try out.write(raw);
        try out.objectField("start");
        try out.write(value.start);
        try out.objectField("end");
        try out.write(value.end);
        try out.endObject();
        return;
    }
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            try out.beginObject();
            inline for (info.field_names) |field| {
                try out.objectField(field);
                try project(out, text, @field(value, field), depth + 1);
            }
            try out.endObject();
        },
        .@"union" => {
            try out.beginObject();
            switch (value) {
                inline else => |payload, tag| {
                    try out.objectField(@tagName(tag));
                    try project(out, text, payload, depth + 1);
                },
            }
            try out.endObject();
        },
        .@"enum" => try out.write(@tagName(value)),
        .void => try out.write(null),
        .optional => if (value) |v| try project(out, text, v, depth + 1) else try out.write(null),
        .pointer => |ptr| switch (ptr.size) {
            .one => try project(out, text, value.*, depth + 1),
            .slice => if (ptr.child == u8) try out.write(value) else {
                try out.beginArray();
                for (value) |item| try project(out, text, item, depth + 1);
                try out.endArray();
            },
            else => @compileError("unbounded projection"),
        },
        else => try out.write(value),
    }
}
fn location(out: *std.json.Stringify, value: p.Diagnostic.Location) !void {
    try out.write(.{ .source = if (value.source) |*s| s.slice() else "", .offset = try value.offset.value(), .line = try value.line.value(), .column = try value.byte_column.value() });
}
fn steps(out: *std.json.Stringify, values: []const c.Compiler.Step) !void {
    try out.beginArray();
    for (values) |v| {
        try out.beginObject();
        try out.objectField("sql");
        try out.write(v.sql);
        try out.objectField("fingerprint");
        try out.write(std.fmt.bytesToHex(v.plan_digest, .lower));
        try out.objectField("bindings");
        try out.write(std.fmt.bytesToHex(v.bindings_digest, .lower));
        try out.objectField("definition");
        try location(out, v.definition);
        try out.objectField("call");
        if (v.call) |site| try location(out, site) else try out.write(null);
        try out.endObject();
    }
    try out.endArray();
}
fn product(out: *std.json.Stringify, value: *c.Product) !void {
    try out.beginObject();
    try out.objectField("sql");
    try out.write(value.sql);
    try out.objectField("steps");
    try steps(out, value.steps);
    try out.objectField("input_digest");
    try out.write(std.fmt.bytesToHex(value.input_digest, .lower));
    try out.objectField("cases");
    try out.beginArray();
    for (value.cases) |case| {
        try out.beginObject();
        try out.objectField("name");
        try out.write(case.name);
        try out.objectField("identity");
        try out.write(std.fmt.bytesToHex(case.identity, .lower));
        try out.objectField("location");
        try location(out, case.location);
        try out.objectField("sql");
        try out.write(case.sql);
        try out.objectField("steps");
        try steps(out, case.steps);
        try out.objectField("actions");
        try out.beginArray();
        for (case.actions) |action| {
            try out.beginObject();
            try out.objectField("step");
            try out.write(action.step);
            try out.objectField("kind");
            try out.write(@tagName(action.expectation));
            try out.objectField("expected");
            switch (action.expectation) {
                .rows => |rows| {
                    try out.beginObject();
                    try out.objectField("schema");
                    try out.write(std.fmt.bytesToHex(try rows.schema.fingerprint(), .lower));
                    try out.objectField("values");
                    try out.beginArray();
                    for (rows.values) |bytes| {
                        try out.beginWriteRaw();
                        try out.writer.writeByte('"');
                        for (bytes) |byte| try out.writer.print("{x:0>2}", .{byte});
                        try out.writer.writeByte('"');
                        out.endWriteRaw();
                    }
                    try out.endArray();
                    try out.endObject();
                },
                .command => |counts| try out.write(counts),
                .refusal => |reason| try out.write(@tagName(reason)),
                .complete => try out.write(null),
            }
            try out.objectField("location");
            try location(out, action.location);
            try out.endObject();
        }
        try out.endArray();
        try out.endObject();
    }
    try out.endArray();
    try out.endObject();
}
fn run(a: std.mem.Allocator, request: Request, out: *std.json.Stringify) !void {
    try out.beginObject();
    try out.objectField("name");
    try out.write(request.name);
    var offset: usize = 0;
    const file = c.Syntax.parse(a, request.source, &offset) catch |err| {
        try out.objectField("parse_error");
        try out.write(@errorName(err));
        try out.objectField("location");
        try location(out, c.Compiler.location(.{ .path = "build.transit", .text = request.source }, offset));
        try out.endObject();
        return;
    };
    try out.objectField("ast");
    try out.write(View{ .text = request.source, .file = file });
    const buffer = try a.alloc(u8, 1024 * 1024);
    var formatted: std.Io.Writer = .fixed(buffer);
    try c.Format.write(request.source, file, &formatted);
    try out.objectField("formatted");
    try out.write(formatted.buffered());
    if (request.compile) |mode| {
        const sources = try a.alloc(c.Source, request.files.len + 1);
        sources[0] = .{ .path = "build.transit", .text = request.source };
        @memcpy(sources[1..], request.files);
        var diagnostic: ?p.Diagnostic = null;
        const result = c.compile(a, sources, .{ .compiler_revision = "source-grammar-proof", .mode = if (mode == .build) .build else .test_suite, .target = if (mode == .build) "default" else "tests" }, &diagnostic) catch |err| {
            try out.objectField("compile_error");
            try out.write(@errorName(err));
            try out.endObject();
            return;
        };
        defer result.deinit();
        try out.objectField("product");
        try product(out, result);
    }
    try out.endObject();
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.Usage;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const requests = try std.json.parseFromSlice([]const Request, init.gpa, bytes, .{ .ignore_unknown_fields = true });
    defer requests.deinit();
    if (requests.value.len > 512) return error.CorpusLimit;
    const buffer = try init.gpa.alloc(u8, 16 * 1024 * 1024);
    defer init.gpa.free(buffer);
    var writer: std.Io.Writer = .fixed(buffer);
    var out: std.json.Stringify = .{ .writer = &writer, .options = .{} };
    try out.beginArray();
    for (requests.value) |request| {
        var budget: memory.Budget = .{ .parent = init.gpa, .limit = 128 * 1024 * 1024 };
        var arena: std.heap.ArenaAllocator = .init(budget.allocator());
        defer arena.deinit();
        try run(arena.allocator(), request, &out);
    }
    try out.endArray();
    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout.interface.writeAll(writer.buffered());
    try stdout.interface.flush();
}
