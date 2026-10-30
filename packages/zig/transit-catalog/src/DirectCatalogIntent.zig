//! Immutable complete Table DDL work. Catalog admission owns this dependency.
const Codec = @import("CatalogIntentCodec.zig").Codec(@import("DirectCatalogRecords.zig").Request, "catalog-intents", "TCATREQ1");
pub const Owned = Codec.Owned;
pub const key = Codec.key;
pub const stage = Codec.stage;
pub const load = Codec.load;
