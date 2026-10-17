//! A bounded checkpoint publishes one gateway/session-default generation. Retained
//! reload outcomes live in individually addressed files, never a resident list.
const std = @import("std");
const q = @import("transit_query");
const C = q.settings.Contract;
const R = q.settings.Registry;
const Config = @import("Config.zig");
const Files = @import("Files.zig");
const Diagnostic = @import("../Diagnostic.zig");
const Self = @This();
pub const Deployment = struct { path: []const u8, binding: C.Binding };
const Retained = struct { request: C.Request, principal: u64, role: ?u64, outcome: C.Outcome };
const State = struct {
    definition: q.protocol.Growth.Definition,
    binding: C.Binding,
    artifacts: Config.Identity,
    boot: [16]u8,
    generation: u64,
    revision: u64,
    position: u64,
    active: Config,
    configured: Config,
    inputs: Config.Inputs,
    file: std.json.Value,
    origins: []const R.Origin,
    configured_origins: []const R.Origin,
    pending: ?Retained,
};
init: std.process.Init,
deployment: Deployment,
mutex: std.Io.Mutex = .init,
failed: bool = false,

pub fn boot(init: std.process.Init, path: []const u8, binding: C.Binding, token: [16]u8, loaded: Config.Loaded, artifacts: Config.Identity) !void {
    const a = init.arena.allocator();
    var previous: ?State = Files.readBounded(State, init.io, a, path, C.max_bytes) catch |err| if (err == error.FileNotFound) null else return err;
    var manager: Self = .{ .init = init, .deployment = .{ .path = path, .binding = binding } };
    if (previous) |*state| {
        try manager.validate(state.*);
        try manager.finish(a, state);
        if (std.mem.eql(u8, &state.boot, &token)) return;
    }
    const history_path = try manager.history(a);
    std.Io.Dir.cwd().createDir(init.io, history_path, .fromMode(0o700)) catch |err| if (err != error.PathAlreadyExists) return err;
    const state: State = .{
        .definition = q.protocol.Growth.current_definition,
        .binding = binding,
        .artifacts = artifacts,
        .boot = token,
        .generation = if (previous) |old| try increment(old.generation) else 1,
        .revision = if (previous) |old| old.revision else 0,
        .position = if (previous) |old| old.position else 0,
        .active = loaded.config,
        .configured = loaded.config,
        .inputs = loaded.inputs,
        .file = loaded.file,
        .origins = try origins(a, loaded),
        .configured_origins = try origins(a, loaded),
        .pending = null,
    };
    try manager.save(a, state);
}
fn increment(value: u64) !u64 {
    if (value >= q.protocol.max_counter) return error.ConfigurationCounterExhausted;
    return value + 1;
}
fn validate(self: Self, state: State) !void {
    if (state.definition != q.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    if (state.origins.len != Config.settings.descriptors.len or state.configured_origins.len != Config.settings.descriptors.len or !std.meta.eql(state.binding, self.deployment.binding) or state.generation == 0 or state.generation > q.protocol.max_counter or state.revision > q.protocol.max_counter or state.position > q.protocol.max_counter) return error.InvalidConfigurationCheckpoint;
}
fn read(self: Self, a: std.mem.Allocator) !State {
    const state = try Files.readBounded(State, self.init.io, a, self.deployment.path, C.max_bytes);
    try self.validate(state);
    return state;
}
fn save(self: *Self, a: std.mem.Allocator, state: State) !void {
    Files.jsonBounded(self.init.io, a, self.deployment.path, state, C.max_bytes) catch |err| {
        self.failed = true;
        return err;
    };
}
fn history(self: Self, a: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(a, "{s}/configuration-history", .{std.fs.path.dirname(self.deployment.path).?});
}
fn operationPath(self: Self, a: std.mem.Allocator, id: [16]u8) ![]const u8 {
    return std.fmt.allocPrint(a, "{s}/operation-{s}.json", .{ try self.history(a), std.fmt.bytesToHex(id, .lower) });
}
fn ordinalPath(self: Self, a: std.mem.Allocator, ordinal: u64) ![]const u8 {
    return std.fmt.allocPrint(a, "{s}/ordinal-{d}.json", .{ try self.history(a), ordinal });
}
/// The checkpoint is the acceptance boundary. These idempotent history indexes
/// are completed before another operation can be accepted, including on restart.
fn finish(self: *Self, a: std.mem.Allocator, state: *State) !void {
    const pending = state.pending orelse return;
    errdefer self.failed = true;
    try Files.jsonBounded(self.init.io, a, try self.operationPath(a, pending.request.operation), pending, C.max_bytes);
    try Files.json(self.init.io, a, try self.ordinalPath(a, pending.outcome.ordinal), pending.outcome);
    state.pending = null;
    try self.save(a, state.*);
}
/// The Host check and dispatch each own a complete snapshot. A request already
/// admitted under an earlier Host policy may finish; no mutable slice is shared.
pub fn allows(self: *Self, a: std.mem.Allocator, host: []const u8) !bool {
    try self.mutex.lock(self.init.io);
    defer self.mutex.unlock(self.init.io);
    if (self.failed) return error.ConfigurationUnavailable;
    const state = try self.read(a);
    return @import("Hosts.zig").allows(try @import("Hosts.zig").list(a, state.active.ports.gateway, state.active.gateway_allowed_hosts), host);
}
pub fn execute(self: *Self, a: std.mem.Allocator, wire: *q.wire.Client, signed: C.Signed) !C.Response {
    try self.mutex.lock(self.init.io);
    defer self.mutex.unlock(self.init.io);
    if (self.failed) return error.ConfigurationUnavailable;
    _ = try signed.validate(a, self.deployment.binding);
    var state = try self.read(a);
    try self.finish(a, &state);
    var observed = try wire.call(q.protocol.Growth.Response, "/v1/query", signed.authority);
    if (observed.position < state.position) return error.AuthorityRollback;
    state.position = observed.position;
    // Persist the observed authority floor even for reads. Storage cannot confer
    // rights: every request still goes through a fresh native guard check.
    try self.save(a, state);
    const request = signed.configuration;
    const result: @FieldType(C.Response, "result") = switch (request.action) {
        .settings => |action| .{ .settings = try rows(a, state, action) },
        .reloads => |action| .{ .reloads = try self.outcomes(a, state, action) },
        .reload => .{ .reload = try self.apply(a, wire, &state, signed) },
    };
    observed = try wire.call(q.protocol.Growth.Response, "/v1/query", signed.authority);
    if (observed.position < state.position) return error.AuthorityRollback;
    state.position = observed.position;
    try self.save(a, state);
    return .{ .definition = q.protocol.Growth.current_definition, .binding = state.binding, .policy_revision = observed.body.authorization.revision, .result = result };
}
fn rows(a: std.mem.Allocator, state: State, action: @FieldType(C.Action, "settings")) !@FieldType(@FieldType(C.Response, "result"), "settings") {
    if (action.cursor) |cursor| if (cursor.revision != state.generation) return error.ConfigurationSnapshotChanged;
    if (action.name) |name| _ = try Config.settings.lookup(name);
    const active = try Config.value(a, state.active);
    const configured = try Config.value(a, state.configured);
    var items: std.array_list.Managed(C.Row) = .init(a);
    var next: ?C.Cursor = null;
    for (Config.settings.descriptors, 0..) |descriptor, i| {
        if (action.cursor) |cursor| if (i < cursor.after) continue;
        if (action.name) |name| if (!std.mem.eql(u8, name, descriptor.name)) continue;
        if (items.items.len == C.page_size) {
            next = .{ .revision = state.generation, .after = i };
            break;
        }
        const origin = state.origins[i];
        const effective = try descriptor.display(a, R.get(active, descriptor.name));
        const candidate = try descriptor.display(a, R.get(configured, descriptor.name));
        try items.append(.{
            .name = descriptor.name,
            .description = descriptor.description,
            .owner = descriptor.owner,
            .instance = "local",
            .value = effective,
            .configured_value = candidate,
            .default_value = try descriptor.display(a, R.get(state.inputs.defaults, descriptor.name)),
            .kind = descriptor.kind,
            .unit = descriptor.unit(),
            .minimum = if (descriptor.kind == .unsigned or descriptor.kind == .duration or descriptor.kind == .bytes) descriptor.minimum else null,
            .maximum = if (descriptor.kind == .unsigned or descriptor.kind == .duration or descriptor.kind == .bytes) descriptor.maximum else null,
            .enum_values = descriptor.values,
            .scope = descriptor.scope,
            .change = descriptor.change,
            .session_mutable = descriptor.session_mutable,
            .session_generation = null,
            .source = origin.source,
            .configured_source = state.configured_origins[i].source,
            .source_name = if (action.origins) origin.name else null,
            .source_line = if (action.origins) origin.line else null,
            .source_column = if (action.origins) origin.column else null,
            .generation = state.generation,
            .pending_restart = !try valueEqual(a, R.get(active, descriptor.name), R.get(configured, descriptor.name)),
            .redacted = descriptor.sensitive,
        });
    }
    return .{ .generation = state.generation, .rows = items.items, .next = next };
}
fn valueEqual(a: std.mem.Allocator, left: ?std.json.Value, right: ?std.json.Value) !bool {
    if (left == null or right == null) return left == null and right == null;
    return std.mem.eql(u8, try q.protocol.Json.valueAlloc(a, left.?), try q.protocol.Json.valueAlloc(a, right.?));
}
fn outcomes(self: *Self, a: std.mem.Allocator, state: State, action: @FieldType(C.Action, "reloads")) !@FieldType(@FieldType(C.Response, "result"), "reloads") {
    if (action.cursor) |cursor| if (cursor.revision != state.revision) return error.ConfigurationSnapshotChanged;
    var items: std.array_list.Managed(C.Outcome) = .init(a);
    if (action.operation) |id| {
        const retained = Files.readBounded(Retained, self.init.io, a, try self.operationPath(a, id), C.max_bytes) catch |err| {
            if (err == error.FileNotFound) return .{ .revision = state.revision, .rows = &.{}, .next = null };
            return err;
        };
        try retained.request.validate();
        try items.append(visibleOutcome(retained.outcome, action.origins));
        return .{ .revision = state.revision, .rows = items.items, .next = null };
    }
    var ordinal = if (action.cursor) |cursor| cursor.after else 0;
    while (ordinal < state.revision and items.items.len < C.page_size) {
        ordinal += 1;
        try items.append(visibleOutcome(try Files.read(C.Outcome, self.init.io, a, try self.ordinalPath(a, ordinal)), action.origins));
    }
    return .{ .revision = state.revision, .rows = items.items, .next = if (ordinal < state.revision) .{ .revision = state.revision, .after = ordinal } else null };
}
fn visibleOutcome(value: C.Outcome, include_origins: bool) C.Outcome {
    var result = value;
    if (!include_origins) {
        result.error_line = null;
        result.error_column = null;
    }
    return result;
}
fn apply(self: *Self, a: std.mem.Allocator, wire: *q.wire.Client, state: *State, signed: C.Signed) !C.Outcome {
    const request = signed.configuration;
    if (Files.readBounded(Retained, self.init.io, a, try self.operationPath(a, request.operation), C.max_bytes)) |existing| {
        if (!std.mem.eql(u8, &try existing.request.digest(a), &try request.digest(a)) or existing.principal != signed.authority.query.principal or existing.role != signed.authority.query.kind.authorization.role) return error.ConfigurationOperationConflict;
        return existing.outcome;
    } else |err| if (err != error.FileNotFound) return err;
    var outcome: C.Outcome = .{ .operation = request.operation, .ordinal = try increment(state.revision), .principal = signed.authority.query.principal, .generation = state.generation, .phase = .rejected, .components = &.{} };
    var diagnostic: Diagnostic = .{};
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    var init = self.init;
    init.arena = &arena;
    // The request allocator owns this complete candidate, prepared before the
    // atomic checkpoint. No process env or discovery takes place during reload.
    const candidate: ?Config.Loaded = if (request.action.reload.expected_generation != state.generation) bad: {
        outcome.error_code = "ConfigurationGenerationConflict";
        break :bad null;
    } else Config.resolve(init, state.inputs, &diagnostic, true) catch |err| bad: {
        outcome.error_code = @errorName(diagnostic.cause orelse err);
        if (diagnostic.field) |field| if (Config.settings.lookup(field)) |descriptor| {
            outcome.error_field = descriptor.name;
        } else |_| {};
        outcome.error_line = diagnostic.line;
        outcome.error_column = diagnostic.column;
        break :bad null;
    };
    if (candidate) |temporary| {
        // The resolution arena ends with apply. Published values must belong to
        // the request snapshot that survives the final authority/disclosure check.
        const encoded = try q.protocol.Json.valueAlloc(a, temporary);
        if (encoded.len > C.max_bytes) return error.ConfigurationTooLarge;
        const loaded = try std.json.parseFromSliceLeaky(Config.Loaded, a, encoded, .{ .allocate = .alloc_always });
        const before = try Config.value(a, state.active);
        const after = try Config.value(a, loaded.config);
        const next_origins = try origins(a, loaded);
        const unchanged = std.mem.eql(u8, try q.protocol.Json.valueAlloc(a, state.configured), try q.protocol.Json.valueAlloc(a, loaded.config)) and std.mem.eql(u8, try q.protocol.Json.valueAlloc(a, state.configured_origins), try q.protocol.Json.valueAlloc(a, next_origins));
        const next_generation = if (unchanged) state.generation else try increment(state.generation);
        var immutable = false;
        var pending = false;
        var components: std.array_list.Managed(C.Component) = .init(a);
        for (Config.settings.descriptors) |descriptor| {
            // Compare private typed values before redaction. A sensitive marker
            // must never suppress a real lifecycle change or pending restart.
            if (try valueEqual(a, R.get(before, descriptor.name), R.get(after, descriptor.name))) continue;
            if (descriptor.change == .initialization) {
                immutable = true;
                outcome.error_field = descriptor.name;
                break;
            }
            const restart = descriptor.change == .restart;
            pending = pending or restart;
            var found = false;
            for (components.items) |*component| if (std.mem.eql(u8, component.owner, descriptor.owner)) {
                found = true;
                if (restart) component.phase = .pending_restart;
            };
            if (!found) try components.append(.{ .owner = descriptor.owner, .generation = next_generation, .phase = if (restart) .pending_restart else .applied });
        }
        const compatible = if (immutable) false else matchingArtifacts(init, loaded.config, state.artifacts) catch false;
        if (immutable) outcome.error_code = "InitializationSettingChanged" else if (!compatible) outcome.error_code = "ConfigurationArtifactMismatch" else {
            // Prepare all live values (including Host validation in Config) first.
            // There are no cross-process live appliers in this profile; remaining
            // owners explicitly require restart and are never silently launched.
            const observed = try wire.call(q.protocol.Growth.Response, "/v1/query", signed.authority);
            if (observed.position < state.position) return error.AuthorityRollback;
            state.position = observed.position;
            state.active.gateway_allowed_hosts = loaded.config.gateway_allowed_hosts;
            state.active.query = loaded.config.query;
            state.configured = loaded.config;
            state.file = loaded.file;
            const applied_origins = try a.dupe(R.Origin, state.origins);
            for (Config.settings.descriptors, 0..) |descriptor, i| if (descriptor.change == .reload or descriptor.change == .new_session or try valueEqual(a, R.get(before, descriptor.name), R.get(after, descriptor.name))) {
                applied_origins[i] = next_origins[i];
            };
            state.origins = applied_origins;
            state.configured_origins = next_origins;
            state.inputs = loaded.inputs;
            state.generation = next_generation;
            outcome.generation = state.generation;
            outcome.phase = if (pending) .pending_restart else .applied;
            outcome.components = components.items;
        }
    }
    state.revision = outcome.ordinal;
    state.pending = .{ .request = request, .principal = outcome.principal, .role = signed.authority.query.kind.authorization.role, .outcome = outcome };
    try self.save(a, state.*);
    try self.finish(a, state);
    return outcome;
}

fn matchingArtifacts(init: std.process.Init, config: Config, identity: Config.Identity) !bool {
    inline for (@typeInfo(Config.Executables).@"struct".field_names) |name| {
        if (comptime std.mem.eql(u8, name, "board")) {
            const path = config.executables.board orelse return false;
            const expected = identity.board orelse return false;
            if (!std.mem.eql(u8, &try Config.digest(init, path), &expected)) return false;
        } else if (!std.mem.eql(u8, &try Config.digest(init, @field(config.executables, name)), &@field(identity, name))) return false;
    }
    return true;
}

fn origins(a: std.mem.Allocator, loaded: Config.Loaded) ![]const R.Origin {
    const result = try a.alloc(R.Origin, Config.settings.descriptors.len);
    for (Config.settings.descriptors, result) |descriptor, *origin| {
        if (R.get(loaded.inputs.environment, descriptor.name) != null) {
            origin.* = .{ .source = .environment, .name = R.environmentSource(loaded.inputs.environment_names, try R.environmentName(a, descriptor.name)) };
        } else if (R.get(loaded.file, descriptor.name) != null) {
            origin.* = .{ .source = .file, .name = loaded.inputs.path };
            for (loaded.locations) |location| if (std.mem.eql(u8, location.name, descriptor.name)) {
                origin.line = location.line;
                origin.column = location.column;
                break;
            };
        } else origin.* = .{ .source = if (descriptor.default_json == null or std.mem.eql(u8, descriptor.name, "board.public_origin")) .derived else .defaults };
    }
    return result;
}
