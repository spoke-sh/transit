//! Result attribution for an original native workload. Output cardinality and
//! native traversal coverage are separate. These values confer no permission,
//! retained read dependency or authority to acknowledge a Queue lease.
const std = @import("std");
const r = @import("root.zig");
const p = r.protocol;
const d = p.DataLifecycle;

pub const Observation = struct {
    intent: d.Content,
    schema: [32]u8,
    projection: [32]u8,
    selection: p.LogWorkloadResult.Selection,

    pub fn validate(self: Observation) !void {
        try self.intent.validate();
        try self.selection.validate();
        if (std.mem.allEqual(u8, &self.schema, 0) or std.mem.allEqual(u8, &self.projection, 0)) return error.InvalidWorkloadObservation;
    }
};

pub const Completion = struct {
    intent: d.Content,
    position: p.LogWorkloadResult.Position,

    pub fn validateShape(self: Completion) !void {
        try self.intent.validate();
        switch (self.position) {
            .append => {},
            inline .consume, .claim => |cursor| try cursor.validate(),
        }
    }
    pub fn validate(self: Completion, observation: Observation, rows: u64) !void {
        try self.validateShape();
        try observation.validate();
        if (!std.meta.eql(self.intent, observation.intent)) return error.WorkloadResultConflict;
        if (!try self.position.complete(observation.selection)) return error.IncompleteWorkloadCoverage;
        switch (self.position) {
            .append => |ordinal| if (rows != ordinal) return error.InvalidWorkloadResultCount,
            .claim => |cursor| if (rows != cursor.next) return error.InvalidWorkloadResultCount,
            // A Stream predicate may remove rows; gaps and timestamp filtering
            // also leave native coverage distinct from the offset interval.
            .consume => |cursor| if (rows > cursor.coverage.rows) return error.InvalidWorkloadResultCount,
        }
    }
};
