#include "internal.hpp"
using namespace transit::sdk::station_detail;
using namespace transit::sdk::internal;
namespace transit::sdk::station_detail {
const char *cell_name(transit_station_cell_kind kind) {
    switch (kind) {
        case TRANSIT_CELL_INT64: return "int64"; case TRANSIT_CELL_BOOLEAN: return "boolean";
        case TRANSIT_CELL_UTF8: return "utf8"; case TRANSIT_CELL_BINARY: return "binary";
        default: fail(TRANSIT_SDK_INVALID_ARGUMENT, "cell-type");
    }
}
std::string cell_wire(transit_station_cell cell, size_t bound) {
    switch (cell.kind) {
        case TRANSIT_CELL_NULL: return "{\"null\":{}}";
        case TRANSIT_CELL_INT64: return "{\"int64\":" + quote(signed_decimal(cell.integer)) + "}";
        case TRANSIT_CELL_BOOLEAN: return std::string("{\"boolean\":") + (cell.boolean ? "true}" : "false}");
        case TRANSIT_CELL_UTF8: { const auto bytes = copy(cell.bytes, bound); return "{\"utf8\":" + quote(std::string(bytes.begin(), bytes.end())) + "}"; }
        case TRANSIT_CELL_BINARY: return "{\"binary\":" + quote(hex(copy(cell.bytes, bound))) + "}";
    }
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "cell-type");
}
void schema_check(const transit_station_table_schema &schema, const Caps &caps) {
    require(schema.id, "table-id"); cell_name(schema.value_type);
    require(!text(schema.key_name, caps.name).empty() && !text(schema.value_name, caps.name).empty(), "table-names");
}
std::unique_ptr<transit_station_table> capture_table(transit_station_turn &turn, const transit_station_table_schema &schema, const transit_station_read_version *retained) {
    const auto &caps = turn.bridge->local.caps; schema_check(schema, caps);
    const auto value = turn_apply(turn, "{\"table_schema\":{\"id\":" + decimal(schema.id) + ",\"version\":" + (retained ? version(*retained) : "null") + "}}");
    const auto &raw = turn.bridge->local.raw;
    if (raw.number(value, "schema/id") != schema.id || raw.field(value, "schema/key_name", true) != schema.key_name || raw.field(value, "schema/value_name", true) != schema.value_name ||
        raw.field(value, "schema/value_type", true) != cell_name(schema.value_type)) fail(TRANSIT_SDK_HANDLER_ERROR, "captured-table-schema");
    return std::make_unique<transit_station_table>(turn, schema.id, schema.value_type, basis(raw, value, "schema/basis", turn.info.process.realm), retained);
}
transit_station_row read_row(const Raw &raw, const Bytes &json, const std::string &path, size_t bound, transit_station_cell_kind type) {
    transit_station_row row{}; row.key = signed_number(raw, json, path + "/key");
    const auto cell = path + "/value/";
    if (exists(raw, json, cell + "null")) return row;
    row.kind = type;
    switch (type) {
        case TRANSIT_CELL_INT64: row.integer = signed_number(raw, json, cell + "int64"); break;
        case TRANSIT_CELL_BOOLEAN: row.boolean = raw.boolean(json, cell + "boolean"); break;
        case TRANSIT_CELL_UTF8: row.bytes = station_detail::json(raw.field(json, cell + "utf8", true)); break;
        case TRANSIT_CELL_BINARY: row.bytes = unhex(raw.field(json, cell + "binary", true), bound); break;
        default: fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "cell-type");
    }
    if (row.bytes.size() > bound) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "cell-bound"); return row;
}
}
extern "C" {
transit_sdk_error transit_station_table_open(transit_station_turn *turn, const transit_station_table_schema *schema, const transit_station_read_version *source, transit_station_table **out) {
    if (out) *out = nullptr;
    return with_turn(turn, true, [&](auto &owner) { require(schema && out, "table-open"); *out = capture_table(owner, *schema, source).release(); });
}
transit_sdk_error transit_station_table_create(transit_station_turn *turn, const transit_station_table_schema *schema, transit_station_table **out) {
    if (out) *out = nullptr;
    return with_turn(turn, true, [&](auto &owner) { require(schema && out, "table-create"); schema_check(*schema, owner.bridge->local.caps);
        turn_apply(owner, "{\"table_create\":{\"id\":" + decimal(schema->id) + ",\"key_name\":" + quote(schema->key_name) + ",\"value_name\":" + quote(schema->value_name) + ",\"value_type\":" + quote(cell_name(schema->value_type)) + "}}");
        *out = capture_table(owner, *schema, nullptr).release(); });
}
transit_sdk_error transit_station_table_basis(transit_station_table *table, transit_station_basis *out) {
    return with_turn(table ? table->turn : nullptr, false, [&](auto &) { require(out, "table-basis"); *out = table->basis; });
}
transit_sdk_error transit_station_table_get(transit_station_table *table, int64_t key, transit_station_row **out) {
    if (out) *out = nullptr;
    return with_turn(table ? table->turn : nullptr, true, [&](auto &owner) { require(out, "table-get");
        const auto action = table->retained ? "{\"version_table_get\":{\"version\":" + version(*table->retained) + "," : "{\"table_get\":{";
        const auto value = turn_apply(owner, action + "\"id\":" + decimal(table->id) + ",\"key\":" + quote(signed_decimal(key)) + "}}");
        const auto &raw = owner.bridge->local.raw;
        if (raw.field(value, "row") != "null") *out = new transit_station_row(read_row(raw, value, "row", owner.bridge->local.caps.cell, table->type)); });
}
transit_sdk_error transit_station_table_write(transit_station_table *table, transit_station_write_mode mode, transit_station_row_view row) {
    return with_turn(table ? table->turn : nullptr, false, [&](auto &owner) {
        require(!table->retained, "retained-table-write"); require(row.value.kind == TRANSIT_CELL_NULL || row.value.kind == table->type, "table-cell-type");
        const char *name = mode == TRANSIT_WRITE_INSERT ? "insert" : mode == TRANSIT_WRITE_UPDATE ? "update" : mode == TRANSIT_WRITE_UPSERT ? "upsert" : nullptr;
        require(name, "table-write-mode");
        turn_apply(owner, "{\"table_write\":{\"id\":" + decimal(table->id) + ",\"mode\":" + quote(name) + ",\"row\":{\"key\":" + quote(signed_decimal(row.key)) + ",\"value\":" + cell_wire(row.value, owner.bridge->local.caps.cell) + "}}}"); });
}
transit_sdk_error transit_station_table_delete(transit_station_table *table, int64_t key) {
    return with_turn(table ? table->turn : nullptr, false, [&](auto &owner) { require(!table->retained, "retained-table-write");
        turn_apply(owner, "{\"table_delete\":{\"id\":" + decimal(table->id) + ",\"key\":" + quote(signed_decimal(key)) + "}}"); });
}
transit_sdk_error transit_station_table_page(transit_station_table *table, const transit_station_cursor *after, transit_station_page **out) {
    if (out) *out = nullptr;
    return with_turn(table ? table->turn : nullptr, true, [&](auto &owner) { require(out, "table-page");
        const auto value = turn_apply(owner, "{\"table_page\":{\"id\":" + decimal(table->id) + ",\"version\":" + (table->retained ? version(*table->retained) : "null") + ",\"cursor\":" + cursor(after) + "}}");
        const auto &raw = owner.bridge->local.raw; const auto &caps = owner.bridge->local.caps; const auto array = raw.field(value, "rows/rows");
        if (array.empty() || array.front() != '[' || exists(raw, value, "rows/rows/" + decimal(caps.page))) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "table-page-bound");
        auto page = std::make_unique<transit_station_page>(); page->table = true;
        for (size_t i = 0; i < caps.page; ++i) {
            const auto path = "rows/rows/" + decimal(i); if (!exists(raw, value, path)) break;
            if (raw.field(value, path) != "null") page->rows.push_back(read_row(raw, value, path, caps.cell, table->type));
        }
        page->next = next_cursor(raw, value, "rows/next"); page->basis = basis(raw, value, "rows/basis", owner.info.process.realm); *out = page.release(); });
}
transit_sdk_error transit_station_page_row(const transit_station_page *page, size_t index, transit_station_row_view *out) {
    return boundary([&] { require(page && out && page->table && index < page->rows.size(), "page-row"); *out = page->rows[index].view(); });
}
transit_sdk_error transit_station_row_inspect(const transit_station_row *row, transit_station_row_view *out) {
    return boundary([&] { require(row && out, "row"); *out = row->view(); });
}
void transit_station_row_destroy(transit_station_row *row) { delete row; }
void transit_station_table_destroy(transit_station_table *table) { delete table; }
}
