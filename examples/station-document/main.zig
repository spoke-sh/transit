//! A non-trading editor caller. Local changes are tentative; publication, calls
//! and replies become durable only through the shared Station implementation.
const std = @import("std");
const doc = @import("transit_station_document");
const s = doc.station;
const p = s.protocol;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: ?[]const u8 = null,
    bootstrap_timeout_ms: u32 = 120000,
    park_after_result_ms: u32 = 0,
    pid: u64 = 0,
    generation: u64 = 0,
    activation_directory: ?[]const u8 = null,
    writer: u64,
    resource: u64,
    document: u64 = 17,
    replica: u64,
    namespace: u64 = 1,
    policy_revision: u64 = 1,
    change: []const u8 = "",
    mode: enum { publish, receive, inspect, resynchronize },
};
const Driver = struct {
    server: s.GenServer,
    reader: s.client.ResourceReader,
    config: Config,
    change: doc.Change,
    reference: doc.Request.Reference,
    io: std.Io,
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
        const self: *Driver = @ptrCast(@alignCast(raw.?));
        if (frame.kind == .reply) {
            _ = try doc.Caller.accept(turn, self.config.namespace);
            return;
        }
        if (frame.kind != .cast or !frame.payload.eql(try self.reference.encode())) return error.UnexpectedDocumentInput;
        switch (turn.delivery.input.origin) {
            .external => |origin| if (origin.principal != self.config.principal) return error.UnexpectedDocumentInput,
            else => return error.UnexpectedDocumentInput,
        }
        _ = try doc.Caller.stage(turn, .{ .pid = self.config.writer, .resource = self.config.resource }, self.reference, self.change);
    }
    fn drive(self: *Driver) !void {
        for (0..32) |_| {
            const result = self.server.step(.{ .context = self, .handle = handle }, @as(u64, @intCast(std.Io.Clock.real.now(self.io).toMilliseconds())) + 30000) catch |err| {
                if (self.server.pending == null or err == error.AccessDenied or err == error.StaleActivation or err == error.Rejected or err == error.Conflict) return err;
                continue;
            };
            switch (result) {
                .committed => return,
                .idle => return error.InputNotDelivered,
                .blocked => return self.server.handler_error orelse error.DocumentCallerBlocked,
                .progress => {},
            }
        }
        return error.AuthorityOutcomeUnknown;
    }
    fn tick(self: *Driver) !void {
        const sequence = (try self.reader.query(.{ .capabilities = {} })).principal_sequence + 1;
        const signed = try p.Growth.sign(.{ .realm = self.config.realm, .principal = self.config.principal, .sequence = sequence, .command = .{ .send = .{ .pid = self.config.pid, .value = try (s.Frame{ .kind = .cast, .payload = try self.reference.encode() }).encode() } } }, self.reader.key);
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
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    if (args.len != 2 and !bootstrap) return error.ExpectedConfiguration;
    const gpa = init.arena.allocator();
    const bytes = if (bootstrap) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], gpa, .limited(16384));
    if (bytes.len > 16384) return error.ConfigurationTooLarge;
    const config = (try std.json.parseFromSlice(Config, gpa, bytes, .{})).value;
    if (config.principal == 0 or config.writer == 0 or config.resource == 0 or config.document == 0 or config.replica == 0) return error.InvalidConfiguration;
    if (config.park_after_result_ms > 300000 or (!bootstrap and config.park_after_result_ms != 0)) return error.InvalidConfiguration;
    var key = if (bootstrap) key: {
        if (config.seed_file != null) return error.BootstrapSeedForbidden;
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :key try p.Ed25519.KeyPair.generateDeterministic(seed);
    } else try s.client.readKey(gpa, init.io, config.seed_file orelse return error.MissingSeedFile);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var wire = s.client.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = 5000;
    if (bootstrap) try s.client.bootstrap.awaitGrowingOwnership(&wire, .{ .realm = config.realm, .pid = config.pid, .principal = config.principal, .generation = config.generation, .public_key = key.public_key.toBytes() }, key, config.bootstrap_timeout_ms);
    const reader: s.client.ResourceReader = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key };
    const client: doc.Client = .{ .source = reader };
    const identity: doc.Client.Identity = .{ .resource = config.resource, .document = config.document };
    var output_buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (config.mode == .resynchronize) {
        const sync = try client.resynchronize(identity, config.replica);
        try std.json.Stringify.value(sync, .{}, &output.interface);
    } else if (config.mode == .inspect) {
        const description = try client.describe(identity);
        const title = (try client.readPath(description.reference, &.{try doc.Model.Name.init("title")})).value;
        const body = (try client.readPath(description.reference, &.{try doc.Model.Name.init("body")})).value;
        var text: [512]u8 = undefined;
        var used: usize = 0;
        if (body.status() == .object and body.assignments[0].value == .text) {
            var cursor: doc.Service.PageCursor = .{ .revision = description.reference.revision, .object = body.assignments[0].id };
            for (0..128) |_| {
                const page = (try client.readSequence(description.reference, cursor)).value;
                for (page.items[0..page.len]) |item| {
                    if (item.values.len != 1 or item.values.assignments[0].value != .character) return error.UnexpectedTextConflict;
                    var scalar: [4]u8 = undefined;
                    const length = try std.unicode.utf8Encode(@intCast(item.values.assignments[0].value.character), &scalar);
                    if (length > text.len - used) return error.ExampleTextBudget;
                    @memcpy(text[used..][0..length], scalar[0..length]);
                    used += length;
                }
                cursor = page.next orelse break;
            } else return error.ExampleReadBudget;
        }
        try output.interface.print("{{\"revision\":\"{d}\",\"epoch\":\"{d}\",\"floor\":\"{d}\",\"title_status\":\"{s}\",\"alternatives\":{d},\"text\":", .{ description.reference.revision, description.reference.epoch, description.floor, @tagName(title.status()), title.len });
        try std.json.Stringify.value(text[0..used], .{}, &output.interface);
        try output.interface.writeByte('}');
    } else {
        if (config.pid == 0 or config.generation == 0 or config.change.len > 8192 or config.change.len % 2 != 0) return error.InvalidConfiguration;
        var encoded: [4096]u8 = undefined;
        const change = try doc.codec.decode(try std.fmt.hexToBytes(&encoded, config.change));
        if (change.document != config.document or change.replica != config.replica) return error.InvalidConfiguration;
        var server = try s.GenServer.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, "state");
        server.failure_policy = .stop;
        _ = try server.session.receive();
        const directory = config.activation_directory orelse return error.MissingActivationDirectory;
        const marker = try std.fmt.allocPrint(gpa, "{s}/{d}-{d}-{d}.activation", .{ directory, config.realm, config.pid, config.generation });
        const file = std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true }) catch |err| {
            if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired;
            return err;
        };
        file.close(init.io);
        const association = (try server.session.association(try p.Value.init("state"))) orelse return error.MissingStateAssociation;
        const reference = try doc.Request.prepare(association.resource, config.namespace, config.policy_revision, change);
        var driver: Driver = .{ .server = server, .reader = reader, .config = config, .reference = reference, .change = change, .io = init.io };
        if (config.mode == .publish) {
            for (0..64) |_| {
                var source = try reader.open(reference.resource);
                if (try doc.Caller.pending(&source, reference.namespace) != null) break;
                if (try driver.server.session.receive() != null) try driver.drive() else try driver.tick();
            } else return error.ExamplePublicationBudget;
            var source = try reader.open(reference.resource);
            const saved = (try doc.Caller.pending(&source, reference.namespace)).?;
            if (!std.meta.eql(saved.request, reference) or saved.target.pid != config.writer or saved.target.resource != config.resource) return error.ChangedCallConfiguration;
            try output.interface.print("{{\"phase\":\"called\",\"peer\":\"{d}\",\"correlation\":\"{d}\"}}", .{ saved.target.pid, saved.correlation });
        } else {
            for (0..64) |_| {
                var source = try reader.open(reference.resource);
                if (try doc.Caller.outcome(&source, reference.namespace) != null) break;
                try driver.drive();
            } else return error.OutcomeNotDelivered;
            var source = try reader.open(reference.resource);
            const result = (try doc.Caller.outcome(&source, reference.namespace)).?;
            try output.interface.print("{{\"phase\":\"{s}\",\"reason\":\"{s}\",\"job\":\"{d}\",\"revision\":\"{d}\"}}", .{ @tagName(result.status), @tagName(result.reason), result.job, if (result.basis) |basis| basis.revision else 0 });
        }
    }
    try output.interface.writeByte('\n');
    try output.interface.flush();
    if (config.park_after_result_ms != 0) try init.io.sleep(.fromMilliseconds(config.park_after_result_ms), .awake);
}
