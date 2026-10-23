#include "catalog_internal.hpp"

namespace transit::sdk::catalog_detail {
namespace {
uint64_t full(const Json &v, bool zero = false) { return logical_detail::wide(v, zero); }
uint64_t small(const Json &v, bool zero = false) { return v.number(TRANSIT_CLIENT_MAX_COUNTER, zero); }
uint32_t choice(const Json &v, std::initializer_list<const char *> names) {
    const auto &text = v.string(); uint32_t i = 0; for (const auto *name : names) { if (text == name) return i; ++i; }
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "catalog-response-tag");
}
void current(const Json &v) { require(v.string() == STATION_ABI_DEFINITION, "catalog-response-definition"); }
template<size_t N> void string(const Json &v, char (&out)[N], bool empty = false) {
    const auto &text = v.string(); require((empty || !text.empty()) && text.size() < N && text.find('\0') == std::string::npos, "catalog-response-string");
    std::copy(text.begin(), text.end(), out); out[text.size()] = 0;
}
Bytes bytes(const Json &v, size_t max, std::optional<size_t> exact = {}) {
    const auto &text = v.string(); require(text.size() % 2 == 0 && text.size() / 2 <= max && (!exact || text.size() / 2 == *exact), "catalog-response-hex");
    for (const auto c : text) require((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'), "catalog-response-hex");
    return unhex(text, max);
}
void digest(const Json &v, uint8_t (&out)[32]) { const auto data = bytes(v, 32, 32); std::copy(data.begin(), data.end(), out); }
Scope scope(const Json &v) { v.fields({"realm", "resource", "catalog"}); return {{small(v.at("realm")), small(v.at("resource"))}, full(v.at("catalog"))}; }
Configuration configuration(const Json &v) {
    v.fields({"scope", "owner", "administrator", "table_limits", "authority", "database_name"});
    Configuration out{}; out.scope = scope(v.at("scope")); out.owner = {out.scope.resource.realm, small(v.at("owner"))}; out.administrator = small(v.at("administrator"), true);
    const auto &limits = v.at("table_limits"); limits.fields({"record_bytes", "staging_bytes", "staging_records"});
    out.table_limits = {static_cast<uint32_t>(limits.at("record_bytes").number(UINT32_MAX, false)), full(limits.at("staging_bytes")), static_cast<uint32_t>(limits.at("staging_records").number(UINT32_MAX, false))};
    const auto &a = v.at("authority"); a.fields({"database_domain", "schema_domain", "table_domain", "database", "initial_schema_authority", "initial_schema"});
    out.authority = {small(a.at("database_domain")), small(a.at("schema_domain")), small(a.at("table_domain")), small(a.at("database")), small(a.at("initial_schema_authority")), small(a.at("initial_schema"))};
    string(v.at("database_name"), out.database_name); (void)configuration_wire(out); return out;
}
Subject subject(const Json &v) {
    v.fields({"principal", "login_role", "role", "credential_epoch", "audience", "context"});
    Subject out{small(v.at("principal"), true), small(v.at("login_role"), true), small(v.at("role"), true), small(v.at("credential_epoch")), small(v.at("audience")), {}};
    const auto &context = v.at("context").array(32); require(context.size() == 32, "catalog-subject-context");
    for (size_t i = 0; i < 32; ++i) out.context[i] = static_cast<uint8_t>(context[i].number(255)); return out;
}
Metadata metadata(const Json &v) {
    v.fields({"scope", "namespace", "object", "revision", "name", "schema_fingerprint", "principal", "operation", "admitted_input", "commitment"}); Metadata out{};
    out.scope = scope(v.at("scope")); out.namespace_id = small(v.at("namespace")); out.object = full(v.at("object")); out.revision = full(v.at("revision")); string(v.at("name"), out.name);
    digest(v.at("schema_fingerprint"), out.schema_fingerprint); out.principal = small(v.at("principal"), true); out.operation = full(v.at("operation")); out.admitted_input = small(v.at("admitted_input"));
    const auto &c = v.at("commitment"); c.fields({"format", "length", "digest"});
    require(c.at("format").number(UINT32_MAX) == 0x54434d01, "catalog-metadata-format");
    out.commitment.bytes = static_cast<uint32_t>(c.at("length").number(444, false));
    const auto &bytes = c.at("digest").array(32); require(bytes.size() == 32, "catalog-metadata-digest");
    for (size_t i = 0; i < bytes.size(); ++i) out.commitment.digest[i] = static_cast<uint8_t>(bytes[i].number(255));
    return out;
}
Head head(const Json &v) { v.fields({"revision", "rows", "pending"}); return {full(v.at("revision")), full(v.at("rows"), true), full(v.at("pending"), true)}; }
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
}
Cursor cursor(const Json &v) {
    v.fields({"definition", "scope", "resource_revision", "after_object"}); current(v.at("definition")); Cursor out{}; string(v.at("definition"), out.definition);
    out.scope = scope(v.at("scope")); out.resource_revision = small(v.at("resource_revision"), true); out.after_object = full(v.at("after_object")); return out;
}
transit_station_catalog_kind kind(const Json &v) { return choice(v, {"create", "alter", "rename", "drop", "insert", "update", "delete"}); }
transit_sdk_diagnostic diagnostic(const Json &v, const Local &local) {
    const auto data = logical_detail::encode(v, 32768);
    require(local.raw.transit_diagnostic_validate(reinterpret_cast<const uint8_t *>(data.data()), data.size()) == 1, "catalog-diagnostic");
    transit_sdk_diagnostic out{}; out.size = data.size(); std::copy(data.begin(), data.end(), out.json); return out;
}
Outcome outcome(const Json &v, const Local &local) {
    v.fields({"kind", "operation", "object", "actual_object", "phase", "terminal", "counts", "admitted_input", "completed_input", "diagnostic"}); Outcome out{};
    out.kind = kind(v.at("kind")); out.operation = full(v.at("operation")); out.object = full(v.at("object"), true);
    if (!v.at("actual_object").is_null()) { out.has_actual_object = true; out.actual_object = full(v.at("actual_object"), true); }
    out.phase = choice(v.at("phase"), {"preparing", "delegated", "building", "applied", "unchanged", "rejected", "cancelled"}); out.terminal = v.at("terminal").boolean();
    require(out.terminal == (out.phase >= TRANSIT_CATALOG_APPLIED), "catalog-terminal"); out.has_counts = !v.at("counts").is_null();
    require(out.has_counts == (out.phase == TRANSIT_CATALOG_APPLIED && out.kind >= TRANSIT_CATALOG_INSERT), "catalog-counts");
    if (out.has_counts) {
        const auto &counts = v.at("counts"); counts.fields({"matched", "changed"}); out.counts = {full(counts.at("matched"), true), full(counts.at("changed"), true)};
        require(out.counts.changed <= out.counts.matched, "catalog-counts");
    }
    out.admitted_input = small(v.at("admitted_input")); if (!v.at("completed_input").is_null()) { out.has_completed_input = true; out.completed_input = small(v.at("completed_input")); }
    out.diagnostic = diagnostic(v.at("diagnostic"), local); return out;
}
Upload upload(const Json &v) {
    v.fields({"phase", "received", "total"}); Upload out{choice(v.at("phase"), {"uploading", "sealed", "ready", "cancelled"}), static_cast<uint32_t>(v.at("received").number(max_intent)), static_cast<uint32_t>(v.at("total").number(max_intent, false))};
    require(out.received <= out.total, "catalog-upload"); return out;
}
State state_fields(const Json &v, const Local &local) {
    State out{}; if (!v.at("outcome").is_null()) { out.has_outcome = true; out.outcome = outcome(v.at("outcome"), local); }
    if (!v.at("upload").is_null()) { out.has_upload = true; out.upload = upload(v.at("upload")); } return out;
}
}
Schema schema(const Json &value, Arena &arena) { return decode_schema(value, arena); }
Capabilities capabilities(const Json &v) {
    v.fields({"version", "definition", "max_columns", "max_rows", "max_sql_bytes", "max_intent_bytes", "max_action_bytes", "max_prepared_bytes", "resident_intents"}); current(v.at("definition"));
    Capabilities out{}; out.version = static_cast<uint8_t>(v.at("version").number(UINT8_MAX, false)); string(v.at("definition"), out.definition);
    out.max_columns = static_cast<uint16_t>(v.at("max_columns").number(UINT16_MAX, false)); out.max_rows = static_cast<uint16_t>(v.at("max_rows").number(UINT16_MAX, false));
    out.max_sql_bytes = static_cast<uint16_t>(v.at("max_sql_bytes").number(UINT16_MAX, false)); out.max_intent_bytes = static_cast<uint32_t>(v.at("max_intent_bytes").number(UINT32_MAX, false));
    out.max_action_bytes = static_cast<uint32_t>(v.at("max_action_bytes").number(UINT32_MAX, false)); out.max_prepared_bytes = static_cast<uint16_t>(v.at("max_prepared_bytes").number(UINT16_MAX, false));
    out.resident_intents = static_cast<uint8_t>(v.at("resident_intents").number(UINT8_MAX, false));
    require(out.version == 1 && out.max_columns == 128 && out.max_rows == 1024 && out.max_sql_bytes == 4096 && out.max_intent_bytes == max_intent && out.max_action_bytes == max_action && out.max_prepared_bytes == max_prepared && out.resident_intents == 1, "catalog-capabilities"); return out;
}
Description description(const Json &v, Connection c, uint64_t principal) {
    v.fields({"configuration", "subject", "authorization_revision", "resource_revision"});
    Description out{configuration(v.at("configuration")), subject(v.at("subject")), small(v.at("authorization_revision"), true), small(v.at("resource_revision"), true)};
    require(same_scope(out.configuration.scope, c.scope) && out.configuration.owner.realm == c.owner.realm && out.configuration.owner.pid == c.owner.pid && out.subject.principal == principal && out.subject.audience == c.owner.pid && out.subject.role == (c.has_role ? c.role : out.subject.login_role), "catalog-description-identity"); return out;
}
std::unique_ptr<Definition> definition(const Json &v, Connection c, const std::string &name) {
    if (v.is_null()) return {}; v.fields({"metadata", "head", "schema", "authorization"}); auto out = std::make_unique<Definition>();
    out->value.authorization = small(v.at("authorization")); out->value.metadata = metadata(v.at("metadata")); out->value.head = head(v.at("head")); out->value.schema = schema(v.at("schema"), out->arena);
    require(same_scope(out->value.metadata.scope, c.scope) && out->value.metadata.namespace_id == c.namespace_id && name == out->value.metadata.name && out->value.metadata.object == out->value.schema.object, "catalog-lookup-identity"); return out;
}
std::unique_ptr<Historical> historical(const Json &v, Scope s, uint64_t object, uint64_t revision) {
    if (v.is_null()) return {}; v.fields({"metadata", "schema"}); auto out = std::make_unique<Historical>(); out->value.metadata = metadata(v.at("metadata")); out->value.schema = schema(v.at("schema"), out->arena);
    require(same_scope(out->value.metadata.scope, s) && out->value.metadata.object == object && out->value.metadata.revision == revision && out->value.schema.object == object, "catalog-history-identity"); return out;
}
Page page(const Json &v, Connection c, const Cursor *previous) {
    const auto s = c.scope;
    v.fields({"resource_revision", "entries", "next"}); Page out{}; out.resource_revision = small(v.at("resource_revision"), true); const auto &entries = v.at("entries").array(8); require(entries.size() == 8, "catalog-page-size");
    bool ended = false;
    for (const auto &e : entries) {
        if (e.is_null()) { ended = true; continue; } require(!ended, "catalog-page-density"); e.fields({"metadata", "head"}); const auto m = metadata(e.at("metadata"));
        require(same_scope(m.scope, s) && m.namespace_id == c.namespace_id && (!out.count || out.entries[out.count - 1].metadata.object < m.object), "catalog-page-order");
        out.entries[out.count++] = {m, head(e.at("head"))};
    }
    if (!v.at("next").is_null()) {
        out.has_next = true; out.next = cursor(v.at("next"));
        require(same_scope(out.next.scope, s) && out.next.resource_revision == out.resource_revision && (!out.count || out.next.after_object >= out.entries[out.count - 1].metadata.object), "catalog-page-next");
    }
    if (previous) require(same_scope(previous->scope, s) && previous->resource_revision == out.resource_revision && (!out.count || out.entries[0].metadata.object > previous->after_object) && (!out.has_next || out.next.after_object > previous->after_object), "catalog-page-continuation"); return out;
}
Intent intent(const Json &v, Connection c, uint64_t principal) {
    v.fields({"reference", "scope", "owner", "principal", "operation", "namespace", "object", "kind"}); Intent out{}; const auto &r = v.at("reference"); r.fields({"definition", "digest"}); current(r.at("definition")); string(r.at("definition"), out.reference.definition); digest(r.at("digest"), out.reference.digest);
    out.scope = scope(v.at("scope")); out.owner = {out.scope.resource.realm, small(v.at("owner"))}; out.principal = small(v.at("principal"), true);
    out.identity = {full(v.at("operation")), full(v.at("namespace"))}; out.object = full(v.at("object"), true); out.kind = kind(v.at("kind"));
    require(same_scope(out.scope, c.scope) && out.owner.realm == c.owner.realm && out.owner.pid == c.owner.pid && out.principal == principal, "catalog-intent-identity"); return out;
}
std::unique_ptr<Compiled> compiled(const Json &v, Connection c, uint64_t principal, Identity id, std::optional<transit_station_catalog_kind> expected_kind, std::optional<uint64_t> object) {
    v.fields({"intent", "saved"}); auto out = std::make_unique<Compiled>(); out->intent = intent(v.at("intent"), c, principal);
    require(out->intent.identity.operation == id.operation && out->intent.identity.namespace_id == id.namespace_id && (!expected_kind || out->intent.kind == *expected_kind) && (!object || out->intent.object == *object), "catalog-compiled-identity");
    const auto &saved = v.at("saved"); saved.fields({"definition", "bytes"}); current(saved.at("definition")); out->saved.definition = saved.at("definition").string(); out->saved.bytes = bytes(saved.at("bytes"), max_intent);
    require(!out->saved.bytes.empty(), "catalog-saved-intent"); return out;
}
std::unique_ptr<Prepared> prepared(const Json &v) { const auto &text = v.string(); require(!text.empty() && text.size() <= max_prepared, "catalog-prepared"); return std::make_unique<Prepared>(Prepared{Bytes(text.begin(), text.end())}); }
State state(const Json &v, const Local &local) { v.fields({"outcome", "upload"}); return state_fields(v, local); }
Disposition disposition(const Json &v, const Local &local) {
    if (v.is_null()) return {}; v.fields({"input", "outcome", "diagnostic"}); return {true, small(v.at("input")), choice(v.at("outcome"), {"initialized", "policy_applied", "dependency_applied", "invalid_command", "blocked", "denied", "identity_conflict", "stale_policy"}), diagnostic(v.at("diagnostic"), local)};
}
Progress progress(const Json &v, const Local &local) {
    const auto &entry = v.variant(); Progress out{};
    if (entry.first == "pending") { entry.second.fields({}); return out; }
    require(entry.first == "processed", "catalog-progress"); const auto &p = entry.second; p.fields({"disposition", "outcome", "upload"});
    out.observation = TRANSIT_CATALOG_PROCESSED; out.disposition = disposition(p.at("disposition"), local); out.state = state_fields(p, local); return out;
}
std::unique_ptr<Next> next(const Json &v, const Local &local) {
    const auto &entry = v.variant(); auto out = std::make_unique<Next>();
    if (entry.first == "send") { out->kind = TRANSIT_CATALOG_NEXT_SEND; out->prepared = prepared(entry.second); }
    else if (entry.first == "terminal") { out->kind = TRANSIT_CATALOG_NEXT_TERMINAL; out->outcome = outcome(entry.second, local); require(out->outcome->terminal, "catalog-terminal"); }
    else { require(entry.first == "running" || entry.first == "upload_cancelled", "catalog-next"); entry.second.fields({}); out->kind = entry.first == "running" ? TRANSIT_CATALOG_NEXT_RUNNING : TRANSIT_CATALOG_NEXT_UPLOAD_CANCELLED; }
    return out;
}
}
