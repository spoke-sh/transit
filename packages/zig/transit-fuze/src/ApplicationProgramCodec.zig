//! Retained ordered instruction trees. SQL is provenance, never recovery input.
//! Structural validation precedes binding or execution, including for trees
//! supplied directly by a native caller rather than produced by the parser.
const std = @import("std");
const p = @import("transit_protocol");
const a = @import("ApplicationProgram.zig");
pub const max_bytes = 1024 * 1024;
const Envelope = struct {
    definition: p.Growth.Definition,
    source_digest: [32]u8,
    program: a.Program,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    source_digest: [32]u8,
    program: a.Program,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn encode(allocator: std.mem.Allocator, program: a.Program, source_digest: [32]u8) ![]u8 {
    try validate(program);
    if (std.mem.allEqual(u8, &source_digest, 0)) return error.InvalidProgramNode;
    return p.Json.valueAllocBounded(allocator, Envelope{ .definition = p.Growth.current_definition, .source_digest = source_digest, .program = program }, max_bytes);
}

pub fn validateEncoding(bytes: []const u8) !void {
    // Bound the JSON syntax before its recursive typed decoder allocates or
    // descends. Escaped strings cannot hide structural depth from the scanner.
    if (bytes.len == 0 or bytes.len > max_bytes) return error.ProgramTooComplex;
    var scratch: [16384]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    var scanner = std.json.Scanner.initCompleteInput(fixed.allocator(), bytes);
    defer scanner.deinit();
    var depth: usize = 0;
    var tokens: usize = 0;
    while (true) {
        const token = try scanner.next();
        if (token == .end_of_document) break;
        tokens += 1;
        if (tokens > a.max_nodes * 128) return error.ProgramTooComplex;
        switch (token) {
            .object_begin, .array_begin => {
                depth += 1;
                if (depth > a.max_depth * 6 + 32) return error.ProgramTooDeep;
            },
            .object_end, .array_end => {
                if (depth == 0) return error.InvalidProgramNode;
                depth -= 1;
            },
            else => {},
        }
    }
}

pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Owned {
    try validateEncoding(bytes);
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const value = try std.json.parseFromSliceLeaky(Envelope, arena.allocator(), bytes, .{ .allocate = .alloc_always, .max_value_len = max_bytes });
    if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    const canonical = try encode(allocator, value.program, value.source_digest);
    defer allocator.free(canonical);
    if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidProgramNode;
    return .{ .arena = arena, .source_digest = value.source_digest, .program = value.program };
}

const Validator = struct {
    seen: std.StaticBitSet(a.max_nodes + 1) = .empty,
    count: usize = 0,
    nodes: u16,
    text_bytes: usize = 0,

    fn text(self: *Validator, value: []const u8, identifier: bool) !void {
        if (!std.unicode.utf8ValidateSlice(value) or std.mem.indexOfAny(u8, value, &.{ 0, 1 }) != null or
            (identifier and (value.len == 0 or value.len > 255))) return error.InvalidProgramNode;
        self.text_bytes = try std.math.add(usize, self.text_bytes, value.len);
        if (self.text_bytes > a.max_source_bytes) return error.ProgramTooComplex;
    }
    fn node(self: *Validator, id: a.Id, span: a.Span, depth: usize) !void {
        if (depth > a.max_depth) return error.ProgramTooDeep;
        if (id == 0 or id > self.nodes or self.seen.isSet(id) or span.start >= span.end or span.end > a.max_source_bytes)
            return error.InvalidProgramNode;
        self.seen.set(id);
        self.count += 1;
    }
    fn expressions(self: *Validator, values: []const *a.Expression, depth: usize) !void {
        if (values.len > a.max_arguments) return error.ProgramTooComplex;
        for (values) |value| try self.expression(value, depth);
    }
    fn expression(self: *Validator, value: *const a.Expression, depth: usize) anyerror!void {
        try self.node(value.id, value.span, depth);
        switch (value.value) {
            .null, .boolean, .integer => {},
            .text => |literal| try self.text(literal, false),
            .name => |name| try self.text(name, true),
            .field => |field| {
                try self.expression(field.base, depth + 1);
                try self.text(field.name, true);
            },
            .call => |call| try self.expressions(call.arguments, depth + 1),
            .unary => |unary| try self.expression(unary.operand, depth + 1),
            .binary => |binary| {
                try self.expression(binary.left, depth + 1);
                try self.expression(binary.right, depth + 1);
            },
            .case => |choice| {
                try self.expression(choice.condition, depth + 1);
                try self.expression(choice.yes, depth + 1);
                try self.expression(choice.no, depth + 1);
            },
            .text_cast => |operand| try self.expression(operand, depth + 1),
            .row => |values| try self.expressions(values, depth + 1),
        }
    }
    fn fields(self: *Validator, values: []const a.Field, depth: usize) !void {
        if (values.len > a.max_arguments) return error.ProgramTooComplex;
        for (values, 0..) |field, i| {
            try self.text(field.name, true);
            for (values[0..i]) |prior| if (std.mem.eql(u8, prior.name, field.name)) return error.DuplicateProgramField;
            try self.expression(field.value, depth);
        }
    }
    fn select(self: *Validator, query: a.Select, depth: usize) !void {
        try self.text(query.target, true);
        if (query.columns) |columns| {
            if (columns.len == 0 or columns.len > a.max_arguments) return error.ProgramTooComplex;
            for (columns) |name| try self.text(name, true);
        }
        if (query.predicate) |predicate| try self.expression(predicate, depth);
    }
    fn block(self: *Validator, instructions: []const a.Instruction, depth: usize, atomic: bool) anyerror!void {
        if (depth > a.max_depth or instructions.len > a.max_nodes) return error.ProgramTooComplex;
        for (instructions) |instruction| {
            try self.node(instruction.id, instruction.span, depth);
            switch (instruction.value) {
                .let => |binding| {
                    try self.text(binding.name, true);
                    switch (binding.value) {
                        .expression => |value| try self.expression(value, depth + 1),
                        .get => |get| {
                            try self.text(get.target, true);
                            try self.expression(get.key, depth + 1);
                        },
                        .select => |query| try self.select(query, depth + 1),
                        .effect => |effect| {
                            if (atomic) return error.EffectInsideAtomic;
                            try self.text(effect.sink, true);
                            try self.expression(effect.identity, depth + 1);
                            try self.expression(effect.guard, depth + 1);
                            try self.fields(switch (effect.request) {
                                .form, .headers => |values| values,
                            }, depth + 1);
                        },
                    }
                },
                .require => |check| {
                    try self.expression(check.condition, depth + 1);
                    try self.text(check.refusal, true);
                },
                .atomic => |body| {
                    if (atomic) return error.NestedAtomicProgram;
                    try self.block(body, depth + 1, true);
                },
                .conditional => |choice| {
                    try self.expression(choice.condition, depth + 1);
                    try self.block(choice.yes, depth + 1, atomic);
                    try self.block(choice.no, depth + 1, atomic);
                },
                .put => |put| {
                    if (!atomic) return error.MutationOutsideAtomic;
                    try self.text(put.target, true);
                    try self.expression(put.key, depth + 1);
                    try self.expression(put.value, depth + 1);
                    try self.fields(put.fields, depth + 1);
                    if (put.expected == .revision) try self.expression(put.expected.revision, depth + 1);
                },
                .insert => |insert| {
                    if (!atomic) return error.MutationOutsideAtomic;
                    try self.text(insert.target, true);
                    try self.expressions(insert.values, depth + 1);
                    if (insert.conflict_columns.len > a.max_arguments) return error.ProgramTooComplex;
                    for (insert.conflict_columns) |column| try self.text(column, true);
                },
                .append => |append| {
                    if (!atomic) return error.MutationOutsideAtomic;
                    try self.text(append.target, true);
                    try self.expressions(append.values, depth + 1);
                },
                .handoff => |handoff| {
                    if (!atomic) return error.MutationOutsideAtomic;
                    try self.text(handoff.queue, true);
                    try self.expression(handoff.request, depth + 1);
                    try self.expression(handoff.effect, depth + 1);
                },
                .respond => |response| {
                    if (response.status < 200 or response.status > 599) return error.InvalidProgramStatus;
                    try self.expression(response.request, depth + 1);
                    if (response.guard) |guard| try self.expression(guard, depth + 1);
                    switch (response.body) {
                        .empty => {},
                        .json, .location => |body| try self.expression(body, depth + 1),
                    }
                    if (response.cookies.len > 8) return error.ProgramTooComplex;
                    for (response.cookies, 0..) |cookie, i| {
                        try self.text(cookie.name, true);
                        for (cookie.name) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-') return error.InvalidProgramCookie;
                        for (response.cookies[0..i]) |prior| if (std.mem.eql(u8, prior.name, cookie.name)) return error.DuplicateProgramField;
                        if ((cookie.value == null) != (cookie.max_age == null)) return error.InvalidProgramCookie;
                        if (cookie.value) |value| try self.expression(value, depth + 1);
                        if (cookie.max_age) |age| try self.expression(age, depth + 1);
                    }
                },
                .respond_error => |response| {
                    try self.expression(response.request, depth + 1);
                    try self.text(response.failure, true);
                    try self.text(response.profile, true);
                },
            }
        }
    }
};

pub fn validate(program: a.Program) !void {
    if (program.nodes == 0 or program.nodes > a.max_nodes) return error.ProgramTooComplex;
    var self: Validator = .{ .nodes = program.nodes };
    try self.text(program.name, true);
    try self.text(program.queue, true);
    try self.text(program.input, true);
    if (program.deadline) |deadline| {
        try self.text(deadline, true);
        _ = try a.deadlineMilliseconds(deadline);
    }
    if (program.predicate) |predicate| try self.expression(predicate, 1);
    switch (program.body) {
        .instructions => |body| try self.block(body, 1, false),
        .page => |page| {
            try self.select(page.select, 1);
            try self.expression(page.request, 1);
            try self.text(page.profile, true);
        },
    }
    if (program.failure) |failure| {
        try self.text(failure.name, true);
        try self.block(failure.instructions, 1, false);
    }
    if (self.count != program.nodes) return error.InvalidProgramNode;
}

test "retained application programs preserve exact instructions and reject changed boundaries" {
    const t = std.testing;
    const source = "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET key = DIGEST('key'); BEGIN ATOMIC PUT INTO data KEY key VALUE ROW(1) IF ABSENT; END; END;";
    var parsed = try a.parse(t.allocator, source, null);
    defer parsed.deinit();
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const bytes = try encode(t.allocator, parsed.program, digest);
    defer t.allocator.free(bytes);
    var recovered = try decode(t.allocator, bytes);
    defer recovered.deinit();
    try t.expectEqualDeep(parsed.program, recovered.program);
    try t.expectEqualSlices(u8, &digest, &recovered.source_digest);
    var changed = recovered.program;
    changed.nodes += 1;
    try t.expectError(error.InvalidProgramNode, validate(changed));
    const atomic = changed.body.instructions[1];
    changed.body = .{ .instructions = atomic.value.atomic };
    try t.expectError(error.MutationOutsideAtomic, validate(changed));
    try t.expectError(error.MissingField, decode(t.allocator, "{}"));
    const duplicate = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(duplicate);
    // A foreign contract fingerprint is rejected before any instruction runs.
    const at = std.mem.indexOf(u8, duplicate, @tagName(p.Growth.current_definition)).?;
    duplicate[at] = if (duplicate[at] == 'a') 'b' else 'a';
    try t.expectError(error.InvalidEnumTag, decode(t.allocator, duplicate));
}

test "retained application trees reject aliases and cycles before serialization" {
    const t = std.testing;
    var parsed = try a.parse(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET n = 1 + 2; END;", null);
    defer parsed.deinit();
    const expression = parsed.program.body.instructions[0].value.let.value.expression;
    expression.value.binary.left = expression;
    try t.expectError(error.InvalidProgramNode, encode(t.allocator, parsed.program, @splat(3)));
}

test "retained application trees release partial ownership on allocation failure" {
    const Fixture = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var parsed = try a.parse(allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET n = 1 + 2; END;", null);
            defer parsed.deinit();
            const bytes = try encode(allocator, parsed.program, @splat(3));
            defer allocator.free(bytes);
            var retained = try decode(allocator, bytes);
            defer retained.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Fixture.run, .{});
}
