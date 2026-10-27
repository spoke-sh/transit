//! Catalog invocation validation precedes configuration, credentials and I/O.
const std = @import("std");
const c = @import("transit_catalog");
const Diagnostic = @import("cli_support").Diagnostic;
pub const Mode = enum { capabilities, describe, lookup, definition, list, query, compile, @"compile-authorization", @"prepare-schema", prepare, next, @"prepare-initialize", @"prepare-dependency", @"prepare-resume", cancel, cleanup, @"cancel-upload", @"collect-upload", submit, receipt, observe, disposition, progress, status };
pub const Flags = struct { config: ?[]const u8 = null, file: ?[]const u8 = null, output: ?[]const u8 = null, operation: ?[]const u8 = null, object: ?[]const u8 = null, revision: ?[]const u8 = null, name: ?[]const u8 = null, namespace: ?[]const u8 = null, schema: ?[]const u8 = null, intent: ?[]const u8 = null, input: ?[]const u8 = null, rows: ?[]const u8 = null, reads: ?[]const u8 = null };
pub const Options = struct { mode: Mode, flags: Flags = .{}, input: u64 = 0, rows: u32 = 1024, reads: u32 = 4096 };
fn preparation(mode: Mode) bool {
    return mode == .@"prepare-initialize" or mode == .@"prepare-dependency" or mode == .@"prepare-resume" or mode == .@"prepare-schema" or mode == .next or mode == .cancel or mode == .cleanup or mode == .@"cancel-upload" or mode == .@"collect-upload";
}
fn allowed(mode: Mode, field: []const u8) bool {
    if (std.mem.eql(u8, field, "config")) return mode != .capabilities;
    if (std.mem.eql(u8, field, "file")) return mode != .capabilities and mode != .describe and mode != .lookup and mode != .definition;
    if (std.mem.eql(u8, field, "output")) return mode == .compile or mode == .@"compile-authorization" or mode == .prepare or preparation(mode) or mode == .list;
    if (std.mem.eql(u8, field, "operation")) return mode == .compile or mode == .@"compile-authorization";
    if (std.mem.eql(u8, field, "namespace")) return mode == .compile;
    if (std.mem.eql(u8, field, "schema")) return mode == .@"compile-authorization";
    if (std.mem.eql(u8, field, "object")) return mode == .compile or mode == .definition;
    if (std.mem.eql(u8, field, "revision")) return mode == .definition;
    if (std.mem.eql(u8, field, "name")) return mode == .lookup;
    if (std.mem.eql(u8, field, "input")) return mode == .observe or mode == .disposition or mode == .progress;
    if (std.mem.eql(u8, field, "rows") or std.mem.eql(u8, field, "reads")) return mode == .query;
    if (std.mem.eql(u8, field, "intent")) return mode == .progress;
    return false;
}

pub fn parse(args: []const []const u8, diagnostic: *Diagnostic) !Options {
    diagnostic.command = "catalog fixture";
    diagnostic.atArgument(2, null);
    if (args.len == 0) return diagnostic.invalidInvocation("a catalog subcommand is required");
    const mode = std.meta.stringToEnum(Mode, args[0]) orelse return diagnostic.invalidArgument("unknown catalog subcommand");
    switch (mode) {
        inline else => |value| {
            diagnostic.command = "catalog fixture " ++ @tagName(value);
        },
    }
    var result: Options = .{ .mode = mode };
    var i: usize = 1;
    while (i < args.len) {
        diagnostic.atArgument(i + 2, null);

        var found = false;
        inline for (@typeInfo(Flags).@"struct".field_names) |field| {
            if (std.mem.eql(u8, args[i], "--" ++ field)) {
                diagnostic.option = "--" ++ field;
                if (!allowed(mode, field)) {
                    return diagnostic.invalidOption("is not supported by this command");
                }
                if (@field(result.flags, field) != null) return diagnostic.invalidOption("can only be specified once");
                if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "--")) return diagnostic.invalidOption(if (comptime std.mem.eql(u8, field, "config") or std.mem.eql(u8, field, "file") or std.mem.eql(u8, field, "output")) "requires a file path" else "requires a value");
                @field(result.flags, field) = args[i + 1];
                found = true;
            }
        }
        if (!found) return diagnostic.invalidArgument("unexpected input");
        if (std.mem.eql(u8, args[i], "--operation") or std.mem.eql(u8, args[i], "--object") or std.mem.eql(u8, args[i], "--revision") or std.mem.eql(u8, args[i], "--namespace") or std.mem.eql(u8, args[i], "--schema")) {
            const value = c.TableValues.unsigned(args[i + 1]) catch return diagnostic.invalidOption("must be a canonical positive uint64 integer");
            if (value == 0) return diagnostic.invalidOption("must be a canonical positive uint64 integer");
        } else if (std.mem.eql(u8, args[i], "--rows") or std.mem.eql(u8, args[i], "--reads")) {
            const value = c.TableValues.unsigned(args[i + 1]) catch return diagnostic.invalidOption("must be a canonical positive integer");
            const rows = std.mem.eql(u8, args[i], "--rows");
            if (value == 0 or value > @as(u64, if (rows) 65536 else 1048576)) return diagnostic.invalidOption("exceeds the query row or read budget");
            if (rows) result.rows = @intCast(value) else result.reads = @intCast(value);
        } else if (std.mem.eql(u8, args[i], "--input")) {
            result.input = c.TableValues.unsigned(args[i + 1]) catch return diagnostic.invalidOption("must be a canonical positive native position");
            c.Model.nativeId(result.input) catch return diagnostic.invalidOption("must be a canonical positive native position");
        } else if (std.mem.eql(u8, args[i], "--name")) {
            _ = c.TableMetadata.Name.init(args[i + 1]) catch return diagnostic.invalidOption("requires a name of 1 through 255 UTF-8 bytes without NUL");
        }
        i += 2;
    }
    inline for (@typeInfo(Flags).@"struct".field_names) |field| {
        const optional = (mode == .query and (std.mem.eql(u8, field, "rows") or std.mem.eql(u8, field, "reads"))) or (mode == .list and (std.mem.eql(u8, field, "file") or std.mem.eql(u8, field, "output"))) or (mode == .compile and std.mem.eql(u8, field, "object")) or (mode == .@"compile-authorization" and (std.mem.eql(u8, field, "operation") or std.mem.eql(u8, field, "schema")));
        if (allowed(mode, field) and !optional and @field(result.flags, field) == null) {
            diagnostic.atArgument(null, "--" ++ field);
            return diagnostic.invalidOption("is required");
        }
    }
    diagnostic.atArgument(null, null);
    return result;
}
