const std = @import("std");

const help =
    \\kubectl transit — inspect Transit installations on Kubernetes
    \\
    \\  get installations [-A]                 Discover chart releases (node Deployments)
    \\  status --release NAME                  Inspect installation resources
    \\  get workloads --release NAME           Inspect Deployments, StatefulSets, Jobs, Pods
    \\  logs COMPONENT --release NAME [-f]     Read service logs (default tail: 100)
    \\  board --release NAME [--port-forward]  Report Board origin or forward it on loopback
    \\
    \\Options (after transit, before or after the command):
    \\  --kubeconfig PATH   --context NAME   --namespace NAME / -n NAME
    \\  --release NAME     --output json / -o json (get/status only)
    \\  --all-namespaces / -A (installation discovery only)
    \\  --follow / -f      --tail N (0..10000; logs only)
    \\  --timeout SECONDS  Query deadline, 1..120 (default: 15)
    \\  --help / -h        --version
    \\
    \\Components: node, board, maintenance, controller, ursula, initialize.
    \\Select with the NAMESPACE and RELEASE columns from get installations -A.
    \\--release is the Helm release name, not a namespace suffix or Transit PID.
    \\Namespace defaults to the selected kubeconfig context's namespace.
    \\Readiness and logs are Kubernetes observations, not Transit execution authority.
    \\Reference up deploys Transit; reference infra-up creates only provider infrastructure.
    \\Board authentication remains required. No Secrets are fetched or contexts changed.
    \\
;

const Command = enum { installations, status, workloads, logs, board };
const Options = struct {
    command: Command,
    kubeconfig: ?[]const u8 = null,
    context: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    release: ?[]const u8 = null,
    component: ?[]const u8 = null,
    all_namespaces: bool = false,
    json: bool = false,
    follow: bool = false,
    port_forward: bool = false,
    tail: ?u16 = null,
    timeout: u8 = 15,
};

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn dnsName(value: []const u8) !void {
    if (value.len == 0 or value.len > 63 or !std.ascii.isAlphanumeric(value[0]) or
        !std.ascii.isAlphanumeric(value[value.len - 1])) return error.InvalidName;
    for (value) |c| if (!(std.ascii.isLower(c) or std.ascii.isDigit(c) or c == '-')) return error.InvalidName;
}

fn optionValue(args: []const []const u8, i: *usize, inline_value: ?[]const u8) ![]const u8 {
    const value = inline_value orelse blk: {
        i.* += 1;
        if (i.* == args.len) return error.MissingOptionValue;
        break :blk args[i.*];
    };
    if (value.len == 0 or value[0] == '-') return error.MissingOptionValue;
    return value;
}

fn parse(args: []const []const u8) !Options {
    var options: Options = .{ .command = undefined };
    var words: [2][]const u8 = undefined;
    var count: usize = 0;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (!std.mem.startsWith(u8, arg, "-")) {
            if (count == words.len) return error.UnexpectedArgument;
            words[count] = arg;
            count += 1;
            continue;
        }
        const split = std.mem.findScalar(u8, arg, '=');
        const flag = arg[0 .. split orelse arg.len];
        const value = if (split) |at| arg[at + 1 ..] else null;
        if (eql(flag, "--kubeconfig")) {
            options.kubeconfig = try optionValue(args, &i, value);
        } else if (eql(flag, "--context")) {
            options.context = try optionValue(args, &i, value);
        } else if (eql(flag, "--namespace") or eql(flag, "-n")) {
            options.namespace = try optionValue(args, &i, value);
            try dnsName(options.namespace.?);
        } else if (eql(flag, "--release")) {
            options.release = try optionValue(args, &i, value);
            try dnsName(options.release.?);
        } else if (eql(flag, "--output") or eql(flag, "-o")) {
            if (!eql(try optionValue(args, &i, value), "json")) return error.UnsupportedOutput;
            options.json = true;
        } else if (eql(flag, "--tail")) {
            options.tail = std.fmt.parseInt(u16, try optionValue(args, &i, value), 10) catch return error.InvalidTail;
            if (options.tail.? > 10000) return error.InvalidTail;
        } else if (eql(flag, "--timeout")) {
            options.timeout = std.fmt.parseInt(u8, try optionValue(args, &i, value), 10) catch return error.InvalidTimeout;
            if (options.timeout == 0 or options.timeout > 120) return error.InvalidTimeout;
        } else if (value != null) {
            return error.UnknownOption;
        } else if (eql(flag, "--all-namespaces") or eql(flag, "-A")) {
            options.all_namespaces = true;
        } else if (eql(flag, "--follow") or eql(flag, "-f")) {
            options.follow = true;
        } else if (eql(flag, "--port-forward")) {
            options.port_forward = true;
        } else return error.UnknownOption;
    }
    if (count == 2 and eql(words[0], "get") and eql(words[1], "installations")) {
        options.command = .installations;
    } else if (count == 2 and eql(words[0], "get") and eql(words[1], "workloads")) {
        options.command = .workloads;
    } else if (count == 1 and eql(words[0], "status")) {
        options.command = .status;
    } else if (count == 1 and eql(words[0], "board")) {
        options.command = .board;
    } else if (count == 2 and eql(words[0], "logs")) {
        options.command = .logs;
        for ([_][]const u8{ "node", "board", "maintenance", "controller", "ursula", "initialize" }) |component| {
            if (eql(words[1], component)) options.component = component;
        }
        if (options.component == null) return error.UnknownComponent;
    } else return error.UnknownCommand;
    if (options.command != .installations and options.release == null) return error.ReleaseRequired;
    if (options.all_namespaces and (options.command != .installations or options.namespace != null)) return error.InvalidOptionCombination;
    if (options.command != .logs and (options.follow or options.tail != null)) return error.InvalidOptionCombination;
    if (options.command != .board and options.port_forward) return error.InvalidOptionCombination;
    if ((options.command == .board or options.command == .logs) and options.json) return error.InvalidOptionCombination;
    return options;
}

const Json = std.json.Value;
fn member(value: Json, key: []const u8) !Json {
    if (value != .object) return error.InvalidKubernetesResponse;
    return value.object.get(key) orelse error.InvalidKubernetesResponse;
}
fn string(value: Json) ![]const u8 {
    if (value != .string) return error.InvalidKubernetesResponse;
    return value.string;
}
fn items(value: Json) ![]const Json {
    const list = try member(value, "items");
    if (list != .array) return error.InvalidKubernetesResponse;
    return list.array.items;
}
fn one(value: Json) !Json {
    const list = try items(value);
    if (list.len == 0) return error.ResourceNotFound;
    if (list.len != 1) return error.AmbiguousResources;
    return list[0];
}
fn optional(value: Json, key: []const u8) Json {
    return member(value, key) catch .null;
}
fn label(value: Json, key: []const u8) []const u8 {
    return string(optional(optional(optional(value, "metadata"), "labels"), key)) catch "-";
}
fn integer(value: Json, fallback: i64) i64 {
    return if (value == .integer) value.integer else fallback;
}

const ViewRow = [6][]const u8;
const view_headers: ViewRow = .{ "NAMESPACE", "RELEASE", "COMPONENT", "KIND", "NAME", "OBSERVED" };

fn writeRow(out: *std.Io.Writer, row: ViewRow, widths: [6]usize) !void {
    for (row, 0..) |cell, column| {
        try out.writeAll(cell);
        if (column + 1 < row.len) try out.splatByteAll(' ', widths[column] - cell.len + 2);
    }
    try out.writeByte('\n');
}

fn writeTable(out: *std.Io.Writer, rows: []const ViewRow) !void {
    var widths: [6]usize = undefined;
    for (view_headers, 0..) |header, column| widths[column] = header.len;
    // Kubernetes names/labels and these status summaries are printable ASCII.
    // Bound padding and reject control sequences before emitting a partial table.
    for (rows) |row| for (row, 0..) |cell, column| {
        if (cell.len > 253) return error.InvalidKubernetesResponse;
        for (cell) |byte| if (byte < 0x20 or byte > 0x7e) return error.InvalidKubernetesResponse;
        widths[column] = @max(widths[column], cell.len);
    };
    try writeRow(out, view_headers, widths);
    for (rows) |row| try writeRow(out, row, widths);
}

const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: Options,
    out: *std.Io.Writer,
    err: *std.Io.Writer,
    exit_code: u8 = 1,

    fn args(self: App, component: ?[]const u8) !std.ArrayList([]const u8) {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.append(self.allocator, "kubectl");
        if (self.options.kubeconfig) |path| try argv.appendSlice(self.allocator, &.{ "--kubeconfig", path });
        if (self.options.context) |context| try argv.appendSlice(self.allocator, &.{ "--context", context });
        if (self.options.namespace) |namespace| try argv.appendSlice(self.allocator, &.{ "--namespace", namespace });
        if (self.options.all_namespaces) try argv.append(self.allocator, "--all-namespaces");
        // Selectors are assembled only from validated names, never raw expressions.
        const base = "app.kubernetes.io/name=transit";
        const release = if (self.options.release) |name|
            try self.allocator.print(",app.kubernetes.io/instance={s}", .{name})
        else
            "";
        const role = if (component) |name|
            try self.allocator.print(",app.kubernetes.io/component={s}", .{name})
        else
            "";
        try argv.appendSlice(self.allocator, &.{ "--selector", try self.allocator.print("{s}{s}{s}", .{ base, release, role }) });
        return argv;
    }

    fn sleep(io: std.Io, seconds: u8) anyerror!void {
        try io.sleep(.fromSeconds(seconds), .awake);
    }

    fn capture(self: App, argv: []const []const u8) anyerror!std.process.RunResult {
        var child = try std.process.spawn(self.io, .{
            .argv = argv,
            .stdin = .ignore,
            .stdout = .pipe,
            .stderr = .pipe,
            .pgid = 0,
        });
        const pid = child.id.?;
        defer {
            if (child.id != null) {
                // A credential helper may inherit pipes or ignore SIGTERM. Own
                // a separate query process group and force its shutdown on error.
                std.posix.kill(-pid, .KILL) catch {};
                child.kill(self.io);
            }
        }
        var buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
        var reader: std.Io.File.MultiReader = undefined;
        reader.init(self.allocator, self.io, buffer.toStreams(), &.{ child.stdout.?, child.stderr.? });
        defer reader.deinit();
        while (reader.fill(4096, .none)) |_| {
            if (reader.reader(0).buffered().len > 1024 * 1024 or
                reader.reader(1).buffered().len > 32 * 1024) return error.StreamTooLong;
        } else |failure| switch (failure) {
            error.EndOfStream => {},
            else => return failure,
        }
        try reader.checkAnyError();
        const term = child.wait(self.io) catch |failure| {
            // Pinned Zig childWaitPosix clears id/handles even when cancellation
            // interrupts wait4 before reaping. Restore the still-owned PID so the
            // error cleanup can kill and reap it; never signal a reaped process.
            if (failure == error.Canceled) child.id = pid;
            return failure;
        };
        return .{ .term = term, .stdout = try reader.toOwnedSlice(0), .stderr = try reader.toOwnedSlice(1) };
    }

    fn query(self: *App, resources: []const u8, component: ?[]const u8) !struct { raw: []const u8, value: Json } {
        var argv = try self.args(component);
        try argv.insertSlice(self.allocator, 1, &.{ "get", resources });
        try argv.appendSlice(self.allocator, &.{ "-o", "json", try self.allocator.print("--request-timeout={d}s", .{self.options.timeout}) });
        // Bound the entire command, including credential helpers and a child that
        // closes output before hanging. Guaranteed concurrency keeps this true on
        // single-CPU hosts. Cancellation kills/reaps the owned query process group.
        const Result = union(enum) { result: anyerror!std.process.RunResult, timeout: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(self.io, &results);
        defer select.cancelDiscard();
        try select.concurrent(.timeout, sleep, .{ self.io, self.options.timeout });
        try select.concurrent(.result, capture, .{ self.*, argv.items });
        const result = switch (try select.await()) {
            .result => |result| try result,
            .timeout => return error.QueryTimeout,
        };
        try self.err.writeAll(result.stderr);
        if (!result.term.success()) {
            self.exit_code = if (result.term == .exited) result.term.exited else 1;
            return error.KubectlFailed;
        }
        const value = try std.json.parseFromSlice(Json, self.allocator, result.stdout, .{ .allocate = .alloc_always });
        _ = try items(value.value);
        return .{ .raw = result.stdout, .value = value.value };
    }

    fn views(self: *App) !void {
        const result = try self.query(switch (self.options.command) {
            .installations => "deployments",
            .workloads => "deployments,statefulsets,jobs,pods",
            .status => "deployments,statefulsets,jobs,pods,services,persistentvolumeclaims",
            else => unreachable,
        }, if (self.options.command == .installations) "node" else null);
        const list = try items(result.value);
        if (list.len == 0 and self.options.command != .installations) return error.ResourceNotFound;
        if (self.options.json) return self.out.writeAll(result.raw);
        if (list.len == 0) return self.out.writeAll("No Transit installations found. Reference up deploys Transit; reference infra-up creates only provider infrastructure.\n");
        const rows = try self.allocator.alloc(ViewRow, list.len);
        for (list, rows) |item, *row| {
            const metadata = try member(item, "metadata");
            const kind = try string(try member(item, "kind"));
            const status = optional(item, "status");
            const spec = optional(item, "spec");
            const observed = if (eql(kind, "Deployment") or eql(kind, "StatefulSet"))
                try self.allocator.print("ready={d}/{d}", .{ integer(optional(status, "readyReplicas"), 0), integer(optional(spec, "replicas"), 1) })
            else if (eql(kind, "Job"))
                try self.allocator.print("succeeded={d}/{d}", .{ integer(optional(status, "succeeded"), 0), integer(optional(spec, "completions"), 1) })
            else
                string(optional(status, "phase")) catch "-";
            row.* = .{
                try string(try member(metadata, "namespace")), label(item, "app.kubernetes.io/instance"),
                label(item, "app.kubernetes.io/component"),    kind,
                try string(try member(metadata, "name")),      observed,
            };
        }
        try writeTable(self.out, rows);
        try self.err.writeAll("Kubernetes observations only; readiness does not establish Transit execution authority.\n");
        if (self.options.command == .installations) try self.err.writeAll("Select an installation with --namespace NAMESPACE --release RELEASE from the columns above.\n");
    }

    fn reportFailure(self: *App, failure: anyerror) !void {
        if (failure == error.KubectlFailed) return; // Keep kubectl's diagnostic and status.
        if (failure == error.ResourceNotFound) {
            const resource = if (self.options.command == .board) "Board resources" else "Transit resources";
            try self.err.print("kubectl transit: ResourceNotFound: no matching {s} for Helm release '{s}'", .{ resource, self.options.release.? });
            if (self.options.namespace) |namespace| {
                try self.err.print(" in namespace '{s}'.\n", .{namespace});
            } else {
                try self.err.writeAll(" in the current context's namespace (--namespace was not supplied).\n");
            }
            try self.err.writeAll("Discover installations with 'kubectl transit get installations -A' using the same context/kubeconfig.\nUse the NAMESPACE column for --namespace and RELEASE for --release; a namespace suffix is not a release name.\n");
            return;
        }
        try self.err.print("kubectl transit: {s}\n", .{@errorName(failure)});
    }

    fn replace(self: *App, argv: []const []const u8) !void {
        try self.out.flush();
        try self.err.flush();
        // Hand over the foreground process itself: terminal signals and exit
        // status reach kubectl directly, with no wrapper or detached child.
        return std.process.replace(self.io, .{ .argv = argv });
    }

    fn logs(self: *App) !void {
        var argv = try self.args(self.options.component);
        try argv.insert(self.allocator, 1, "logs");
        try argv.appendSlice(self.allocator, &.{ "--all-containers=true", "--prefix=true", "--max-log-requests=5", try self.allocator.print("--tail={d}", .{self.options.tail orelse 100}) });
        if (self.options.follow) try argv.append(self.allocator, "--follow");
        // No total deadline for intentional live streams; kubectl owns log I/O.
        try self.replace(argv.items);
    }

    fn board(self: *App) !void {
        const config = try one((try self.query("configmaps", "board")).value);
        const data = try string(try member(try member(config, "data"), "config.json"));
        const parsed = try std.json.parseFromSlice(Json, self.allocator, data, .{});
        const origin = try string(try member(parsed.value, "public_origin"));
        const uri = std.Uri.parse(origin) catch return error.InvalidBoardOrigin;
        if ((!eql(uri.scheme, "https") and !eql(uri.scheme, "http")) or uri.host == null or
            uri.user != null or uri.password != null or uri.query != null or uri.fragment != null or
            uri.path.percent_encoded.len != 0) return error.InvalidBoardOrigin;
        for (origin) |c| if (c < 0x21 or c > 0x7e) return error.InvalidBoardOrigin;
        if (!self.options.port_forward) return self.out.print("{s}\n", .{origin});
        const port = uri.port orelse 80;
        if (!eql(uri.scheme, "http") or !eql(uri.host.?.percent_encoded, "127.0.0.1") or port == 0) {
            try self.err.print("Board advertises {s}. Port-forward requires an http://127.0.0.1[:PORT] origin; use the advertised ingress. Board Host/Origin checks and authentication are preserved.\n", .{origin});
            return error.BoardOriginCannotBeForwarded;
        }
        const service = try one((try self.query("services", "board")).value);
        const metadata = try member(service, "metadata");
        const name = try string(try member(metadata, "name"));
        const namespace = try string(try member(metadata, "namespace"));
        try dnsName(name);
        try dnsName(namespace);
        const ports = try member(try member(service, "spec"), "ports");
        if (ports != .array) return error.InvalidKubernetesResponse;
        var http_port: ?i64 = null;
        for (ports.array.items) |entry| {
            if (eql(string(optional(entry, "name")) catch "", "http")) {
                if (http_port != null) return error.AmbiguousResources;
                const number = integer(optional(entry, "port"), 0);
                if (number < 1 or number > 65535) return error.InvalidKubernetesResponse;
                http_port = number;
            }
        }
        const remote = http_port orelse return error.BoardHttpPortNotFound;
        var argv = try self.args(null);
        // Port-forward uses the discovered Service's name and namespace, never a
        // guessed release-derived name or a selector unsupported by kubectl.
        argv.items.len -= 2;
        try argv.insert(self.allocator, 1, "port-forward");
        try argv.appendSlice(self.allocator, &.{ "--namespace", namespace, "--address=127.0.0.1", try self.allocator.print("service/{s}", .{name}), try self.allocator.print("{d}:{d}", .{ port, remote }) });
        try self.err.print("Board: {s} (existing sign-in required). Ctrl-C closes the tunnel.\n", .{origin});
        try self.replace(argv.items);
    }
};

pub fn main(init: std.process.Init) void {
    const allocator = init.arena.allocator();
    const args = init.minimal.args.toSlice(allocator) catch std.process.exit(1);
    var out_buffer: [4096]u8 = undefined;
    var err_buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &out_buffer);
    var err = std.Io.File.stderr().writerStreaming(init.io, &err_buffer);
    if (args.len == 1 or (args.len == 2 and (eql(args[1], "--help") or eql(args[1], "-h") or eql(args[1], "help")))) {
        out.interface.writeAll(help) catch {};
        out.interface.flush() catch {};
        return;
    }
    if (args.len == 2 and eql(args[1], "--version")) {
        out.interface.writeAll("kubectl-transit 0.1.0 (Kubernetes inspection)\n") catch {};
        out.interface.flush() catch {};
        return;
    }
    const options = parse(args[1..]) catch |failure| {
        err.interface.print("kubectl transit: {s}; see kubectl transit --help\n", .{@errorName(failure)}) catch {};
        err.interface.flush() catch {};
        std.process.exit(2);
    };
    var app: App = .{ .allocator = allocator, .io = init.io, .options = options, .out = &out.interface, .err = &err.interface };
    const result = switch (options.command) {
        .installations, .workloads, .status => app.views(),
        .logs => app.logs(),
        .board => app.board(),
    };
    result catch |failure| {
        app.reportFailure(failure) catch {};
        err.interface.flush() catch {};
        std.process.exit(app.exit_code);
    };
    out.interface.flush() catch std.process.exit(1);
    err.interface.flush() catch {};
}
