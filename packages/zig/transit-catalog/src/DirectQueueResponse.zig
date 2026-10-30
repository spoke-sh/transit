//! Validate original operation attribution and owned claim-page observations.
//! These shape/binding checks grant neither current rights nor a live lease.
const std = @import("std");
const c = @import("root.zig");
const queue = c.DirectQueue;

pub fn requireReceipt(work: c.DirectQueueMutation.Request, result: queue.Receipt) !void {
    if (!std.mem.eql(u8, @tagName(work), @tagName(result))) return error.InvalidQueueResponse;
    switch (result) {
        .enqueue => |value| try value.requireAppend(work.enqueue),
        .claim => |value| try value.requireClaim(work.claim),
        .settle => |value| try value.requireSettlement(work.settle),
    }
}
pub fn validate(allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, request: queue.Request, result: queue.Result) !void {
    try request.validate(connection.principal, connection.scope);
    try connection.object(request.target().interpretation.object);
    if (result == .recovering) {
        const progress = result.recovering;
        try progress.position.validate();
        if (progress.complete or progress.examined == 0 or progress.examined > 256 or progress.position.next_lsn == 0) return error.InvalidQueueResponse;
        return;
    }
    const expected: std.meta.Tag(queue.Result) = switch (request) {
        .mutate, .operation => .operation,
        .observe => .cut,
        .page => .page,
    };
    if (std.meta.activeTag(result) != expected) return error.InvalidQueueResponse;
    switch (result) {
        .recovering => unreachable,
        .operation => |maybe| if (maybe) |value| {
            try requireReceipt(if (request == .operation) request.operation else request.mutate.work, value);
        } else if (request != .operation) return error.InvalidQueueResponse,
        .cut => |value| {
            try value.validate();
            if (value.retained_from != 0 or !std.meta.eql(value.target.interpretation.object, request.observe.interpretation.object) or
                value.target.partition != request.observe.partition or value.target.interpretation.revision < request.observe.interpretation.revision or
                (value.target.interpretation.revision == request.observe.interpretation.revision and !std.meta.eql(value.target, request.observe))) return error.InvalidQueueResponse;
        },
        .page => |page| {
            const input = request.page;
            try page.cursor.requireReceipt(input.cursor.receipt);
            try page.basis.requireReceipt(input.cursor.receipt);
            if (page.cursor.next < input.cursor.next or page.cursor.next - input.cursor.next != page.rows.len or
                page.rows.len > input.limits.rows or page.encoded_bytes > input.limits.encoded_bytes or
                (!page.cursor.complete() and page.rows.len == 0)) return error.InvalidQueueResponse;
            try c.DirectLogProtocol.validateMetadata(allocator, connection, page.source);
            const declared = page.source.declaration.stored;
            const original = input.cursor.receipt.claim.target;
            if (declared.retired or page.source.declaration.kind() != .queue or !std.meta.eql(declared.declaration.interpretation, original.interpretation) or
                try page.source.declaration.partition(original.partition) != input.cursor.receipt.accepted.partition) return error.InvalidQueueResponse;
            const schema_bytes = try page.source.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
            defer allocator.free(schema_bytes);
            var schema = try c.fuze.TableSchema.decode(allocator, schema_bytes);
            defer schema.deinit();
            var scratch: std.heap.ArenaAllocator = .init(allocator);
            defer scratch.deinit();
            var previous: ?u64 = null;
            var byte_count: usize = 0;
            for (page.rows) |row| {
                _ = scratch.reset(.retain_capacity);
                try row.lease.requireBasis(page.basis, input.cursor.receipt);
                try row.operation.validate();
                if (!std.meta.eql(row.operation.scope, connection.scope) or (previous != null and row.lease.original.offset <= previous.?)) return error.InvalidQueueResponse;
                const bytes = try row.encoded.decode(scratch.allocator(), @min(c.fuze.TableRow.max_bytes, input.limits.encoded_bytes));
                const decoded = try c.fuze.TableRow.decodeInto(scratch.allocator(), schema.schema, bytes);
                if (!std.meta.eql(decoded.identity, c.fuze.TableRow.Identity{ .origin = row.operation.principal + 1, .operation = row.operation.operation, .ordinal = row.ordinal })) return error.InvalidQueueResponse;
                byte_count = std.math.add(usize, byte_count, bytes.len) catch return error.InvalidQueueResponse;
                if (byte_count > page.encoded_bytes) return error.InvalidQueueResponse;
                previous = row.lease.original.offset;
            }
            if (byte_count != page.encoded_bytes) return error.InvalidQueueResponse;
        },
    }
}
