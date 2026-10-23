//! Concrete storage mutations, independent of transport and execution policy.
const f = @import("transit_fuze");
pub const max_changes = 1024;
pub const Expect = enum { absent, present, any };
pub const Change = union(enum) {
    put: struct { row: f.TableRow.Row, expect: Expect = .any },
    replace: struct { key: []const u8, row: f.TableRow.Row },
    remove: []const u8,

    pub fn row(self: Change) ?f.TableRow.Row {
        return switch (self) {
            inline .put, .replace => |value| value.row,
            .remove => null,
        };
    }
};
pub const Ingestion = enum { point, bulk };
