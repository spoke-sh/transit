//! Private trace adapter for the production editor reducer. Payload classes are
//! synthetic; the adapter supplies edits/history results and never performs I/O
//! effects or SQL. Terminal integration is separately exercised through PTYs.
const std = @import("std");
const Editor = @import("console_editor");
const Event = enum {
    Type,
    Move,
    Filter,
    Match,
    Miss,
    OpenUnique,
    OpenMenu,
    Refresh,
    Remote,
    LocalUnique,
    LocalMany,
    ReplyUniqueSame,
    ReplyUniqueChanged,
    ReplyManySame,
    ReplyManyChanged,
    ReplyInterrupted,
    Failed,
    Protected,
    Joined,
    Accept,
    AcceptEmpty,
    Enter,
    EnterEmpty,
    Dismiss,
    Cancel,
    Search,
    HistoryAccept,
    Clear,
    Executed,
};
const texts = [_][]const u8{ "", "draft", "match", "other" };
fn act(state: *Editor, event: Event) Editor.Effects {
    switch (event) {
        .Type => {
            state.checkpoint(.atomic, false);
            @memcpy(state.bytes[0..texts[1].len], texts[1]);
            state.length = texts[1].len;
            state.cursor = state.length;
            return state.transition(.changed);
        },
        .Move => {
            state.cursor = 0;
            return state.transition(.changed);
        },
        .Filter => {
            state.checkpoint(.atomic, false);
            @memcpy(state.search[0..texts[3].len], texts[3]);
            state.search_length = texts[3].len;
            return .{};
        },
        .Match => {
            @memcpy(state.bytes[0..texts[2].len], texts[2]);
            state.length = texts[2].len;
            state.cursor = state.length;
            state.history_position = 1;
            state.search_failed = false;
            return state.transition(.changed);
        },
        .Miss => {
            state.search_failed = true;
            return .{};
        },
        .OpenUnique => return state.transition(.{ .open = .unique }),
        .OpenMenu => return state.transition(.{ .open = .choose }),
        .Refresh => return state.transition(.refresh),
        .Remote => return state.transition(.remote),
        .LocalUnique, .LocalMany => return state.transition(.{ .local = event == .LocalUnique }),
        .ReplyUniqueSame, .ReplyUniqueChanged, .ReplyManySame, .ReplyManyChanged, .ReplyInterrupted => return state.transition(.{ .reply = .{
            .unique = event == .ReplyUniqueSame or event == .ReplyUniqueChanged or event == .ReplyInterrupted,
            .matches = event == .ReplyUniqueSame or event == .ReplyManySame or event == .ReplyInterrupted,
            .interrupted = event == .ReplyInterrupted,
        } }),
        .Failed => return state.transition(.failed),
        .Protected => return state.transition(.protected_failure),
        .Joined => return state.transition(.joined),
        .Accept, .AcceptEmpty => return state.transition(.{ .accept = event == .Accept }),
        .Enter, .EnterEmpty => return state.transition(.{ .enter = event == .Enter }),
        .Dismiss => return state.transition(.dismiss),
        .Cancel => return state.transition(.cancel),
        .Search => return state.transition(.search),
        .HistoryAccept => return state.transition(.history_accept),
        .Clear => return state.transition(.clear),
        .Executed => return state.transition(.executed),
    }
}
fn symbol(text: []const u8) !usize {
    for (texts, 0..) |value, index| if (std.mem.eql(u8, text, value)) return index;
    return error.UnmappedEditorText;
}
fn snapshot(state: *const Editor, effects: Editor.Effects, out: *std.Io.Writer) !void {
    try std.json.Stringify.value(.{ .state = .{
        .mode = state.mode,
        .request = state.request,
        .freshness = state.freshness,
        .intent = state.intent,
        .source = state.source,
        .text = try symbol(state.text()),
        .cursor = @intFromBool(state.cursor > 0),
        .saved = try symbol(state.draft[0..state.draft_length]),
        .savedCursor = @intFromBool(state.draft_cursor > 0),
        .filter = try symbol(state.search[0..state.search_length]),
        .matched = state.history_position != null,
        .failed = state.search_failed,
    }, .effects = effects }, .{}, out);
    try out.writeByte('\n');
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedTracePath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(32 * 1024 * 1024));
    defer init.gpa.free(bytes);
    var traces = try std.json.parseFromSlice([]const []const Event, init.gpa, bytes, .{});
    defer traces.deinit();
    if (traces.value.len > 8192) return error.TooManyTraces;
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    var state: Editor = .{};
    defer state.erase();
    for (traces.value) |events| {
        if (events.len > 128) return error.TraceTooLong;
        state.erase();
        state = .{};
        var effects: Editor.Effects = .{};
        for (events) |event| effects = act(&state, event);
        try snapshot(&state, effects, &output.interface);
    }
    try output.interface.flush();
}
