#include "catalog_internal.hpp"
using namespace transit::sdk::catalog_detail;
namespace ld = transit::sdk::logical_detail;
namespace {
Json tag(const char *name, Json value = Json::object()) { return Json::object({{name, std::move(value)}}); }
struct NativeCatalog {
    Local local;
    std::unique_ptr<station_catalog_client, decltype(&::station_catalog_destroy)> handle;
    Connection connection;
    uint64_t principal;
    NativeCatalog(const transit_sdk_config &config, const transit_sdk_credential &identity, Connection c)
        : local(config.native_directory), handle(nullptr, local.station_catalog_destroy), connection(c), principal(identity.principal) {
        if (config.sdk_version != TRANSIT_SDK_VERSION) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "catalog-sdk-version");
        credential(identity); require(identity.realm == c.owner.realm, "catalog-realm");
        const auto url = text(config.url, 2048);
        const auto settings = ld::encode(Json::object({{"connection", connection_wire(c, principal)}, {"timeout_ms", Json::integer(config.timeout_ms)}}));
        Seed seed(identity.seed_file); station_catalog_client *pointer = nullptr;
        const auto status = local.station_catalog_create(STATION_ABI_VERSION, reinterpret_cast<const uint8_t *>(url.data()), url.size(), seed.data(), reinterpret_cast<const uint8_t *>(settings.data()), settings.size(), &pointer);
        handle.reset(pointer); local.raw.check(status, {}, "open-catalog"); require(pointer, "catalog-handle");
        read(ld::encode(tag("capabilities")), "capabilities", [](const Json &v) { return capabilities(v); });
    }
    Bytes call(const std::string &action, bool mutation) {
        require(action.size() <= max_action, "catalog-action-bound"); station_buffer *buffer = nullptr;
        const auto status = local.station_catalog_call(handle.get(), reinterpret_cast<const uint8_t *>(action.data()), action.size(), &buffer);
        return local.result(status, buffer, "catalog-action", mutation, max_result);
    }
    template<class F> auto read(const std::string &action, const char *key, F &&decode, bool mutation = false) -> decltype(decode(std::declval<const Json &>())) {
        const auto bytes = call(action, mutation);
        try {
            const auto value = ld::parse(view(bytes), max_result); value.fields({key}); return decode(value.at(key));
        } catch (const Failure &) { fail(mutation ? TRANSIT_SDK_UNKNOWN_OUTCOME : TRANSIT_SDK_INCOMPATIBLE_NATIVE, "catalog-response"); }
        catch (...) { if (mutation) fail(TRANSIT_SDK_UNKNOWN_OUTCOME, "catalog-receipt"); throw; }
    }
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
        owner->worker.run([&] { require(bool(owner->native), "catalog-client"); consume(*owner->native, bytes); });
    });
}
template<class Build> transit_sdk_error prepare_action(transit_station_catalog_client *client, Prepared **out, Build &&build) {
    if (out) *out = nullptr;
    return action(client, [&] { require(out, "catalog-prepared"); return ld::encode(build()); },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, "prepared", prepared); *out = result.release(); });
}
Json reference_action(const char *key, const Reference *value) { require(value, "catalog-reference"); return tag(key, reference_wire(*value)); }
Json input(const Prepared *p, uint64_t position) {
    require(p, "catalog-prepared"); counter(position); return Json::object({{"prepared", prepared_wire(*p)}, {"input", Json::integer(position)}});
}
std::optional<uint64_t> object(const transit_station_catalog_action &a) {
    switch (a.kind) {
        case TRANSIT_CATALOG_CREATE: require(a.as.create.schema, "catalog-schema"); return a.as.create.schema->object;
        case TRANSIT_CATALOG_ALTER: return a.as.alter.basis.object;
        case TRANSIT_CATALOG_RENAME: return a.as.rename.basis.object;
        case TRANSIT_CATALOG_DROP: return a.as.drop.basis ? a.as.drop.basis->object : 0;
        case TRANSIT_CATALOG_INSERT: return a.as.insert.basis.object;
        case TRANSIT_CATALOG_UPDATE: return a.as.update.basis.object;
        case TRANSIT_CATALOG_DELETE: return a.as.remove.basis.object;
        default: fail(TRANSIT_SDK_INVALID_ARGUMENT, "catalog-kind");
    }
}
}
extern "C" {
transit_sdk_error transit_station_catalog_saved_import(const char *definition, transit_sdk_bytes bytes, Saved **out) {
    if (out) *out = nullptr; return boundary([&] {
        require(out && bytes.size, "catalog-saved-intent"); current(definition);
        auto value = std::make_unique<Saved>(); value->definition = definition; value->bytes = copy(bytes, max_intent); *out = value.release();
    });
}
transit_sdk_error transit_station_catalog_saved_get(const Saved *value, const char **definition, transit_sdk_bytes *out) {
    if (definition) *definition = nullptr; if (out) *out = {}; return boundary([&] { require(value && definition && out, "catalog-saved-intent"); *definition = value->definition.c_str(); *out = view(value->bytes); });
}
void transit_station_catalog_saved_destroy(Saved *value) { delete value; }
transit_sdk_error transit_station_catalog_compiled_get(const Compiled *value, Intent *out, const Saved **saved) {
    if (out) *out = {}; if (saved) *saved = nullptr; return boundary([&] { require(value && out && saved, "catalog-compiled"); *out = value->intent; *saved = &value->saved; });
}
void transit_station_catalog_compiled_destroy(Compiled *value) { delete value; }
transit_sdk_error transit_station_catalog_prepared_import(transit_sdk_bytes bytes, Prepared **out) {
    if (out) *out = nullptr; return boundary([&] {
        require(out && bytes.size, "catalog-prepared"); auto data = copy(bytes, max_prepared); ld::utf8({reinterpret_cast<const char *>(data.data()), data.size()});
        *out = new Prepared{std::move(data)};
    });
}
transit_sdk_error transit_station_catalog_prepared_bytes(const Prepared *value, transit_sdk_bytes *out) {
    if (out) *out = {}; return boundary([&] { require(value && out, "catalog-prepared"); *out = view(value->bytes); });
}
void transit_station_catalog_prepared_destroy(Prepared *value) { delete value; }
transit_sdk_error transit_station_catalog_definition_get(const Definition *value, const transit_station_catalog_definition_view **out) {
    if (out) *out = nullptr; return boundary([&] { require(value && out, "catalog-definition"); *out = &value->value; });
}
void transit_station_catalog_definition_destroy(Definition *value) { delete value; }
transit_sdk_error transit_station_catalog_historical_get(const Historical *value, const transit_station_catalog_historical_view **out) {
    if (out) *out = nullptr; return boundary([&] { require(value && out, "catalog-history"); *out = &value->value; });
}
void transit_station_catalog_historical_destroy(Historical *value) { delete value; }
transit_sdk_error transit_station_catalog_next_get(const Next *value, transit_station_catalog_next_view *out) {
    if (out) *out = {}; return boundary([&] { require(value && out, "catalog-next"); *out = {value->kind, value->prepared.get(), value->outcome ? &*value->outcome : nullptr}; });
}
void transit_station_catalog_next_destroy(Next *value) { delete value; }
transit_sdk_error transit_station_catalog_open(const transit_sdk_config *config, const transit_sdk_credential *identity, Connection connection, transit_station_catalog_client **out) {
    Uninterruptible guard; if (out) *out = nullptr; return boundary([&] {
        require(config && identity && out, "catalog-open"); auto owner = std::make_unique<transit_station_catalog_client>();
        owner->worker.run([&] { owner->native = std::make_unique<NativeCatalog>(*config, *identity, connection); }); *out = owner.release();
    });
}
transit_sdk_error transit_station_catalog_close(transit_station_catalog_client *owner) {
    Uninterruptible guard; return boundary([&] { require(owner, "catalog-client"); owner->worker.close([&] { owner->native.reset(); }); });
}
void transit_station_catalog_client_destroy(transit_station_catalog_client *value) { Uninterruptible guard; delete value; }
transit_sdk_error transit_station_catalog_capabilities_read(transit_station_catalog_client *client, Capabilities *out) {
    if (out) *out = {}; return action(client, [&] { require(out, "catalog-capabilities"); return ld::encode(tag("capabilities")); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "capabilities", capabilities); });
}
transit_sdk_error transit_station_catalog_describe(transit_station_catalog_client *client, Description *out) {
    if (out) *out = {}; return action(client, [&] { require(out, "catalog-description"); return ld::encode(tag("describe")); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "description", [&](const Json &v) { return description(v, n.connection, n.principal); }); });
}
transit_sdk_error transit_station_catalog_lookup(transit_station_catalog_client *client, const char *value, Definition **out) {
    if (out) *out = nullptr; std::string expected;
    return action(client, [&] { require(out, "catalog-lookup"); expected = name(value); return ld::encode(tag("lookup", Json::string(expected))); },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, "definition", [&](const Json &v) { return definition(v, n.connection.scope, expected); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_definition_read(transit_station_catalog_client *client, uint64_t object_id, uint64_t revision, Historical **out) {
    if (out) *out = nullptr;
    return action(client, [&] { require(out && object_id && revision, "catalog-history"); return ld::encode(tag("definition", Json::object({{"object", Json::string(std::to_string(object_id))}, {"revision", Json::string(std::to_string(revision))}}))); },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, "historical", [&](const Json &v) { return historical(v, n.connection.scope, object_id, revision); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_list(transit_station_catalog_client *client, const Cursor *cursor, Page *out) {
    const Cursor previous = cursor ? *cursor : Cursor{}; if (out) *out = {};
    return action(client, [&] { require(out, "catalog-page"); return ld::encode(tag("list", cursor ? cursor_wire(previous) : Json{})); },
        [&](NativeCatalog &n, const std::string &bytes) {
            require(!cursor || same_scope(previous.scope, n.connection.scope), "catalog-cursor-scope");
            *out = n.read(bytes, "page", [&](const Json &v) { return page(v, n.connection.scope, cursor ? &previous : nullptr); });
        });
}
transit_sdk_error transit_station_catalog_compile_sql(transit_station_catalog_client *client, const char *sql, Identity id, const uint64_t *create_object, Compiled **out) {
    const std::optional<uint64_t> requested = create_object ? std::optional<uint64_t>(*create_object) : std::nullopt; if (out) *out = nullptr;
    return action(client, [&] {
        require(out && (!requested || *requested), "catalog-compile"); const auto statement = text(sql, 4096); require(!statement.empty(), "catalog-sql");
        return ld::encode(tag("compile", Json::object({{"sql", Json::string(statement)}, {"identity", identity_wire(id)}, {"create_object", requested ? Json::string(std::to_string(*requested)) : Json{}}})));
    }, [&](NativeCatalog &n, const std::string &bytes) {
        auto result = n.read(bytes, "compiled", [&](const Json &v) { return compiled(v, n.connection, n.principal, id, requested ? std::optional<transit_station_catalog_kind>(TRANSIT_CATALOG_CREATE) : std::nullopt, requested); }); *out = result.release();
    });
}
transit_sdk_error transit_station_catalog_prepare(transit_station_catalog_client *client, const Request *value, Compiled **out) {
    if (out) *out = nullptr; Identity expected{}; std::optional<uint64_t> expected_object; transit_station_catalog_kind expected_kind = 0;
    return action(client, [&] { require(value && out, "catalog-prepare"); auto bytes = request_wire(*value); expected = value->identity; expected_kind = value->action.kind; expected_object = object(value->action); return bytes; },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, "compiled", [&](const Json &v) { return compiled(v, n.connection, n.principal, expected, expected_kind, expected_object); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_load(transit_station_catalog_client *client, const Saved *value, Intent *out) {
    if (out) *out = {}; return action(client, [&] { require(value && out, "catalog-load"); return ld::encode(tag("load", saved_wire(*value))); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "loaded", [&](const Json &v) { return intent(v, n.connection, n.principal); }); });
}
transit_sdk_error transit_station_catalog_forget(transit_station_catalog_client *client, const Reference *value) {
    return action(client, [&] { return ld::encode(reference_action("forget", value)); }, [&](NativeCatalog &n, const std::string &bytes) { n.read(bytes, "forgotten", [](const Json &v) { v.fields({}); }); });
}
transit_sdk_error transit_station_catalog_next_read(transit_station_catalog_client *client, const Reference *value, Next **out) {
    if (out) *out = nullptr; return action(client, [&] { require(out, "catalog-next"); return ld::encode(reference_action("next", value)); },
        [&](NativeCatalog &n, const std::string &bytes) { auto result = n.read(bytes, "next", [&](const Json &v) { return next(v, n.local); }); *out = result.release(); });
}
transit_sdk_error transit_station_catalog_status_read(transit_station_catalog_client *client, const Reference *value, State *out) {
    if (out) *out = {}; return action(client, [&] { require(out, "catalog-state"); return ld::encode(reference_action("status", value)); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "state", [&](const Json &v) { return state(v, n.local); }); });
}
transit_sdk_error transit_station_catalog_prepare_resume(transit_station_catalog_client *client, const Reference *value, Prepared **out) {
    return prepare_action(client, out, [&] { return reference_action("prepare_resume", value); });
}
transit_sdk_error transit_station_catalog_prepare_control(transit_station_catalog_client *client, const Reference *value, transit_station_catalog_control control, Prepared **out) {
    return prepare_action(client, out, [&] { require(value, "catalog-reference"); return tag("prepare_control", Json::object({{"intent", reference_wire(*value)}, {"control", Json::string(control_name(control))}})); });
}
transit_sdk_error transit_station_catalog_prepare_initialize(transit_station_catalog_client *client, const Configuration *value, Prepared **out) {
    return prepare_action(client, out, [&] { require(value, "catalog-configuration"); return tag("prepare_initialize", configuration_wire(*value)); });
}
transit_sdk_error transit_station_catalog_prepare_policy(transit_station_catalog_client *client, const transit_station_catalog_policy_change *value, Prepared **out) {
    return prepare_action(client, out, [&] { require(value, "catalog-policy"); return tag("prepare_policy", policy_change_wire(*value)); });
}
transit_sdk_error transit_station_catalog_prepare_dependency(transit_station_catalog_client *client, const transit_station_catalog_dependency *value, bool present, Prepared **out) {
    return prepare_action(client, out, [&] { require(value, "catalog-dependency"); return tag("prepare_dependency", dependency_wire(*value, present)); });
}
transit_sdk_error transit_station_catalog_submit(transit_station_catalog_client *client, const Prepared *value, uint64_t *out) {
    if (out) *out = 0; return action(client, [&] { require(value && out, "catalog-submit"); return ld::encode(tag("submit", prepared_wire(*value))); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "receipt", [](const Json &v) { v.fields({"position"}); return v.at("position").number(TRANSIT_CLIENT_MAX_COUNTER, false); }, true); });
}
transit_sdk_error transit_station_catalog_observe(transit_station_catalog_client *client, const Prepared *value, uint64_t position, bool wait, transit_station_catalog_observation *out) {
    if (out) *out = 0; return action(client, [&] { require(out, "catalog-observe"); return ld::encode(tag(wait ? "wait_observe" : "observe", input(value, position))); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "observation", [](const Json &v) -> transit_station_catalog_observation { const auto &s = v.string(); require(s == "pending" || s == "processed", "catalog-observation"); return s == "pending" ? TRANSIT_CATALOG_PENDING : TRANSIT_CATALOG_PROCESSED; }); });
}
transit_sdk_error transit_station_catalog_input_disposition(transit_station_catalog_client *client, const Prepared *value, uint64_t position, Disposition *out) {
    if (out) *out = {}; return action(client, [&] { require(out, "catalog-disposition"); return ld::encode(tag("input_disposition", input(value, position))); },
        [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "disposition", [&](const Json &v) { auto result = disposition(v, n.local); require(!result.found || result.input == position, "catalog-disposition-input"); return result; }); });
}
transit_sdk_error transit_station_catalog_progress_read(transit_station_catalog_client *client, const Reference *reference, const Prepared *value, uint64_t position, bool wait, Progress *out) {
    if (out) *out = {}; return action(client, [&] {
        require(reference && out, "catalog-progress"); auto v = input(value, position); v.members.emplace_back("intent", reference_wire(*reference)); return ld::encode(tag(wait ? "wait_progress" : "progress", std::move(v)));
    }, [&](NativeCatalog &n, const std::string &bytes) { *out = n.read(bytes, "progress", [&](const Json &v) { auto result = progress(v, n.local); require(!result.disposition.found || result.disposition.input == position, "catalog-disposition-input"); return result; }); });
}
}
