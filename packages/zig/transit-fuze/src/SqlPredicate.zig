//! Owned postfix syntax with compact literal spans. The statement byte budget
//! bounds the literal pool; each instruction does not reserve a maximum string.
const sql = @import("Sql.zig");
const m = @import("Unified.zig");
const Self = @This();
pub const max_instructions = m.PredicateProgram.max_instructions;
pub const Span = struct { start: u16, len: u16 };
pub const Literal = union(enum) { null, int64: i64, uint64: u64, float64: f64, boolean: bool, utf8: Span, binary: Span };
pub const Atom = union(enum) {
    all,
    state: @FieldType(sql.PredicateAtom, "state"),
    compare: struct { column: sql.Column, op: m.Plan.Comparison, literal: Literal },
};
pub const Instruction = union(enum) { atom: Atom, negate, conjunction, disjunction };
instructions: [max_instructions]Instruction = @splat(.negate),
count: u8 = 0,
bytes: [sql.max_statement_bytes]u8 = @splat(0),
byte_count: u16 = 0,

pub fn append(self: *Self, instruction: Instruction) !void {
    if (self.count >= max_instructions) return error.PredicateTooComplex;
    self.instructions[self.count] = instruction;
    self.count += 1;
}
pub fn appendAtom(self: *Self, atom: sql.PredicateAtom) !void {
    if (self.byte_count > self.bytes.len) return error.InvalidPredicateProgram;
    const compact: Atom = switch (atom) {
        .all => .all,
        .state => |state| .{ .state = state },
        .compare => |comparison| .{ .compare = .{
            .column = comparison.column,
            .op = comparison.op,
            .literal = switch (comparison.literal) {
                .utf8, .binary => |*value| blk: {
                    if (value.len > value.bytes.len) return error.LiteralTooLarge;
                    if (value.len > self.bytes.len - self.byte_count) return error.StatementTooLarge;
                    const span: Span = .{ .start = self.byte_count, .len = value.len };
                    @memcpy(self.bytes[self.byte_count..][0..value.len], value.slice());
                    self.byte_count += value.len;
                    break :blk if (comparison.literal == .utf8) .{ .utf8 = span } else .{ .binary = span };
                },
                inline else => |value, tag| @unionInit(Literal, @tagName(tag), value),
            },
        } },
    };
    try self.append(.{ .atom = compact });
}
/// Returned atom owns its literal bytes; it never points into this program.
pub fn expand(self: *const Self, atom: Atom) !sql.PredicateAtom {
    return switch (atom) {
        .all => .all,
        .state => |state| .{ .state = state },
        .compare => |comparison| .{ .compare = .{
            .column = comparison.column,
            .op = comparison.op,
            .literal = switch (comparison.literal) {
                .utf8, .binary => |span| blk: {
                    try self.validateSpan(span);
                    var value: sql.Text = .{ .len = span.len };
                    @memcpy(value.bytes[0..span.len], self.bytes[span.start..][0..span.len]);
                    break :blk if (comparison.literal == .utf8) .{ .utf8 = value } else .{ .binary = value };
                },
                inline else => |value, tag| @unionInit(sql.Literal, @tagName(tag), value),
            },
        } },
    };
}
fn validateSpan(self: *const Self, span: Span) !void {
    if (self.byte_count > self.bytes.len or span.start > self.byte_count or
        span.len > self.byte_count - span.start or span.len > sql.max_literal_bytes)
        return error.InvalidPredicateProgram;
}
pub fn validate(self: *const Self) !void {
    if (self.count == 0 or self.count > max_instructions or self.byte_count > self.bytes.len) return error.InvalidPredicateProgram;
    var depth: usize = 0;
    for (self.instructions[0..self.count]) |instruction| switch (instruction) {
        .atom => |atom| {
            if (atom == .compare) switch (atom.compare.literal) {
                .utf8, .binary => |span| try self.validateSpan(span),
                else => {},
            };
            depth += 1;
        },
        .negate => if (depth == 0) return error.InvalidPredicateProgram,
        .conjunction, .disjunction => {
            if (depth < 2) return error.InvalidPredicateProgram;
            depth -= 1;
        },
    };
    if (depth != 1) return error.InvalidPredicateProgram;
}
