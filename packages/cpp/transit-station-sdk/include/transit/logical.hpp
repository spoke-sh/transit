#pragma once
#include <transit/client.hpp>
#include <transit/logical.h>
#include <algorithm>
#include <array>

namespace transit::sdk::logical {
using Kind = transit_logical_kind;
using Zone = transit_logical_zone;
using State = transit_logical_state;
using ValueKind = transit_logical_value_kind;
using AtomKind = transit_logical_atom_kind;
using Int128 = transit_logical_i128;
using Uint128 = transit_logical_u128;
inline transit_sdk_bytes text_view(const std::string &value) { return {reinterpret_cast<const uint8_t *>(value.data()), value.size()}; }
struct Field;
// Copies share an immutable owned tree. Construction copies every caller view;
// child accessors return independent owners. No view borrows a native client.
class Type {
    std::shared_ptr<transit_logical_type> value_;
    explicit Type(transit_logical_type *value) : value_(value, transit_logical_type_destroy) {}
public:
    explicit Type(const transit_logical_type_view &view) {
        transit_logical_type *out = nullptr; check(transit_logical_type_create(&view, &out)); value_ = {out, transit_logical_type_destroy};
    }
    const transit_logical_type_view &native() const {
        const transit_logical_type_view *out = nullptr; check(transit_logical_type_get(value_.get(), &out)); return *out;
    }
    Kind kind() const { return native().kind; }
    static Type scalar(Kind kind) {
        // Parameterized kinds require their corresponding constructor.
        if (kind > TRANSIT_LOGICAL_JSON) { transit_sdk_error e{}; e.kind = TRANSIT_SDK_INVALID_ARGUMENT; throw Error(e); }
        transit_logical_type_view out{}; out.kind = kind; return Type(out);
    }
    static Type decimal(uint8_t precision, uint8_t scale) { transit_logical_type_view out{}; out.kind = TRANSIT_LOGICAL_DECIMAL; out.as.decimal = {precision, scale}; return Type(out); }
    static Type timestamp(Zone zone) { transit_logical_type_view out{}; out.kind = TRANSIT_LOGICAL_TIMESTAMP; out.as.timestamp = zone; return Type(out); }
    static Type structure(const std::vector<Field> &fields);
    static Type tagged_union(const std::vector<Field> &fields);
    static Type list(const Type &element, bool nullable = true) { transit_logical_type_view out{}; out.kind = TRANSIT_LOGICAL_LIST; out.as.list = {&element.native(), nullable}; return Type(out); }
    static Type array(const Type &element, uint32_t length, bool nullable = true) {
        transit_logical_type_view out{}; out.kind = TRANSIT_LOGICAL_ARRAY; out.as.array = {{&element.native(), nullable}, length}; return Type(out);
    }
    static Type map(const Type &key, const Type &value, bool nullable = true) {
        transit_logical_type_view out{}; out.kind = TRANSIT_LOGICAL_MAP; out.as.map = {&key.native(), {&value.native(), nullable}}; return Type(out);
    }
    std::vector<Field> fields() const;
    Bytes encode() const { transit_sdk_buffer out{}; check(transit_logical_type_encode(value_.get(), &out)); return Buffer(out).copy(); }
    static Type decode(const Bytes &bytes) { transit_logical_type *out = nullptr; check(transit_logical_type_decode(bytes_view(bytes), &out)); return Type(out); }
};
struct Field { std::string name; Type type; bool nullable = true, optional = false; };
inline Type fields_type(Kind kind, const std::vector<Field> &fields) {
    std::vector<transit_logical_field> views;
    if (fields.size() > 256) { transit_sdk_error e{}; e.kind = TRANSIT_SDK_INVALID_ARGUMENT; throw Error(e); }
    for (const auto &f : fields) views.push_back({text_view(f.name), &f.type.native(), f.nullable, f.optional});
    transit_logical_type_view out{}; out.kind = kind; out.as.fields = {views.data(), views.size()}; return Type(out);
}
inline Type Type::structure(const std::vector<Field> &fields) { return fields_type(TRANSIT_LOGICAL_STRUCTURE, fields); }
inline Type Type::tagged_union(const std::vector<Field> &fields) { return fields_type(TRANSIT_LOGICAL_TAGGED_UNION, fields); }
inline std::vector<Field> Type::fields() const {
    const auto &v = native();
    if (v.kind != TRANSIT_LOGICAL_STRUCTURE && v.kind != TRANSIT_LOGICAL_TAGGED_UNION) { transit_sdk_error e{}; e.kind = TRANSIT_SDK_INVALID_ARGUMENT; throw Error(e); }
    std::vector<Field> out;
    for (size_t i = 0; i < v.as.fields.size; ++i) {
        const auto &f = v.as.fields.data[i];
        out.push_back({f.name.size ? std::string(reinterpret_cast<const char *>(f.name.data), f.name.size) : std::string{}, Type(*f.type), f.nullable, f.optional});
    }
    return out;
}
namespace detail {
inline void require(bool yes) { if (!yes) { transit_sdk_error e{}; e.kind = TRANSIT_SDK_INVALID_ARGUMENT; throw Error(e); } }
class OwnedCell {
    std::shared_ptr<transit_logical_cell> value_;
public:
    explicit OwnedCell(transit_logical_cell *value) : value_(value, transit_logical_cell_destroy) {}
    explicit OwnedCell(const transit_logical_cell_view &value) {
        transit_logical_cell *out = nullptr; check(transit_logical_cell_create(&value, &out)); value_ = {out, transit_logical_cell_destroy};
    }
    const transit_logical_cell_view &native() const {
        const transit_logical_cell_view *out = nullptr; check(transit_logical_cell_get(value_.get(), &out)); return *out;
    }
    Bytes encode() const { transit_sdk_buffer out{}; check(transit_logical_cell_encode(value_.get(), &out)); return Buffer(out).copy(); }
};
}
class Atom {
    detail::OwnedCell value_;
    static transit_logical_cell_view present(const transit_logical_atom &atom) {
        transit_logical_cell_view cell{}; cell.state = TRANSIT_LOGICAL_VALUE; cell.as.value.kind = TRANSIT_VALUE_ATOM; cell.as.value.as.atom = atom; return cell;
    }
public:
    explicit Atom(const transit_logical_atom &value) : value_(present(value)) {}
    const transit_logical_atom &native() const { return value_.native().as.value.as.atom; }
    AtomKind kind() const { return native().kind; }
    static Atom signed_integer(Int128 value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_SIGNED; out.as.signed_value = value; return Atom(out); }
    static Atom signed_integer(int64_t value) { return signed_integer({static_cast<uint64_t>(value), value < 0 ? -1 : 0}); }
    static Atom unsigned_integer(Uint128 value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_UNSIGNED; out.as.unsigned_value = value; return Atom(out); }
    static Atom unsigned_integer(uint64_t value) { return unsigned_integer({value, 0}); }
    static Atom decimal(Int128 coefficient) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_DECIMAL; out.as.signed_value = coefficient; return Atom(out); }
    static Atom decimal(int64_t coefficient) { return decimal({static_cast<uint64_t>(coefficient), coefficient < 0 ? -1 : 0}); }
    static Atom float32(float value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_FLOAT32; out.as.float32 = value; return Atom(out); }
    static Atom float64(double value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_FLOAT64; out.as.float64 = value; return Atom(out); }
    static Atom boolean(bool value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_BOOLEAN; out.as.boolean = value; return Atom(out); }
    static Atom utf8(const std::string &value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_UTF8; out.as.bytes = text_view(value); return Atom(out); }
    static Atom binary(const Bytes &value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_BINARY; out.as.bytes = bytes_view(value); return Atom(out); }
    static Atom date_days(int32_t value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_DATE_DAYS; out.as.date_days = value; return Atom(out); }
    static Atom time_nanos(uint64_t value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_TIME_NANOS; out.as.time_nanos = value; return Atom(out); }
    static Atom timestamp_micros(int64_t value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_TIMESTAMP_MICROS; out.as.timestamp_micros = value; return Atom(out); }
    static Atom interval(int32_t months, int32_t days, int64_t nanos) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_INTERVAL; out.as.interval = {months, days, nanos}; return Atom(out); }
    static Atom uuid(const std::array<uint8_t, 16> &value) { transit_logical_atom out{}; out.kind = TRANSIT_ATOM_UUID; std::copy(value.begin(), value.end(), out.as.uuid); return Atom(out); }
};
struct Alternative;
class Cell {
    detail::OwnedCell value_;
    explicit Cell(transit_logical_cell *value) : value_(value) {}
public:
    explicit Cell(const transit_logical_cell_view &value) : value_(value) {}
    const transit_logical_cell_view &native() const { return value_.native(); }
    State state() const { return native().state; }
    ValueKind kind() const { detail::require(state() == TRANSIT_LOGICAL_VALUE); return native().as.value.kind; }
    static Cell missing() { transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_MISSING; return Cell(out); }
    static Cell null() { transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_NULL; return Cell(out); }
    static Cell type_error(Kind kind) { transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_TYPE_ERROR; out.as.type_error = kind; return Cell(out); }
    static Cell atom(const Atom &value) { transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_VALUE; out.as.value.kind = TRANSIT_VALUE_ATOM; out.as.value.as.atom = value.native(); return Cell(out); }
    static Cell sequence(ValueKind kind, const std::vector<Cell> &values) {
        detail::require((kind == TRANSIT_VALUE_STRUCTURE || kind == TRANSIT_VALUE_LIST || kind == TRANSIT_VALUE_ARRAY) && values.size() <= 65536);
        std::vector<transit_logical_cell_view> views; for (const auto &v : values) views.push_back(v.native());
        transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_VALUE; out.as.value.kind = kind; out.as.value.as.cells = {views.data(), views.size()}; return Cell(out);
    }
    static Cell structure(const std::vector<Cell> &values) { return sequence(TRANSIT_VALUE_STRUCTURE, values); }
    static Cell list(const std::vector<Cell> &values) { return sequence(TRANSIT_VALUE_LIST, values); }
    static Cell array(const std::vector<Cell> &values) { return sequence(TRANSIT_VALUE_ARRAY, values); }
    static Cell map(const std::vector<std::pair<Atom, Cell>> &values) {
        detail::require(values.size() <= 32767); std::vector<transit_logical_entry> views;
        for (const auto &v : values) views.push_back({v.first.native(), v.second.native()});
        transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_VALUE; out.as.value.kind = TRANSIT_VALUE_MAP; out.as.value.as.map = {views.data(), views.size()}; return Cell(out);
    }
    static Cell tagged_union(uint8_t index, const Cell &value) {
        transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_VALUE; out.as.value.kind = TRANSIT_VALUE_TAGGED_UNION;
        out.as.value.as.tagged_union = {index, &value.native()}; return Cell(out);
    }
    static Cell json(const std::string &value) {
        transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_VALUE; out.as.value.kind = TRANSIT_VALUE_JSON; out.as.value.as.json = text_view(value); return Cell(out);
    }
    static Cell conflict(const std::vector<Alternative> &values);
    Atom atom() const { detail::require(kind() == TRANSIT_VALUE_ATOM); return Atom(native().as.value.as.atom); }
    std::vector<Cell> children() const {
        const auto k = kind(); detail::require(k == TRANSIT_VALUE_STRUCTURE || k == TRANSIT_VALUE_LIST || k == TRANSIT_VALUE_ARRAY); std::vector<Cell> out;
        const auto &v = native().as.value.as.cells; for (size_t i = 0; i < v.size; ++i) out.emplace_back(v.data[i]); return out;
    }
    std::vector<std::pair<Atom, Cell>> entries() const {
        detail::require(kind() == TRANSIT_VALUE_MAP); std::vector<std::pair<Atom, Cell>> out; const auto &v = native().as.value.as.map;
        for (size_t i = 0; i < v.size; ++i) out.emplace_back(Atom(v.data[i].key), Cell(v.data[i].value)); return out;
    }
    std::vector<Alternative> alternatives() const;
    Bytes encode() const { return value_.encode(); }
    static Cell decode(const Bytes &bytes) { transit_logical_cell *out = nullptr; check(transit_logical_cell_decode(bytes_view(bytes), &out)); return Cell(out); }
};
struct Alternative { uint64_t counter, replica; Cell value; };
inline Cell Cell::conflict(const std::vector<Alternative> &values) {
    detail::require(values.size() >= 2 && values.size() <= 8); std::vector<transit_logical_alternative> views;
    for (const auto &v : values) views.push_back({v.counter, v.replica, v.value.native()});
    transit_logical_cell_view out{}; out.state = TRANSIT_LOGICAL_CONFLICT; out.as.conflict = {views.data(), views.size()}; return Cell(out);
}
inline std::vector<Alternative> Cell::alternatives() const {
    detail::require(state() == TRANSIT_LOGICAL_CONFLICT); std::vector<Alternative> out; const auto &v = native().as.conflict;
    for (size_t i = 0; i < v.size; ++i) out.push_back({v.data[i].counter, v.data[i].replica, Cell(v.data[i].value)}); return out;
}
}
