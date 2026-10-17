#include "table_internal.hpp"
namespace transit::sdk::table_detail {
namespace {
uint64_t small(const Json &v, bool zero = false) { return v.number(TRANSIT_CLIENT_MAX_COUNTER, zero); }
uint64_t full(const Json &v, bool zero = false) { return logical_detail::wide(v, zero); }
uint32_t choice(const Json &v, std::initializer_list<const char *> values) {
    const auto &name = v.string(); uint32_t i = 0;
    for (const auto *value : values) { if (name == value) return i; ++i; }
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "table-tag");
}
template<size_t N> void fixed(const Json &v, uint8_t (&out)[N]) {
    const auto &text = v.string(); require(text.size() == 2 * N, "table-hex");
    const auto bytes = unhex(text, N); require(hex(bytes) == text && bytes.size() == N, "table-hex");
    std::copy(bytes.begin(), bytes.end(), out);
}
Json hex_value(const uint8_t *data, size_t size) { return Json::string(hex(Bytes(data, data + size))); }
void assignments(const Json &v) {
    for (const auto &a : v.array(128)) {
        a.fields({"column", "value"}); full(a.at("column"));
        const auto &tag = a.at("value").variant();
        if (tag.first == "default") tag.second.fields({});
        else { require(tag.first == "cell", "table-assignment"); logical_detail::Arena arena; (void)logical_detail::cell_from(tag.second, arena); }
    }
}
void predicate(const Json &v) {
    if (v.is_null()) return;
    const auto &terms = v.array(64); require(!terms.empty(), "table-predicate"); size_t depth = 0;
    for (const auto &term : terms) {
        const auto &tag = term.variant();
        if (tag.first == "atom") {
            const auto &atom = tag.second.variant(); const auto &value = atom.second;
            if (atom.first == "all") value.fields({});
            else if (atom.first == "state") {
                value.fields({"column", "value"}); full(value.at("column"));
                choice(value.at("value"), {"missing", "null", "type_error", "value", "conflict"});
            } else {
                require(atom.first == "compare", "table-predicate-atom"); value.fields({"column", "op", "value"}); full(value.at("column"));
                choice(value.at("op"), {"eq", "ne", "lt", "le", "gt", "ge"});
                logical_detail::Arena arena; logical_detail::Budget budget(65536); (void)logical_detail::atom_from(value.at("value"), arena, budget);
            }
            ++depth;
        } else {
            tag.second.fields({});
            if (tag.first == "negate") require(depth >= 1, "table-predicate-stack");
            else { require((tag.first == "conjunction" || tag.first == "disjunction") && depth >= 2, "table-predicate-stack"); --depth; }
        }
    }
    require(depth == 1, "table-predicate-stack");
}
void mutation(const Json &v) {
    v.fields({"action", "predicate"}); const auto &tag = v.at("action").variant();
    if (tag.first == "insert") {
        require(v.at("predicate").is_null(), "table-insert-predicate");
        const auto &rows = tag.second.array(1024); require(!rows.empty(), "table-insert-rows");
        for (const auto &row : rows) assignments(row);
    } else {
        if (tag.first == "update") assignments(tag.second);
        else { require(tag.first == "delete", "table-mutation-action"); tag.second.fields({}); }
        predicate(v.at("predicate"));
    }
}
}
Json parse(const std::string &v) { return logical_detail::JsonParser(v, bound).parse(); }
std::string action(const char *tag, const std::string &payload) {
    require(payload.size() <= bound, "table-action-bound");
    const auto out = "{\"table\":{" + quote(tag) + ":" + payload + "}}";
    require(out.size() <= bound, "table-action-bound"); return out;
}
Json apply(transit_station_turn &turn, const char *tag, const std::string &payload, const char *result) {
    const auto bytes = turn_apply(turn, action(tag, payload));
    const auto value = logical_detail::parse(view(bytes), bound); value.fields({"table"});
    const auto &table = value.at("table"); table.fields({result}); return table.at(result);
}
bool same_resource(transit_sdk_resource a, transit_sdk_resource b) { return a.realm == b.realm && a.resource == b.resource; }
bool same_reference(const transit_station_table_reference &a, const transit_station_table_reference &b) {
    return same_resource(a.resource, b.resource) && a.object == b.object && a.principal == b.principal && a.operation == b.operation &&
        std::equal(std::begin(a.definition), std::end(a.definition), std::begin(b.definition)) && std::equal(std::begin(a.digest), std::end(a.digest), std::begin(b.digest));
}
std::unique_ptr<transit_station_table_mutation> load(transit_sdk_bytes bytes) {
    require(bytes.size <= bound, "table-action-bound"); const auto value = logical_detail::parse(bytes, bound);
    const auto encoded = logical_detail::encode(value, bound);
    require(encoded.size() == bytes.size && std::equal(encoded.begin(), encoded.end(), reinterpret_cast<const char *>(bytes.data)), "table-saved-canonical");
    (void)action("mutate", encoded); value.fields({"realm", "resource", "principal", "operation", "schema", "mutation"});
    auto out = std::make_unique<transit_station_table_mutation>(); out->bytes = encoded;
    out->resource = {small(value.at("realm")), small(value.at("resource"))}; out->principal = small(value.at("principal"), true); out->operation = full(value.at("operation"));
    out->schema = catalog_detail::schema(value.at("schema"), out->arena); mutation(value.at("mutation")); return out;
}
std::unique_ptr<transit_station_table_mutation> prepare(transit_sdk_resource resource, uint64_t principal, uint64_t operation, const transit_station_catalog_schema &schema, const transit_station_table_mutation_spec &spec) {
    counter(resource.realm); counter(resource.resource); counter(principal, true); require(operation, "table-operation");
    transit_station_catalog_action a{};
    if (spec.kind == TRANSIT_TABLE_INSERT) { a.kind = TRANSIT_CATALOG_INSERT; a.as.insert = {{}, spec.as.insert.rows, spec.as.insert.row_count}; }
    else if (spec.kind == TRANSIT_TABLE_UPDATE) { a.kind = TRANSIT_CATALOG_UPDATE; a.as.update = {{}, spec.as.update.assignments, spec.as.update.predicate}; }
    else { require(spec.kind == TRANSIT_TABLE_DELETE, "table-mutation-kind"); a.kind = TRANSIT_CATALOG_DELETE; a.as.remove = {{}, spec.as.remove}; }
    auto encoded = "{\"realm\":" + decimal(resource.realm) + ",\"resource\":" + decimal(resource.resource) + ",\"principal\":" + decimal(principal) +
        ",\"operation\":" + quote(decimal(operation)) + ",\"schema\":" + catalog_detail::schema_wire(schema);
    require(encoded.size() + 13 <= bound, "table-action-bound");
    encoded += ",\"mutation\":" + catalog_detail::mutation_wire(a, bound - encoded.size() - 13) + "}";
    return load(view(json(encoded)));
}
Json reference_wire(const transit_station_table_reference &v) {
    require(text(v.definition, 64) == STATION_ABI_DEFINITION, "table-definition");
    counter(v.resource.realm); counter(v.resource.resource); counter(v.principal, true); require(v.object && v.operation, "table-identity");
    return Json::object({{"definition", Json::string(STATION_ABI_DEFINITION)}, {"realm", Json::integer(v.resource.realm)}, {"resource", Json::integer(v.resource.resource)},
        {"object", Json::string(decimal(v.object))}, {"principal", Json::integer(v.principal)}, {"operation", Json::string(decimal(v.operation))}, {"digest", hex_value(v.digest, 32)}});
}
transit_station_table_reference reference(const Json &v) {
    v.fields({"definition", "realm", "resource", "object", "principal", "operation", "digest"}); require(v.at("definition").string() == STATION_ABI_DEFINITION, "table-definition");
    transit_station_table_reference out{}; std::copy_n(STATION_ABI_DEFINITION, 65, out.definition);
    out.resource = {small(v.at("realm")), small(v.at("resource"))}; out.object = full(v.at("object")); out.principal = small(v.at("principal"), true);
    out.operation = full(v.at("operation")); fixed(v.at("digest"), out.digest); return out;
}
transit_station_table_status status(const Json &v) {
    v.fields({"reference", "state", "route", "admitted_input", "completed_input", "counts", "rejection", "witness"}); transit_station_table_status out{};
    out.reference = reference(v.at("reference")); out.state = choice(v.at("state"), {"building", "applied", "rejected", "cancelled"});
    out.route = choice(v.at("route"), {"point", "statement", "alter"}); out.admitted_input = small(v.at("admitted_input"));
    out.has_completed_input = !v.at("completed_input").is_null(); if (out.has_completed_input) out.completed_input = small(v.at("completed_input"));
    out.has_counts = !v.at("counts").is_null();
    if (out.has_counts) {
        const auto &counts = v.at("counts"); counts.fields({"matched", "changed"}); out.counts = {full(counts.at("matched"), true), full(counts.at("changed"), true)};
        require(out.counts.changed <= out.counts.matched, "table-counts");
    }
    out.rejection = choice(v.at("rejection"), {"none", "row_exists", "row_identity_exists", "null_not_allowed", "missing_required_field", "character_limit_exceeded", "overflow", "inexact"});
    require(out.has_completed_input == (out.state != TRANSIT_TABLE_BUILDING) && (!out.has_completed_input || out.completed_input >= out.admitted_input) &&
        out.has_counts == (out.state == TRANSIT_TABLE_APPLIED) && (out.rejection != TRANSIT_TABLE_NONE) == (out.state == TRANSIT_TABLE_REJECTED), "table-status");
    out.has_witness = !v.at("witness").is_null();
    if (out.has_witness) {
        const auto &w = v.at("witness"); w.fields({"source", "row", "column", "text", "truncated"}); auto &o = out.witness;
        o.source = choice(w.at("source"), {"input", "stored", "withheld"}); o.has_row = !w.at("row").is_null();
        if (o.has_row) fixed(w.at("row"), o.row.bytes); o.column = full(w.at("column"), true);
        const auto &text = w.at("text").string(); require(text.size() <= 256, "table-witness-text");
        o.text_bytes = text.size(); std::copy(text.begin(), text.end(), o.text); o.truncated = w.at("truncated").boolean();
    }
    return out;
}
transit_station_table_creation creation(const Json &v) {
    v.fields({"state", "admitted_input", "completed_input"}); transit_station_table_creation out{};
    out.state = choice(v.at("state"), {"building", "applied"}); out.admitted_input = small(v.at("admitted_input"));
    out.completed_input = small(v.at("completed_input"), true); out.has_completed_input = out.completed_input != 0;
    require(out.has_completed_input == (out.state == TRANSIT_TABLE_CREATION_APPLIED) && (!out.has_completed_input || out.completed_input >= out.admitted_input), "table-creation"); return out;
}
transit_station_table_basis basis(const Json &v, uint64_t realm) {
    v.fields({"resource", "revision", "object", "head"}); transit_station_table_basis out{};
    out.resource = {realm, small(v.at("resource"))}; out.revision = small(v.at("revision")); out.object = full(v.at("object")); fixed(v.at("head"), out.head); return out;
}
void check_basis(const Json &v, const transit_station_table &table) {
    v.fields({"schema", "basis"}); const auto b = basis(v.at("basis"), table.basis.resource.realm);
    require(same_resource(b.resource, table.basis.resource) && b.revision == table.basis.revision && b.object == table.basis.object &&
        std::equal(std::begin(b.head), std::end(b.head), std::begin(table.basis.head)), "table-basis-changed");
    logical_detail::Arena arena; const auto schema = catalog_detail::schema(v.at("schema"), arena);
    require(catalog_detail::schema_wire(schema) == catalog_detail::schema_wire(table.schema), "table-schema-changed");
}
std::unique_ptr<transit_station_row> row(const Json &v, size_t columns) {
    v.fields({"identity", "cells"}); auto out = std::make_unique<transit_station_row>(); fixed(v.at("identity"), out->value.identity.bytes);
    const auto &cells = v.at("cells").array(128); require(cells.size() == columns && columns, "table-row-columns");
    auto *values = out->arena.array<transit_logical_cell_view>(cells.size());
    for (size_t i = 0; i < cells.size(); ++i) values[i] = logical_detail::cell_from(cells[i], out->arena);
    out->value.cells = values; out->value.cell_count = cells.size(); return out;
}
}
