//! Application-owned process mechanics, independent of native protocol tests.
test {
    _ = @import("Options.zig");
    _ = @import("Undo.zig");
    _ = @import("EditorState.zig");
    _ = @import("SqlInput.zig");
    _ = @import("Settings.zig");
    _ = @import("Show.zig");
    _ = @import("Results.zig");
    _ = @import("ResultJson.zig");
    _ = @import("Output.zig");
    _ = @import("Style.zig");
    _ = @import("server/Gateway.zig");
    _ = @import("server/Config.zig");
    _ = @import("server/ArtifactHash.zig");
    _ = @import("server/Process.zig");
    _ = @import("server/Applications.zig");
    _ = @import("server/Hosts.zig");
}
