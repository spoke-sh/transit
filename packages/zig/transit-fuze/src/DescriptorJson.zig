//! Descriptor JSON decoding with a first-failure path at the original check.
//! Scalar parsing remains owned by std.json; recursive shapes follow the Zig
//! descriptor types. The caller owns an arena and has checked lexical budgets.
const std = @import("std");
const Diagnostic = @import("TypeDiagnostic.zig");
const Self = @This();
allocator: std.mem.Allocator,
scanner: std.json.Scanner,
bytes: []const u8,
failure: ?*?Diagnostic,
const options: std.json.ParseOptions = .{ .allocate = .alloc_always, .max_value_len = 65536 };

pub fn parse(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8, failure: ?*?Diagnostic) !T {
    var self: Self = .{ .allocator = allocator, .scanner = .initCompleteInput(allocator, bytes), .bytes = bytes, .failure = failure };
    defer self.scanner.deinit();
    const result = try self.read(T, .{});
    if (try self.scanner.next() != .end_of_document) return error.UnexpectedToken;
    return result;
}
fn remember(self: *Self, path: Diagnostic.Path, kind: Diagnostic.Kind, expectation: []const u8, supplied: []const u8, offset: ?usize) void {
    if (self.failure) |failure| if (failure.* == null) {
        var detail: Diagnostic = .{ .path = path, .kind = kind, .offset = offset };
        detail.capture(supplied);
        detail.expectation(expectation);
        failure.* = detail;
    };
}
fn expected(comptime T: type) []const u8 {
    return switch (@typeInfo(T)) {
        .@"struct" => "object with the descriptor's required members",
        .@"union" => "object containing exactly one logical type tag",
        .@"enum" => |info| comptime blk: {
            var choices: []const u8 = "one of: ";
            for (info.field_names, 0..) |name, index| choices = choices ++ (if (index == 0) "" else ", ") ++ name;
            break :blk choices;
        },
        .pointer => |p| if (p.size == .one) expected(p.child) else if (p.child == u8) "UTF-8 string" else "array of field descriptors",
        .int => std.fmt.comptimePrint("integer from {d} to {d}", .{ std.math.minInt(T), std.math.maxInt(T) }),
        .bool => "boolean",
        .void => "empty object",
        else => @compileError("unsupported descriptor JSON type"),
    };
}
fn read(self: *Self, comptime T: type, path: Diagnostic.Path) anyerror!T {
    _ = self.scanner.peekNextTokenType() catch |err| {
        if (err != error.OutOfMemory) self.remember(path, .json_value, expected(T), "", null);
        return err;
    };
    const start = self.scanner.cursor;
    return self.readInner(T, path) catch |err| {
        if (err != error.OutOfMemory) self.remember(path, .json_value, expected(T), self.bytes[start..self.scanner.cursor], start);
        return err;
    };
}
fn readInner(self: *Self, comptime T: type, path: Diagnostic.Path) anyerror!T {
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            if (info.is_tuple) @compileError("descriptor tuples are not supported");
            if (try self.scanner.next() != .object_begin) return error.UnexpectedToken;
            var result: T = undefined;
            var seen: [info.field_names.len]bool = @splat(false);
            while (true) {
                _ = try self.scanner.peekNextTokenType();
                const member_start = self.scanner.cursor;
                const token = try self.scanner.nextAllocMax(self.allocator, .alloc_always, 65536);
                const name = switch (token) {
                    inline .string, .allocated_string => |value| value,
                    .object_end => break,
                    else => return error.UnexpectedToken,
                };
                inline for (info.field_names, info.field_types, info.field_attrs, 0..) |name_decl, Member, attr, index| {
                    if (attr.@"comptime") @compileError("descriptor comptime fields are not supported");
                    if (std.mem.eql(u8, name, name_decl)) {
                        if (seen[index]) {
                            self.remember(path.field(name), .json_duplicate, "unique object member", name, member_start);
                            return error.DuplicateField;
                        }
                        @field(result, name_decl) = try self.read(Member, path.field(name));
                        seen[index] = true;
                        break;
                    }
                } else {
                    self.remember(path.field(name), .json_unknown, "declared descriptor member", name, member_start);
                    return error.UnknownField;
                }
            }
            inline for (info.field_names, info.field_types, info.field_attrs, 0..) |name, Member, attr, index| {
                if (!seen[index]) {
                    if (attr.defaultValue(Member)) |value| {
                        @field(result, name) = value;
                    } else {
                        self.remember(path.field(name), .json_missing, expected(Member), "", null);
                        return error.MissingField;
                    }
                }
            }
            return result;
        },
        .@"union" => |info| {
            if (try self.scanner.next() != .object_begin) return error.UnexpectedToken;
            _ = try self.scanner.peekNextTokenType();
            const tag_start = self.scanner.cursor;
            const token = try self.scanner.nextAllocMax(self.allocator, .alloc_always, 65536);
            const name = switch (token) {
                inline .string, .allocated_string => |value| value,
                else => return error.UnexpectedToken,
            };
            inline for (info.field_names, info.field_types) |name_decl, Member| {
                if (std.mem.eql(u8, name, name_decl)) {
                    const result = @unionInit(T, name_decl, try self.read(Member, path.field(name)));
                    if (try self.scanner.next() != .object_end) return error.UnexpectedToken;
                    return result;
                }
            }
            self.remember(path.field(name), .json_unknown, "declared logical type tag", name, tag_start);
            return error.UnknownField;
        },
        .pointer => |info| {
            if (info.size == .one) {
                const result = try self.allocator.create(info.child);
                result.* = try self.read(info.child, path);
                return result;
            }
            if (info.size != .slice) @compileError("unsupported descriptor pointer");
            if (info.child == u8) return std.json.innerParse(T, self.allocator, &self.scanner, options);
            if (try self.scanner.next() != .array_begin) return error.UnexpectedToken;
            var result: std.ArrayList(info.child) = .empty;
            while (try self.scanner.peekNextTokenType() != .array_end) {
                const value = try self.read(info.child, path.index(result.items.len));
                try result.append(self.allocator, value);
            }
            _ = try self.scanner.next();
            return result.toOwnedSlice(self.allocator);
        },
        .void => {
            if (try self.scanner.next() != .object_begin) return error.UnexpectedToken;
            if (try self.scanner.next() != .object_end) return error.UnexpectedToken;
            return {};
        },
        else => return std.json.innerParse(T, self.allocator, &self.scanner, options),
    }
}
