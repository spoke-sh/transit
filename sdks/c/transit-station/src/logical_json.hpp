#pragma once
// Local SDK value codec. This parses a bounded response once; it does not apply
// framework semantics, authorize work or replace generated native admission.
#include <transit/internal/support.hpp>
#include <charconv>
#include <string_view>

namespace transit::sdk::logical_detail {
using namespace internal;
inline constexpr size_t json_bytes = 16 * 1024 * 1024;
inline void utf8(std::string_view value) {
    size_t i = 0;
    while (i < value.size()) {
        const auto first = static_cast<uint8_t>(value[i++]);
        if (first < 128) continue;
        const size_t count = first >= 0xc2 && first <= 0xdf ? 1 : first >= 0xe0 && first <= 0xef ? 2 : first >= 0xf0 && first <= 0xf4 ? 3 : 0;
        require(count && count <= value.size() - i, "json-utf8");
        uint32_t point = first & ((1u << (6 - count)) - 1);
        for (size_t j = 0; j < count; ++j) {
            const auto next = static_cast<uint8_t>(value[i++]);
            require((next & 0xc0) == 0x80, "json-utf8");
            point = (point << 6) | (next & 63);
        }
        require(point >= (count == 1 ? 128u : count == 2 ? 2048u : 65536u) && point <= 0x10ffff && !(point >= 0xd800 && point <= 0xdfff), "json-utf8");
    }
}
struct Json {
    enum class Kind { Null, Boolean, Number, String, Array, Object } kind = Kind::Null;
    bool flag = false;
    std::string text;
    std::vector<Json> items;
    std::vector<std::pair<std::string, Json>> members;
    static Json boolean(bool value) { Json out; out.kind = Kind::Boolean; out.flag = value; return out; }
    static Json string(std::string value) { utf8(value); Json out; out.kind = Kind::String; out.text = std::move(value); return out; }
    static Json integer(uint64_t value) { Json out; out.kind = Kind::Number; out.text = std::to_string(value); return out; }
    static Json array() { Json out; out.kind = Kind::Array; return out; }
    static Json object(std::initializer_list<std::pair<std::string, Json>> values = {}) {
        Json out; out.kind = Kind::Object; out.members = values; return out;
    }
    const Json &at(std::string_view key) const {
        require(kind == Kind::Object, "json-object");
        for (const auto &entry : members) if (entry.first == key) return entry.second;
        fail(TRANSIT_SDK_INVALID_ARGUMENT, "json-field");
    }
    void fields(std::initializer_list<const char *> keys) const {
        require(kind == Kind::Object && members.size() == keys.size(), "json-fields");
        for (const auto key : keys) (void)at(key);
    }
    const std::pair<std::string, Json> &variant() const {
        require(kind == Kind::Object && members.size() == 1, "json-variant"); return members.front();
    }
    const std::string &string() const { require(kind == Kind::String, "json-string"); return text; }
    bool boolean() const { require(kind == Kind::Boolean, "json-boolean"); return flag; }
    uint64_t number(uint64_t max, bool zero = true) const {
        require(kind == Kind::Number, "json-number"); uint64_t out = 0;
        const auto result = std::from_chars(text.data(), text.data() + text.size(), out);
        require(result.ec == std::errc{} && result.ptr == text.data() + text.size() && std::to_string(out) == text && out <= max && (zero || out), "json-number");
        return out;
    }
    const std::vector<Json> &array(size_t max) const {
        require(kind == Kind::Array && items.size() <= max, "json-array"); return items;
    }
    bool is_null() const { return kind == Kind::Null; }
};
class JsonParser {
    std::string_view source;
    size_t offset = 0, nodes = 0, depth_bound, field_bound;
    char peek() const { return offset < source.size() ? source[offset] : '\0'; }
    char get() { require(offset < source.size(), "json-truncated"); return source[offset++]; }
    bool consume(char expected) { if (peek() != expected) return false; ++offset; return true; }
    void space() { while (peek() == ' ' || peek() == '\n' || peek() == '\r' || peek() == '\t') ++offset; }
    void literal(std::string_view expected) {
        require(source.substr(offset, expected.size()) == expected, "json-literal"); offset += expected.size();
    }
    static bool digit(char c) { return c >= '0' && c <= '9'; }
    uint32_t hex4() {
        uint32_t out = 0;
        for (size_t i = 0; i < 4; ++i) {
            const char c = get();
            const int value = digit(c) ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
            require(value >= 0, "json-escape"); out = (out << 4) | static_cast<uint32_t>(value);
        }
        return out;
    }
    static void point(std::string &out, uint32_t value) {
        if (value < 128) out += static_cast<char>(value);
        else if (value < 2048) { out += static_cast<char>(0xc0 | (value >> 6)); out += static_cast<char>(0x80 | (value & 63)); }
        else if (value < 65536) {
            out += static_cast<char>(0xe0 | (value >> 12)); out += static_cast<char>(0x80 | ((value >> 6) & 63)); out += static_cast<char>(0x80 | (value & 63));
        } else {
            out += static_cast<char>(0xf0 | (value >> 18)); out += static_cast<char>(0x80 | ((value >> 12) & 63));
            out += static_cast<char>(0x80 | ((value >> 6) & 63)); out += static_cast<char>(0x80 | (value & 63));
        }
    }
    std::string string() {
        require(get() == '"', "json-string"); std::string out;
        for (;;) {
            const auto c = static_cast<uint8_t>(get());
            if (c == '"') break;
            require(c >= 32, "json-string-control");
            if (c != '\\') { out += static_cast<char>(c); continue; }
            switch (get()) {
                case '"': out += '"'; break; case '\\': out += '\\'; break; case '/': out += '/'; break;
                case 'b': out += '\b'; break; case 'f': out += '\f'; break; case 'n': out += '\n'; break;
                case 'r': out += '\r'; break; case 't': out += '\t'; break;
                case 'u': {
                    auto value = hex4();
                    if (value >= 0xd800 && value <= 0xdbff) {
                        require(get() == '\\' && get() == 'u', "json-surrogate"); const auto low = hex4();
                        require(low >= 0xdc00 && low <= 0xdfff, "json-surrogate"); value = 65536 + ((value - 0xd800) << 10) + low - 0xdc00;
                    } else require(!(value >= 0xdc00 && value <= 0xdfff), "json-surrogate");
                    point(out, value); break;
                }
                default: fail(TRANSIT_SDK_INVALID_ARGUMENT, "json-escape");
            }
        }
        utf8(out); return out;
    }
    Json value(size_t depth) {
        require(depth < depth_bound && nodes++ < 1048576, "json-budget"); space();
        if (peek() == 'n') { literal("null"); return {}; }
        if (peek() == 't') { literal("true"); return Json::boolean(true); }
        if (peek() == 'f') { literal("false"); return Json::boolean(false); }
        if (peek() == '"') return Json::string(string());
        if (consume('[')) {
            auto out = Json::array(); space(); if (consume(']')) return out;
            for (;;) { out.items.push_back(value(depth + 1)); space(); if (consume(']')) return out; require(consume(','), "json-array-separator"); }
        }
        if (consume('{')) {
            auto out = Json::object(); space(); if (consume('}')) return out;
            for (;;) {
                require(out.members.size() < field_bound, "json-field-budget"); space(); auto key = string();
                for (const auto &entry : out.members) require(entry.first != key, "json-duplicate-key");
                space(); require(consume(':'), "json-colon"); out.members.emplace_back(std::move(key), value(depth + 1));
                space(); if (consume('}')) return out; require(consume(','), "json-object-separator");
            }
        }
        const auto start = offset; consume('-');
        if (!consume('0')) { require(peek() >= '1' && peek() <= '9', "json-number"); while (digit(peek())) ++offset; }
        if (consume('.')) { require(digit(peek()), "json-fraction"); while (digit(peek())) ++offset; }
        if (consume('e') || consume('E')) { if (!consume('+')) consume('-'); require(digit(peek()), "json-exponent"); while (digit(peek())) ++offset; }
        Json out; out.kind = Json::Kind::Number; out.text = source.substr(start, offset - start); return out;
    }
public:
    JsonParser(std::string_view input, size_t bytes = json_bytes, size_t depth = 96, size_t fields = 256) : source(input), depth_bound(depth), field_bound(fields) {
        require(!input.empty() && input.size() <= bytes && depth && depth <= 128 && fields, "json-budget");
    }
    Json parse() { auto out = value(0); space(); require(offset == source.size(), "json-trailing"); return out; }
};
class JsonWriter {
    std::string out;
    size_t bound, nodes = 0;
    void append(std::string_view value) { require(value.size() <= bound - out.size(), "json-byte-budget"); out += value; }
    void quoted(const std::string &value) {
        utf8(value); append("\"");
        for (const auto c : value) {
            if (c == '"') append("\\\""); else if (c == '\\') append("\\\\");
            else if (static_cast<uint8_t>(c) < 32) { const char digits[] = "0123456789abcdef"; char escaped[] = {'\\', 'u', '0', '0', digits[(c >> 4) & 15], digits[c & 15]}; append({escaped, 6}); }
            else append({&c, 1});
        }
        append("\"");
    }
    void write(const Json &value, size_t depth) {
        require(depth < 96 && nodes++ < 1048576, "json-budget");
        switch (value.kind) {
            case Json::Kind::Null: append("null"); break;
            case Json::Kind::Boolean: append(value.flag ? "true" : "false"); break;
            case Json::Kind::Number: append(value.text); break;
            case Json::Kind::String: quoted(value.text); break;
            case Json::Kind::Array: {
                append("["); bool first = true; for (const auto &item : value.items) { if (!first) append(","); first = false; write(item, depth + 1); } append("]"); break;
            }
            case Json::Kind::Object: {
                require(value.members.size() <= 256, "json-field-budget"); append("{"); bool first = true;
                for (const auto &entry : value.members) { if (!first) append(","); first = false; quoted(entry.first); append(":"); write(entry.second, depth + 1); }
                append("}"); break;
            }
        }
    }
public:
    explicit JsonWriter(size_t maximum = json_bytes) : bound(maximum) {}
    std::string encode(const Json &value) { write(value, 0); return std::move(out); }
};
inline Json parse(transit_sdk_bytes bytes, size_t maximum = json_bytes) {
    require(bytes.data && bytes.size <= maximum, "json-bytes");
    return JsonParser({reinterpret_cast<const char *>(bytes.data), bytes.size}, maximum).parse();
}
inline Json parse(const Bytes &bytes) { return parse(view(bytes)); }
inline std::string encode(const Json &value, size_t maximum = json_bytes) { return JsonWriter(maximum).encode(value); }
}
