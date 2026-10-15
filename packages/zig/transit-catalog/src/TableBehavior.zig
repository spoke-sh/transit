//! General Table owner: exact inline commands, bounded uploaded bodies and
//! durable self-continuations over the same catalog resource and authority.
const std = @import("std");
const c = @import("root.zig");
const s = c.station;
const p = c.protocol;
const Control = c.TableControl;
const Command = c.TableCommand;
const Self = @This();
allocator: std.mem.Allocator,
configuration: c.TableCatalogRecords.Configuration,
registration: ?p.Authorization.Action = null,
namespace: ?u64 = null,
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn catalog(self: *Self) c.TableCatalog {
    return .{ .configuration = self.configuration, .registration = &self.registration, .namespace = self.namespace };
}
fn uploads(self: *Self) c.TableUpload {
    return .{ .catalog = self.catalog() };
}
fn administrator(self: *Self, turn: *s.Turn) bool {
    return turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == self.configuration.administrator;
}
fn check(self: *Self, turn: *s.Turn) !bool {
    try self.configuration.validate();
    if (turn.delivery.realm != self.configuration.scope.realm or turn.delivery.pid != self.configuration.owner or turn.view.resource != self.configuration.scope.resource) return error.CatalogOwnerChanged;
    const value = (try turn.read(self.catalog().key('c', 0, 0))) orelse return false;
    if (!std.meta.eql(try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', value), self.configuration)) return error.CatalogConfigurationChanged;
    return true;
}
fn initializer(self: *Self, turn: *s.Turn, command: Control.Command) bool {
    return command == .initialize and self.administrator(turn) and std.meta.eql(command.initialize, self.configuration);
}
fn disposition(self: *Self, turn: *s.Turn, outcome: @FieldType(Control.Disposition, "outcome")) !bool {
    const value: Control.Disposition = .{
        .scope = self.configuration.scope,
        .origin = switch (turn.delivery.input.origin) {
            .external => .external,
            .process => .process,
            .effect => .effect,
        },
        .principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0,
        .input = turn.delivery.input.position,
        .payload = try c.Model.fingerprint(turn.delivery.input.value),
        .outcome = outcome,
    };
    const key = self.catalog().key('e', value.input, 0);
    const encoded = try c.Records.encode('E', value);
    if (try turn.read(key)) |existing| {
        _ = try c.Records.decode(Control.Disposition, 'E', existing);
        if (!existing.eql(encoded)) return error.InvalidCatalogDisposition;
    } else try turn.write(key, encoded);
    return true;
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !self.initializer(turn, try Control.Command.decode(frame.payload))) return error.UninitializedCatalog;
    if (try self.check(turn)) return error.CatalogAlreadyPopulated;
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.catalog().initialize(turn);
    _ = try self.disposition(turn, .initialized);
}
fn rejectInput(raw: ?*anyopaque, turn: *s.Turn) !bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const initialized = try self.check(turn);
    const frame = s.Frame.decode(turn.delivery.input.value) catch return if (initialized) self.disposition(turn, .invalid_command) else error.UninitializedCatalog;
    if (frame.kind != .cast) return if (initialized) self.disposition(turn, .invalid_command) else error.UninitializedCatalog;
    if (std.mem.startsWith(u8, frame.payload.slice(), "TCQ1")) {
        if (!initialized) return error.UninitializedCatalog;
        const header = Command.inspect(frame.payload.slice()) catch return self.disposition(turn, .invalid_command);
        if (!std.meta.eql(header.scope, self.configuration.scope) or header.owner != self.configuration.owner) return self.disposition(turn, .identity_conflict);
        const valid_origin = switch (turn.delivery.input.origin) {
            .external => |origin| origin.principal == header.principal,
            .process => |origin| origin.pid == self.configuration.owner,
            else => false,
        };
        if (!valid_origin) return self.disposition(turn, .denied);
        return false;
    }
    const command = Control.Command.decode(frame.payload) catch return if (initialized) self.disposition(turn, .invalid_command) else error.UninitializedCatalog;
    if (!initialized) {
        if (!self.initializer(turn, command)) return error.UninitializedCatalog;
        return false;
    }
    if (!std.meta.eql(try command.scope(), self.configuration.scope)) return self.disposition(turn, .identity_conflict);
    if (turn.delivery.input.origin != .external and !((command == .drive or command == .schema) and turn.delivery.input.origin == .process and turn.delivery.input.origin.process.pid == self.configuration.owner)) return self.disposition(turn, .denied);
    if ((command == .initialize) and !self.administrator(turn)) return self.disposition(turn, .denied);
    return false;
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (!try self.check(turn)) return error.UninitializedCatalog;
    if (frame.kind != .cast) return error.InvalidCatalogCommand;
    const before = turn.decision;
    self.registration = null;
    self.namespace = null;
    self.apply(turn, frame.payload) catch |err| {
        turn.decision = before;
        if (turn.read_error != null) return err;
        const reason: @FieldType(Control.Disposition, "outcome") = switch (err) {
            error.CatalogDenied => .denied,
            error.CatalogIdentityConflict, error.CatalogScopeChanged, error.CatalogOwnerChanged, error.PublicationIdentityConflict => .identity_conflict,
            error.CatalogPolicyConflict => .stale_policy,
            error.InvalidCatalogCommand, error.InvalidTableCommand, error.InvalidTableUploadPart, error.InvalidSchemaCommand => .invalid_command,
            error.CatalogSchemaMissing => .blocked,
            error.CatalogDefinitionChanged, error.CatalogSourceChanged, error.TableRetired, error.TableBusy, error.TableNotFound, error.CatalogOperationNotFound, error.TableWriteNotFound, error.TableUploadNotFound, error.TableUploadNotSealed, error.TableUploadNotReady, error.TableUploadClosed, error.TableUploadGap, error.IncompletePublication, error.TableUploadStillActive, error.CatalogCleanupNotClosed, error.PublicationQuotaExceeded, error.PublicationTooLarge, error.CatalogAlreadyPopulated, error.CatalogDependencyConflict, error.CatalogDefinitionMissing => .blocked,
            else => return err,
        };
        _ = try self.disposition(turn, reason);
    };
}
fn continueUpload(self: *Self, turn: *s.Turn, upload: Control.Upload) !void {
    try turn.cast(self.configuration.owner, try (Control.Command{ .drive = upload }).encode());
}
fn apply(self: *Self, turn: *s.Turn, payload: p.Value) !void {
    if (std.mem.startsWith(u8, payload.slice(), "TCQ1")) return self.inlineCommand(turn, payload);
    const command = try Control.Command.decode(payload);
    if (!std.meta.eql(try command.scope(), self.configuration.scope)) return error.CatalogScopeChanged;
    switch (command) {
        .initialize => {
            if (!self.initializer(turn, command)) return error.CatalogDenied;
            if (try turn.read(self.catalog().key('e', turn.delivery.input.position, 0)) == null) try self.catalog().initialize(turn);
            _ = try self.disposition(turn, .initialized);
        },
        .dependency => |change| {
            try self.catalog().setDependency(turn, change.dependency, change.present);
            _ = try self.disposition(turn, .dependency_applied);
        },
        .cancel_ddl => |ref| _ = try self.catalog().cancel(turn, ref.principal, ref.operation, ref.digest),
        .cleanup_ddl => |ref| _ = try self.catalog().cleanup(turn, ref.principal, ref.operation, ref.digest),
        .cancel_dml => |ref| _ = try self.catalog().cancelMutationReference(turn, ref.reference),
        .cleanup_dml => |ref| _ = try self.catalog().cleanupMutationReference(turn, ref.reference),
        .begin => |value| _ = try self.uploads().begin(turn, try Command.inspect(&value.header), value.namespace, value.spec),
        .part => |value| _ = try self.uploads().append(turn, value.upload.namespace, value.offset, value.bytes[0..value.length]),
        .seal => |value| {
            _ = self.uploads().seal(turn, value.namespace) catch |err| switch (err) {
                error.InvalidPublicationDigest => return error.InvalidTableCommand,
                else => return err,
            };
            try self.continueUpload(turn, value);
        },
        .drive => |value| {
            const upload = try self.uploads().executionStatus(turn, value.namespace);
            if (upload.phase == .sealed) {
                _ = try self.uploads().bind(self.allocator, turn, value.namespace);
                try self.continueUpload(turn, value);
            } else if (!try self.catalog().executeUploaded(self.allocator, turn, value.namespace)) try self.continueUpload(turn, value);
        },
        .cancel_upload => |value| _ = try self.uploads().cancel(turn, value.namespace),
        .collect_upload => |value| _ = try self.uploads().collect(turn, value.namespace),
        .schema => |value| {
            const result = try (c.SchemaCatalog{ .configuration = self.configuration, .registration = &self.registration }).apply(turn, value);
            if (result.state == .scanning) try turn.cast(self.configuration.owner, try command.encode());
        },
    }
}
fn inlineCommand(self: *Self, turn: *s.Turn, payload: p.Value) !void {
    const header = try Command.inspect(payload.slice());
    self.namespace = header.namespace;
    const continuation = turn.delivery.input.origin == .process;
    if (continuation) {
        if (turn.delivery.input.origin.process.pid != self.configuration.owner) return error.CatalogDenied;
    } else if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != header.principal) return error.CatalogDenied;
    try self.catalog().bindCommand(turn, header);
    var basis = try self.catalog().commandBasis(self.allocator, turn, header.principal, header, .execute);
    defer if (basis) |*value| value.deinit();
    var command = Command.decode(self.allocator, payload.slice(), if (basis) |*value| value.borrow() else null) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.InvalidTableCommand,
    };
    defer command.deinit();
    const terminal = switch (command.body.request) {
        .ddl => |request| (if (continuation) try self.catalog().continueDdl(self.allocator, turn, request) else try self.catalog().step(self.allocator, turn, request)).terminal(),
        .dml => |request| (if (continuation) try self.catalog().continueMutation(self.allocator, turn, request) else try self.catalog().mutate(self.allocator, turn, request)).state != .building,
    };
    if (!terminal) try turn.cast(self.configuration.owner, payload);
}
