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
    profile: enum { table_v1, unified_v2 },
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
        if (self.version != 1 or self.components != 1) return error.UnsupportedInterfaceVersion;
        try native(self.realm);
        if (self.revision.value == 0) return error.InvalidInterfaceRevision;
        try identifier(self.name);
        if (self.themes.len == 0 or self.themes.len > 2 or self.screens.len == 0 or self.screens.len > max_members or self.bindings.len > max_members or self.actions.len > max_members) return error.InterfaceCapacity;
        try unique(self.themes);
        try unique(self.screens);
        try unique(self.bindings);
        try unique(self.actions);
        if (!named(self.themes, self.theme) or !named(self.screens, self.entry)) return error.MissingInterfaceReference;
        for (self.bindings) |item| switch (item.source) {
            .inspection => |value| if (value.page_budget != 1) return error.UnsupportedInspectionBudget,
            .query => |value| {
                try native(value.resource);
                try identifier(value.name);
                try text(value.sql, 4096);
                _ = try root.serving.query.fuze.Sql.parse(value.sql);
                if (value.starts == 0 or value.starts > 8 or (value.refresh == .snapshot and value.starts != 1)) return error.InvalidQueryBudget;
                if (value.refresh == .follow and (value.profile != .unified_v2 or value.source_kind != .table)) return error.UnsupportedInterfaceWatch;
                if (value.profile == .table_v1 and value.source_kind != .table) return error.UnsupportedInterfaceSource;
            },
            .command => |value| {
                try native(value.service);
                try native(value.target);
                try native(value.revision);
                if (value.codec == 0) return error.InvalidInterfaceCommand;
            },
        };
        for (self.screens, 0..) |screen, index| {
            try text(screen.label, 128);
            try path(screen.path);
            for (self.screens[0..index]) |prior| if (std.mem.eql(u8, screen.path, prior.path)) return error.DuplicateInterfacePath;
            const bound = self.binding(screen.binding) orelse return error.MissingInterfaceReference;
            switch (screen.renderer) {
                .worksheet, .work_items => if (bound.source != .query) return error.IncompatibleRenderer,
                else => if (bound.source != .inspection) return error.IncompatibleRenderer,
            }
        }
        for (self.actions) |action| {
            try text(action.label, 128);
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
}
fn unique(items: anytype) !void {
    for (items, 0..) |item, index| {
        try identifier(item.name);
        for (items[0..index]) |prior| if (std.mem.eql(u8, prior.name, item.name)) return error.DuplicateInterfaceName;
    }
}
fn named(items: anytype, name: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.name, name)) return true;
    return false;
}
