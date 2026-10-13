//! Process-local CPU capability selection, separate from plan/result identity.
const std = @import("std");
const builtin = @import("builtin");
pub const Implementation = enum { automatic, portable, avx2 };
var capability: std.atomic.Value(u8) = .init(0);
pub fn hasAvx2() bool {
    if (builtin.cpu.arch != .x86_64) return false;
    const observed = capability.load(.acquire);
    if (observed != 0) return observed == 2;
    const available = detect();
    capability.store(if (available) 2 else 1, .release);
    return available;
}
fn detect() bool {
    if (builtin.cpu.arch != .x86_64) return false;
    if (cpuid(0, 0)[0] < 7) return false;
    const features = cpuid(1, 0)[2];
    const required = (@as(u32, 1) << 26) | (@as(u32, 1) << 27) | (@as(u32, 1) << 28);
    if (features & required != required) return false;
    // Never execute XGETBV without both CPU XSAVE and OSXSAVE. XMM and YMM
    // state must be enabled by the OS, not merely advertised by CPUID.
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("xgetbv"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [index] "{ecx}" (@as(u32, 0)),
    );
    if (low & 6 != 6) return false;
    return cpuid(7, 0)[1] & (@as(u32, 1) << 5) != 0;
}
fn cpuid(leaf: u32, subleaf: u32) [4]u32 {
    var a: u32 = undefined;
    var b: u32 = undefined;
    var c: u32 = undefined;
    var d: u32 = undefined;
    asm volatile ("cpuid"
        : [a] "={eax}" (a),
          [b] "={ebx}" (b),
          [c] "={ecx}" (c),
          [d] "={edx}" (d),
        : [leaf] "{eax}" (leaf),
          [subleaf] "{ecx}" (subleaf),
    );
    return .{ a, b, c, d };
}
pub fn resolve(requested: Implementation) !Implementation {
    return switch (requested) {
        .portable => .portable,
        // Paired decoded-kernel measurements favor the portable loop on the
        // qualified host. Keep explicit guarded AVX2 for measured host policies.
        .automatic => .portable,
        .avx2 => if (hasAvx2()) .avx2 else error.UnsupportedVectorCpu,
    };
}
extern fn transit_fuze_compare_avx2(words: [*]align(1) const u64, literal: u64, kind: u8, operation: u8, output: [*]u8, len: usize) callconv(.c) void;
pub fn compare(words: []align(1) const u64, literal: u64, kind: u8, operation: u8, output: []u8) void {
    std.debug.assert(words.len == output.len);
    if (builtin.cpu.arch == .x86_64) transit_fuze_compare_avx2(words.ptr, literal, kind, operation, output.ptr, words.len) else unreachable;
}

test "AVX2 accepts unaligned words, preserves unsigned extremes and signed zero, and bounds tails" {
    if (!hasAvx2()) return error.SkipZigTest;
    const Case = struct { kind: u8, values: [5]u64, literal: u64 };
    const cases = [_]Case{
        .{ .kind = 0, .values = .{ @bitCast(@as(i64, std.math.minInt(i64))), @bitCast(@as(i64, -1)), 0, 1, std.math.maxInt(i64) }, .literal = 0 },
        .{ .kind = 1, .values = .{ 0, 1, std.math.maxInt(u64) - 1, std.math.maxInt(u64), std.math.maxInt(u64) }, .literal = std.math.maxInt(u64) - 1 },
        .{ .kind = 2, .values = .{ @bitCast(@as(f64, -1e300)), @bitCast(@as(f64, -0.0)), @bitCast(@as(f64, 0.0)), @bitCast(@as(f64, 0.25)), @bitCast(@as(f64, 1e300)) }, .literal = @bitCast(@as(f64, 0.0)) },
    };
    const orders = [_][5]std.math.Order{ .{ .lt, .lt, .eq, .gt, .gt }, .{ .lt, .lt, .eq, .gt, .gt }, .{ .lt, .eq, .eq, .gt, .gt } };
    for (cases, orders) |case, expected| {
        for (0..8) |offset| {
            var bytes: [8 * 13 + 7]u8 = undefined;
            const words = std.mem.bytesAsSlice(u64, bytes[offset..][0 .. 8 * 13]);
            for (words, 0..) |*word, i| word.* = case.values[i % 5];
            for (0..14) |len| {
                for (0..6) |op| {
                    var guarded: [15]u8 = @splat(0xa5);
                    compare(words[0..len], case.literal, case.kind, @intCast(op), guarded[1..][0..len]);
                    try std.testing.expectEqual(@as(u8, 0xa5), guarded[0]);
                    try std.testing.expectEqual(@as(u8, 0xa5), guarded[len + 1]);
                    for (guarded[1..][0..len], 0..) |actual, i| {
                        const order = expected[i % 5];
                        const answer = switch (op) {
                            0 => order == .eq,
                            1 => order != .eq,
                            2 => order == .lt,
                            3 => order != .gt,
                            4 => order == .gt,
                            5 => order != .lt,
                            else => unreachable,
                        };
                        try std.testing.expectEqual(@intFromBool(answer), actual);
                    }
                }
            }
        }
    }
}
