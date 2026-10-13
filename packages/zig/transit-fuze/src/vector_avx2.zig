//! Isolated AVX2 object. Baseline code may call these only after CPU/OS checks.
//! Inputs contain initialized fixed-width words; the caller merges five states.
const std = @import("std");
export fn transit_fuze_compare_avx2(words: [*]align(1) const u64, literal: u64, kind: u8, operation: u8, output: [*]u8, len: usize) callconv(.c) void {
    switch (kind) {
        0 => dispatch(i64, words, literal, operation, output, len),
        1 => dispatch(u64, words, literal, operation, output, len),
        2 => dispatch(f64, words, literal, operation, output, len),
        else => unreachable,
    }
}
fn dispatch(comptime T: type, words: [*]align(1) const u64, literal: u64, operation: u8, output: [*]u8, len: usize) void {
    switch (operation) {
        inline 0...5 => |op| compare(T, op, words, literal, output, len),
        else => unreachable,
    }
}
fn compare(comptime T: type, comptime op: u8, words: [*]align(1) const u64, literal: u64, output: [*]u8, len: usize) void {
    const scalar: T = @bitCast(literal);
    const bound: @Vector(4, T) = @splat(scalar);
    var i: usize = 0;
    while (len - i >= 4) : (i += 4) {
        const raw: @Vector(4, u64) = words[i..][0..4].*;
        const values: @Vector(4, T) = @bitCast(raw);
        const matches = switch (op) {
            0 => values == bound,
            1 => values != bound,
            2 => values < bound,
            3 => values <= bound,
            4 => values > bound,
            5 => values >= bound,
            else => unreachable,
        };
        const result: [4]u8 = @select(u8, matches, @as(@Vector(4, u8), @splat(1)), @as(@Vector(4, u8), @splat(0)));
        @memcpy(output[i..][0..4], &result);
    }
    while (i < len) : (i += 1) {
        const value: T = @bitCast(words[i]);
        output[i] = @intFromBool(switch (op) {
            0 => value == scalar,
            1 => value != scalar,
            2 => value < scalar,
            3 => value <= scalar,
            4 => value > scalar,
            5 => value >= scalar,
            else => unreachable,
        });
    }
}
