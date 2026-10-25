#pragma once
#include "internal.hpp"
#include "logical_internal.hpp"
#include <transit/catalog.h>

// Saved values own their complete binding, including all authorization
// prerequisites. Public views borrow only from these immutable owners.
struct CatalogSaved {
    transit::sdk::logical_detail::Json wire;
    std::string encoded;
    explicit CatalogSaved(const transit::sdk::logical_detail::Json &v)
        : wire(v), encoded(transit::sdk::logical_detail::encode(v, TRANSIT_SDK_STATION_CATALOG_ACTION_BYTES)) {}
};
struct transit_station_catalog_basis : CatalogSaved { using CatalogSaved::CatalogSaved; transit_station_catalog_basis_view value{}; };
struct transit_station_catalog_reference : CatalogSaved { using CatalogSaved::CatalogSaved; transit_station_catalog_reference_view value{}; };
struct transit_station_catalog_cursor : CatalogSaved { using CatalogSaved::CatalogSaved; transit_station_catalog_cursor_view value{}; };
struct transit_station_catalog_snapshot_owner : CatalogSaved { using CatalogSaved::CatalogSaved; transit_station_catalog_snapshot_owner_view value{}; };
struct transit_station_catalog_saved_intent : CatalogSaved { using CatalogSaved::CatalogSaved; };
struct transit_station_catalog_snapshot_acquisition : CatalogSaved { using CatalogSaved::CatalogSaved; transit_station_catalog_snapshot_acquisition_view value{}; std::unique_ptr<transit_station_catalog_snapshot_owner> owner; };
struct transit_station_catalog_snapshot : CatalogSaved { using CatalogSaved::CatalogSaved; transit_station_catalog_snapshot_view value{}; std::unique_ptr<transit_station_catalog_snapshot_owner> owner; };
struct transit_station_catalog_intent {
    transit::sdk::logical_detail::Json id, binding;
    transit_station_catalog_intent_view value{};
    std::unique_ptr<transit_station_catalog_saved_intent> saved;
};
struct transit_station_catalog_compiled { std::unique_ptr<transit_station_catalog_intent> intent; };
struct transit_station_catalog_metadata {
    transit::sdk::logical_detail::Arena arena;
    transit_station_catalog_metadata_view value{};
    std::unique_ptr<transit_station_catalog_basis> basis;
};
struct transit_station_catalog_namespace_page { transit_station_catalog_namespace_page_view value{}; std::unique_ptr<transit_station_catalog_cursor> next; };
struct transit_station_catalog_table_page { transit_station_catalog_table_page_view value{}; std::unique_ptr<transit_station_catalog_cursor> next; };
struct transit_station_catalog_observation { transit_station_catalog_observation_view value{}; std::unique_ptr<transit_station_catalog_reference> reference; };
struct transit_station_catalog_preview { transit_station_catalog_preview_view value{}; };
struct transit_station_catalog_snapshot_status {
    transit_station_catalog_snapshot_status_view value{};
    std::unique_ptr<transit_station_catalog_snapshot_owner> owner;
    std::unique_ptr<transit_station_catalog_snapshot> snapshot;
};
struct transit_station_catalog_snapshot_metadata {
    transit::sdk::logical_detail::Arena arena;
    transit_station_catalog_snapshot_metadata_view value{};
    std::unique_ptr<transit_station_catalog_snapshot> snapshot;
};
namespace transit::sdk::catalog_detail {
using namespace internal;
using logical_detail::Json;
using logical_detail::Arena;
using station_detail::Local;
using Scope = transit_station_catalog_scope;
using Connection = transit_station_catalog_connection;
using Configuration = transit_station_catalog_configuration;
using Authority = transit_station_catalog_authority;
using Subject = transit_station_catalog_subject;
using Schema = transit_station_catalog_schema;
using Column = transit_station_catalog_column;
using Identity = transit_station_catalog_identity;
using Basis = transit_station_catalog_basis;
using Request = transit_station_catalog_request;
using Metadata = transit_station_catalog_metadata;
using Cursor = transit_station_catalog_cursor;
using Reference = transit_station_catalog_reference;
using Intent = transit_station_catalog_intent;
using Observation = transit_station_catalog_observation;
using Preview = transit_station_catalog_preview;
using Capabilities = transit_station_catalog_capabilities;
using Description = transit_station_catalog_description;
using Saved = transit_station_catalog_saved_intent;
using Compiled = transit_station_catalog_compiled;
using Position = transit_station_catalog_position;
using Object = transit_station_catalog_object;
using Interpretation = transit_station_catalog_interpretation;
using Content = transit_station_catalog_content;
using Stored = transit_station_catalog_stored;
using Namespace = transit_station_catalog_namespace;
using NamespacePage = transit_station_catalog_namespace_page;
using TablePage = transit_station_catalog_table_page;
using Owner = transit_station_catalog_snapshot_owner;
using Acquisition = transit_station_catalog_snapshot_acquisition;
using Snapshot = transit_station_catalog_snapshot;
using SnapshotStatus = transit_station_catalog_snapshot_status;
using SnapshotMetadata = transit_station_catalog_snapshot_metadata;
constexpr size_t max_action = TRANSIT_SDK_STATION_CATALOG_ACTION_BYTES;
constexpr size_t max_result = TRANSIT_SDK_STATION_CATALOG_LINE_BYTES;
constexpr size_t max_intent = TRANSIT_SDK_STATION_CATALOG_INTENT_BYTES;
bool equal(const Json &, const Json &);
void validate(const char *schema, const Json &);
Json tag(const char *, Json = Json::object());
Json wide(uint64_t, bool zero = false);
Json small(uint64_t, bool zero = false);
bool same_scope(Scope, Scope);
bool same_position(Position, Position);
std::string name(const char *);
void current(const char *);
Json scope_wire(Scope);
Json connection_wire(Connection, uint64_t principal);
Json position_wire(Position);
Json object_wire(Object);
std::string schema_wire(const Schema &);
Schema schema(const Json &, Arena &);
std::string mutation_wire(const transit_station_catalog_action &, size_t maximum = max_action);
std::string request_wire(const Request &);
std::string kind_name(transit_station_catalog_kind);
Capabilities capabilities(const Json &);
Description description(const Json &, Connection, uint64_t);
Namespace namespace_value(const Json &, Connection, uint64_t expected = 0);
std::unique_ptr<Basis> basis(const Json &);
std::unique_ptr<Saved> saved(const Json &);
std::unique_ptr<Reference> reference(const Json &);
std::unique_ptr<Cursor> cursor(const Json &);
std::unique_ptr<Owner> owner(const Json &);
std::unique_ptr<Acquisition> acquisition(const Json &);
std::unique_ptr<Snapshot> snapshot(const Json &);
void owns(const Json &connection, Connection, uint64_t);
void cursor_check(const Cursor &, Connection, uint64_t, uint64_t namespace_id);
std::unique_ptr<Metadata> metadata(const Json &, Connection, uint64_t, const std::string &, uint64_t);
std::unique_ptr<NamespacePage> namespace_page(const Json &, Connection, uint64_t, const Cursor *);
std::unique_ptr<TablePage> table_page(const Json &, Connection, uint64_t, uint64_t, const Cursor *);
std::unique_ptr<Intent> intent(const Json &, const Saved &, Connection, uint64_t, const Identity * = nullptr);
std::unique_ptr<Compiled> compiled(const Json &, Connection, uint64_t, Identity);
std::unique_ptr<Reference> staged(const Json &, const Intent &, Connection, uint64_t);
std::unique_ptr<Observation> observation(const Json &, const Reference &);
std::unique_ptr<Preview> preview(const Json &, const Intent &);
std::unique_ptr<SnapshotStatus> snapshot_status(const Json &, const Owner &);
std::unique_ptr<SnapshotMetadata> snapshot_metadata(const Json &, const Snapshot &);
}
