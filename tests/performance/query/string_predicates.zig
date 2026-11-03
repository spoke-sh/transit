//! Matched raw/prepared physical-page work. Python checks every outcome digest.
const std = @import("std");
const f = @import("transit_fuze");
const Probe = @import("transit_memory").AllocationProbe;
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.Usage;
    const prepared_mode = std.mem.eql(u8, args[1], "prepared");
    if (!prepared_mode and !std.mem.eql(u8, args[1], "raw")) return error.Usage;
    const collation = std.meta.stringToEnum(f.TableSchema.Collation, args[2]) orelse return error.Usage;
    const encoding = std.meta.stringToEnum(f.TableSchema.Encoding, args[3]) orelse return error.Usage;
    const column: f.TableSchema.Column = .{ .id = 1, .name = "text", .type = .utf8, .collation = collation, .encoding = encoding };
    const schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{column} };
    const a = init.arena.allocator();
    const rows = 4096;
    const repeats = 30;
    const constructions = 100;
    const budget_bytes = 2 * 1024 * 1024;
    const cells = try a.alloc(f.Types.Values.Cell, rows);
    for (cells, 0..) |*cell, i| cell.* = .{ .value = .{ .atom = .{ .bytes = try std.fmt.allocPrint(a, "Repeated Common Prefix {d:0>3} Mixed Case Payload", .{i % 256}) } } };
    const literal = "Repeated Common Prefix 128 Mixed Case Payload";
    const page = try f.PhysicalCodecs.encodeColumnPage(a, column, cells, try a.alloc(u8, 1024 * 1024));
    var raw: [6]f.ColumnPredicate.Predicate = undefined;
    var instructions: [11]f.ColumnPredicate.Program.Instruction = undefined;
    for ([_]@TypeOf(raw[0].compare.op){ .eq, .ne, .lt, .le, .gt, .ge }, 0..) |op, i| {
        raw[i] = .{ .compare = .{ .op = op, .value = .{ .bytes = literal } } };
        const position = if (i == 0) 0 else 2 * i - 1;
        instructions[position] = .{ .atom = .{ .column = 0, .predicate = raw[i] } };
        if (i > 0) instructions[position + 1] = .conjunction;
    }
    const program: f.ColumnPredicate.Program = .{ .instructions = &instructions };
    var reserve: f.MemoryBudget = .{ .parent = init.gpa, .limit = budget_bytes };
    // Immediately below both arenas: even refused/fallback attempts are visible.
    var probe: Probe = .{ .parent = reserve.allocator() };
    const cold_start = std.Io.Clock.awake.now(init.io);
    for (0..constructions) |_| {
        if (prepared_mode) {
            var owner = try f.ColumnPredicate.PreparedProgram.init(probe.allocator(), schema, program);
            owner.deinit();
        } else try program.validate(schema);
    }
    const cold_ns = cold_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const cold_allocations = probe.counts.alloc_successes;
    const cold_allocated_bytes = probe.counts.acquired_bytes;
    var owner: ?f.ColumnPredicate.PreparedProgram = if (prepared_mode) try .init(probe.allocator(), schema, program) else null;
    defer if (owner) |*value| value.deinit();
    const prepared_bytes = reserve.used;
    var prepared: [6]f.ColumnPredicate.PreparedPredicate = undefined;
    if (owner) |value| for (&prepared, 0..) |*atom, i| {
        atom.* = value.instructions[if (i == 0) 0 else 2 * i - 1].atom.predicate;
    };
    var workspace = std.heap.ArenaAllocator.init(probe.allocator());
    defer workspace.deinit();
    var digest: u64 = 0;
    var visits: usize = 0;
    var elapsed: i96 = 0;
    var cpu_elapsed: i96 = 0;
    var outcomes_sha256: [32]u8 = undefined;
    var outcome_bytes: [6 * rows]u8 = undefined;
    for (0..repeats + 1) |iteration| {
        _ = workspace.reset(.retain_capacity);
        if (iteration == 1) probe.begin(true);
        const cpu_start = std.Io.Clock.cpu_process.now(init.io);
        const start = std.Io.Clock.awake.now(init.io);
        const result = if (prepared_mode)
            try f.PhysicalCodecs.evaluatePreparedColumnPredicates(workspace.allocator(), workspace.allocator(), column, page, &prepared)
        else
            try f.PhysicalCodecs.evaluateColumnPredicates(workspace.allocator(), workspace.allocator(), column, page, &raw);
        const duration = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        const cpu_duration = cpu_start.durationTo(std.Io.Clock.cpu_process.now(init.io)).toNanoseconds();
        if (result.outcomes.len != outcome_bytes.len) return error.IncompleteOutcomes;
        var checksum: u64 = 0;
        for (result.outcomes, 0..) |outcome, i| {
            outcome_bytes[i] = switch (outcome) {
                .yes => 'Y',
                .no => 'N',
                .unknown => 'U',
                .type_error => 'T',
                .conflict => 'C',
            };
            if (outcome == .yes) checksum +%= i + 1;
        }
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&outcome_bytes, &hash, .{});
        if (iteration == 0) outcomes_sha256 = hash else if (!std.mem.eql(u8, &outcomes_sha256, &hash)) return error.InconsistentOutcomes;
        if (iteration > 0) {
            elapsed += duration;
            cpu_elapsed += cpu_duration;
            digest +%= checksum;
            visits += result.evaluated_values;
        }
    }
    try probe.verify();
    const warm = probe.counts;
    // Validate cleanup separately from the sealed warm interval.
    workspace.deinit();
    workspace = std.heap.ArenaAllocator.init(probe.allocator());
    if (owner) |*value| value.deinit();
    owner = null;
    if (reserve.used != 0 or probe.live_bytes != 0) return error.LeakedWorkspace;
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{
        .mode = args[1],
        .collation = collation,
        .encoding = encoding,
        .rows = rows,
        .repeats = repeats,
        .constructions = constructions,
        .cold_ns = cold_ns,
        .cold_allocations = cold_allocations,
        .cold_allocated_bytes = cold_allocated_bytes,
        .elapsed_ns = elapsed,
        .cpu_ns = cpu_elapsed,
        .checksum = digest,
        .outcomes_sha256 = std.fmt.bytesToHex(&outcomes_sha256, .lower),
        .visits = visits,
        .encoded_bytes = page.len,
        .prepared_bytes = prepared_bytes,
        .budget_bytes = budget_bytes,
        .peak_bytes = reserve.peak,
        .end_live_bytes = reserve.used,
        .warm_allocations = warm.alloc_attempts,
        .warm_resizes = warm.growing_resize_attempts,
        .warm_remaps = warm.remap_attempts,
        .warm_allocated_bytes = warm.acquired_bytes,
        .build_mode = @tagName(@import("builtin").mode),
        .compiler = @import("builtin").zig_version_string,
        .cpu = @import("builtin").cpu.model.name,
    }, .{}, &output.interface);
    try output.interface.writeByte('\n');
    try output.interface.flush();
}
