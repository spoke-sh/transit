#pragma once
#include "catalog_internal.hpp"
#include <transit/table.h>

struct transit_station_row {
    transit::sdk::logical_detail::Arena arena;
    transit_station_row_view value{};
};
struct transit_station_table_page {
    std::vector<std::unique_ptr<transit_station_row>> rows;
    std::optional<std::string> next;
};
struct transit_station_table {
    transit_station_turn *turn;
    transit::sdk::logical_detail::Arena arena;
    transit_station_catalog_schema schema{};
    transit_station_table_basis basis{};
    std::optional<transit_station_read_version> retained;
    explicit transit_station_table(transit_station_turn &owner) : turn(&owner) { transit_station_turn_retain(turn); }
    ~transit_station_table() { transit_station_turn_release(turn); }
};
struct transit_station_table_mutation {
    std::string bytes;
    transit::sdk::logical_detail::Arena arena;
    transit_station_catalog_schema schema{};
    transit_sdk_resource resource{};
    uint64_t principal{}, operation{};
};
namespace transit::sdk::table_detail {
using namespace station_detail;
using logical_detail::Json;
constexpr size_t bound = TRANSIT_SDK_STATION_HANDLER_ACTION_BYTES;
static_assert(bound == TRANSIT_SDK_STATION_HANDLER_TABLE_RESULT_BYTES && bound == TRANSIT_CLIENT_MAX_BODY);
Json parse(const std::string &);
Json apply(transit_station_turn &, const char *action, const std::string &payload, const char *result);
std::string action(const char *tag, const std::string &payload);
std::unique_ptr<transit_station_table_mutation> load(transit_sdk_bytes);
std::unique_ptr<transit_station_table_mutation> prepare(transit_sdk_resource, uint64_t principal, uint64_t operation, const transit_station_catalog_schema &, const transit_station_table_mutation_spec &);
Json reference_wire(const transit_station_table_reference &);
transit_station_table_reference reference(const Json &);
transit_station_table_status status(const Json &);
transit_station_table_creation creation(const Json &);
transit_station_table_basis basis(const Json &, uint64_t realm);
void check_basis(const Json &, const transit_station_table &);
std::unique_ptr<transit_station_row> row(const Json &, size_t columns);
bool same_resource(transit_sdk_resource, transit_sdk_resource);
bool same_reference(const transit_station_table_reference &, const transit_station_table_reference &);
}
