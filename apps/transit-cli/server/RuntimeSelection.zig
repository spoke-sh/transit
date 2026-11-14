//! Explicit same-definition replacement of the external server artifact.
//! Original publication, authority, configuration and application identities stay
//! bound. A binary hash is deployment intent, never protocol compatibility proof.
const std = @import("std");
const Config = @import("Config.zig");
const Installation = @import("Installation.zig");

pub fn validate(config: Config, record: Installation.Record, proposed: Config.Identity) !void {
    const current = if (record.runtime) |runtime| runtime.identity else record.identity;
    if (config.startup.replace_runtime) |intent| {
        if (config.external == null or !record.complete) return error.InvalidRuntimeReplacement;
        inline for (@typeInfo(Config.Executables).@"struct".field_names) |name| {
            if (@field(config.executables, name) != null) return error.InvalidRuntimeReplacement;
        }
        var from: [32]u8 = undefined;
        var to: [32]u8 = undefined;
        if (intent.from.len != 64 or intent.to.len != 64) return error.InvalidRuntimeReplacement;
        _ = std.fmt.hexToBytes(&from, intent.from) catch return error.InvalidRuntimeReplacement;
        _ = std.fmt.hexToBytes(&to, intent.to) catch return error.InvalidRuntimeReplacement;
        if (!std.mem.eql(u8, &to, &proposed.cli) or !std.mem.eql(u8, &current.config, &proposed.config)) return error.InstallationIdentityMismatch;
        if (std.meta.eql(current, proposed)) {
            const previous = if (record.runtime) |runtime| runtime.previous else current.cli;
            if (!std.mem.eql(u8, &from, &previous)) return error.InstallationIdentityMismatch;
            return;
        }
        if (!std.mem.eql(u8, &from, &current.cli) or std.mem.eql(u8, &from, &to)) return error.InstallationIdentityMismatch;
        // A role override is not replaceable through an aggregate binary pin.
        // Verify that the old selection also consisted of embedded roles.
        inline for (@typeInfo(Config.Executables).@"struct".field_names) |name| {
            var hash = std.crypto.hash.sha2.Sha256.init(.{});
            hash.update("transit.local.role.v1\x00");
            hash.update(&@import("transit_query").protocol.Growth.definition_bytes);
            hash.update(name);
            hash.update("\x00embedded\x00");
            hash.update(&current.cli);
            if (!std.mem.eql(u8, &hash.finalResult(), &@field(current, name))) return error.InvalidRuntimeReplacement;
        }
        return;
    }
    if (!std.meta.eql(current, proposed)) return error.InstallationIdentityMismatch;
}
