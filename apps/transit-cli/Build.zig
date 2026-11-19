//! Transit command adapter for the pinned offline compiler/workspace package.
const std = @import("std");
const w = @import("transit_workspace");
const Diagnostic = @import("Diagnostic.zig");
pub const emitHumanFailure = w.Build.emitHumanFailure;
pub const emitFailure = w.Build.emitFailure;
pub const executableDigest = w.Build.executableDigest;
pub fn run(init: std.process.Init, options: w.Options, diagnostic: *Diagnostic) !void {
    return w.Build.run(init, options, diagnostic, @import("build_version").revision);
}
