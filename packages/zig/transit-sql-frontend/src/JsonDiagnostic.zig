//! Owned JSON failure coordinates and a token-source observer. The pinned
//! std.json scanner/parser remains the authority for syntax and duplicate keys.
const std = @import("std");
const Self = @This();
pub const Path = @import("DiagnosticPath.zig");
pub const Kind = enum { syntax, encoding, duplicate, fields, budget };
kind: Kind,
path: ?Path = null,
offset: ?usize = null,
earlier: ?usize = null,
pub fn remember(slot: ?*?Self, detail: Self) void {
    if (slot) |value| if (value.* == null) {
        value.* = detail;
    };
}
pub fn constraint(self: Self) []const u8 {
    return switch (self.kind) {
        .syntax => "The JSON parser could not continue at the recorded byte position.",
        .encoding => "The input contains invalid UTF-8; the recorded byte begins the invalid sequence.",
        .duplicate => "Decoded JSON member names must be unique within each object.",
        .fields => "The JSON object exceeds the configured field-count limit.",
        .budget => "JSON framing exceeds the recorded input budget.",
    };
}

pub fn invalidUtf8Offset(bytes: []const u8) ?usize {
    if (std.unicode.utf8ValidateSlice(bytes)) return null;
    var at: usize = 0;
    while (at < bytes.len) {
        const width = std.unicode.utf8ByteSequenceLength(bytes[at]) catch break;
        if (width > bytes.len - at) break;
        _ = std.unicode.utf8Decode(bytes[at..][0..width]) catch break;
        at += width;
    }
    return at;
}

pub const Reader = struct {
    allocator: std.mem.Allocator,
    scanner: std.json.Scanner,
    failure: ?*?Self,
    stack: std.ArrayList(Frame) = .empty,
    completed: ?Self = null,
    const Frame = struct {
        path: Path,
        object: bool,
        index: usize = 0,
        key: ?[]const u8 = null,
        key_offset: usize = 0,
        earlier: ?usize = null,
        keys: std.StringHashMapUnmanaged(usize) = .empty,
    };
    pub const NextError = std.json.Scanner.NextError;
    pub const AllocError = std.json.Scanner.AllocError || std.json.Scanner.PeekError;
    pub const PeekError = std.json.Scanner.PeekError;
    pub fn init(allocator: std.mem.Allocator, bytes: []const u8, failure: ?*?Self) Reader {
        return .{ .allocator = allocator, .scanner = .initCompleteInput(allocator, bytes), .failure = failure };
    }
    pub fn deinit(self: *Reader) void {
        for (self.stack.items) |*frame| frame.keys.deinit(self.allocator);
        self.stack.deinit(self.allocator);
        self.scanner.deinit();
    }
    fn path(self: *const Reader) Path {
        if (self.stack.items.len == 0) return .{};
        const frame = &self.stack.items[self.stack.items.len - 1];
        return if (frame.object) if (frame.key) |key| frame.path.field(key) else frame.path else frame.path.index(frame.index);
    }
    fn failed(self: *Reader, err: anyerror) void {
        if (err == error.OutOfMemory) return;
        remember(self.failure, .{ .kind = .syntax, .path = self.path(), .offset = self.scanner.cursor });
    }
    pub fn peekNextTokenType(self: *Reader) PeekError!std.json.TokenType {
        return self.scanner.peekNextTokenType() catch |err| {
            self.failed(err);
            return err;
        };
    }
    pub fn next(self: *Reader) NextError!std.json.Token {
        // std.json.Value uses this only for the end-of-document check.
        return self.scanner.next() catch |err| {
            self.failed(err);
            return err;
        };
    }
    pub fn nextAllocMax(self: *Reader, allocator: std.mem.Allocator, when: std.json.AllocWhen, max_value_len: usize) AllocError!std.json.Token {
        _ = try self.peekNextTokenType();
        const offset = self.scanner.cursor;
        const token = self.scanner.nextAllocMax(allocator, when, max_value_len) catch |err| {
            self.failed(err);
            return err;
        };
        switch (token) {
            .object_begin, .array_begin => try self.stack.append(self.allocator, .{ .path = self.path(), .object = token == .object_begin }),
            .object_end, .array_end => {
                var frame = self.stack.pop().?;
                frame.keys.deinit(self.allocator);
                self.complete();
            },
            inline .string, .allocated_string => |bytes| {
                if (self.stack.items.len != 0) {
                    const frame = &self.stack.items[self.stack.items.len - 1];
                    if (frame.object and frame.key == null) {
                        const entry = try frame.keys.getOrPut(self.allocator, bytes);
                        frame.earlier = if (entry.found_existing) entry.value_ptr.* else null;
                        if (!entry.found_existing) entry.value_ptr.* = offset;
                        frame.key = bytes;
                        frame.key_offset = offset;
                        return token;
                    }
                }
                self.complete();
            },
            .number, .allocated_number, .null, .true, .false => self.complete(),
            else => {},
        }
        return token;
    }
    fn complete(self: *Reader) void {
        self.completed = .{ .kind = .duplicate, .path = self.path() };
        if (self.stack.items.len == 0) return;
        const frame = &self.stack.items[self.stack.items.len - 1];
        if (frame.object) {
            self.completed.?.offset = frame.key_offset;
            self.completed.?.earlier = frame.earlier;
            frame.key = null;
        } else frame.index += 1;
    }
    pub fn parse(self: *Reader, allocator: std.mem.Allocator, options: std.json.ParseOptions) !std.json.Parsed(std.json.Value) {
        return std.json.parseFromTokenSource(std.json.Value, allocator, self, options) catch |err| {
            if (err == error.DuplicateField) if (self.completed) |detail| remember(self.failure, detail);
            return err;
        };
    }
};
