//! Runtime validation of Stream outcomes and finite pages. These checks bind a
//! server observation to its request; they do not grant rights or verify a MAC
//! using the server's private key. Missing completion stays incomplete.
const std = @import("std");
const c = @import("root.zig");
const stream = c.DirectStream;
const q = c.protocol.StreamQueue;

fn samePartition(left: q.Partition, right: q.Partition) !void {
    try left.validate();
    try right.validate();
    if (!std.meta.eql(left.interpretation.object, right.interpretation.object) or left.partition != right.partition) return error.InvalidStreamResponse;
}

pub fn requireReceipt(work: c.DirectStreamMutation.Request, result: stream.Receipt) !void {
    if (result == .closed) return result.closed.requireStream(work);
    const expected: std.meta.Tag(stream.Receipt) = switch (work) {
        .append => .append,
        .assign => .assign,
        .consume => .consume,
        .release => .release,
        .offset => .offset,
    };
    if (expected != std.meta.activeTag(result)) return error.InvalidStreamResponse;
    switch (result) {
        .closed => unreachable,
        .append => |value| try value.requireAppend(work.append),
        .assign => |value| try value.requireAssignment(work.assign),
        .consume => |value| try value.requireRequest(work.consume),
        .release => |value| try value.requireRelease(work.release),
        .offset => |value| try value.requireCommit(work.offset.commit),
    }
}

pub fn validate(allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, request: stream.Request, result: stream.Result) !void {
    try request.validate(connection.principal, connection.scope);
    try connection.object(request.target().interpretation.object);
    if (result == .recovering) {
        const progress = result.recovering;
        try progress.position.validate();
        if (progress.complete or progress.examined == 0 or progress.examined > 256 or progress.position.next_lsn == 0) return error.InvalidStreamResponse;
        return;
    }
    if (result == .timed_out) {
        if (request != .wait) return error.InvalidStreamResponse;
        const cut = result.timed_out;
        try cut.validate();
        const input = request.wait.consume;
        try input.target.requireSame(cut.target);
        if (input.from < cut.retained_from or
            (if (input.until) |until| until <= cut.next else input.from < cut.next)) return error.InvalidStreamResponse;
        return;
    }
    const expected: std.meta.Tag(stream.Result) = switch (request) {
        .mutate, .operation, .wait, .cancel => .operation,
        .observe => .cut,
        .group => .group,
        .cursor => .cursor,
        .page => .page,
    };
    if (std.meta.activeTag(result) != expected) return error.InvalidStreamResponse;
    switch (result) {
        .recovering, .timed_out => unreachable,
        .operation => |maybe| if (maybe) |value| {
            try requireReceipt(switch (request) {
                .operation, .cancel => |work| work,
                .wait => |input| .{ .consume = input.consume },
                .mutate => |input| input.work,
                else => unreachable,
            }, value);
        } else if (request != .operation) return error.InvalidStreamResponse,
        .cut => |value| {
            try value.validate();
            try samePartition(value.target, request.observe);
            if (value.target.interpretation.revision < request.observe.interpretation.revision) return error.InvalidStreamResponse;
        },
        .group => |maybe| if (maybe) |value| {
            try value.validate();
            try samePartition(value.target, request.group.target);
            if (value.group.id != request.group.id) return error.InvalidStreamResponse;
        },
        .cursor => |value| {
            try value.validate();
            try samePartition(value.coverage.cut.target, request.cursor.target);
            if (!std.meta.eql(value.read, request.cursor.read) or value.coverage.through != value.coverage.from or value.coverage.rows != 0) return error.InvalidStreamResponse;
        },
        .page => |page| {
            const input = request.page;
            const prior = input.cursor.coverage;
            const next = page.cursor.coverage;
            try page.cursor.validate();
            if (!std.meta.eql(page.cursor.read, input.cursor.read) or !std.meta.eql(next.cut, prior.cut) or
                next.from != prior.from or next.until != prior.until or next.through < prior.through or
                next.through - prior.through != page.examined or page.examined > input.limits.scanned_rows or
                page.rows.len > input.limits.rows or page.encoded_bytes > input.limits.encoded_bytes or
                (!next.complete and page.examined == 0) or
                next.rows != (std.math.add(u64, prior.rows, page.rows.len) catch return error.InvalidStreamResponse)) return error.InvalidStreamResponse;
            try c.DirectLogProtocol.validateMetadata(allocator, connection, page.source);
            const declared = page.source.declaration.stored;
            if (declared.retired or page.source.declaration.kind() != .stream or !std.meta.eql(declared.declaration.interpretation, next.cut.target.interpretation)) return error.InvalidStreamResponse;
            _ = try page.source.declaration.partition(next.cut.target.partition);
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
                try row.operation.validate();
                if (!std.meta.eql(row.operation.scope, connection.scope) or row.offset < prior.through or row.offset >= next.through or
                    (previous != null and row.offset <= previous.?) or
                    (row.tombstone and declared.declaration.configuration.policy.stream.compact_key_column == null)) return error.InvalidStreamResponse;
                const bytes = try row.encoded.decode(scratch.allocator(), @min(c.fuze.TableRow.max_bytes, input.limits.encoded_bytes));
                const decoded = try c.fuze.TableRow.decodeInto(scratch.allocator(), schema.schema, bytes);
                if (!std.meta.eql(decoded.identity, c.fuze.TableRow.Identity{ .origin = row.operation.principal + 1, .operation = row.operation.operation, .ordinal = row.ordinal })) return error.InvalidStreamResponse;
                byte_count = std.math.add(usize, byte_count, bytes.len + c.storage.LogBatch.row_header_bytes) catch return error.InvalidStreamResponse;
                if (byte_count > page.encoded_bytes) return error.InvalidStreamResponse;
                previous = row.offset;
            }
            if (byte_count != page.encoded_bytes) return error.InvalidStreamResponse;
        },
    }
}
