//! Borrowed output for one explicit authorization disclosure. The host keeps
//! cells alive until the next pull or close; wire engines never retain a batch
//! across a suspended portal or another command.
const g = @import("root.zig");
const Self = @This();
pub const max_rows = g.query.TableQuery.Batch.max_rows;
rows: [max_rows]?[]const g.fuze.Types.Values.Cell = @splat(null),
len: u8 = 0,
complete: bool = false,
pub fn validate(self: Self, requested: u8) !void {
    if (requested == 0 or requested > max_rows or self.len > requested or (self.len == 0 and !self.complete)) return error.InvalidReadBatch;
    for (self.rows, 0..) |row, i| if ((row != null) != (i < self.len)) return error.InvalidReadBatch;
}
