#ifndef TRANSIT_SDK_LOGICAL_H
#define TRANSIT_SDK_LOGICAL_H
#include <transit/client.h>
#ifdef __cplusplus
extern "C" {
#endif

/* Borrowed construction views. create() validates and copies the entire tree;
 * getters borrow the resulting immutable owner, independently of any client.
 * Tags use uint32_t so unknown values are rejected without foreign-enum UB.
 * A view's tag selects its union member. Pointer/count pairs must be valid for
 * the duration of a call. Logical validation never follows more than 16 levels. */
typedef uint32_t transit_logical_kind;
enum {
    TRANSIT_LOGICAL_INT8, TRANSIT_LOGICAL_INT16, TRANSIT_LOGICAL_INT32,
    TRANSIT_LOGICAL_INT64, TRANSIT_LOGICAL_INT128, TRANSIT_LOGICAL_UINT8,
    TRANSIT_LOGICAL_UINT16, TRANSIT_LOGICAL_UINT32, TRANSIT_LOGICAL_UINT64,
    TRANSIT_LOGICAL_UINT128, TRANSIT_LOGICAL_FLOAT32, TRANSIT_LOGICAL_FLOAT64,
    TRANSIT_LOGICAL_BOOLEAN, TRANSIT_LOGICAL_UTF8, TRANSIT_LOGICAL_BINARY,
    TRANSIT_LOGICAL_DATE, TRANSIT_LOGICAL_TIME, TRANSIT_LOGICAL_INTERVAL,
    TRANSIT_LOGICAL_UUID, TRANSIT_LOGICAL_JSON, TRANSIT_LOGICAL_DECIMAL,
    TRANSIT_LOGICAL_TIMESTAMP, TRANSIT_LOGICAL_STRUCTURE, TRANSIT_LOGICAL_TAGGED_UNION,
    TRANSIT_LOGICAL_LIST, TRANSIT_LOGICAL_ARRAY, TRANSIT_LOGICAL_MAP
};
typedef uint32_t transit_logical_zone;
enum { TRANSIT_LOGICAL_CIVIL, TRANSIT_LOGICAL_UTC };
typedef struct transit_logical_type_view transit_logical_type_view;
typedef struct transit_logical_field {
    transit_sdk_bytes name; const transit_logical_type_view *type; bool nullable, optional;
} transit_logical_field;
typedef struct transit_logical_element { const transit_logical_type_view *type; bool nullable; } transit_logical_element;
struct transit_logical_type_view {
    transit_logical_kind kind;
    union {
        struct { uint8_t precision, scale; } decimal;
        transit_logical_zone timestamp;
        struct { const transit_logical_field *data; size_t size; } fields;
        transit_logical_element list;
        struct { transit_logical_element element; uint32_t length; } array;
        struct { const transit_logical_type_view *key; transit_logical_element value; } map;
    } as;
};
/* Exact two-limb integers; signed high is the signed upper 64 bits of the
 * two's-complement value. No compiler-specific __int128 enters the C ABI. */
typedef struct transit_logical_i128 { uint64_t low; int64_t high; } transit_logical_i128;
typedef struct transit_logical_u128 { uint64_t low, high; } transit_logical_u128;
typedef uint32_t transit_logical_atom_kind;
enum {
    TRANSIT_ATOM_SIGNED, TRANSIT_ATOM_UNSIGNED, TRANSIT_ATOM_DECIMAL,
    TRANSIT_ATOM_FLOAT32, TRANSIT_ATOM_FLOAT64, TRANSIT_ATOM_BOOLEAN,
    TRANSIT_ATOM_UTF8, TRANSIT_ATOM_BINARY, TRANSIT_ATOM_DATE_DAYS,
    TRANSIT_ATOM_TIME_NANOS, TRANSIT_ATOM_TIMESTAMP_MICROS, TRANSIT_ATOM_INTERVAL,
    TRANSIT_ATOM_UUID
};
typedef struct transit_logical_atom {
    transit_logical_atom_kind kind;
    union {
        transit_logical_i128 signed_value;
        transit_logical_u128 unsigned_value;
        float float32; double float64; bool boolean; transit_sdk_bytes bytes;
        int32_t date_days; uint64_t time_nanos; int64_t timestamp_micros;
        struct { int32_t months, days; int64_t nanos; } interval;
        uint8_t uuid[16];
    } as;
} transit_logical_atom;
typedef struct transit_logical_cell_view transit_logical_cell_view;
typedef struct transit_logical_entry transit_logical_entry;
typedef struct transit_logical_alternative transit_logical_alternative;
typedef uint32_t transit_logical_state;
enum {
    TRANSIT_LOGICAL_MISSING, TRANSIT_LOGICAL_NULL, TRANSIT_LOGICAL_TYPE_ERROR,
    TRANSIT_LOGICAL_VALUE, TRANSIT_LOGICAL_CONFLICT
};
typedef uint32_t transit_logical_value_kind;
enum {
    TRANSIT_VALUE_ATOM, TRANSIT_VALUE_STRUCTURE, TRANSIT_VALUE_LIST,
    TRANSIT_VALUE_ARRAY, TRANSIT_VALUE_MAP, TRANSIT_VALUE_TAGGED_UNION, TRANSIT_VALUE_JSON
};
typedef struct transit_logical_value {
    transit_logical_value_kind kind;
    union {
        transit_logical_atom atom;
        struct { const transit_logical_cell_view *data; size_t size; } cells;
        struct { const transit_logical_entry *data; size_t size; } map;
        struct { uint8_t index; const transit_logical_cell_view *value; } tagged_union;
        transit_sdk_bytes json;
    } as;
} transit_logical_value;
struct transit_logical_cell_view {
    transit_logical_state state;
    union {
        transit_logical_kind type_error;
        transit_logical_value value;
        struct { const transit_logical_alternative *data; size_t size; } conflict;
    } as;
};
struct transit_logical_entry { transit_logical_atom key; transit_logical_cell_view value; };
struct transit_logical_alternative { uint64_t counter, replica; transit_logical_cell_view value; };
typedef struct transit_logical_type transit_logical_type;
typedef struct transit_logical_cell transit_logical_cell;

/* Descriptor limits: 256 nodes, 4096 total UTF-8 name bytes. Cell limits: 65536
 * nodes and 1 MiB total variable data, including float bits and MAP keys.
 * Constructors clear out on failure. Destruction accepts NULL. */
transit_sdk_error transit_logical_type_create(const transit_logical_type_view *, transit_logical_type **out);
transit_sdk_error transit_logical_type_get(const transit_logical_type *, const transit_logical_type_view **out);
void transit_logical_type_destroy(transit_logical_type *);
transit_sdk_error transit_logical_cell_create(const transit_logical_cell_view *, transit_logical_cell **out);
transit_sdk_error transit_logical_cell_get(const transit_logical_cell *, const transit_logical_cell_view **out);
void transit_logical_cell_destroy(transit_logical_cell *);

/* Lossless neutral codecs, without authority or execution. Buffers own their
 * bytes and use transit_sdk_buffer_release. Malformed input is INVALID_ARGUMENT;
 * native-response decoders separately classify malformed responses. */
transit_sdk_error transit_logical_type_encode(const transit_logical_type *, transit_sdk_buffer *out);
transit_sdk_error transit_logical_type_decode(transit_sdk_bytes, transit_logical_type **out);
transit_sdk_error transit_logical_cell_encode(const transit_logical_cell *, transit_sdk_buffer *out);
transit_sdk_error transit_logical_cell_decode(transit_sdk_bytes, transit_logical_cell **out);
#ifdef __cplusplus
}
#endif
#endif
