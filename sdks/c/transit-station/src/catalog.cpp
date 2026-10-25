#include "catalog_internal.hpp"
using namespace transit::sdk::catalog_detail;
namespace ld = transit::sdk::logical_detail;
namespace {
struct NativeCatalog {
    Local local;
    std::unique_ptr<station_catalog_client, decltype(&::station_catalog_destroy)> handle;
    Connection connection;
    uint64_t principal;
    NativeCatalog(const transit_sdk_config &config, const transit_sdk_credential &identity, Connection c, const char *service_url)
        : local(config.native_directory), handle(nullptr, local.station_catalog_destroy), connection(c), principal(identity.principal) {
        if (config.sdk_version != TRANSIT_SDK_VERSION) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "catalog-sdk-version");
        credential(identity); require(identity.realm == c.scope.resource.realm, "catalog-realm");
        const auto url = text(config.url, 2048);
        const auto settings = ld::encode(Json::object({{"definition", Json::string(STATION_ABI_DEFINITION)}, {"connection", connection_wire(c, principal)}, {"timeout_ms", Json::integer(config.timeout_ms)}, {"service_url", service_url ? Json::string(text(service_url, 2048)) : Json{}}}));
        Seed seed(identity.seed_file); station_catalog_client *pointer = nullptr;
        const auto status = local.station_catalog_create(STATION_ABI_VERSION, reinterpret_cast<const uint8_t *>(url.data()), url.size(), seed.data(), reinterpret_cast<const uint8_t *>(settings.data()), settings.size(), &pointer);
        handle.reset(pointer); local.raw.check(status, {}, "open-catalog"); require(pointer, "catalog-handle");
        read(ld::encode(tag("catalog", tag("capabilities"))), {"catalog", "capabilities"}, capabilities);
    }
    Bytes call(const std::string &action, bool mutation) {
        require(action.size() <= max_action, "catalog-action-bound"); station_buffer *buffer = nullptr;
        const auto status = local.station_catalog_call(handle.get(), reinterpret_cast<const uint8_t *>(action.data()), action.size(), &buffer);
        return local.result(status, buffer, "catalog-action", mutation, max_result);
    }
    template<class F> auto read(const std::string &action, std::initializer_list<const char *> path, F &&decode, bool mutation = false) -> decltype(decode(std::declval<const Json &>())) {
        const auto bytes = call(action, mutation);
        try {
            const auto value = ld::parse(view(bytes), max_result); validate("CatalogResult", value); const Json *v = &value;
            for (const auto *key : path) { v->fields({key}); v = &v->at(key); }
            return decode(*v);
        } catch (const Failure &) { fail(mutation ? TRANSIT_SDK_UNKNOWN_OUTCOME : TRANSIT_SDK_INCOMPATIBLE_NATIVE, "catalog-response"); }
        catch (...) { if (mutation) fail(TRANSIT_SDK_UNKNOWN_OUTCOME, "catalog-receipt"); throw; }
    }
    void check(const Json &c) const { owns(c, connection, principal); }
};
}
struct transit_station_catalog_client {
    Worker worker; std::unique_ptr<NativeCatalog> native;
    ~transit_station_catalog_client() { worker.close([&] { native.reset(); }); }
};
namespace {
template<class Build, class F> transit_sdk_error action(transit_station_catalog_client *owner, Build &&build, F &&consume) {
    Uninterruptible guard;
    return boundary([&] {
        require(owner, "catalog-client"); const auto bytes = build(); require(bytes.size() <= max_action, "catalog-action-bound");
        validate("CatalogAction", ld::JsonParser(bytes, max_action).parse());
        owner->worker.run([&] { require(bool(owner->native), "catalog-client"); consume(*owner->native, bytes); });
    });
}
std::string action_bytes(const Json &v) { return ld::encode(v, max_action); }
template<class T, class Decode> transit_sdk_error restore(transit_sdk_bytes bytes, T **out, Decode &&decode) {
    if (out) *out = nullptr; return boundary([&] { require(out, "catalog-saved-output"); auto value = decode(ld::parse(bytes, max_action)); *out = value.release(); });
}
template<class T> transit_sdk_error export_value(const T *value, transit_sdk_bytes *out) {
    if (out) *out = {}; return boundary([&] { require(value && out, "catalog-saved-value"); *out = {reinterpret_cast<const uint8_t *>(value->encoded.data()), value->encoded.size()}; });
}
template<class T, class V> transit_sdk_error get(const T *value, const V **out) {
    if (out) *out = nullptr; return boundary([&] { require(value && out, "catalog-view"); *out = &value->value; });
}
void intent_owner(const Intent &i, NativeCatalog &n) {
    if (i.value.kind == TRANSIT_CATALOG_NAME_ASSERTION) n.check(i.binding.at("connection"));
    else {
        const auto &identity = i.binding.at("identity");
        require(equal(identity.at("scope"), scope_wire(n.connection.scope)) && identity.at("principal").number(TRANSIT_CLIENT_MAX_COUNTER) == n.principal && i.binding.at("target").at("branch").string() == std::to_string(n.connection.branch), "catalog-intent-owner");
    }
}
void prepared_kind(const Intent &i, transit_station_catalog_kind kind, std::optional<uint64_t> object) {
    if (i.value.kind == TRANSIT_CATALOG_NAME_ASSERTION) {
        require((kind == TRANSIT_CATALOG_CREATE && i.binding.at("action").string() == "create_if_not_exists") || (kind == TRANSIT_CATALOG_DROP && i.binding.at("action").string() == "drop_if_exists"), "catalog-prepared-name-kind");
    } else {
        require(i.binding.at("action").string() == kind_name(kind), "catalog-prepared-kind");
        if (object) require(i.binding.at("target").at("object").string() == std::to_string(*object), "catalog-prepared-object");
    }
}
std::optional<uint64_t> request_object(const transit_station_catalog_action &a) {
    if (a.kind == TRANSIT_CATALOG_CREATE) { require(a.as.create.schema, "catalog-schema"); return a.as.create.schema->object; }
    const Basis *b = nullptr;
    switch (a.kind) {
        case TRANSIT_CATALOG_ALTER: b = a.as.alter.basis; break;
        case TRANSIT_CATALOG_RENAME: b = a.as.rename.basis; break;
        case TRANSIT_CATALOG_DROP: b = a.as.drop.basis; break;
        case TRANSIT_CATALOG_INSERT: b = a.as.insert.basis; break;
        case TRANSIT_CATALOG_UPDATE: b = a.as.update.basis; break;
        case TRANSIT_CATALOG_DELETE: b = a.as.remove.basis; break;
        default: fail(TRANSIT_SDK_INVALID_ARGUMENT, "catalog-kind");
    }
    return b ? std::optional<uint64_t>(b->value.interpretation.interpretation.object.object) : std::nullopt;
}
transit_sdk_error operation(transit_station_catalog_client *client, const Reference *r, const char *command, uint16_t steps, Observation **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(r && out && steps, "catalog-operation"); return action_bytes(tag("operation", Json::object({{"reference", r->wire}, {"command", Json::string(command)}, {"steps", Json::integer(steps)}}))); },
        [&](NativeCatalog &n, const std::string &bytes) { n.check(r->wire.variant().second.at("connection")); auto result = n.read(bytes, {"observation"}, [&](const Json &v) { return observation(v, *r); }, std::string_view(command) != "inspect"); *out = result.release(); });
}
}
extern "C" {
transit_sdk_error transit_station_catalog_basis_restore(transit_sdk_bytes b, transit_station_catalog_basis **out) { return restore(b, out, basis); }
transit_sdk_error transit_station_catalog_basis_export(const transit_station_catalog_basis *v, transit_sdk_bytes *out) { return export_value(v, out); }
transit_sdk_error transit_station_catalog_saved_intent_restore(transit_sdk_bytes b, transit_station_catalog_saved_intent **out) { return restore(b, out, saved); }
transit_sdk_error transit_station_catalog_saved_intent_export(const transit_station_catalog_saved_intent *v, transit_sdk_bytes *out) { return export_value(v, out); }
transit_sdk_error transit_station_catalog_reference_restore(transit_sdk_bytes b, transit_station_catalog_reference **out) { return restore(b, out, reference); }
transit_sdk_error transit_station_catalog_reference_export(const transit_station_catalog_reference *v, transit_sdk_bytes *out) { return export_value(v, out); }
transit_sdk_error transit_station_catalog_cursor_restore(transit_sdk_bytes b, transit_station_catalog_cursor **out) { return restore(b, out, cursor); }
transit_sdk_error transit_station_catalog_cursor_export(const transit_station_catalog_cursor *v, transit_sdk_bytes *out) { return export_value(v, out); }
transit_sdk_error transit_station_catalog_snapshot_owner_restore(transit_sdk_bytes b, transit_station_catalog_snapshot_owner **out) { return restore(b, out, owner); }
transit_sdk_error transit_station_catalog_snapshot_owner_export(const transit_station_catalog_snapshot_owner *v, transit_sdk_bytes *out) { return export_value(v, out); }
transit_sdk_error transit_station_catalog_snapshot_acquisition_restore(transit_sdk_bytes b, transit_station_catalog_snapshot_acquisition **out) { return restore(b, out, acquisition); }
transit_sdk_error transit_station_catalog_snapshot_acquisition_export(const transit_station_catalog_snapshot_acquisition *v, transit_sdk_bytes *out) { return export_value(v, out); }
transit_sdk_error transit_station_catalog_snapshot_restore(transit_sdk_bytes b, transit_station_catalog_snapshot **out) { return restore(b, out, snapshot); }
transit_sdk_error transit_station_catalog_snapshot_export(const transit_station_catalog_snapshot *v, transit_sdk_bytes *out) { return export_value(v, out); }
void transit_station_catalog_basis_destroy(transit_station_catalog_basis *v) { delete v; }
transit_sdk_error transit_station_catalog_basis_get(const transit_station_catalog_basis *v, const transit_station_catalog_basis_view **out) { return get(v, out); }
void transit_station_catalog_saved_intent_destroy(transit_station_catalog_saved_intent *v) { delete v; }
void transit_station_catalog_reference_destroy(transit_station_catalog_reference *v) { delete v; }
transit_sdk_error transit_station_catalog_reference_get(const transit_station_catalog_reference *v, const transit_station_catalog_reference_view **out) { return get(v, out); }
void transit_station_catalog_cursor_destroy(transit_station_catalog_cursor *v) { delete v; }
transit_sdk_error transit_station_catalog_cursor_get(const transit_station_catalog_cursor *v, const transit_station_catalog_cursor_view **out) { return get(v, out); }
void transit_station_catalog_snapshot_owner_destroy(transit_station_catalog_snapshot_owner *v) { delete v; }
transit_sdk_error transit_station_catalog_snapshot_owner_get(const transit_station_catalog_snapshot_owner *v, const transit_station_catalog_snapshot_owner_view **out) { return get(v, out); }
void transit_station_catalog_snapshot_acquisition_destroy(transit_station_catalog_snapshot_acquisition *v) { delete v; }
transit_sdk_error transit_station_catalog_snapshot_acquisition_get(const transit_station_catalog_snapshot_acquisition *v, const transit_station_catalog_snapshot_acquisition_view **out) { return get(v, out); }
void transit_station_catalog_snapshot_destroy(transit_station_catalog_snapshot *v) { delete v; }
transit_sdk_error transit_station_catalog_snapshot_get(const transit_station_catalog_snapshot *v, const transit_station_catalog_snapshot_view **out) { return get(v, out); }
void transit_station_catalog_intent_destroy(transit_station_catalog_intent *v) { delete v; }
transit_sdk_error transit_station_catalog_intent_get(const transit_station_catalog_intent *v, const transit_station_catalog_intent_view **out) { return get(v, out); }
void transit_station_catalog_compiled_destroy(transit_station_catalog_compiled *v) { delete v; }
void transit_station_catalog_metadata_destroy(transit_station_catalog_metadata *v) { delete v; }
transit_sdk_error transit_station_catalog_metadata_get(const transit_station_catalog_metadata *v, const transit_station_catalog_metadata_view **out) { return get(v, out); }
void transit_station_catalog_namespace_page_destroy(transit_station_catalog_namespace_page *v) { delete v; }
transit_sdk_error transit_station_catalog_namespace_page_get(const transit_station_catalog_namespace_page *v, const transit_station_catalog_namespace_page_view **out) { return get(v, out); }
void transit_station_catalog_table_page_destroy(transit_station_catalog_table_page *v) { delete v; }
transit_sdk_error transit_station_catalog_table_page_get(const transit_station_catalog_table_page *v, const transit_station_catalog_table_page_view **out) { return get(v, out); }
void transit_station_catalog_observation_destroy(transit_station_catalog_observation *v) { delete v; }
transit_sdk_error transit_station_catalog_observation_get(const transit_station_catalog_observation *v, const transit_station_catalog_observation_view **out) { return get(v, out); }
void transit_station_catalog_preview_destroy(transit_station_catalog_preview *v) { delete v; }
transit_sdk_error transit_station_catalog_preview_get(const transit_station_catalog_preview *v, const transit_station_catalog_preview_view **out) { return get(v, out); }
void transit_station_catalog_snapshot_status_destroy(transit_station_catalog_snapshot_status *v) { delete v; }
transit_sdk_error transit_station_catalog_snapshot_status_get(const transit_station_catalog_snapshot_status *v, const transit_station_catalog_snapshot_status_view **out) { return get(v, out); }
void transit_station_catalog_snapshot_metadata_destroy(transit_station_catalog_snapshot_metadata *v) { delete v; }
transit_sdk_error transit_station_catalog_snapshot_metadata_get(const transit_station_catalog_snapshot_metadata *v, const transit_station_catalog_snapshot_metadata_view **out) { return get(v, out); }
transit_sdk_error transit_station_catalog_compiled_get(const Compiled *v, const Intent **intent, const Saved **saved) {
    if (intent) *intent = nullptr; if (saved) *saved = nullptr;
    return boundary([&] { require(v && intent && saved, "catalog-compiled"); *intent = v->intent.get(); *saved = v->intent->saved.get(); });
}
transit_sdk_error transit_station_catalog_open(const transit_sdk_config *config, const transit_sdk_credential *identity, Connection connection, const char *service_url, transit_station_catalog_client **out) {
    Uninterruptible guard; if (out) *out = nullptr; return boundary([&] {
        require(config && identity && out, "catalog-open"); auto owner = std::make_unique<transit_station_catalog_client>();
        owner->worker.run([&] { owner->native = std::make_unique<NativeCatalog>(*config, *identity, connection, service_url); }); *out = owner.release();
    });
}
transit_sdk_error transit_station_catalog_close(transit_station_catalog_client *owner) {
    Uninterruptible guard; return boundary([&] { require(owner, "catalog-client"); owner->worker.close([&] { owner->native.reset(); }); });
}
void transit_station_catalog_client_destroy(transit_station_catalog_client *value) { Uninterruptible guard; delete value; }
transit_sdk_error transit_station_catalog_capabilities_read(transit_station_catalog_client *client, Capabilities *out) {
    if (out) *out = {}; return action(client, [&] { require(out, "catalog-capabilities"); return action_bytes(tag("catalog", tag("capabilities"))); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, {"catalog", "capabilities"}, capabilities); });
}
transit_sdk_error transit_station_catalog_describe(transit_station_catalog_client *client, Description *out) {
    if (out) *out = {}; return action(client, [&] { require(out, "catalog-description"); return action_bytes(tag("catalog", tag("describe"))); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, {"catalog", "description"}, [&](const Json &v) { return description(v, n.connection, n.principal); }); });
}
transit_sdk_error transit_station_catalog_namespace_read(transit_station_catalog_client *client, uint64_t id, bool *found, Namespace *out) {
    if (found) *found = false; if (out) *out = {};
    return action(client, [&] { require(found && out, "catalog-namespace"); return action_bytes(tag("catalog", tag("namespace", small(id)))); },
        [&](NativeCatalog &n, const std::string &bytes) { n.read(bytes, {"catalog", "namespace"}, [&](const Json &v) { if (!v.is_null()) { auto value = namespace_value(v, n.connection, id); *out = value; *found = true; } }); });
}
transit_sdk_error transit_station_catalog_namespaces(transit_station_catalog_client *client, const Cursor *cursor, NamespacePage **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(out, "catalog-namespaces"); return action_bytes(tag("catalog", tag("namespaces", cursor ? cursor->wire : Json{}))); },
        [&](NativeCatalog &n, const std::string &bytes) { if (cursor) cursor_check(*cursor, n.connection, n.principal, 0); auto result = n.read(bytes, {"catalog", "namespaces"}, [&](const Json &v) { return namespace_page(v, n.connection, n.principal, cursor); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_tables(transit_station_catalog_client *client, uint64_t ns, const Cursor *cursor, TablePage **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(out, "catalog-tables"); return action_bytes(tag("catalog", tag("tables", Json::object({{"namespace", small(ns)}, {"cursor", cursor ? cursor->wire : Json{}}})))); },
        [&](NativeCatalog &n, const std::string &bytes) { if (cursor) cursor_check(*cursor, n.connection, n.principal, ns); auto result = n.read(bytes, {"catalog", "tables"}, [&](const Json &v) { return table_page(v, n.connection, n.principal, ns, cursor); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_lookup(transit_station_catalog_client *client, const char *value, uint64_t ns, Metadata **out) {
    if (out) *out = nullptr; std::string expected;
    return action(client, [&] { require(out, "catalog-lookup"); expected = name(value); return action_bytes(tag("lookup", Json::object({{"namespace", small(ns)}, {"name", Json::string(expected)}}))); },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, {"metadata"}, [&](const Json &v) { return metadata(v, n.connection, n.principal, expected, ns); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_compile_sql(transit_station_catalog_client *client, const char *sql, Identity id, const uint64_t *create_object, transit_station_catalog_dialect dialect, transit_station_catalog_ingestion ingestion, Compiled **out) {
    const std::optional<uint64_t> requested = create_object ? std::optional<uint64_t>(*create_object) : std::nullopt; if (out) *out = nullptr;
    return action(client, [&] {
        require(out && dialect <= TRANSIT_CATALOG_MYSQL && ingestion <= TRANSIT_CATALOG_BULK, "catalog-compile"); const auto statement = text(sql, 4096); require(!statement.empty(), "catalog-sql");
        return action_bytes(tag("compile", Json::object({{"sql", Json::string(statement)}, {"namespace", small(id.namespace_id)}, {"operation", wide(id.operation)}, {"create_object", requested ? wide(*requested) : Json{}}, {"dialect", Json::string(dialect ? "mysql" : "transit")}, {"ingestion", Json::string(ingestion ? "bulk" : "point")}})));
    }, [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, {"compiled"}, [&](const Json &v) { auto result = compiled(v, n.connection, n.principal, id); if (requested) prepared_kind(*result->intent, TRANSIT_CATALOG_CREATE, requested); return result; }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_prepare(transit_station_catalog_client *client, const Request *value, Compiled **out) {
    if (out) *out = nullptr; Identity expected{}; transit_station_catalog_kind kind{}; std::optional<uint64_t> object;
    return action(client, [&] { require(value && out, "catalog-prepare"); expected = value->identity; kind = value->action.kind; object = request_object(value->action); return request_wire(*value); },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, {"compiled"}, [&](const Json &v) { auto result = compiled(v, n.connection, n.principal, expected); prepared_kind(*result->intent, kind, object); return result; }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_load(transit_station_catalog_client *client, const Saved *s, Intent **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(s && out, "catalog-load"); return action_bytes(tag("load", s->wire)); },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, {"loaded"}, [&](const Json &v) { return intent(v, *s, n.connection, n.principal); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_forget(transit_station_catalog_client *client, const Intent *i) {
    return action(client, [&] { require(i, "catalog-forget"); return action_bytes(tag("forget", i->id)); },
        [&](NativeCatalog &n, const std::string &bytes) { intent_owner(*i, n); n.read(bytes, {"forgotten"}, [](const Json &v) { v.fields({}); }); });
}
transit_sdk_error transit_station_catalog_preview_read(transit_station_catalog_client *client, const Intent *i, Preview **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(i && out, "catalog-preview"); return action_bytes(tag("preview", i->id)); },
        [&](NativeCatalog &n, const std::string &bytes) { intent_owner(*i, n); auto result = n.read(bytes, {"preview"}, [&](const Json &v) { return preview(v, *i); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_stage(transit_station_catalog_client *client, const Intent *i, Reference **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(i && out, "catalog-stage"); return action_bytes(tag("stage", i->id)); },
        [&](NativeCatalog &n, const std::string &bytes) { intent_owner(*i, n); auto result = n.read(bytes, {"staged"}, [&](const Json &v) { return staged(v, *i, n.connection, n.principal); }, true); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_admit(transit_station_catalog_client *client, const Reference *r, Observation **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(r && out, "catalog-admit"); return action_bytes(tag("admit", r->wire)); },
        [&](NativeCatalog &n, const std::string &bytes) { n.check(r->wire.variant().second.at("connection")); auto result = n.read(bytes, {"observation"}, [&](const Json &v) { return observation(v, *r); }, true); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_inspect(transit_station_catalog_client *c, const Reference *r, Observation **out) { return operation(c, r, "inspect", 256, out); }
transit_sdk_error transit_station_catalog_execute(transit_station_catalog_client *c, const Reference *r, uint16_t steps, Observation **out) { return operation(c, r, "execute", steps, out); }
transit_sdk_error transit_station_catalog_cancel(transit_station_catalog_client *c, const Reference *r, Observation **out) { return operation(c, r, "cancel", 256, out); }
transit_sdk_error transit_station_catalog_prepare_snapshot(const Metadata *m, uint64_t op, Acquisition **out) {
    if (out) *out = nullptr; return boundary([&] {
        require(m && out, "catalog-prepare-snapshot"); const auto &basis = m->basis;
        auto o = Json::object({{"definition", Json::string(STATION_ABI_DEFINITION)}, {"connection", basis->wire.at("connection")}, {"object", object_wire(basis->value.interpretation.interpretation.object)}, {"operation", wide(op)}});
        auto result = acquisition(Json::object({{"owner", std::move(o)}, {"expected", position_wire(m->value.position)}})); *out = result.release();
    });
}
transit_sdk_error transit_station_catalog_acquire_snapshot(transit_station_catalog_client *client, const Acquisition *a, Snapshot **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(a && out, "catalog-acquire-snapshot"); return action_bytes(tag("retention", tag("acquire", a->wire))); },
        [&](NativeCatalog &n, const std::string &bytes) { n.check(a->owner->wire.at("connection")); auto result = n.read(bytes, {"retention", "acquired"}, [&](const Json &v) { auto s = snapshot(v); require(equal(s->owner->wire, a->owner->wire), "catalog-acquired-owner"); return s; }, true); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_snapshot_status_read(transit_station_catalog_client *client, const Owner *o, SnapshotStatus **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(o && out, "catalog-snapshot-status"); return action_bytes(tag("retention", tag("status", o->wire))); },
        [&](NativeCatalog &n, const std::string &bytes) { n.check(o->wire.at("connection")); auto result = n.read(bytes, {"retention", "status"}, [&](const Json &v) { return snapshot_status(v, *o); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_snapshot_metadata_read(transit_station_catalog_client *client, const Snapshot *s, SnapshotMetadata **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(s && out, "catalog-snapshot-metadata"); return action_bytes(tag("retention", tag("metadata", s->wire))); },
        [&](NativeCatalog &n, const std::string &bytes) { n.check(s->owner->wire.at("connection")); auto result = n.read(bytes, {"retention", "metadata"}, [&](const Json &v) { return snapshot_metadata(v, *s); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_release_snapshot(transit_station_catalog_client *client, const Snapshot *s) {
    return action(client, [&] { require(s, "catalog-release-snapshot"); return action_bytes(tag("retention", tag("release", s->wire))); },
        [&](NativeCatalog &n, const std::string &bytes) { n.check(s->owner->wire.at("connection")); n.read(bytes, {"retention", "released"}, [&](const Json &v) { require(equal(v, s->wire), "catalog-released-binding"); }, true); });
}
}
