#include "catalog_internal.hpp"
#include "catalog_schema.hpp"

namespace transit::sdk::catalog_detail {
namespace {
const Json *find(const Json &v, std::string_view key) {
    if (v.kind != Json::Kind::Object) return nullptr;
    for (const auto &e : v.members) if (e.first == key) return &e.second;
    return nullptr;
}
// Validate generated schemas, with no defaults for persisted compatibility or
// authority fields. The parser bounds bytes, nodes and depth before validation.
void check_schema(const Json &rule, const Json &v, const Json &root, size_t depth) {
    require(depth < 256, "catalog-schema-depth");
    if (const auto *ref = find(rule, "$ref")) {
        const auto &s = ref->string(); require(s.substr(0, 8) == "#/$defs/", "catalog-schema-ref");
        check_schema(root.at("$defs").at(s.substr(8)), v, root, depth + 1); return;
    }
    for (const auto *key : {"oneOf", "anyOf"}) if (const auto *choices = find(rule, key)) {
        size_t accepted = 0;
        for (const auto &choice : choices->array(256)) {
            try { check_schema(choice, v, root, depth + 1); ++accepted; } catch (const Failure &) {}
        }
        require(accepted && (std::string_view(key) == "anyOf" || accepted == 1), "catalog-schema-union"); return;
    }
    const auto &type = rule.at("type").string();
    if (type == "object") {
        require(v.kind == Json::Kind::Object, "catalog-schema-object");
        if (const auto *max = find(rule, "maxProperties")) require(v.members.size() <= max->number(SIZE_MAX), "catalog-schema-fields");
        if (const auto *keys = find(rule, "required")) for (const auto &key : keys->array(256)) (void)v.at(key.string());
        const auto *properties = find(rule, "properties");
        for (const auto &entry : v.members) {
            if (properties) if (const auto *property = find(*properties, entry.first)) { check_schema(*property, entry.second, root, depth + 1); continue; }
            const auto *additional = find(rule, "additionalProperties");
            require(!additional || additional->boolean(), "catalog-schema-extra-field");
        }
    } else if (type == "array") {
        const auto *max = find(rule, "maxItems"); const auto &items = v.array(max ? max->number(SIZE_MAX) : 1048576);
        if (const auto *min = find(rule, "minItems")) require(items.size() >= min->number(SIZE_MAX), "catalog-schema-array");
        for (const auto &item : items) check_schema(rule.at("items"), item, root, depth + 1);
    } else if (type == "string") {
        const auto &s = v.string();
        if (const auto *max = find(rule, "maxLength")) require(s.size() <= max->number(SIZE_MAX), "catalog-schema-string");
        if (const auto *values = find(rule, "enum")) {
            bool matched = false; for (const auto &value : values->array(256)) matched |= equal(v, value);
            require(matched, "catalog-schema-enum");
        }
        if (const auto *pattern = find(rule, "pattern")) {
            require(pattern->string() == "^(?:[0-9a-f]{2})*$" && s.size() % 2 == 0, "catalog-schema-pattern");
            for (const auto c : s) require((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'), "catalog-schema-hex");
        }
    } else if (type == "integer") {
        const auto *max = find(rule, "maximum"); const auto number = v.number(max ? max->number(UINT64_MAX) : UINT64_MAX);
        if (const auto *min = find(rule, "minimum")) require(number >= min->number(UINT64_MAX), "catalog-schema-integer");
    } else if (type == "boolean") (void)v.boolean();
    else { require(type == "null" && v.is_null(), "catalog-schema-null"); }
}
uint64_t full(const Json &v, bool zero = false) { return logical_detail::wide(v, zero); }
uint64_t counter_value(const Json &v, bool zero = false) { return v.number(TRANSIT_CLIENT_MAX_COUNTER, zero); }
uint32_t choice(const Json &v, std::initializer_list<const char *> names) {
    const auto &text = v.string(); uint32_t i = 0; for (const auto *name : names) { if (text == name) return i; ++i; }
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "catalog-response-tag");
}
void current(const Json &v) { require(v.string() == STATION_ABI_DEFINITION, "catalog-response-definition"); }
template<size_t N> void string(const Json &v, char (&out)[N]) {
    const auto &text = v.string(); require(!text.empty() && text.size() < N && text.find('\0') == std::string::npos, "catalog-response-string");
    std::copy(text.begin(), text.end(), out); out[text.size()] = 0;
}
Bytes bytes(const Json &v, size_t max, std::optional<size_t> exact = {}) {
    const auto &text = v.string(); require(text.size() % 2 == 0 && text.size() / 2 <= max && (!exact || text.size() / 2 == *exact), "catalog-response-hex");
    for (const auto c : text) require((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'), "catalog-response-hex");
    return unhex(text, max);
}
void digest(const Json &v, uint8_t (&out)[32]) { const auto data = bytes(v, 32, 32); std::copy(data.begin(), data.end(), out); }
Scope scope(const Json &v) { return {{counter_value(v.at("realm")), counter_value(v.at("resource"))}, full(v.at("catalog"))}; }
Connection connection(const Json &v) {
    Connection c{scope(v.at("scope")), counter_value(v.at("audience")), full(v.at("branch")), !v.at("role").is_null(), 0};
    if (c.has_role) c.role = counter_value(v.at("role"), true);
    (void)counter_value(v.at("principal"), true); return c;
}
Position position(const Json &v) { return {full(v.at("partition")), full(v.at("next_lsn"), true)}; }
Object object(const Json &v) { return {scope(v.at("scope")), full(v.at("branch")), full(v.at("object"))}; }
bool same_object(Object a, Object b) { return same_scope(a.scope, b.scope) && a.branch == b.branch && a.object == b.object; }
void owns_object(Connection c, Object o) { require(same_scope(c.scope, o.scope) && c.branch == o.branch, "catalog-object-owner"); }
Interpretation interpretation(const Json &v) {
    Interpretation i{object(v.at("object")), full(v.at("revision")), {}}; digest(v.at("digest"), i.digest); return i;
}
Content content(const Json &v) { Content c{full(v.at("bytes")), {}}; digest(v.at("sha256"), c.sha256); return c; }
Stored stored(const Json &v) {
    Stored s{interpretation(v.at("interpretation")), content(v.at("content")), {}, v.at("retired").boolean()};
    require(std::equal(std::begin(s.interpretation.digest), std::end(s.interpretation.digest), std::begin(s.content.sha256)), "catalog-definition-content");
    digest(v.at("schema_fingerprint"), s.schema_fingerprint); return s;
}
void binding_check(const Json &v, Connection c, uint64_t principal) {
    current(v.at("definition")); const auto &id = v.at("identity"); (void)full(id.at("operation"));
    require(same_scope(scope(id.at("scope")), c.scope) && counter_value(id.at("principal"), true) == principal, "catalog-binding-owner");
    const auto target = object(v.at("target")); owns_object(c, target); (void)bytes(v.at("intent"), 32, 32);
    const auto kind = choice(v.at("action"), {"create", "alter", "rename", "drop", "insert", "update", "delete"});
    if (kind == TRANSIT_CATALOG_CREATE) require(v.at("expected_definition").is_null() && v.at("expected_data").is_null(), "catalog-create-basis");
    else require(same_object(interpretation(v.at("expected_definition")).object, target), "catalog-binding-target");
    if (!v.at("expected_data").is_null()) (void)position(v.at("expected_data"));
}
void assertion_check(const Json &v) {
    current(v.at("definition")); const auto c = connection(v.at("connection")); (void)counter_value(v.at("namespace"));
    (void)name(v.at("name").string().c_str()); (void)full(v.at("operation")); (void)bytes(v.at("intent"), 32, 32);
    const auto action = choice(v.at("action"), {"create_if_not_exists", "drop_if_exists"});
    require(v.at("expected").is_null() == (action == 1), "catalog-name-assertion");
    if (!v.at("expected").is_null()) owns_object(c, interpretation(v.at("expected")).object);
}
Json selection(uint64_t ns) { return ns ? tag("tables", small(ns)) : tag("namespaces"); }
const Json &reference_binding(const Reference &r) {
    const auto &variant = r.wire.variant(); return variant.first == "table" ? variant.second.at("binding") : variant.second;
}
uint32_t expected_kind(uint32_t work, const Json &binding) {
    if (work == TRANSIT_CATALOG_NAME_ASSERTION) return TRANSIT_CATALOG_NAME_OBSERVATION;
    const auto &kind = binding.at("action").string(); return kind == "insert" || kind == "update" || kind == "delete" ? TRANSIT_CATALOG_ROWS : TRANSIT_CATALOG_DDL;
}
uint32_t reason(const Json &v) { return choice(v, {"none", "name_conflict", "object_conflict", "stale_definition", "stale_data", "dependency", "constraint", "definition_changed", "data_changed", "duplicate_key", "missing_row", "invalid_rows", "work_limit", "condition_changed"}); }
transit_station_catalog_read_authority read_authority(const Json &v) {
    transit_station_catalog_read_authority out{counter_value(v.at("database")), counter_value(v.at("schema")), counter_value(v.at("table"))};
    require(out.database != out.schema && out.database != out.table && out.schema != out.table, "catalog-read-authority"); return out;
}
Schema decode_schema(const Json &v, Arena &a) {
    v.fields({"definition", "object", "revision", "next_column", "columns", "primary_key"}); current(v.at("definition"));
    // Bound the entire schema independently of each descriptor/default.
    (void)logical_detail::encode(v, 2 * 1024 * 1024);
    Schema out{}; out.object = full(v.at("object")); out.revision = full(v.at("revision")); out.next_column = full(v.at("next_column"));
    const auto &columns = v.at("columns").array(128); require(!columns.empty(), "catalog-response-columns"); auto *values = a.array<Column>(columns.size()); out.columns = values; out.column_count = columns.size();
    for (size_t i = 0; i < columns.size(); ++i) {
        const auto &c = columns[i]; c.fields({"id", "name", "type", "nullable", "default", "max_characters", "encoding", "collation"}); char name[256]{}; string(c.at("name"), name);
        auto *owned_name = a.array<char>(std::strlen(name) + 1); std::copy_n(name, std::strlen(name) + 1, owned_name);
        auto *type = a.array<transit_logical_type_view>(1); *type = logical_detail::type_from(c.at("type"), a);
        transit_logical_cell_view *cell = nullptr;
        if (!c.at("default").is_null()) { cell = a.array<transit_logical_cell_view>(1); *cell = logical_detail::cell_from(c.at("default"), a); }
        values[i] = {full(c.at("id")), owned_name, type, c.at("nullable").boolean(), cell, c.at("max_characters").is_null() ? 0 : static_cast<uint32_t>(c.at("max_characters").number(UINT32_MAX, false)), choice(c.at("encoding"), {"plain", "bitpacked", "rle", "dictionary", "fsst", "comp", "comp_3", "zoned", "ibm_hfp", "ebcdic"}), choice(c.at("collation"), {"none", "utf8_binary", "ascii_ci", "ebcdic_cp037", "icu_root"})};
    }
    const auto &keys = v.at("primary_key").array(out.column_count); auto *owned_keys = a.array<uint64_t>(keys.size()); out.primary_key = owned_keys; out.primary_key_count = keys.size();
    for (size_t i = 0; i < keys.size(); ++i) owned_keys[i] = full(keys[i]); return out;
}} // namespace
bool equal(const Json &a, const Json &b) {
    if (a.kind != b.kind || a.flag != b.flag || a.text != b.text || a.items.size() != b.items.size() || a.members.size() != b.members.size()) return false;
    for (size_t i = 0; i < a.items.size(); ++i) if (!equal(a.items[i], b.items[i])) return false;
    for (const auto &e : a.members) { const auto *other = find(b, e.first); if (!other || !equal(e.second, *other)) return false; }
    return true;
}
void validate(const char *key, const Json &v) {
    static const Json action = logical_detail::JsonParser(generated::CatalogAction).parse();
    static const Json result = logical_detail::JsonParser(generated::CatalogResult).parse();
    require(std::string_view(key) == "CatalogAction" || std::string_view(key) == "CatalogResult", "catalog-schema-name");
    const auto &root = std::string_view(key) == "CatalogAction" ? action : result;
    check_schema(root, v, root, 0);
}
bool same_position(Position a, Position b) { return a.partition == b.partition && a.next_lsn == b.next_lsn; }
void owns(const Json &wire, Connection c, uint64_t principal) { require(equal(wire, connection_wire(c, principal)), "catalog-connection-owner"); }
Schema schema(const Json &v, Arena &a) { return decode_schema(v, a); }
std::unique_ptr<Basis> basis(const Json &v) {
    validate("CatalogAction", tag("prepare", Json::object({{"definition", Json::string(STATION_ABI_DEFINITION)}, {"namespace", small(1)}, {"operation", wide(1)}, {"name", Json::string("check")}, {"action", tag("drop", Json::object({{"basis", v}, {"if_exists", Json::boolean(false)}}))}})));
    current(v.at("definition")); auto out = std::make_unique<Basis>(v); auto &b = out->value;
    b.connection = connection(v.at("connection")); b.principal = counter_value(v.at("connection").at("principal"), true);
    b.namespace_id = counter_value(v.at("namespace")); string(v.at("name"), b.name); b.interpretation = stored(v.at("interpretation"));
    owns_object(b.connection, b.interpretation.interpretation.object); require(!b.interpretation.retired, "catalog-retired-basis"); return out;
}
std::unique_ptr<Saved> saved(const Json &v) {
    validate("CatalogAction", tag("load", v)); const auto &variant = v.variant(); const auto &raw = variant.second;
    if (variant.first == "table") {
        current(raw.at("definition")); (void)counter_value(raw.at("namespace")); require(!bytes(raw.at("bytes"), max_intent).empty(), "catalog-empty-intent");
    } else { require(variant.first == "name_assertion", "catalog-work-kind"); assertion_check(raw); }
    return std::make_unique<Saved>(v);
}
std::unique_ptr<Reference> reference(const Json &v) {
    validate("CatalogAction", tag("admit", v)); const auto &variant = v.variant(); const auto &raw = variant.second;
    auto out = std::make_unique<Reference>(v); auto &r = out->value;
    current(raw.at("definition")); r.connection = connection(raw.at("connection")); r.principal = counter_value(raw.at("connection").at("principal"), true); r.identity.namespace_id = counter_value(raw.at("namespace"));
    if (variant.first == "table") {
        r.kind = TRANSIT_CATALOG_TABLE; binding_check(raw.at("binding"), r.connection, r.principal);
        r.identity.operation = full(raw.at("binding").at("identity").at("operation"));
        const auto c = content(raw.at("content")); require(c.bytes > 36 && c.bytes <= max_intent, "catalog-intent-content");
    } else { require(variant.first == "name_assertion", "catalog-work-kind"); r.kind = TRANSIT_CATALOG_NAME_ASSERTION; assertion_check(raw); r.identity.operation = full(raw.at("operation")); }
    return out;
}
std::unique_ptr<Cursor> cursor(const Json &v) {
    const auto &s = v.at("selection").variant();
    const auto ns = s.first == "tables" ? counter_value(s.second) : 0;
    require(ns || s.first == "namespaces", "catalog-page-selection");
    validate("CatalogAction", tag("catalog", ns ? tag("tables", Json::object({{"namespace", small(ns)}, {"cursor", v}})) : tag("namespaces", v)));
    current(v.at("definition")); (void)connection(v.at("connection")); auto out = std::make_unique<Cursor>(v);
    out->value = {position(v.at("position")), full(v.at("after"))}; require(out->value.position.next_lsn, "catalog-cursor-position");
    if (!ns) counter(out->value.after); return out;
}
void cursor_check(const Cursor &v, Connection c, uint64_t p, uint64_t ns) {
    owns(v.wire.at("connection"), c, p); require(equal(v.wire.at("selection"), selection(ns)), "catalog-cursor-selection");
}
std::unique_ptr<Owner> owner(const Json &v) {
    validate("CatalogAction", tag("retention", tag("status", v))); current(v.at("definition")); auto out = std::make_unique<Owner>(v);
    out->value = {connection(v.at("connection")), counter_value(v.at("connection").at("principal"), true), object(v.at("object")), full(v.at("operation"))};
    owns_object(out->value.connection, out->value.object); return out;
}
std::unique_ptr<Acquisition> acquisition(const Json &v) {
    validate("CatalogAction", tag("retention", tag("acquire", v))); auto out = std::make_unique<Acquisition>(v);
    out->owner = owner(v.at("owner")); out->value = {out->owner.get(), position(v.at("expected"))}; return out;
}
std::unique_ptr<Snapshot> snapshot(const Json &v) {
    validate("CatalogAction", tag("retention", tag("metadata", v))); auto out = std::make_unique<Snapshot>(v);
    out->owner = owner(v.at("owner")); out->value = {out->owner.get(), content(v.at("content"))}; return out;
}
Capabilities capabilities(const Json &v) {
    current(v.at("definition")); Capabilities out{}; string(v.at("definition"), out.definition);
    auto number = [&](const char *k) { return static_cast<uint32_t>(v.at(k).number(UINT32_MAX, false)); };
    out.version = number("version"); out.max_columns = number("max_columns"); out.max_rows = number("max_rows"); out.max_sql_bytes = number("max_sql_bytes");
    out.max_intent_bytes = number("max_intent_bytes"); out.max_action_bytes = number("max_action_bytes"); out.metadata_page_entries = number("metadata_page_entries"); out.resident_intents = number("resident_intents");
    require(out.version == 1 && out.max_columns == 128 && out.max_rows == 1024 && out.max_sql_bytes == 4096 && out.max_intent_bytes == max_intent && out.max_action_bytes == max_action && out.metadata_page_entries == 8 && out.resident_intents == 1, "catalog-capabilities"); return out;
}
Description description(const Json &v, Connection c, uint64_t p) {
    Description out{}; const auto &config = v.at("configuration"); auto &g = out.configuration;
    g.scope = scope(config.at("scope")); g.branch = full(config.at("branch")); g.partition = full(config.at("partition")); g.audience = counter_value(config.at("audience"));
    string(config.at("database_name"), g.database_name); string(config.at("initial_schema_name"), g.initial_schema_name);
    const auto &a = config.at("authority"); g.authority = {counter_value(a.at("database_domain")), counter_value(a.at("schema_domain")), counter_value(a.at("table_domain")), counter_value(a.at("database")), counter_value(a.at("initial_schema_authority")), counter_value(a.at("initial_schema"))};
    const auto &x = g.authority; require(x.database_domain != x.schema_domain && x.database_domain != x.table_domain && x.schema_domain != x.table_domain && x.database != x.initial_schema_authority, "catalog-authority");
    const auto &s = v.at("subject"); out.subject = {counter_value(s.at("principal"), true), counter_value(s.at("login_role"), true), counter_value(s.at("role"), true), counter_value(s.at("credential_epoch")), counter_value(s.at("audience")), {}};
    const auto &context = s.at("context").array(32); require(context.size() == 32, "catalog-context");
    for (size_t i = 0; i < context.size(); ++i) out.subject.context[i] = static_cast<uint8_t>(context[i].number(255));
    out.policy_revision = counter_value(v.at("policy_revision"), true);
    require(same_scope(g.scope, c.scope) && g.branch == c.branch && g.audience == c.audience && out.subject.principal == p && out.subject.audience == c.audience && out.subject.role == (c.has_role ? c.role : out.subject.login_role), "catalog-description-owner"); return out;
}
Namespace namespace_value(const Json &v, Connection c, uint64_t expected) {
    Namespace out{scope(v.at("scope")), counter_value(v.at("id")), counter_value(v.at("authorization")), counter_value(v.at("revision")), {}, v.at("retired").boolean()}; string(v.at("name"), out.name);
    require(same_scope(out.scope, c.scope) && (!expected || out.id == expected), "catalog-namespace-owner"); return out;
}
std::unique_ptr<Metadata> metadata(const Json &v, Connection c, uint64_t p, const std::string &n, uint64_t ns) {
    if (v.is_null()) return {}; auto out = std::make_unique<Metadata>(); out->basis = basis(v.at("binding"));
    const auto &b = out->basis->value; owns(out->basis->wire.at("connection"), c, p);
    require(b.namespace_id == ns && n == b.name, "catalog-lookup-name"); auto &m = out->value;
    m = {out->basis.get(), counter_value(v.at("authorization")), position(v.at("position")), full(v.at("changed_lsn"), true), full(v.at("row_count"), true), schema(v.at("schema"), out->arena)};
    require(m.schema.object == b.interpretation.interpretation.object.object, "catalog-lookup-schema"); return out;
}
namespace {
template<class Page, class Entry> std::unique_ptr<Page> page(const Json &v, Connection c, uint64_t p, uint64_t ns, const Cursor *previous, Entry &&entry) {
    auto out = std::make_unique<Page>(); auto &view = out->value; view.position = position(v.at("position"));
    const auto before = previous ? previous->value.after : 0;
    if (previous) { cursor_check(*previous, c, p, ns); require(same_position(previous->value.position, view.position), "catalog-page-position"); }
    const auto &slots = v.at("entries").array(8); require(slots.size() == 8, "catalog-page-slots"); bool ended = false; auto last = before;
    for (const auto &raw : slots) {
        if (raw.is_null()) { ended = true; continue; }
        require(!ended, "catalog-page-density"); const auto id = entry(raw, view.entries[view.count]);
        require(id > last, "catalog-page-order"); last = id; ++view.count;
    }
    if (!v.at("next").is_null()) {
        out->next = cursor(v.at("next")); cursor_check(*out->next, c, p, ns); const auto &next = out->next->value;
        require(same_position(next.position, view.position) && next.after >= last && next.after > before, "catalog-page-next"); view.next = out->next.get();
    }
    return out;
}
}
std::unique_ptr<NamespacePage> namespace_page(const Json &v, Connection c, uint64_t p, const Cursor *previous) {
    return page<NamespacePage>(v, c, p, 0, previous, [&](const Json &raw, Namespace &out) { out = namespace_value(raw, c); return out.id; });
}
std::unique_ptr<TablePage> table_page(const Json &v, Connection c, uint64_t p, uint64_t ns, const Cursor *previous) {
    require(v.at("consistency").string() == "independent", "catalog-page-consistency");
    return page<TablePage>(v, c, p, ns, previous, [&](const Json &raw, transit_station_catalog_entry &out) {
        out.interpretation = interpretation(raw.at("interpretation")); owns_object(c, out.interpretation.object); out.namespace_id = counter_value(raw.at("namespace"));
        require(out.namespace_id == ns, "catalog-page-namespace"); string(raw.at("name"), out.name); out.position = position(raw.at("position")); out.changed_lsn = full(raw.at("changed_lsn"), true); return out.interpretation.object.object;
    });
}
std::unique_ptr<Intent> intent(const Json &v, const Saved &s, Connection c, uint64_t p, const Identity *expected) {
    auto out = std::make_unique<Intent>(); out->id = v.at("id"); current(out->id.at("definition")); (void)bytes(out->id.at("digest"), 32, 32);
    const auto &variant = v.at("binding").variant(); out->binding = variant.second; auto &view = out->value; view.identity.namespace_id = counter_value(v.at("namespace"));
    if (variant.first == "table") {
        view.kind = TRANSIT_CATALOG_TABLE; binding_check(out->binding, c, p); view.identity.operation = full(out->binding.at("identity").at("operation"));
    } else {
        require(variant.first == "name_assertion", "catalog-work-kind"); view.kind = TRANSIT_CATALOG_NAME_ASSERTION; assertion_check(out->binding); owns(out->binding.at("connection"), c, p);
        view.identity.operation = full(out->binding.at("operation")); require(counter_value(out->binding.at("namespace")) == view.identity.namespace_id, "catalog-intent-namespace");
    }
    require(!expected || (expected->operation == view.identity.operation && expected->namespace_id == view.identity.namespace_id), "catalog-intent-identity");
    const auto &sv = s.wire.variant(); require(sv.first == variant.first && counter_value(sv.second.at("namespace")) == view.identity.namespace_id, "catalog-saved-binding");
    if (view.kind == TRANSIT_CATALOG_NAME_ASSERTION) require(equal(sv.second, out->binding), "catalog-saved-assertion");
    out->saved = saved(s.wire); view.saved = out->saved.get(); return out;
}
std::unique_ptr<Compiled> compiled(const Json &v, Connection c, uint64_t p, Identity expected) {
    auto out = std::make_unique<Compiled>(); const auto s = saved(v.at("saved")); out->intent = intent(v.at("summary"), *s, c, p, &expected); return out;
}
std::unique_ptr<Reference> staged(const Json &v, const Intent &i, Connection c, uint64_t p) {
    auto out = reference(v); const auto &r = out->value; owns(out->wire.variant().second.at("connection"), c, p);
    require(r.kind == i.value.kind && r.identity.operation == i.value.identity.operation && r.identity.namespace_id == i.value.identity.namespace_id && equal(reference_binding(*out), i.binding), "catalog-staged-binding"); return out;
}
std::unique_ptr<Observation> observation(const Json &v, const Reference &r) {
    auto out = std::make_unique<Observation>(); out->reference = reference(r.wire); auto &view = out->value; view.reference = out->reference.get();
    const auto &binding = reference_binding(r); const auto &outer = v.variant(); view.kind = choice(Json::string(outer.first), {"ddl", "rows", "name_assertion"});
    require(view.kind == expected_kind(r.value.kind, binding), "catalog-observation-kind"); const auto &variant = outer.second.variant(); const auto &raw = variant.second;
    if (variant.first == "not_observed") { raw.fields({}); view.state = TRANSIT_CATALOG_NOT_OBSERVED; return out; }
    require(equal(raw.at("binding"), binding), "catalog-observation-binding");
    if (view.kind == TRANSIT_CATALOG_NAME_OBSERVATION) {
        require(variant.first == "outcome", "catalog-name-outcome"); const auto s = choice(raw.at("state"), {"unchanged", "rejected"});
        view.state = s == 0 ? TRANSIT_CATALOG_UNCHANGED : TRANSIT_CATALOG_REJECTED; view.has_reason = true; view.reason = reason(raw.at("reason")); view.has_position = true; view.position = position(raw.at("position")); return out;
    }
    if (variant.first == "committed") {
        view.state = TRANSIT_CATALOG_COMMITTED; view.has_commit = true; auto &commit = view.commit; commit.definition = stored(raw.at("resulting")); const auto &result = raw.at("outcome");
        commit.position = position(result.at("position")); commit.matched = full(result.at("matched"), true); commit.affected = full(result.at("affected"), true); commit.live_rows = full(result.at("live_rows"), true);
        require(commit.affected <= commit.matched && same_object(commit.definition.interpretation.object, object(binding.at("target"))), "catalog-commit-result"); return out;
    }
    const auto state = choice(Json::string(variant.first), {"admitted", "rejected", "cancelled"}); view.state = state + TRANSIT_CATALOG_ADMITTED;
    view.has_phase = true; view.phase = choice(raw.at("phase"), {"admitted", "ready", "settled", "rejected", "cancelled"});
    require(state == 0 ? view.phase <= TRANSIT_CATALOG_SETTLED : view.phase == state + 2, "catalog-observation-phase");
    (void)content(raw.at("intent")); view.has_reason = true; view.reason = reason(raw.at("reason"));
    if (view.kind == TRANSIT_CATALOG_ROWS) { const auto &b = raw.at("basis"); (void)interpretation(b.at("interpretation")); (void)position(b.at("position")); (void)full(b.at("changed_lsn"), true); }
    return out;
}
std::unique_ptr<Preview> preview(const Json &v, const Intent &i) {
    auto out = std::make_unique<Preview>(); auto &view = out->value; const auto &variant = v.variant(); const auto &raw = variant.second;
    view.kind = choice(Json::string(variant.first), {"ddl", "rows", "name_assertion"}); require(view.kind == expected_kind(i.value.kind, i.binding) && equal(raw.at("binding"), i.binding), "catalog-preview-binding");
    view.has_current = !raw.at("current").is_null();
    if (view.kind == TRANSIT_CATALOG_NAME_OBSERVATION) {
        view.position = position(raw.at("position")); if (view.has_current) view.current_name = interpretation(raw.at("current")); view.matches = raw.at("matches").boolean(); return out;
    }
    view.position = position(raw.at("directory_position")); view.has_reason = true; view.reason = reason(raw.at("reason"));
    if (view.has_current) { const auto &b = raw.at("current"); view.current = {stored(b.at("interpretation")), position(b.at("position")), full(b.at("changed_lsn"), true), full(b.at("row_count"), true)}; }
    if (view.kind == TRANSIT_CATALOG_DDL) {
        view.has_work = !raw.at("work").is_null(); if (view.has_work) view.work = choice(raw.at("work"), {"metadata", "validate_rows", "rewrite_rows"});
        view.rebuild_key = raw.at("rebuild_key").boolean(); view.has_schema_fingerprint = !raw.at("schema_fingerprint").is_null(); if (view.has_schema_fingerprint) digest(raw.at("schema_fingerprint"), view.schema_fingerprint);
    }
    return out;
}
std::unique_ptr<SnapshotStatus> snapshot_status(const Json &v, const Owner &o) {
    require(equal(v.at("owner"), o.wire), "catalog-snapshot-status-owner"); auto out = std::make_unique<SnapshotStatus>(); out->owner = owner(v.at("owner")); auto &view = out->value;
    view.owner = out->owner.get(); view.current_interpretation = interpretation(v.at("current_interpretation")); require(same_object(view.current_interpretation.object, o.value.object), "catalog-snapshot-current-object");
    view.current_position = position(v.at("current_position")); view.retired = v.at("retired").boolean(); view.released = v.at("released").boolean(); view.authority = read_authority(v.at("authority"));
    if (!v.at("snapshot").is_null()) { out->snapshot = snapshot(v.at("snapshot")); require(equal(out->snapshot->owner->wire, o.wire), "catalog-snapshot-owner"); view.snapshot = out->snapshot.get(); }
    return out;
}
std::unique_ptr<SnapshotMetadata> snapshot_metadata(const Json &v, const Snapshot &s) {
    require(equal(v.at("snapshot"), s.wire), "catalog-snapshot-metadata-binding"); auto out = std::make_unique<SnapshotMetadata>(); out->snapshot = snapshot(v.at("snapshot")); auto &view = out->value;
    view.snapshot = out->snapshot.get(); view.interpretation = stored(v.at("interpretation")); view.accepted = position(v.at("accepted")); view.changed_lsn = full(v.at("changed_lsn"), true); view.row_count = full(v.at("row_count"), true);
    view.schema = schema(v.at("schema"), out->arena); view.authority = read_authority(v.at("authority"));
    require(same_object(view.interpretation.interpretation.object, s.owner->value.object) && view.schema.object == s.owner->value.object.object, "catalog-retained-schema"); return out;
}
}
