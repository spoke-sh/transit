const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const x = p.Transaction;
const D = s.TransactionDirectory;
pub const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
pub const identity: x.Identity = .{ .begin = .{ .scope = scope, .principal = 0, .operation = 100 }, .branch = 1 };
pub const content: p.DataLifecycle.Content = .{ .bytes = 100, .sha256 = @splat(5) };

pub fn participant(object: u64) D.Entry {
    return .{ .participant = .{ .state = .{
        .kind = .table,
        .guard = .{ .source = .{
            .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = object }, .revision = 1, .digest = @splat(1) },
            .accepted = .{ .partition = object + 10, .next_lsn = 5 },
        }, .changed_lsn = 3 },
        .access = .write,
    } } };
}

pub fn begin(directory: x.Directory) x.Begin {
    return .{
        .definition = p.Growth.current_definition,
        .identity = identity,
        .mode = .serializable,
        .selection = .explicit_objects,
        .objects = directory,
        .catalog = .{ .partition = 1, .next_lsn = 1 },
        .limits = .{ .resident_bytes = 65536, .workspace_bytes = 1048576, .participants = 1000, .statements = 1000, .savepoints = 32 },
    };
}

pub fn attempt(directory: x.Directory) x.Attempt {
    return .{
        .definition = p.Growth.current_definition,
        .transaction = identity,
        .operation = .{ .scope = scope, .principal = 0, .operation = 101 },
        .cut = content,
        .workspace = content,
        .participants = directory,
        .writes = directory.count,
        .last_statement = 1,
    };
}

pub fn preparation(object: u64, frozen: x.Attempt) D.Entry {
    const state = participant(object).participant.state;
    return .{ .prepared = .{
        .attempt = frozen,
        .target = participant(object).target(),
        .predecessor = participant(object).participant.guard(),
        .position = .{ .partition = state.guard.source.accepted.partition, .next_lsn = 6 },
        .successor = content,
    } };
}
