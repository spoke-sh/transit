//! Line-framed transport for runtimes using an isolated native host process.
const std = @import("std");
const abi = @import("Abi.zig");
const p = @import("transit_station").protocol;
const raw = @import("client_abi").host;
pub const version = 1;
pub const catalog_line_bytes = abi.catalog_client.bridge.max_input_bytes + 16384;
pub fn lineBytes(catalog: bool) usize {
    return if (catalog) catalog_line_bytes else raw.max_line_bytes;
}
/// Grow only for the current request. An idle host retains the small Reader
/// buffer, not the catalog profile's maximum complete-message allocation.
pub fn readLine(allocator: std.mem.Allocator, reader: *std.Io.Reader, maximum: usize) !?[]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    _ = try reader.streamDelimiterLimit(&output.writer, '\n', .limited(maximum));
    _ = reader.takeByte() catch |err| switch (err) {
        error.EndOfStream => if (output.written().len == 0) return null else return error.TruncatedHostLine,
        else => return err,
    };
    return try output.toOwnedSlice();
}
pub const Config = struct {
    url: ?[]const u8 = null,
    local_codec: bool = false,
    seed_file: ?[]const u8 = null,
    growing_server: ?abi.growing.Config = null,
    query_client: ?abi.query_client.Config = null,
    mutation_client: ?abi.mutation_client.Config = null,
    catalog_client: ?abi.catalog_client.Config = null,
    timeout_ms: u32 = 5000,
    pub fn validateProfiles(self: Config) !void {
        var profiles: u8 = 0;
        inline for (.{ self.growing_server != null, self.query_client != null, self.mutation_client != null, self.catalog_client != null }) |present| if (present) {
            profiles += 1;
        };
        if (self.local_codec) {
            if (self.url != null or self.seed_file != null or profiles != 0) return error.ConflictingHostProfiles;
        } else if (self.url == null) return error.MissingAuthorityEndpoint;
        if (profiles > 1) return error.ConflictingHostProfiles;
    }
};
pub const Request = union(enum) {
    pub const json_schema_text_bounds = .{ .catalog = abi.catalog_client.bridge.max_input_bytes };
    pub const json_schema_sequence_bounds = .{ .catalog = 65536 };
    hello: void,
    shutdown: void,
    growing_capabilities: void,
    growing_document_read: abi.document_bridge.ReadAction,
    document_codec: abi.document.Action,
    unified_query_codec: abi.unified_query.Action,
    logical_codec: abi.logical_codec.Action,
    unified_query: abi.query_client.bridge.Action,
    table_mutation: abi.mutation_client.bridge.Action,
    catalog: abi.catalog_client.bridge.Action,
    grpc_codec: abi.grpc.Action,
    growing_grpc_read: abi.grpc.ReadAction,
    http_codec: abi.http.Action,
    growing_http_read: abi.http.ReadAction,
    growing_prepare: u64,
    growing_dispatch: void,
    growing_confirmation: void,
    growing_apply: struct { scope: u64, action: abi.growing.actions.Action },
    growing_finish: struct { scope: u64, failed: bool },
    growing_finish_result: struct { scope: u64, failed: bool },
    growing_discard: u64,
    growing_pending: void,
    growing_arrow_cell: struct { ipc: []const u8, row: u32, column: u32 },
    frame: struct { kind: u32, correlation: []const u8, payload: p.Value },
    prepare: raw.Prepare,
    call: []const u8,
    metadata: []const u8,
    client_capabilities: void,
};

test "host framing grows per request and rejects unterminated or oversized work" {
    const t = std.testing;
    var reader: std.Io.Reader = .fixed("123\n\n4567\n");
    const first = (try readLine(t.allocator, &reader, 4)).?;
    defer t.allocator.free(first);
    try t.expectEqualStrings("123", first);
    const empty = (try readLine(t.allocator, &reader, 4)).?;
    defer t.allocator.free(empty);
    try t.expectEqual(@as(usize, 0), empty.len);
    try t.expectError(error.StreamTooLong, readLine(t.allocator, &reader, 4));
    var partial: std.Io.Reader = .fixed("partial");
    try t.expectError(error.TruncatedHostLine, readLine(t.allocator, &partial, 100));
    var ended: std.Io.Reader = .fixed("");
    try t.expect((try readLine(t.allocator, &ended, 100)) == null);
    try t.expectEqual(raw.max_line_bytes, lineBytes(false));
    try t.expect(lineBytes(true) > raw.max_line_bytes);
}
