//! Uses the public SQL statement/result owner. A failed/uncertain write is never
//! resubmitted under a fresh operation identity; callers start a new login.
const std = @import("std");
const sql = @import("transit_sql_client");
const Self = @This();
a: std.mem.Allocator,
client: sql.Client,
control: sql.Client,
executor: sql.Executor,
pub fn init(a: std.mem.Allocator, io: std.Io, config: sql.Client.Config) !*Self {
    const self = try a.create(Self);
    self.a = a;
    self.client = try sql.Client.init(std.heap.page_allocator, io, config);
    errdefer self.client.deinit();
    const raw = if (config.password_file) |path| try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(4096)) else null;
    defer if (raw) |bytes| std.crypto.secureZero(u8, bytes);
    const password = if (raw) |bytes| std.mem.trimEnd(u8, bytes, "\r\n") else null;
    try self.client.open(config, password);
    self.control = try self.client.observationClient(config);
    self.control.instance = self.client.instance;
    self.control.session = self.client.session;
    self.control.account = self.client.account;
    self.executor = .{ .client = &self.client, .control = &self.control, .config = config };
    return self;
}
pub fn deinit(self: *Self) void {
    if (self.control.call(.close)) |response| response.deinit() else |_| {}
    self.control.deinit();
    self.client.deinit();
    self.a.destroy(self);
}
pub fn command(self: *Self, statement: []const u8) !u64 {
    const result = try self.executor.execute(statement, null, .{});
    defer result.deinit();
    if (result.value != .command) return error.BrowserStateUnavailable;
    const completed = result.value.command;
    if (completed.outcome != .applied and completed.outcome != .unchanged) return error.BrowserStateUnavailable;
    return (completed.counts orelse return error.BrowserStateUnavailable).changed;
}
/// Finite public snapshots require complete rows and a fresh final disclosure
/// check. Integers remain decimal strings rather than losing browser precision.
pub fn rows(self: *Self, statement: []const u8, limit: usize) !std.json.Value {
    const outcome = try self.executor.read(statement, .{ .resident_bytes = 4 * 1024 * 1024 });
    defer outcome.deinit();
    if (outcome.value != .rows) return error.BrowserReadUnavailable;
    const result = &outcome.value.rows;
    try result.holdDisclosure();
    var list: std.array_list.Managed(std.json.Value) = .init(self.a);
    var bytes: usize = 0;
    while (try result.nextRow()) |row| {
        if (list.items.len >= limit) return error.BrowserResultLimit;
        var object: std.json.ObjectMap = .empty;
        for (row, result.schema.structure) |cell, field| {
            if (object.contains(field.name)) return error.InvalidBrowserResult;
            const value: std.json.Value = switch (cell) {
                .null => .null,
                .value => |value| switch (value) {
                    .atom => |atom| switch (atom) {
                        .signed => |number| .{ .string = try std.fmt.allocPrint(self.a, "{d}", .{number}) },
                        .unsigned => |number| .{ .string = try std.fmt.allocPrint(self.a, "{d}", .{number}) },
                        .bytes => |text| .{ .string = try self.a.dupe(u8, text) },
                        .boolean => |boolean| .{ .bool = boolean },
                        .float => |number| if (std.math.isFinite(number)) .{ .float = number } else return error.InvalidBrowserResult,
                        else => return error.InvalidBrowserResult,
                    },
                    else => return error.InvalidBrowserResult,
                },
                else => return error.InvalidBrowserResult,
            };
            bytes += field.name.len + (if (value == .string) value.string.len else @as(usize, 16));
            if (bytes > 1024 * 1024) return error.BrowserResultLimit;
            try object.put(self.a, try self.a.dupe(u8, field.name), value);
        }
        try list.append(.{ .object = object });
    }
    if ((result.completion() orelse return error.IncompleteBrowserResult).rows != list.items.len) return error.IncompleteBrowserResult;
    try result.validateDisclosure();
    return .{ .array = list };
}
