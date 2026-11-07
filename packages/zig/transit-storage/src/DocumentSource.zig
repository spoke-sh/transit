//! Document-owned immutable chunks. Catalog reservation owns their lifetime.
const Chunks = @import("SourceChunks.zig").For(.document);
pub const pages = Chunks.pages;
pub const chunk_bytes = Chunks.chunk_bytes;
pub const step_bytes = Chunks.step_bytes;
pub const Chunk = Chunks.Chunk;
pub const key = Chunks.key;
pub const put = Chunks.put;
pub const read = Chunks.read;
pub const lookup = Chunks.lookup;
