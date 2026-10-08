#include "table_internal.hpp"
using namespace transit::sdk::station_detail;
using namespace transit::sdk::internal;
namespace t = transit::sdk::table_detail;
namespace l = transit::sdk::logical_detail;
namespace c = transit::sdk::catalog_detail;
namespace {
std::string source(const transit_station_table &table) {
    return "{\"object\":" + quote(decimal(table.schema.object)) + ",\"version\":" + (table.retained ? version(*table.retained) : "null") + "}";
}
std::unique_ptr<transit_station_row> read_row(transit_station_turn &owner, const transit_station_table &table, const char *tag, const std::string &payload) {
    const auto result = t::apply(owner, tag, payload, "row"); result.fields({"definition", "row"}); t::check_basis(result.at("definition"), table);
    if (result.at("row").is_null()) return {}; return t::row(result.at("row"), table.schema.column_count);
}
std::optional<transit_station_table_status> read_status(transit_station_turn &owner, const transit_station_table_reference &reference, const char *tag) {
    const auto wire = l::encode(t::reference_wire(reference), t::bound);
    require(t::same_resource(owner.info.resource, reference.resource), "foreign-table-resource");
    const auto result = t::apply(owner, tag, wire, "mutation"); if (result.is_null()) return {};
    const auto status = t::status(result); require(t::same_reference(status.reference, reference), "table-status-reference"); return status;
}
}
extern "C" {
transit_sdk_error transit_station_table_open(transit_station_turn *turn, uint64_t object, const transit_station_read_version *retained, transit_station_table **out) {
    if (out) *out = nullptr;
    return with_turn(turn, true, [&](auto &owner) {
        require(object && out, "table-open");
        const auto result = t::apply(owner, "schema", "{\"object\":" + quote(decimal(object)) + ",\"version\":" + (retained ? version(*retained) : "null") + "}", "schema");
        result.fields({"schema", "basis"}); auto table = std::make_unique<transit_station_table>(owner);
        table->schema = c::schema(result.at("schema"), table->arena); table->basis = t::basis(result.at("basis"), owner.info.process.realm);
        require(table->schema.object == object && table->basis.object == object && t::same_resource(table->basis.resource, owner.info.resource), "table-object");
        if (retained) table->retained = *retained; *out = table.release();
    });
}
transit_sdk_error transit_station_table_create(transit_station_turn *turn, const transit_station_catalog_schema *schema, const transit_station_catalog_limits *limits, transit_station_table_creation *out) {
    if (out) *out = {};
    return with_turn(turn, false, [&](auto &owner) {
        require(schema && limits && out && limits->record_bytes && limits->staging_bytes && limits->staging_records, "table-create");
        const auto payload = "{\"realm\":" + decimal(owner.info.resource.realm) + ",\"resource\":" + decimal(owner.info.resource.resource) + ",\"schema\":" + c::schema_wire(*schema) +
            ",\"limits\":{\"record_bytes\":" + decimal(limits->record_bytes) + ",\"staging_bytes\":" + quote(decimal(limits->staging_bytes)) + ",\"staging_records\":" + decimal(limits->staging_records) + "}}";
        *out = t::creation(t::apply(owner, "create", payload, "created"));
    });
}
transit_sdk_error transit_station_table_schema(transit_station_table *table, const transit_station_catalog_schema **out) {
    if (out) *out = nullptr;
    return with_turn(table ? table->turn : nullptr, true, [&](auto &) { require(out, "table-schema"); *out = &table->schema; });
}
transit_sdk_error transit_station_table_read_basis(transit_station_table *table, transit_station_table_basis *out) {
    if (out) *out = {};
    return with_turn(table ? table->turn : nullptr, true, [&](auto &) { require(out, "table-basis"); *out = table->basis; });
}
transit_sdk_error transit_station_table_get(transit_station_table *table, transit_station_row_identity identity, transit_station_row **out) {
    if (out) *out = nullptr;
    return with_turn(table ? table->turn : nullptr, true, [&](auto &owner) {
        require(out, "table-get"); *out = read_row(owner, *table, "get", "{\"source\":" + source(*table) + ",\"identity\":" + quote(hex(Bytes(identity.bytes, identity.bytes + 20))) + "}").release();
    });
}
transit_sdk_error transit_station_table_get_key(transit_station_table *table, const transit_logical_cell_view *cells, size_t count, transit_station_row **out) {
    if (out) *out = nullptr;
    return with_turn(table ? table->turn : nullptr, true, [&](auto &owner) {
        require(out && cells && count && count <= 128 && count == table->schema.primary_key_count, "table-get-key");
        std::string key = "[";
        for (size_t i = 0; i < count; ++i) {
            if (i) key += ','; require(key.size() < t::bound, "table-action-bound"); key += l::encode(l::cell_json(cells[i]), t::bound - key.size());
        }
        *out = read_row(owner, *table, "get_key", "{\"source\":" + source(*table) + ",\"key\":" + key + "]}").release();
    });
}
transit_sdk_error transit_station_table_page_read(transit_station_table *table, const transit_station_cursor *after, size_t limit, transit_station_table_page **out) {
    if (out) *out = nullptr;
    return with_turn(table ? table->turn : nullptr, true, [&](auto &owner) {
        require(out && limit && limit <= 8 && limit <= owner.bridge->local.caps.table_page, "table-page-limit");
        if (after) require(!after->value.empty() && after->value.size() <= 2048, "table-cursor");
        const auto result = t::apply(owner, "page", "{\"source\":" + source(*table) + ",\"cursor\":" + cursor(after) + ",\"limit\":" + decimal(limit) + "}", "page");
        result.fields({"definition", "rows", "next"}); t::check_basis(result.at("definition"), *table);
        auto page = std::make_unique<transit_station_table_page>();
        for (const auto &row : result.at("rows").array(limit)) page->rows.push_back(t::row(row, table->schema.column_count));
        if (!result.at("next").is_null()) {
            page->next = result.at("next").string(); require(!page->next->empty() && page->next->size() <= 2048, "table-cursor");
        }
        *out = page.release();
    });
}
transit_sdk_error transit_station_row_inspect(const transit_station_row *row, transit_station_row_view *out) {
    if (out) *out = {}; return boundary([&] { require(row && out, "table-row"); *out = row->value; });
}
void transit_station_row_destroy(transit_station_row *row) { delete row; }
size_t transit_station_table_page_size(const transit_station_table_page *page) { return page ? page->rows.size() : 0; }
transit_sdk_error transit_station_table_page_row(const transit_station_table_page *page, size_t index, transit_station_row_view *out) {
    if (out) *out = {}; return boundary([&] { require(page && out && index < page->rows.size(), "table-page-row"); *out = page->rows[index]->value; });
}
transit_sdk_error transit_station_table_page_next(const transit_station_table_page *page, transit_station_cursor **out) {
    if (out) *out = nullptr; return boundary([&] { require(page && out, "table-page-next"); if (page->next) *out = new transit_station_cursor{*page->next}; });
}
void transit_station_table_page_destroy(transit_station_table_page *page) { delete page; }
transit_sdk_error transit_station_table_fail_read(transit_station_table *table, transit_sdk_error error) {
    return with_turn(table ? table->turn : nullptr, true, [&](auto &) {
        require(error.kind != TRANSIT_SDK_OK, "table-read-failure"); throw Failure{error};
    });
}
void transit_station_table_destroy(transit_station_table *table) { delete table; }
transit_sdk_error transit_station_table_mutation_prepare(transit_sdk_resource resource, uint64_t principal, uint64_t operation, const transit_station_catalog_schema *schema, const transit_station_table_mutation_spec *spec, transit_station_table_mutation **out) {
    if (out) *out = nullptr;
    return boundary([&] { require(schema && spec && out, "table-prepare"); *out = t::prepare(resource, principal, operation, *schema, *spec).release(); });
}
transit_sdk_error transit_station_table_prepare(transit_station_table *table, uint64_t principal, uint64_t operation, const transit_station_table_mutation_spec *spec, transit_station_table_mutation **out) {
    if (out) *out = nullptr;
    return with_turn(table ? table->turn : nullptr, false, [&](auto &) {
        require(out && spec && !table->retained, "table-prepare"); *out = t::prepare(table->basis.resource, principal, operation, table->schema, *spec).release();
    });
}
transit_sdk_error transit_station_table_mutation_import(transit_sdk_bytes bytes, transit_station_table_mutation **out) {
    if (out) *out = nullptr; return boundary([&] { require(out, "table-mutation-import"); *out = t::load(bytes).release(); });
}
transit_sdk_error transit_station_table_mutation_bytes(const transit_station_table_mutation *mutation, transit_sdk_bytes *out) {
    if (out) *out = {}; return boundary([&] { require(mutation && out, "table-mutation-bytes"); *out = {reinterpret_cast<const uint8_t *>(mutation->bytes.data()), mutation->bytes.size()}; });
}
transit_sdk_error transit_station_table_mutation_schema(const transit_station_table_mutation *mutation, const transit_station_catalog_schema **out) {
    if (out) *out = nullptr; return boundary([&] { require(mutation && out, "table-mutation-schema"); *out = &mutation->schema; });
}
transit_sdk_error transit_station_table_mutation_step(transit_station_turn *turn, const transit_station_table_mutation *mutation, transit_station_table_status *out) {
    if (out) *out = {};
    return with_turn(turn, false, [&](auto &owner) {
        require(mutation && out && t::same_resource(mutation->resource, owner.info.resource), "table-mutation-resource");
        const auto result = t::status(t::apply(owner, "mutate", mutation->bytes, "mutation")); const auto &r = result.reference;
        require(t::same_resource(r.resource, mutation->resource) && r.object == mutation->schema.object && r.principal == mutation->principal && r.operation == mutation->operation, "table-mutation-identity"); *out = result;
    });
}
void transit_station_table_mutation_destroy(transit_station_table_mutation *mutation) { delete mutation; }
transit_sdk_error transit_station_table_reference_import(transit_sdk_bytes bytes, transit_station_table_reference *out) {
    if (out) *out = {};
    return boundary([&] {
        require(out, "table-reference-import"); const auto value = l::parse(bytes, t::bound); const auto encoded = l::encode(value, t::bound);
        require(encoded.size() == bytes.size && std::equal(encoded.begin(), encoded.end(), reinterpret_cast<const char *>(bytes.data)), "table-saved-canonical");
        (void)t::action("status", encoded); *out = t::reference(value);
    });
}
transit_sdk_error transit_station_table_reference_export(const transit_station_table_reference *reference, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(reference && out, "table-reference-export"); *out = owned(json(l::encode(t::reference_wire(*reference), t::bound))); });
}
transit_sdk_error transit_station_table_status_read(transit_station_turn *turn, const transit_station_table_reference *reference, bool *found, transit_station_table_status *out) {
    if (out) *out = {}; if (found) *found = false;
    return with_turn(turn, true, [&](auto &owner) { require(reference && found && out, "table-status"); const auto result = read_status(owner, *reference, "status"); if (result) { *out = *result; *found = true; } });
}
transit_sdk_error transit_station_table_cancel(transit_station_turn *turn, const transit_station_table_reference *reference, transit_station_table_status *out) {
    if (out) *out = {};
    return with_turn(turn, false, [&](auto &owner) { require(reference && out, "table-cancel"); const auto result = read_status(owner, *reference, "cancel"); require(result.has_value(), "table-cancel-result"); *out = *result; });
}
}
