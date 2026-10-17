#include "logical_internal.hpp"
#include <limits>

namespace transit::sdk::logical_detail {
namespace {
constexpr const char *kinds[] = {"int8", "int16", "int32", "int64", "int128", "uint8", "uint16", "uint32", "uint64", "uint128", "float32", "float64", "boolean", "utf8", "binary", "date", "time", "interval", "uuid", "json", "decimal", "timestamp", "structure", "tagged_union", "list", "array", "map", "unknown", "null_value", "text", "character"};
using U128 = unsigned __int128;
std::string unsigned_text(U128 value) {
    char buffer[40]; auto *end = buffer + sizeof(buffer); auto *start = end;
    do { *--start = static_cast<char>('0' + value % 10); value /= 10; } while (value);
    return {start, end};
}
std::string signed_text(transit_logical_i128 value) {
    const auto bits = (static_cast<U128>(static_cast<uint64_t>(value.high)) << 64) | value.low;
    return value.high < 0 ? "-" + unsigned_text(~bits + 1) : unsigned_text(bits);
}
U128 unsigned_number(std::string_view text) {
    require(!text.empty() && text.size() <= 39 && (text.size() == 1 || text[0] != '0'), "logical-number"); U128 out = 0;
    for (const auto c : text) {
        require(c >= '0' && c <= '9', "logical-number"); const auto digit = static_cast<unsigned>(c - '0');
        require(out <= (~static_cast<U128>(0) - digit) / 10, "logical-number-range"); out = out * 10 + digit;
    }
    return out;
}
transit_logical_i128 signed_number(const Json &value) {
    const auto &text = value.string(); const bool negative = !text.empty() && text[0] == '-';
    const auto magnitude = unsigned_number(std::string_view(text).substr(negative ? 1 : 0));
    const auto limit = static_cast<U128>(1) << 127;
    require(negative ? magnitude && magnitude <= limit : magnitude < limit, "logical-number-range");
    const auto bits = negative ? ~magnitude + 1 : magnitude;
    const uint64_t high_bits = static_cast<uint64_t>(bits >> 64); int64_t high = 0;
    std::memcpy(&high, &high_bits, sizeof(high)); return {static_cast<uint64_t>(bits), high};
}
int64_t narrow_signed(const Json &value, int64_t minimum, int64_t maximum) {
    const auto n = signed_number(value); int64_t out = 0; std::memcpy(&out, &n.low, sizeof(out));
    require(n.high == (out < 0 ? -1 : 0) && out >= minimum && out <= maximum, "logical-number-range"); return out;
}
std::string bytes_text(transit_sdk_bytes bytes, size_t bound) {
    require(bytes.size <= bound && (bytes.data || !bytes.size), "logical-bytes");
    return bytes.size ? std::string(reinterpret_cast<const char *>(bytes.data), bytes.size) : std::string{};
}
template<class T> void array_check(const T *values, size_t size, size_t bound) { require(size <= bound && (values || !size), "logical-array"); }
Json tagged(const char *tag, Json value) { return Json::object({{tag, std::move(value)}}); }
std::string text_data(transit_sdk_bytes bytes, Budget &b) { b.bytes(bytes.size); auto out = bytes_text(bytes, 1048576); utf8(out); return out; }
Json binary(transit_sdk_bytes bytes, Budget &b) { b.bytes(bytes.size); return Json::string(hex(copy(bytes, 1048576))); }
Bytes binary_from(const Json &value, Budget &b, size_t max) {
    const auto &text = value.string(); require(text.size() % 2 == 0 && text.size() / 2 <= max, "logical-hex");
    for (const auto c : text) require((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'), "logical-hex");
    b.bytes(text.size() / 2); return unhex(text, max);
}
void finite(uint64_t bits, size_t size) {
    require(size == 4 ? (bits & 0x7f800000) != 0x7f800000 : size == 8 && (bits & UINT64_C(0x7ff0000000000000)) != UINT64_C(0x7ff0000000000000), "logical-finite-float");
}
Json float_json(const transit_logical_atom &value, Budget &b) {
    static_assert(sizeof(float) == 4 && sizeof(double) == 8 && std::numeric_limits<float>::is_iec559 && std::numeric_limits<double>::is_iec559);
    uint64_t bits = 0; const size_t size = value.kind == TRANSIT_ATOM_FLOAT32 ? 4 : 8;
    if (size == 4) { uint32_t small = 0; std::memcpy(&small, &value.as.float32, 4); bits = small; }
    else std::memcpy(&bits, &value.as.float64, 8);
    finite(bits, size); uint8_t bytes[8]; for (size_t i = 0; i < size; ++i) bytes[i] = static_cast<uint8_t>(bits >> (8 * i));
    return tagged("float_bits", binary({bytes, size}, b));
}
Json element_json(const transit_logical_element &e, Budget &b, size_t depth) {
    require(e.type, "logical-element"); return Json::object({{"type", type_json(*e.type, b, depth + 1)}, {"nullable", Json::boolean(e.nullable)}});
}
transit_logical_element element_from(const Json &v, Arena &a, Budget &b, size_t depth) {
    v.fields({"type", "nullable"}); auto *type = a.array<transit_logical_type_view>(1); *type = type_from(v.at("type"), a, b, depth + 1);
    return {type, v.at("nullable").boolean()};
}
}
std::string wide(uint64_t value) { return std::to_string(value); }
uint64_t wide(const Json &value, bool zero) { const auto n = unsigned_number(value.string()); require(n <= UINT64_MAX && (zero || n), "logical-u64"); return static_cast<uint64_t>(n); }
const char *kind_name(transit_logical_kind kind) { require(static_cast<unsigned>(kind) < sizeof(kinds) / sizeof(kinds[0]), "logical-kind"); return kinds[kind]; }
transit_logical_kind kind_from(const std::string &name) {
    for (size_t i = 0; i < sizeof(kinds) / sizeof(kinds[0]); ++i) if (kinds[i] == name) return static_cast<transit_logical_kind>(i);
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "logical-kind");
}
Json type_json(const transit_logical_type_view &v, Budget &b, size_t depth) {
    require(v.kind <= TRANSIT_LOGICAL_MAP, "logical-descriptor-kind");
    b.enter(depth); const auto *tag = kind_name(v.kind); Json payload = Json::object();
    switch (v.kind) {
        case TRANSIT_LOGICAL_DECIMAL:
            require(v.as.decimal.precision && v.as.decimal.precision <= 38 && v.as.decimal.scale <= v.as.decimal.precision, "logical-decimal");
            payload = Json::object({{"precision", Json::integer(v.as.decimal.precision)}, {"scale", Json::integer(v.as.decimal.scale)}}); break;
        case TRANSIT_LOGICAL_TIMESTAMP:
            require(v.as.timestamp == TRANSIT_LOGICAL_CIVIL || v.as.timestamp == TRANSIT_LOGICAL_UTC, "logical-zone");
            payload = Json::string(v.as.timestamp == TRANSIT_LOGICAL_CIVIL ? "civil" : "utc"); break;
        case TRANSIT_LOGICAL_STRUCTURE: case TRANSIT_LOGICAL_TAGGED_UNION:
            array_check(v.as.fields.data, v.as.fields.size, 256); payload = Json::array();
            for (size_t i = 0; i < v.as.fields.size; ++i) {
                const auto &f = v.as.fields.data[i]; b.name(f.name.size); require(f.type, "logical-field-type");
                payload.items.push_back(Json::object({{"name", Json::string(bytes_text(f.name, 4096))}, {"type", type_json(*f.type, b, depth + 1)}, {"nullable", Json::boolean(f.nullable)}, {"optional", Json::boolean(f.optional)}}));
            }
            break;
        case TRANSIT_LOGICAL_LIST: payload = element_json(v.as.list, b, depth); break;
        case TRANSIT_LOGICAL_ARRAY:
            require(v.as.array.length, "logical-array-length");
            payload = Json::object({{"element", element_json(v.as.array.element, b, depth)}, {"length", Json::integer(v.as.array.length)}}); break;
        case TRANSIT_LOGICAL_MAP:
            require(v.as.map.key, "logical-map-key"); payload = Json::object({{"key", type_json(*v.as.map.key, b, depth + 1)}, {"value", element_json(v.as.map.value, b, depth)}}); break;
        default: break;
    }
    return tagged(tag, std::move(payload));
}
transit_logical_type_view type_from(const Json &v, Arena &a, Budget &b, size_t depth) {
    b.enter(depth); const auto &entry = v.variant(); const auto &p = entry.second; transit_logical_type_view out{}; out.kind = kind_from(entry.first);
    require(out.kind <= TRANSIT_LOGICAL_MAP, "logical-descriptor-kind");
    switch (out.kind) {
        case TRANSIT_LOGICAL_DECIMAL:
            p.fields({"precision", "scale"}); out.as.decimal.precision = static_cast<uint8_t>(p.at("precision").number(38, false));
            out.as.decimal.scale = static_cast<uint8_t>(p.at("scale").number(out.as.decimal.precision)); break;
        case TRANSIT_LOGICAL_TIMESTAMP:
            require(p.string() == "civil" || p.string() == "utc", "logical-zone"); out.as.timestamp = p.string() == "civil" ? TRANSIT_LOGICAL_CIVIL : TRANSIT_LOGICAL_UTC; break;
        case TRANSIT_LOGICAL_STRUCTURE: case TRANSIT_LOGICAL_TAGGED_UNION: {
            const auto &fields = p.array(256); auto *values = a.array<transit_logical_field>(fields.size()); out.as.fields = {values, fields.size()};
            for (size_t i = 0; i < fields.size(); ++i) {
                const auto &f = fields[i]; f.fields({"name", "type", "nullable", "optional"}); const auto &name = f.at("name").string(); b.name(name.size());
                auto *type = a.array<transit_logical_type_view>(1); *type = type_from(f.at("type"), a, b, depth + 1);
                values[i] = {a.bytes(name), type, f.at("nullable").boolean(), f.at("optional").boolean()};
            }
            break;
        }
        case TRANSIT_LOGICAL_LIST: out.as.list = element_from(p, a, b, depth); break;
        case TRANSIT_LOGICAL_ARRAY:
            p.fields({"element", "length"}); out.as.array = {element_from(p.at("element"), a, b, depth), static_cast<uint32_t>(p.at("length").number(UINT32_MAX, false))}; break;
        case TRANSIT_LOGICAL_MAP: {
            p.fields({"key", "value"}); auto *key = a.array<transit_logical_type_view>(1); *key = type_from(p.at("key"), a, b, depth + 1);
            out.as.map = {key, element_from(p.at("value"), a, b, depth)}; break;
        }
        default: p.fields({}); break;
    }
    return out;
}
Json atom_json(const transit_logical_atom &v, Budget &b) {
    switch (v.kind) {
        case TRANSIT_ATOM_SIGNED: return tagged("signed", Json::string(signed_text(v.as.signed_value)));
        case TRANSIT_ATOM_DECIMAL: return tagged("decimal", Json::string(signed_text(v.as.signed_value)));
        case TRANSIT_ATOM_UNSIGNED: return tagged("unsigned", Json::string(unsigned_text((static_cast<U128>(v.as.unsigned_value.high) << 64) | v.as.unsigned_value.low)));
        case TRANSIT_ATOM_FLOAT32: case TRANSIT_ATOM_FLOAT64: return float_json(v, b);
        case TRANSIT_ATOM_BOOLEAN: return tagged("boolean", Json::boolean(v.as.boolean));
        case TRANSIT_ATOM_UTF8: return tagged("utf8", Json::string(text_data(v.as.bytes, b)));
        case TRANSIT_ATOM_BINARY: return tagged("binary", binary(v.as.bytes, b));
        case TRANSIT_ATOM_UUID: return tagged("uuid", binary({v.as.uuid, 16}, b));
        case TRANSIT_ATOM_DATE_DAYS: return tagged("date_days", Json::string(std::to_string(v.as.date_days)));
        case TRANSIT_ATOM_TIME_NANOS: return tagged("time_nanos", Json::string(wide(v.as.time_nanos)));
        case TRANSIT_ATOM_TIMESTAMP_MICROS: return tagged("timestamp_micros", Json::string(std::to_string(v.as.timestamp_micros)));
        case TRANSIT_ATOM_INTERVAL: return tagged("interval", Json::object({{"months", Json::string(std::to_string(v.as.interval.months))}, {"days", Json::string(std::to_string(v.as.interval.days))}, {"nanos", Json::string(std::to_string(v.as.interval.nanos))}}));
    }
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "logical-atom");
}
transit_logical_atom atom_from(const Json &v, Arena &a, Budget &b) {
    const auto &entry = v.variant(); const auto &tag = entry.first; const auto &p = entry.second; transit_logical_atom out{};
    if (tag == "signed" || tag == "decimal") { out.kind = tag == "signed" ? TRANSIT_ATOM_SIGNED : TRANSIT_ATOM_DECIMAL; out.as.signed_value = signed_number(p); }
    else if (tag == "unsigned") { out.kind = TRANSIT_ATOM_UNSIGNED; const auto n = unsigned_number(p.string()); out.as.unsigned_value = {static_cast<uint64_t>(n), static_cast<uint64_t>(n >> 64)}; }
    else if (tag == "float_bits") {
        const auto bytes = binary_from(p, b, 8); require(bytes.size() == 4 || bytes.size() == 8, "logical-float-size");
        uint64_t bits = 0; for (size_t i = 0; i < bytes.size(); ++i) bits |= static_cast<uint64_t>(bytes[i]) << (8 * i); finite(bits, bytes.size());
        if (bytes.size() == 4) { out.kind = TRANSIT_ATOM_FLOAT32; const auto small = static_cast<uint32_t>(bits); std::memcpy(&out.as.float32, &small, 4); }
        else { out.kind = TRANSIT_ATOM_FLOAT64; std::memcpy(&out.as.float64, &bits, 8); }
    } else if (tag == "boolean") { out.kind = TRANSIT_ATOM_BOOLEAN; out.as.boolean = p.boolean(); }
    else if (tag == "utf8") { out.kind = TRANSIT_ATOM_UTF8; const auto &s = p.string(); b.bytes(s.size()); out.as.bytes = a.bytes(s); }
    else if (tag == "binary") { out.kind = TRANSIT_ATOM_BINARY; out.as.bytes = a.bytes(binary_from(p, b, 1048576)); }
    else if (tag == "uuid") { out.kind = TRANSIT_ATOM_UUID; const auto bytes = binary_from(p, b, 16); require(bytes.size() == 16, "logical-uuid"); std::copy(bytes.begin(), bytes.end(), out.as.uuid); }
    else if (tag == "date_days") { out.kind = TRANSIT_ATOM_DATE_DAYS; out.as.date_days = static_cast<int32_t>(narrow_signed(p, INT32_MIN, INT32_MAX)); }
    else if (tag == "time_nanos") { out.kind = TRANSIT_ATOM_TIME_NANOS; out.as.time_nanos = wide(p); }
    else if (tag == "timestamp_micros") { out.kind = TRANSIT_ATOM_TIMESTAMP_MICROS; out.as.timestamp_micros = narrow_signed(p, INT64_MIN, INT64_MAX); }
    else if (tag == "interval") {
        out.kind = TRANSIT_ATOM_INTERVAL; p.fields({"months", "days", "nanos"});
        out.as.interval = {static_cast<int32_t>(narrow_signed(p.at("months"), INT32_MIN, INT32_MAX)), static_cast<int32_t>(narrow_signed(p.at("days"), INT32_MIN, INT32_MAX)), narrow_signed(p.at("nanos"), INT64_MIN, INT64_MAX)};
    } else fail(TRANSIT_SDK_INVALID_ARGUMENT, "logical-atom");
    return out;
}
namespace {
Json value_json(const transit_logical_value &v, Budget &b, size_t depth) {
    switch (v.kind) {
        case TRANSIT_VALUE_ATOM: return tagged("atom", atom_json(v.as.atom, b));
        case TRANSIT_VALUE_STRUCTURE: case TRANSIT_VALUE_LIST: case TRANSIT_VALUE_ARRAY: {
            array_check(v.as.cells.data, v.as.cells.size, 65536); auto items = Json::array();
            for (size_t i = 0; i < v.as.cells.size; ++i) items.items.push_back(cell_json(v.as.cells.data[i], b, depth + 1));
            return tagged(v.kind == TRANSIT_VALUE_STRUCTURE ? "structure" : v.kind == TRANSIT_VALUE_LIST ? "list" : "array", std::move(items));
        }
        case TRANSIT_VALUE_MAP: {
            array_check(v.as.map.data, v.as.map.size, 32767); auto items = Json::array();
            for (size_t i = 0; i < v.as.map.size; ++i) {
                const auto &e = v.as.map.data[i]; b.enter(depth + 1);
                items.items.push_back(Json::object({{"key", atom_json(e.key, b)}, {"value", cell_json(e.value, b, depth + 1)}}));
            }
            return tagged("map", std::move(items));
        }
        case TRANSIT_VALUE_TAGGED_UNION:
            require(v.as.tagged_union.value, "logical-union");
            return tagged("tagged_union", Json::object({{"index", Json::integer(v.as.tagged_union.index)}, {"value", cell_json(*v.as.tagged_union.value, b, depth + 1)}}));
        case TRANSIT_VALUE_JSON: return tagged("json", Json::string(text_data(v.as.json, b)));
    }
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "logical-value");
}
transit_logical_value value_from(const Json &v, Arena &a, Budget &b, size_t depth) {
    const auto &entry = v.variant(); const auto &tag = entry.first; const auto &p = entry.second; transit_logical_value out{};
    if (tag == "atom") { out.kind = TRANSIT_VALUE_ATOM; out.as.atom = atom_from(p, a, b); }
    else if (tag == "structure" || tag == "list" || tag == "array") {
        out.kind = tag == "structure" ? TRANSIT_VALUE_STRUCTURE : tag == "list" ? TRANSIT_VALUE_LIST : TRANSIT_VALUE_ARRAY;
        const auto &items = p.array(65536); auto *cells = a.array<transit_logical_cell_view>(items.size()); out.as.cells = {cells, items.size()};
        for (size_t i = 0; i < items.size(); ++i) cells[i] = cell_from(items[i], a, b, depth + 1);
    } else if (tag == "map") {
        out.kind = TRANSIT_VALUE_MAP; const auto &items = p.array(32767); auto *entries = a.array<transit_logical_entry>(items.size()); out.as.map = {entries, items.size()};
        for (size_t i = 0; i < items.size(); ++i) {
            const auto &e = items[i]; e.fields({"key", "value"}); b.enter(depth + 1);
            entries[i] = {atom_from(e.at("key"), a, b), cell_from(e.at("value"), a, b, depth + 1)};
        }
    } else if (tag == "tagged_union") {
        out.kind = TRANSIT_VALUE_TAGGED_UNION; p.fields({"index", "value"}); auto *cell = a.array<transit_logical_cell_view>(1); *cell = cell_from(p.at("value"), a, b, depth + 1);
        out.as.tagged_union = {static_cast<uint8_t>(p.at("index").number(255)), cell};
    } else if (tag == "json") { out.kind = TRANSIT_VALUE_JSON; const auto &s = p.string(); b.bytes(s.size()); out.as.json = a.bytes(s); }
    else fail(TRANSIT_SDK_INVALID_ARGUMENT, "logical-value");
    return out;
}
void alternative_check(const transit_logical_alternative &a, std::pair<uint64_t, uint64_t> &before) {
    const auto dot = std::make_pair(a.counter, a.replica);
    require(a.counter && a.replica && dot > before && (a.value.state == TRANSIT_LOGICAL_NULL || a.value.state == TRANSIT_LOGICAL_TYPE_ERROR || a.value.state == TRANSIT_LOGICAL_VALUE), "logical-conflict"); before = dot;
}
}
Json cell_json(const transit_logical_cell_view &v, Budget &b, size_t depth) {
    b.enter(depth);
    switch (v.state) {
        case TRANSIT_LOGICAL_MISSING: return tagged("missing", Json::object());
        case TRANSIT_LOGICAL_NULL: return tagged("null", Json::object());
        case TRANSIT_LOGICAL_TYPE_ERROR: return tagged("type_error", Json::string(kind_name(v.as.type_error)));
        case TRANSIT_LOGICAL_VALUE: return tagged("value", value_json(v.as.value, b, depth));
        case TRANSIT_LOGICAL_CONFLICT: {
            array_check(v.as.conflict.data, v.as.conflict.size, 8); require(v.as.conflict.size >= 2, "logical-conflict");
            auto items = Json::array(); std::pair<uint64_t, uint64_t> before{};
            for (size_t i = 0; i < v.as.conflict.size; ++i) {
                const auto &a = v.as.conflict.data[i]; alternative_check(a, before);
                items.items.push_back(Json::object({{"counter", Json::string(wide(a.counter))}, {"replica", Json::string(wide(a.replica))}, {"value", cell_json(a.value, b, depth)}}));
            }
            return tagged("conflict", std::move(items));
        }
    }
    fail(TRANSIT_SDK_INVALID_ARGUMENT, "logical-state");
}
transit_logical_cell_view cell_from(const Json &v, Arena &a, Budget &b, size_t depth) {
    b.enter(depth); const auto &entry = v.variant(); const auto &tag = entry.first; const auto &p = entry.second; transit_logical_cell_view out{};
    if (tag == "missing" || tag == "null") { p.fields({}); out.state = tag == "missing" ? TRANSIT_LOGICAL_MISSING : TRANSIT_LOGICAL_NULL; }
    else if (tag == "type_error") { out.state = TRANSIT_LOGICAL_TYPE_ERROR; out.as.type_error = kind_from(p.string()); }
    else if (tag == "value") { out.state = TRANSIT_LOGICAL_VALUE; out.as.value = value_from(p, a, b, depth); }
    else if (tag == "conflict") {
        out.state = TRANSIT_LOGICAL_CONFLICT; const auto &items = p.array(8); require(items.size() >= 2, "logical-conflict");
        auto *values = a.array<transit_logical_alternative>(items.size()); out.as.conflict = {values, items.size()}; std::pair<uint64_t, uint64_t> before{};
        for (size_t i = 0; i < items.size(); ++i) {
            const auto &entry_value = items[i]; entry_value.fields({"counter", "replica", "value"});
            values[i] = {wide(entry_value.at("counter"), false), wide(entry_value.at("replica"), false), cell_from(entry_value.at("value"), a, b, depth)};
            alternative_check(values[i], before);
        }
    } else fail(TRANSIT_SDK_INVALID_ARGUMENT, "logical-state");
    return out;
}
}

using namespace transit::sdk::logical_detail;
extern "C" {
transit_sdk_error transit_logical_type_create(const transit_logical_type_view *value, transit_logical_type **out) {
    if (out) *out = nullptr; return boundary([&] { require(value && out, "logical-type"); auto owner = std::make_unique<transit_logical_type>(); owner->value = type_from(type_json(*value), owner->arena); *out = owner.release(); });
}
transit_sdk_error transit_logical_type_get(const transit_logical_type *value, const transit_logical_type_view **out) {
    if (out) *out = nullptr; return boundary([&] { require(value && out, "logical-type"); *out = &value->value; });
}
void transit_logical_type_destroy(transit_logical_type *value) { delete value; }
transit_sdk_error transit_logical_cell_create(const transit_logical_cell_view *value, transit_logical_cell **out) {
    if (out) *out = nullptr; return boundary([&] { require(value && out, "logical-cell"); auto owner = std::make_unique<transit_logical_cell>(); owner->value = cell_from(cell_json(*value), owner->arena); *out = owner.release(); });
}
transit_sdk_error transit_logical_cell_get(const transit_logical_cell *value, const transit_logical_cell_view **out) {
    if (out) *out = nullptr; return boundary([&] { require(value && out, "logical-cell"); *out = &value->value; });
}
void transit_logical_cell_destroy(transit_logical_cell *value) { delete value; }
transit_sdk_error transit_logical_type_encode(const transit_logical_type *value, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(value && out, "logical-type"); const auto json = encode(type_json(value->value), 65536); *out = owned(Bytes(json.begin(), json.end())); });
}
transit_sdk_error transit_logical_type_decode(transit_sdk_bytes value, transit_logical_type **out) {
    if (out) *out = nullptr; return boundary([&] { require(out, "logical-type"); auto owner = std::make_unique<transit_logical_type>(); owner->value = type_from(parse(value, 65536), owner->arena); *out = owner.release(); });
}
transit_sdk_error transit_logical_cell_encode(const transit_logical_cell *value, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(value && out, "logical-cell"); const auto json = encode(cell_json(value->value)); *out = owned(Bytes(json.begin(), json.end())); });
}
transit_sdk_error transit_logical_cell_decode(transit_sdk_bytes value, transit_logical_cell **out) {
    if (out) *out = nullptr; return boundary([&] { require(out, "logical-cell"); auto owner = std::make_unique<transit_logical_cell>(); owner->value = cell_from(parse(value), owner->arena); *out = owner.release(); });
}
}
