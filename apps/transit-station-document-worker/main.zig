//! Fenced Document service over public Station calls. No direct storage, CRDT
//! authority in local files, implicit ownership acquisition or effect transport.
const std = @import("std");
const doc = @import("transit_station_document");
const telemetry = @import("telemetry");
const s = doc.station;
const p = s.protocol;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    pid: u64,
    generation: u64,
    activation_directory: []const u8,
    association: []const u8 = "state",
    document: u64,
    type_revision: u32 = 1,
    policies: []const doc.Remote.Policy = &.{},
    node_limit: u32 = 512,
    max_steps: u32 = 1024,
    mode: enum { create, run, checkpoint, window, reject, retire, collect } = .run,
    job: u64 = 0,
    merge_window: u64 = 0,
    retired_cleanup: bool = false,
    checkpoint_cleanup: bool = false,
};
const Control = union(enum) {
    create,
    advance,
    checkpoint: u64,
    window: u64,
    reject: u64,
    retire,
    collect: struct { job: u64, retired: bool, checkpoint: bool },
};
const Driver = struct {
    server: s.GenServer,
    reader: s.client.ResourceReader,
    config: Config,
    io: std.Io,
    gpa: std.mem.Allocator,
    complete: bool = false,
    committed: u32 = 0,
    fn service(self: *Driver, resource: u64) doc.Service {
        return .{ .resource = resource, .document = self.config.document };
    }
    fn policy(self: *Driver, caller: u64) doc.Remote.Policy {
        for (self.config.policies) |allowed| if (allowed.caller == caller) return allowed;
        return .{ .caller = 0, .resource = 0, .replica = 0, .revision = 0 };
    }
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
        const self: *Driver = @ptrCast(@alignCast(raw.?));
        const service_ = self.service(turn.view.resource);
        self.complete = false;
        if (frame.kind == .call) {
            const caller = try s.Frame.source(turn.delivery.input);
            _ = try doc.Remote.admit(service_, turn, self.policy(caller), self.reader, self.config.node_limit);
            return;
        }
        if (frame.kind != .cast) return error.UnexpectedDocumentInput;
        switch (turn.delivery.input.origin) {
            .external => |origin| if (origin.principal != self.config.principal) return error.UnexpectedDocumentInput,
            else => return error.UnexpectedDocumentInput,
        }
        const parsed = try std.json.parseFromSlice(Control, self.gpa, frame.payload.slice(), .{});
        defer parsed.deinit();
        switch (parsed.value) {
            .create => {
                try service_.create(turn, self.config.type_revision, .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 });
                self.complete = true;
            },
            .advance => {
                const head = try service_.head(turn);
                if (head.active_job != 0) {
                    const route = try doc.Remote.route(service_, turn, head.active_job);
                    _ = try doc.Remote.advance(service_, turn, self.policy(route.caller), self.reader);
                }
            },
            .checkpoint => |id| {
                const saved = doc.Checkpoint.inspect(service_, turn, id) catch |err| switch (err) {
                    error.DocumentCheckpointNotFound => {
                        try doc.Checkpoint.begin(service_, turn, id);
                        return;
                    },
                    else => return err,
                };
                self.complete = saved.phase == .complete or (try doc.Checkpoint.step(service_, turn, id)) == .complete;
            },
            .window => |revisions| {
                try service_.configureMergeWindow(turn, revisions);
                self.complete = true;
            },
            .reject => |id| {
                try doc.Remote.reject(service_, turn, id, .denied);
                self.complete = true;
            },
            .retire => {
                try service_.retire(turn);
                self.complete = true;
            },
            .collect => |operation| {
                self.complete = if (operation.checkpoint)
                    if (operation.retired) try doc.Checkpoint.collectRetired(service_, turn, operation.job) else try doc.Checkpoint.collectRejected(service_, turn, operation.job)
                else if (operation.retired) try service_.collectRetired(turn, operation.job) else try service_.collectRejected(turn, operation.job);
            },
        }
    }
    fn drive(self: *Driver) !void {
        for (0..32) |_| {
            const result = self.server.step(.{ .context = self, .handle = handle }, @as(u64, @intCast(std.Io.Clock.real.now(self.io).toMilliseconds())) + 30000) catch |err| {
                if (self.server.pending == null or err == error.AccessDenied or err == error.StaleActivation or err == error.Rejected or err == error.Conflict) return err;
                continue; // Only the existing exact pending operation may retry.
            };
            switch (result) {
                .committed => {
                    self.committed += 1;
                    return;
                },
                .idle => return error.InputNotDelivered,
                .blocked => return self.server.handler_error orelse error.DocumentWorkerBlocked,
                .progress => {},
            }
        }
        return error.AuthorityOutcomeUnknown;
    }
    fn tick(self: *Driver, control: Control) !void {
        var bytes: [s.Frame.max_payload]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try std.json.Stringify.value(control, .{}, &writer);
        const sequence = (try self.reader.query(.{ .capabilities = {} })).principal_sequence + 1;
        const signed = try p.Growth.sign(.{ .realm = self.config.realm, .principal = self.config.principal, .sequence = sequence, .command = .{ .send = .{ .pid = self.config.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init(writer.buffered()) }).encode() } } }, self.reader.key);
        for (0..3) |_| {
            _ = self.reader.wire.submit(signed) catch |err| {
                if (err == error.AccessDenied or err == error.StaleActivation or err == error.Rejected or err == error.Conflict) return err;
                continue;
            };
            return self.drive();
        }
        return error.AuthorityOutcomeUnknown;
    }
};
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-station-document-worker", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    diagnostics.event(.{ .name = "service.starting" });
    defer diagnostics.event(.{ .name = "service.stopped" });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(16384));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.principal == 0 or config.principal > p.max_counter or config.realm == 0 or config.pid == 0 or config.pid > p.max_counter or config.generation == 0 or config.document == 0 or config.type_revision == 0 or config.node_limit == 0 or config.node_limit > 65536 or config.max_steps == 0 or config.max_steps > 10000 or config.policies.len > 64) return error.InvalidConfiguration;
    if (config.mode == .checkpoint and (config.job == 0 or config.job >= (@as(u64, 1) << 63))) return error.InvalidConfiguration;
    if ((config.mode == .reject or config.mode == .collect) and config.job == 0) return error.InvalidConfiguration;
    for (config.policies, 0..) |policy, index| {
        if (policy.caller == 0 or policy.caller > p.max_counter or policy.resource == 0 or policy.resource > p.max_counter or policy.replica == 0 or policy.revision == 0) return error.InvalidConfiguration;
        for (config.policies[0..index]) |previous| if (previous.caller == policy.caller or previous.replica == policy.replica) return error.AmbiguousDocumentPolicy;
    }
    var key = try s.client.readKey(init.gpa, init.io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var wire = s.client.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = 5000;
    wire.observer = diagnostics;
    var driver: Driver = .{ .server = try s.GenServer.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, config.association), .reader = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key }, .config = config, .io = init.io, .gpa = init.gpa };
    driver.server.failure_policy = .stop;
    _ = try driver.server.session.receive();
    const marker = try std.fmt.allocPrint(init.gpa, "{s}/{d}-{d}-{d}.activation", .{ config.activation_directory, config.realm, config.pid, config.generation });
    defer init.gpa.free(marker);
    const file = std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired;
        return err;
    };
    file.close(init.io);
    const association = (try driver.server.session.association(try p.Value.init(config.association))) orelse return error.MissingStateAssociation;
    const service = driver.service(association.resource);
    diagnostics.event(.{ .name = "service.ready", .realm = config.realm, .pid = config.pid, .generation = config.generation });
    var operation = diagnostics.begin(.application, null);
    errdefer operation.finish(.{ .name = "document.worker.operation", .operation = @tagName(config.mode), .level = .err, .outcome = .failed });
    wire.parent_context = operation.context;
    defer wire.parent_context = null;
    // Drain earlier inputs with their recorded control arguments before emitting
    // this invocation's operation. No lost tick is reinterpreted from local mode.
    for (0..config.max_steps) |_| {
        if (try driver.server.session.receive() == null) break;
        try driver.drive();
    } else return error.DocumentMailboxBudget;
    const control: Control = switch (config.mode) {
        .create => .create,
        .run => .advance,
        .checkpoint => .{ .checkpoint = config.job },
        .window => .{ .window = config.merge_window },
        .reject => .{ .reject = config.job },
        .retire => .retire,
        .collect => .{ .collect = .{ .job = config.job, .retired = config.retired_cleanup, .checkpoint = config.checkpoint_cleanup } },
    };
    driver.complete = false;
    var completed = false;
    for (0..config.max_steps) |_| {
        if (config.mode == .run) {
            var reader = try driver.reader.open(service.resource);
            if ((try service.head(&reader)).active_job == 0) {
                completed = true;
                break;
            }
        }
        try driver.tick(control);
        if (config.mode != .run and driver.complete) {
            completed = true;
            break;
        }
    }
    var reader = try driver.reader.open(service.resource);
    const head = try service.head(&reader);
    var buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try output.interface.print("{{\"phase\":\"{s}\",\"document\":\"{d}\",\"revision\":\"{d}\",\"epoch\":\"{d}\",\"floor\":\"{d}\",\"active_job\":\"{d}\",\"retired\":{},\"committed\":{d}}}\n", .{ if (completed) "complete" else "progress", config.document, head.state.revision, head.state.epoch, head.floor, head.active_job, head.retired, driver.committed });
    try output.interface.flush();
    operation.finish(.{ .name = "document.worker.operation", .operation = @tagName(config.mode), .outcome = .ok, .realm = config.realm, .pid = config.pid, .generation = config.generation });
}
