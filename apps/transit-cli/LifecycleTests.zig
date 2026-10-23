//! Application-owned process mechanics, independent of native protocol tests.
test {
    _ = @import("Options.zig");
    _ = @import("SqlInput.zig");
    _ = @import("Settings.zig");
    _ = @import("Show.zig");
    _ = @import("Results.zig");
    _ = @import("Output.zig");
    _ = @import("Style.zig");
    _ = @import("TableRecovery.zig");
    _ = @import("server/Gateway.zig");
    _ = @import("server/Config.zig");
    _ = @import("server/Process.zig");
    _ = @import("server/Applications.zig");
    _ = @import("server/Hosts.zig");
}
