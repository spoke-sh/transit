//! Bounded neutral definitions. Current authority and source compilation are separate.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
pub const Wide = root.serving.RefreshModel.Namespace;
pub const max_program_bytes = 64 * 1024;
pub const max_members = 16;
const name_schema = .{ .type = "string", .minLength = 1, .maxLength = 64, .pattern = "^[A-Za-z_][A-Za-z_0-9]*$" };
const label_schema = .{ .type = "string", .minLength = 1, .maxLength = 128 };
pub const Theme = struct {
    pub const json_schema_fields = .{ .name = name_schema };
    name: []const u8,
    density: enum { comfortable, compact },
};
pub const Renderer = enum { atlas, worksheet, records, activity, definition, operations, work_items };
pub const Area = enum { workspace, operations };
pub const Screen = struct {
    pub const json_schema_fields = .{ .name = name_schema, .path = .{ .type = "string", .minLength = 1, .maxLength = 128, .pattern = "^/[A-Za-z_0-9/-]*$" }, .label = label_schema, .binding = name_schema };
    name: []const u8,
    path: []const u8,
    label: []const u8,
    area: Area,
    renderer: Renderer,
    binding: []const u8,
};
pub const Inspection = enum { atlas, resources, processes, records, capabilities, activity };
pub const Refresh = enum { snapshot, follow };
pub const Query = struct {
    pub const json_schema_fields = .{ .name = name_schema, .sql = .{ .type = "string", .minLength = 1, .maxLength = 4096 } };
    resource: u64,
    name: []const u8,
    source_kind: enum { table, kv, document },
    schema: [32]u8,
    profile: enum { unified_v1 },
    sql: []const u8,
    refresh: Refresh = .snapshot,
    starts: u8 = 1,
};
pub const Binding = struct {
    pub const json_schema_fields = .{ .name = name_schema };
    name: []const u8,
    source: union(enum) {
        inspection: struct { projection: Inspection, page_budget: u8 = 1 },
        query: Query,
        command: struct { service: u64, target: u64, revision: u64, codec: u16 },
    },
};
pub const Action = struct {
    pub const json_schema_fields = .{ .name = name_schema, .label = label_schema };
    name: []const u8,
    label: []const u8,
    target: union(enum) { navigate: []const u8, command: []const u8, follow: []const u8 },
};
pub const Definition = struct {
    pub const json_schema_fields = .{
        .name = name_schema,
        .entry = name_schema,
        .theme = name_schema,
        .version = .{ .type = "integer", .@"const" = 1 },
        .themes = .{ .type = "array", .maxItems = 2, .items = .{ .@"$ref" = "#/$defs/Theme" } },
        .screens = .{ .type = "array", .maxItems = max_members, .items = .{ .@"$ref" = "#/$defs/Screen" } },
        .bindings = .{ .type = "array", .maxItems = max_members, .items = .{ .@"$ref" = "#/$defs/Binding" } },
        .actions = .{ .type = "array", .maxItems = max_members, .items = .{ .@"$ref" = "#/$defs/Action" } },
    };
    version: u8 = 1,
    name: []const u8,
    realm: u64,
    revision: Wide,
    components: u16 = 1,
    entry: []const u8,
    theme: []const u8,
    themes: []const Theme,
    screens: []const Screen,
    bindings: []const Binding,
    actions: []const Action,

    pub fn binding(self: Definition, name: []const u8) ?Binding {
        for (self.bindings) |item| if (std.mem.eql(u8, item.name, name)) return item;
        return null;
    }
    pub fn validate(self: Definition) !void {
        return self.validateDiagnostic(null);
    }
    pub fn validateDiagnostic(self: Definition, diagnostic: ?*@import("Diagnostic.zig")) !void {
        const Diagnostic = @import("Diagnostic.zig");
        Diagnostic.subject(diagnostic, "interface", self.name);
        if (diagnostic) |detail| detail.stage = .validate;
        if (self.version != 1 or self.components != 1) return error.UnsupportedInterfaceVersion;
        try native(self.realm);
        if (self.revision.value == 0) return error.InvalidInterfaceRevision;
        try identifier(self.name);
        inline for (.{ .{ "themes", 1, 2 }, .{ "screens", 1, max_members }, .{ "bindings", 0, max_members }, .{ "actions", 0, max_members } }) |range| {
            const count = @field(self, range[0]).len;
            if (count < range[1] or count > range[2]) {
                Diagnostic.capacity(diagnostic, range[0], "members", count < range[1], if (count < range[1]) range[1] else range[2], count);
                return error.InterfaceCapacity;
            }
        }
        try unique(self.themes, diagnostic, "theme");
        try unique(self.screens, diagnostic, "screen");
        try unique(self.bindings, diagnostic, "binding");
        try unique(self.actions, diagnostic, "action");
        Diagnostic.subject(diagnostic, "interface", self.name);
        if (!named(self.themes, self.theme)) {
            Diagnostic.subject(diagnostic, "interface", self.name);
            Diagnostic.field(diagnostic, "theme", null);
            Diagnostic.target(diagnostic, self.theme);
            return error.MissingInterfaceReference;
        }
        if (!named(self.screens, self.entry)) {
            Diagnostic.subject(diagnostic, "interface", self.name);
            Diagnostic.field(diagnostic, "entry", null);
            Diagnostic.target(diagnostic, self.entry);
            return error.MissingInterfaceReference;
        }
        for (self.bindings) |item| {
            Diagnostic.subject(diagnostic, "binding", item.name);
            switch (item.source) {
                .inspection => |value| {
                    Diagnostic.field(diagnostic, "page_budget", null);
                    if (value.page_budget != 1) return error.UnsupportedInspectionBudget;
                },
                .query => |value| {
                    Diagnostic.field(diagnostic, "resource", null);
                    try native(value.resource);
                    Diagnostic.field(diagnostic, "source", null);
                    try identifier(value.name);
                    Diagnostic.field(diagnostic, "query", null);
                    try text(value.sql, 4096);
                    _ = root.serving.query.fuze.Sql.parse(value.sql) catch |err| {
                        Diagnostic.field(diagnostic, "query", null);
                        if (diagnostic) |detail| {
                            detail.sql = root.serving.query.fuze.SqlDiagnostic.query(value.sql, err, false);
                            if (detail.sql) |*nested| nested.hint = "Correct the SELECT in this binding and compile the declaration again.";
                        }
                        return err;
                    };
                    Diagnostic.field(diagnostic, "starts", null);
                    if (value.starts == 0 or value.starts > 8 or (value.refresh == .snapshot and value.starts != 1)) return error.InvalidQueryBudget;
                    Diagnostic.field(diagnostic, "refresh", null);
                    if (value.refresh == .follow and (value.profile != .unified_v1 or value.source_kind != .table)) return error.UnsupportedInterfaceWatch;
                },
                .command => |value| {
                    Diagnostic.field(diagnostic, "service", null);
                    try native(value.service);
                    Diagnostic.field(diagnostic, "target", null);
                    try native(value.target);
                    Diagnostic.field(diagnostic, "revision", null);
                    try native(value.revision);
                    Diagnostic.field(diagnostic, "codec", null);
                    if (value.codec == 0) return error.InvalidInterfaceCommand;
                },
            }
        }
        for (self.screens, 0..) |screen, index| {
            Diagnostic.subject(diagnostic, "screen", screen.name);
            Diagnostic.field(diagnostic, "label", null);
            try text(screen.label, 128);
            Diagnostic.field(diagnostic, "path", null);
            try path(screen.path);
            for (self.screens[0..index]) |prior| if (std.mem.eql(u8, screen.path, prior.path)) return error.DuplicateInterfacePath;
            Diagnostic.field(diagnostic, "binding", null);
            Diagnostic.target(diagnostic, screen.binding);
            const bound = self.binding(screen.binding) orelse return error.MissingInterfaceReference;
            Diagnostic.field(diagnostic, "renderer", null);
            switch (screen.renderer) {
                .worksheet, .work_items => if (bound.source != .query) return error.IncompatibleRenderer,
                else => {
                    if (bound.source != .inspection) return error.IncompatibleRenderer;
                    const projection = bound.source.inspection.projection;
                    const compatible = projection == .atlas or switch (screen.renderer) {
                        .atlas => projection == .processes or projection == .resources,
                        .records => projection == .resources or projection == .records,
                        .activity => projection == .activity,
                        .operations, .definition => projection == .capabilities,
                        else => unreachable,
                    };
                    if (!compatible) return error.IncompatibleRenderer;
                },
            }
        }
        for (self.actions) |action| {
            Diagnostic.subject(diagnostic, "action", action.name);
            Diagnostic.field(diagnostic, "label", null);
            try text(action.label, 128);
            Diagnostic.field(diagnostic, "target", null);
            Diagnostic.target(diagnostic, switch (action.target) {
                inline else => |name| name,
            });
            switch (action.target) {
                .navigate => |name| if (!named(self.screens, name)) return error.MissingInterfaceReference,
                .command => |name| if ((self.binding(name) orelse return error.MissingInterfaceReference).source != .command) return error.IncompatibleAction,
                .follow => |name| {
                    const bound = self.binding(name) orelse return error.MissingInterfaceReference;
                    if (bound.source != .query or bound.source.query.refresh != .follow) return error.IncompatibleAction;
                },
            }
        }
    }
};
fn native(value: u64) !void {
    if (value == 0 or value > p.max_counter) return error.InvalidInterfaceIdentity;
}
pub fn text(value: []const u8, maximum: usize) !void {
    if (value.len == 0 or value.len > maximum or !std.unicode.utf8ValidateSlice(value) or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidInterfaceText;
}
pub fn identifier(value: []const u8) !void {
    try text(value, 64);
    if (!std.ascii.isAlphabetic(value[0]) and value[0] != '_') return error.InvalidInterfaceName;
    for (value) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_') return error.InvalidInterfaceName;
}
pub fn path(value: []const u8) !void {
    try text(value, 128);
    if (value[0] != '/' or std.mem.indexOf(u8, value, "//") != null or std.mem.indexOf(u8, value, "..") != null) return error.InvalidInterfacePath;
    for (value) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '/' and byte != '-' and byte != '_') return error.InvalidInterfacePath;
    inline for (.{ "/api", "/assets", "/health", "/openapi", "/recovery", "/processes" }) |reserved| {
        if (std.mem.eql(u8, value, reserved) or (std.mem.startsWith(u8, value, reserved) and value.len > reserved.len and value[reserved.len] == '/')) return error.ReservedInterfacePath;
    }
}
fn unique(items: anytype, diagnostic: ?*@import("Diagnostic.zig"), kind: []const u8) !void {
    for (items, 0..) |item, index| {
        @import("Diagnostic.zig").subject(diagnostic, kind, item.name);
        try identifier(item.name);
        for (items[0..index]) |prior| if (std.mem.eql(u8, prior.name, item.name)) return error.DuplicateInterfaceName;
    }
}
fn named(items: anytype, name: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.name, name)) return true;
    return false;
}
