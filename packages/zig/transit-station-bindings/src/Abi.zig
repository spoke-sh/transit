//! Station v1 C exports. A handle owns the same GenServer as native Zig callers.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
pub const actions = @import("Actions.zig");
pub const host = @import("HostProtocol.zig");
pub const growing = @import("GrowingAbi.zig");
pub const document_bridge = @import("DocumentBridge.zig");
pub const document = @import("DocumentCodec.zig");
pub const unified_query = @import("QueryCodec.zig");
pub const logical_codec = @import("LogicalCodec.zig");
pub const query_client = @import("QueryAbi.zig");
pub const catalog_client = @import("CatalogAbi.zig");
pub const grpc = @import("GrpcCodec.zig");
pub const http = @import("HttpCodec.zig");
pub const version: u32 = 1;
pub const minimum_stack_bytes: usize = 8 * 1024 * 1024;
pub const Status = enum(u32) { ok = 0, invalid_argument = 1, out_of_memory = 2, rejected = 3, denied = 4, conflict = 5, uncertain = 6, unavailable = 7, invalid_response = 8, busy = 9, incompatible_version = 10, stale_activation = 11, blocked = 12, not_ready = 13, budget_exceeded = 14 };
pub const Buffer = opaque {};
const allocator = std.heap.page_allocator;
const BufferImpl = struct { bytes: []u8 };
fn cast(comptime T: type, pointer: anytype) *T {
    return @ptrCast(@alignCast(@constCast(pointer)));
}
pub fn output(value: anytype, out: *?*Buffer) !void {
    return outputWithAllocator(allocator, value, out);
}
/// Copy a domain-validated JSON response into an independently owned ABI buffer.
pub fn outputEncoded(bytes: []const u8, out: *?*Buffer) !void {
    const buffer = try allocator.create(BufferImpl);
    errdefer allocator.destroy(buffer);
    buffer.bytes = try allocator.dupe(u8, bytes);
    out.* = @ptrCast(buffer);
}
pub fn outputWithAllocator(alloc: std.mem.Allocator, value: anytype, out: *?*Buffer) !void {
    const buffer = try alloc.create(BufferImpl);
    errdefer alloc.destroy(buffer);
    buffer.bytes = try std.json.Stringify.valueAlloc(alloc, value, .{});
    out.* = @ptrCast(buffer);
}
pub fn destroyBufferWithAllocator(alloc: std.mem.Allocator, pointer: ?*Buffer) void {
    const buffer = cast(BufferImpl, pointer orelse return);
    alloc.free(buffer.bytes);
    alloc.destroy(buffer);
}
pub fn status(err: anyerror) Status {
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        error.AccessDenied => .denied,
        error.Rejected => .rejected,
        error.Conflict => .conflict,
        error.StaleActivation => .stale_activation,
        error.ProcessExpired, error.ProcessTerminated => .rejected,
        error.BlockedProcess => .blocked,
        error.NoPreparedTurn, error.NoPendingOperation => .not_ready,
        error.PendingOperation => .busy,
        error.InvalidAuthorityResponse => .invalid_response,
        error.MutationBudgetExceeded, error.OutputBudgetExceeded, error.StateCapacityExceeded, error.ChildBudgetExceeded, error.QueryBudgetExceeded, error.WriteFailed => .budget_exceeded,
        else => .invalid_argument,
    };
}
pub fn failure(err: anyerror, out: *?*Buffer) Status {
    output(.{ .err = @errorName(err) }, out) catch {};
    return status(err);
}
pub const Api = struct {
    pub const station_diagnostic_validate = @import("client_abi").Api.transit_diagnostic_validate;
    pub const station_logical_codec = logical_codec.codec;
    pub const station_catalog_create = catalog_client.create;
    pub const station_catalog_destroy = catalog_client.destroy;
    pub const station_catalog_call = catalog_client.call;
    pub const station_unified_query_create = query_client.create;
    pub const station_unified_query_destroy = query_client.destroy;
    pub const station_unified_query_call = query_client.call;
    pub const station_unified_query_codec = unified_query.codec;
    pub const station_growing_document_read = growing.documentRead;
    pub const station_document_codec = document.codec;
    pub const station_grpc_codec = grpc.codec;
    pub const station_growing_grpc_read = growing.grpcRead;
    pub const station_http_codec = http.codec;
    pub const station_growing_http_read = growing.httpRead;
    pub const station_growing_capabilities = growing.capabilities;
    pub const station_growing_create = growing.create;
    pub const station_growing_destroy = growing.destroy;
    pub const station_growing_prepare = growing.prepare;
    pub const station_growing_dispatch = growing.dispatch;
    pub const station_growing_confirmation = growing.confirmation;
    pub const station_growing_apply = growing.apply;
    pub const station_growing_finish = growing.finish;
    pub const station_growing_finish_result = growing.finishResult;
    pub const station_growing_discard = growing.discard;
    pub const station_growing_pending = growing.pending;
    /// Compare the complete contract definition before constructing handles.
    pub fn station_abi_definition_matches(definition: [*]const u8, len: usize) callconv(.c) u32 {
        const expected = @tagName(p.Growth.current_definition);
        return @intFromBool(len == expected.len and std.mem.eql(u8, definition[0..len], expected));
    }
    pub fn station_abi_version() callconv(.c) u32 {
        return version;
    }
    /// Shared JSON access for C/C++ hosts without another parser dependency.
    /// format 0 returns JSON; format 1 returns the selected string's raw bytes.
    pub fn station_json_extract(json: [*]const u8, len: usize, path: [*]const u8, path_len: usize, format: u32, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const bytes = @import("client_abi").extractJson(allocator, json[0..len], path[0..path_len], format) catch |err| {
            return if (err == error.InvalidArgument) .invalid_argument else failure(err, out);
        };
        const result = allocator.create(BufferImpl) catch {
            allocator.free(bytes);
            return .out_of_memory;
        };
        result.* = .{ .bytes = bytes };
        out.* = @ptrCast(result);
        return .ok;
    }
    pub fn station_frame_encode(kind: u32, correlation: u64, payload: [*]const u8, len: usize, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const frame: s.Frame = .{ .kind = std.enums.fromInt(s.Frame.Kind, kind) orelse return .invalid_argument, .correlation = correlation, .payload = p.Value.init(payload[0..len]) catch |err| return failure(err, out) };
        const value = frame.encode() catch |err| return failure(err, out);
        output(value, out) catch |err| return status(err);
        return .ok;
    }
    pub fn station_buffer_data(pointer: *const Buffer) callconv(.c) [*]const u8 {
        return cast(BufferImpl, pointer).bytes.ptr;
    }
    /// Decodes owned segment bytes; it performs no resource read or authority
    /// check. Obtaining those bytes requires the scoped completed-result API.
    pub fn station_growing_arrow_cell(bytes: [*]const u8, len: usize, row: u32, column: u32, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const result = actions.arrowCellBounded(arena.allocator(), bytes[0..len], row, column, s.Query.records.segment_bytes) catch |err| return failure(err, out);
        output(result, out) catch |err| return status(err);
        return .ok;
    }
    pub fn station_buffer_size(pointer: *const Buffer) callconv(.c) usize {
        return cast(BufferImpl, pointer).bytes.len;
    }
    pub fn station_buffer_destroy(pointer: ?*Buffer) callconv(.c) void {
        destroyBufferWithAllocator(allocator, pointer);
    }
};

test {
    _ = host;
    _ = growing;
    _ = http;
    _ = grpc;
    _ = document;
    _ = document_bridge;
    _ = unified_query;
    _ = catalog_client;
    _ = query_client;
}
