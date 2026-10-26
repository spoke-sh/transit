#include "catalog_internal.hpp"

namespace transit::sdk::catalog_detail {
Json tag(const char *name, Json value) { return Json::object({{name, std::move(value)}}); }
Json wide(uint64_t value, bool zero) { require(value || zero, "catalog-identity"); return Json::string(std::to_string(value)); }
Json small(uint64_t value, bool zero) { counter(value, zero); return Json::integer(value); }
namespace {
template<class T> void array(const T *data, size_t size, size_t maximum) { require(size <= maximum && (data || !size), "catalog-array"); }
std::string choice(uint32_t value, std::initializer_list<const char *> names) {
    require(value < names.size(), "catalog-tag"); return *(names.begin() + value);
}
Json basis_wire(const Basis *v) { require(v, "catalog-basis"); return v->wire; }
Json characters(uint32_t value) { return value ? Json::integer(value) : Json{}; }
Json descriptor(const transit_logical_type_view *value) { require(value, "catalog-type"); return logical_detail::type_json(*value); }
Json cell(const transit_logical_cell_view *value) { return value ? logical_detail::cell_json(*value) : Json{}; }
// Each fragment is checked before appending. Only one bounded logical value is
// materialized at a time, independently of the operation's finite row/column
// counts. The final native action still undergoes shared schema/domain admission.
class Writer {
    std::string bytes;
    size_t maximum;
public:
    explicit Writer(size_t bound = max_action) : maximum(bound) {}
    void text(std::string_view v) { require(v.size() <= maximum - bytes.size(), "catalog-action-bound"); bytes += v; }
    void value(const Json &v) { text(logical_detail::encode(v, maximum - bytes.size())); }
    std::string finish() { return std::move(bytes); }
};
Json encoding(uint32_t v) { return Json::string(choice(v, {"plain", "bitpacked", "rle", "dictionary", "fsst", "comp", "comp_3", "zoned", "ibm_hfp", "ebcdic"})); }
Json collation(uint32_t v) { return Json::string(choice(v, {"none", "utf8_binary", "ascii_ci", "ebcdic_cp037", "icu_root"})); }
void column_fields(Writer &w, const transit_station_catalog_column_spec &c) {
    w.text("\"name\":"); w.value(Json::string(name(c.name))); w.text(",\"type\":"); w.value(descriptor(c.type));
    w.text(",\"nullable\":"); w.value(Json::boolean(c.nullable)); w.text(",\"default\":"); w.value(cell(c.default_value));
    w.text(",\"max_characters\":"); w.value(characters(c.max_characters));
    w.text(",\"encoding\":"); w.value(encoding(c.encoding)); w.text(",\"collation\":"); w.value(collation(c.collation));
}
std::string encode_schema(const Schema &s) {
    array(s.columns, s.column_count, 128); require(s.column_count, "catalog-columns"); array(s.primary_key, s.primary_key_count, s.column_count);
    Writer w(2 * 1024 * 1024); w.text("{\"definition\":"); w.value(Json::string(STATION_ABI_DEFINITION));
    w.text(",\"object\":"); w.value(wide(s.object)); w.text(",\"revision\":"); w.value(wide(s.revision));
    w.text(",\"next_column\":"); w.value(wide(s.next_column)); w.text(",\"columns\":[");
    for (size_t i = 0; i < s.column_count; ++i) {
        if (i) w.text(","); const auto &c = s.columns[i]; w.text("{\"id\":"); w.value(wide(c.id)); w.text(",");
        column_fields(w, {c.name, c.type, c.nullable, c.default_value, c.max_characters, c.encoding, c.collation}); w.text("}");
    }
    w.text("],\"primary_key\":["); for (size_t i = 0; i < s.primary_key_count; ++i) { if (i) w.text(","); w.value(wide(s.primary_key[i])); }
    w.text("]}"); return w.finish();
}
void assignments(Writer &w, transit_station_catalog_assignments values) {
    array(values.data, values.size, 128); w.text("[");
    for (size_t i = 0; i < values.size; ++i) {
        if (i) w.text(","); const auto &a = values.data[i]; w.text("{\"column\":"); w.value(wide(a.column)); w.text(",\"value\":");
        if (a.value) { w.text("{\"cell\":"); w.value(cell(a.value)); w.text("}"); } else w.text("{\"default\":{}}");
        w.text("}");
    }
    w.text("]");
}
void predicate(Writer &w, transit_station_catalog_predicate p) {
    array(p.data, p.size, 64); if (!p.data && !p.size) { w.text("null"); return; }
    w.text("[");
    for (size_t i = 0; i < p.size; ++i) {
        if (i) w.text(","); const auto &t = p.data[i];
        switch (t.kind) {
            case TRANSIT_CATALOG_ALL: w.text("{\"atom\":{\"all\":{}}}"); break;
            case TRANSIT_CATALOG_STATE:
                w.value(tag("atom", tag("state", Json::object({{"column", wide(t.column)}, {"value", Json::string(choice(t.as.state, {"missing", "null", "type_error", "value", "conflict"}))}})))); break;
            case TRANSIT_CATALOG_COMPARE:
                w.value(tag("atom", tag("compare", Json::object({{"column", wide(t.column)}, {"op", Json::string(choice(t.as.compare.op, {"eq", "ne", "lt", "le", "gt", "ge"}))}, {"value", logical_detail::atom_json(t.as.compare.value)}})))); break;
            case TRANSIT_CATALOG_NOT: w.text("{\"negate\":{}}"); break;
            case TRANSIT_CATALOG_AND: w.text("{\"conjunction\":{}}"); break;
            case TRANSIT_CATALOG_OR: w.text("{\"disjunction\":{}}"); break;
            default: fail(TRANSIT_SDK_INVALID_ARGUMENT, "catalog-predicate");
        }
    }
    w.text("]");
}
void change(Writer &w, const transit_station_catalog_change &v) {
    switch (v.kind) {
        case TRANSIT_CATALOG_ADD_COLUMN: w.text("{\"add\":{"); column_fields(w, v.as.add); w.text("}}"); break;
        case TRANSIT_CATALOG_DROP_COLUMN: w.value(tag("drop", wide(v.column))); break;
        case TRANSIT_CATALOG_RENAME_COLUMN: w.value(tag("rename", Json::object({{"column", wide(v.column)}, {"name", Json::string(name(v.as.name))}}))); break;
        case TRANSIT_CATALOG_DEFAULT: w.value(tag("default", Json::object({{"column", wide(v.column)}, {"value", cell(v.as.default_value)}}))); break;
        case TRANSIT_CATALOG_NULLABLE: w.value(tag("nullable", Json::object({{"column", wide(v.column)}, {"value", Json::boolean(v.as.nullable)}}))); break;
        case TRANSIT_CATALOG_PHYSICAL: w.value(tag("physical", Json::object({{"column", wide(v.column)}, {"encoding", encoding(v.as.physical.encoding)}, {"collation", collation(v.as.physical.collation)}}))); break;
        case TRANSIT_CATALOG_TYPE: w.value(tag("type", Json::object({{"column", wide(v.column)}, {"type", descriptor(v.as.type.type)}, {"max_characters", characters(v.as.type.max_characters)}}))); break;
        default: fail(TRANSIT_SDK_INVALID_ARGUMENT, "catalog-change");
    }
}
void mutation(Writer &w, const transit_station_catalog_action &a) {
    w.text("{\"action\":");
    if (a.kind == TRANSIT_CATALOG_INSERT) {
        array(a.as.insert.rows, a.as.insert.row_count, 1024); require(a.as.insert.row_count, "catalog-rows"); w.text("{\"insert\":[");
        for (size_t i = 0; i < a.as.insert.row_count; ++i) { if (i) w.text(","); assignments(w, a.as.insert.rows[i]); }
        w.text("]},\"predicate\":null");
    } else if (a.kind == TRANSIT_CATALOG_UPDATE) {
        w.text("{\"update\":"); assignments(w, a.as.update.assignments); w.text("},\"predicate\":"); predicate(w, a.as.update.predicate);
    } else {
        require(a.kind == TRANSIT_CATALOG_DELETE, "table-mutation-kind");
        w.text("{\"delete\":{}},\"predicate\":"); predicate(w, a.as.remove.predicate);
    }
    w.text("}");
}

}
Json collation_wire(uint32_t value) { return collation(value); }
std::string schema_wire(const Schema &value) { return encode_schema(value); }
std::string mutation_wire(const transit_station_catalog_action &value, size_t maximum) {
    Writer writer(maximum); mutation(writer, value); return writer.finish();
}
bool same_scope(Scope a, Scope b) { return a.catalog == b.catalog && a.resource.realm == b.resource.realm && a.resource.resource == b.resource.resource; }
std::string name(const char *value) {
    auto out = text(value, 255); require(!out.empty(), "catalog-name"); logical_detail::utf8(out); return out;
}
void current(const char *value) { require(text(value, 64) == STATION_ABI_DEFINITION, "catalog-definition"); }
std::string kind_name(transit_station_catalog_kind value) { return choice(value, {"create", "alter", "rename", "drop", "insert", "update", "delete"}); }
Json scope_wire(Scope v) { return Json::object({{"realm", small(v.resource.realm)}, {"resource", small(v.resource.resource)}, {"catalog", wide(v.catalog)}}); }
Json connection_wire(Connection c, uint64_t principal) {
    return Json::object({{"scope", scope_wire(c.scope)}, {"audience", small(c.audience)}, {"branch", wide(c.branch)}, {"principal", small(principal, true)}, {"role", c.has_role ? small(c.role, true) : Json{}}});
}
Json position_wire(Position p) { return Json::object({{"partition", wide(p.partition)}, {"next_lsn", wide(p.next_lsn, true)}}); }
Json object_wire(Object o) { return Json::object({{"scope", scope_wire(o.scope)}, {"branch", wide(o.branch)}, {"object", wide(o.object)}}); }
std::string request_wire(const Request &v) {
    Writer w; w.text("{\"prepare\":{\"definition\":"); w.value(Json::string(STATION_ABI_DEFINITION)); w.text(",\"name\":"); w.value(Json::string(name(v.name)));
    w.text(",\"namespace\":"); w.value(small(v.identity.namespace_id)); w.text(",\"operation\":"); w.value(wide(v.identity.operation)); w.text(",\"action\":"); const auto &a = v.action;
    switch (a.kind) {
        case TRANSIT_CATALOG_CREATE:
            require(a.as.create.schema, "catalog-schema"); w.text("{\"create\":{\"schema\":"); w.text(schema_wire(*a.as.create.schema));
            w.text(",\"if_not_exists\":"); w.value(Json::boolean(a.as.create.if_not_exists)); w.text("}}"); break;
        case TRANSIT_CATALOG_ALTER:
            w.text("{\"alter\":{\"basis\":"); w.value(basis_wire(a.as.alter.basis)); w.text(",\"change\":"); change(w, a.as.alter.change); w.text("}}"); break;
        case TRANSIT_CATALOG_RENAME: w.value(tag("rename", Json::object({{"basis", basis_wire(a.as.rename.basis)}, {"name", Json::string(name(a.as.rename.name))}}))); break;
        case TRANSIT_CATALOG_DROP: w.value(tag("drop", Json::object({{"basis", a.as.drop.basis ? basis_wire(a.as.drop.basis) : Json{}}, {"if_exists", Json::boolean(a.as.drop.if_exists)}}))); break;
        case TRANSIT_CATALOG_INSERT: case TRANSIT_CATALOG_UPDATE: case TRANSIT_CATALOG_DELETE:
            w.text("{\"mutate\":{\"basis\":"); w.value(basis_wire(a.kind == TRANSIT_CATALOG_INSERT ? a.as.insert.basis : a.kind == TRANSIT_CATALOG_UPDATE ? a.as.update.basis : a.as.remove.basis));
            w.text(",\"mutation\":"); mutation(w, a); w.text(",\"ingestion\":"); w.value(Json::string(choice(a.ingestion, {"point", "bulk"}))); w.text("}}"); break;
        default: fail(TRANSIT_SDK_INVALID_ARGUMENT, "catalog-action");
    }
    w.text("}}"); return w.finish();
}
}
