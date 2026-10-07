#pragma once
#include "internal.hpp"
#include "logical_internal.hpp"
#include <transit/catalog.h>

struct transit_station_catalog_saved_intent { std::string definition; transit::sdk::internal::Bytes bytes; };
struct transit_station_catalog_compiled { transit_station_catalog_intent intent{}; transit_station_catalog_saved_intent saved; };
struct transit_station_catalog_prepared { transit::sdk::internal::Bytes bytes; };
struct transit_station_catalog_definition { transit::sdk::logical_detail::Arena arena; transit_station_catalog_definition_view value{}; };
struct transit_station_catalog_historical { transit::sdk::logical_detail::Arena arena; transit_station_catalog_historical_view value{}; };
struct transit_station_catalog_next {
    transit_station_catalog_next_kind kind{};
    std::unique_ptr<transit_station_catalog_prepared> prepared;
    std::optional<transit_station_catalog_outcome> outcome;
};
namespace transit::sdk::catalog_detail {
using namespace internal;
using logical_detail::Json;
using logical_detail::Arena;
using station_detail::Local;
using Scope = transit_station_catalog_scope;
using Connection = transit_station_catalog_connection;
using Configuration = transit_station_catalog_configuration;
using Policy = transit_station_catalog_policy;
using Schema = transit_station_catalog_schema;
using Column = transit_station_catalog_column;
using Identity = transit_station_catalog_identity;
using Basis = transit_station_catalog_basis;
using Request = transit_station_catalog_request;
using Metadata = transit_station_catalog_metadata;
using Head = transit_station_catalog_head;
using Cursor = transit_station_catalog_cursor;
using Page = transit_station_catalog_page;
using Reference = transit_station_catalog_reference;
using Intent = transit_station_catalog_intent;
using Outcome = transit_station_catalog_outcome;
using Upload = transit_station_catalog_upload;
using State = transit_station_catalog_state;
using Disposition = transit_station_catalog_disposition;
using Progress = transit_station_catalog_progress;
using Capabilities = transit_station_catalog_capabilities;
using Description = transit_station_catalog_description;
using Prepared = transit_station_catalog_prepared;
using Saved = transit_station_catalog_saved_intent;
using Compiled = transit_station_catalog_compiled;
using Definition = transit_station_catalog_definition;
using Historical = transit_station_catalog_historical;
using Next = transit_station_catalog_next;
constexpr size_t max_action = TRANSIT_SDK_STATION_CATALOG_ACTION_BYTES;
constexpr size_t max_result = TRANSIT_SDK_STATION_CATALOG_LINE_BYTES;
constexpr size_t max_intent = TRANSIT_SDK_STATION_CATALOG_INTENT_BYTES;
constexpr size_t max_prepared = TRANSIT_SDK_STATION_CATALOG_PREPARED_BYTES;
bool same_scope(Scope, Scope);
std::string name(const char *);
void current(const char *);
Json scope_wire(Scope);
Json connection_wire(Connection, uint64_t principal);
Json configuration_wire(const Configuration &);
Json policy_change_wire(const transit_station_catalog_policy_change &);
Json dependency_wire(const transit_station_catalog_dependency &, bool present);
Json cursor_wire(const Cursor &);
Json reference_wire(const Reference &);
Json identity_wire(Identity);
Json saved_wire(const Saved &);
Json prepared_wire(const Prepared &);
// This streams arrays into a bounded action, validating each logical value
// before appending it. A finite row count never permits an unbounded aggregate
// allocation of individually valid megabyte cells.
std::string schema_wire(const Schema &);
Schema schema(const Json &, Arena &);
// Only INSERT/UPDATE/DELETE payloads are encoded here. Source basis belongs to
// the caller envelope and is deliberately excluded from a saved mutation body.
std::string mutation_wire(const transit_station_catalog_action &, size_t maximum = max_action);
std::string request_wire(const Request &);
std::string kind_name(transit_station_catalog_kind);
std::string control_name(transit_station_catalog_control);
Capabilities capabilities(const Json &);
Description description(const Json &, Connection, uint64_t principal);
std::unique_ptr<Definition> definition(const Json &, Scope, const std::string &name);
std::unique_ptr<Historical> historical(const Json &, Scope, uint64_t object, uint64_t revision);
Page page(const Json &, Scope, const Cursor *previous);
Intent intent(const Json &, Connection, uint64_t principal);
std::unique_ptr<Compiled> compiled(const Json &, Connection, uint64_t principal, Identity, std::optional<transit_station_catalog_kind>, std::optional<uint64_t> object);
std::unique_ptr<Prepared> prepared(const Json &);
State state(const Json &, const Local &);
Disposition disposition(const Json &, const Local &);
Progress progress(const Json &, const Local &);
std::unique_ptr<Next> next(const Json &, const Local &);
}
