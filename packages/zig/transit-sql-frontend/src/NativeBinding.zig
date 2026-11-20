//! Names of canonical native state bindings. Parsing identifies the binding;
//! its domain owner validates schemas and current authority at admission/use.
const std = @import("std");
const Parser = @import("SqlTyped.zig");
pub const Kind = enum {
    browser_identities,
    browser_bindings,
    browser_challenges,
    browser_sessions,
    secret_references,

    pub fn name(self: Kind) []const u8 {
        return switch (self) {
            .browser_identities => "browser.identities",
            .browser_bindings => "browser.bindings",
            .browser_challenges => "browser.challenges",
            .browser_sessions => "browser.sessions",
            .secret_references => "transit.secret_references",
        };
    }
    pub fn parse(value: []const u8) !Kind {
        inline for (std.meta.tags(Kind)) |kind| if (std.mem.eql(u8, value, kind.name())) return kind;
        return error.UnknownNativeBinding;
    }
    pub fn isKV(self: Kind) bool {
        return self == .browser_challenges or self == .browser_sessions or self == .secret_references;
    }
};

pub fn clause(parser: *Parser) !?Kind {
    if (!try parser.takeWord("WITH")) return null;
    try parser.require(.left);
    try parser.requireWord("native_binding");
    try parser.require(.eq);
    const value = try parser.value(.utf8);
    if (value != .value or value.value != .atom or value.value.atom != .bytes) return error.UnknownNativeBinding;
    const result = try Kind.parse(value.value.atom.bytes);
    try parser.require(.right);
    return result;
}
