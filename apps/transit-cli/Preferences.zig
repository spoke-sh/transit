//! Console startup files contain settings only, evaluated before any connection.
const std = @import("std");
const Options = @import("Options.zig");
const Diagnostic = @import("Diagnostic.zig");
const Self = @This();
connection: ?[]const u8 = null,
format: ?Options.Format = null,
connection_source: []const u8 = "local installation",
format_source: []const u8 = "connection configuration",

pub fn load(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic) !Self {
    var result: Self = .{};
    const allocator = init.arena.allocator();
    if (options.rc) |file| {
        try result.read(init, file, false, diagnostic);
    } else if (!options.no_rc) {
        try result.read(init, "/etc/transit/transitrc", true, diagnostic);
        if (init.environ_map.get("HOME")) |home| if (home.len > 0) try result.read(init, try std.fs.path.join(allocator, &.{ home, ".transitrc" }), true, diagnostic);
        try result.read(init, ".transitrc", true, diagnostic);
    }
    if (options.path) |file| {
        result.connection = file;
        result.connection_source = if (options.path_from_environment) "TRANSIT_CONSOLE_CONFIG" else "--config";
    }
    if (options.format) |format| {
        result.format = format;
        result.format_source = "--format";
    }
    return result;
}
fn read(self: *Self, init: std.process.Init, name: []const u8, optional: bool, diagnostic: *Diagnostic) !void {
    const allocator = init.arena.allocator();
    diagnostic.atFile(name);
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, name, allocator, .limited(65536)) catch |err| {
        if (optional and err == error.FileNotFound) return;
        diagnostic.configurationFailure(err);
        return error.InvalidConfiguration;
    };
    const absolute = try std.Io.Dir.cwd().realPathFileAlloc(init.io, name, allocator);
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    var line: u64 = 0;
    while (lines.next()) |raw| {
        line += 1;
        diagnostic.line = line;
        const text = std.mem.trim(u8, raw, " \t\r");
        if (text.len == 0 or text[0] == '#') continue;
        if (std.mem.startsWith(u8, text, ".mode ")) {
            self.format = std.meta.stringToEnum(Options.Format, std.mem.trim(u8, text[6..], " \t")) orelse return diagnostic.invalidField(".mode", "must be table or json", null);
            self.format_source = absolute;
        } else if (std.mem.startsWith(u8, text, ".connect ")) {
            const file = argument(allocator, text[9..]) catch return diagnostic.invalidField(".connect", "requires a file path", null);
            self.connection = try std.fs.path.resolve(allocator, &.{ std.fs.path.dirname(absolute).?, file });
            self.connection_source = absolute;
        } else return diagnostic.invalidField("startup command", "must be .mode or .connect", "Startup files configure the console; use -f to execute SQL.");
    }
}
pub fn argument(allocator: std.mem.Allocator, raw: []const u8) ![]const u8 {
    const text = std.mem.trim(u8, raw, " \t\r");
    if (text.len == 0) return error.MissingPath;
    if (text[0] == '"') return validPath(try std.json.parseFromSliceLeaky([]const u8, allocator, text, .{ .allocate = .alloc_always }));
    if (text[0] == '\'') {
        if (text.len < 2 or text[text.len - 1] != '\'') return error.InvalidPath;
        return validPath(text[1 .. text.len - 1]);
    }
    return validPath(text);
}

fn validPath(text: []const u8) ![]const u8 {
    if (text.len == 0 or std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidPath;
    return text;
}
