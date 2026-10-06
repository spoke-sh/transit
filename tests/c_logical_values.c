#define _POSIX_C_SOURCE 200809L
#include <transit/logical.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void ok(transit_sdk_error error) { assert(error.kind == TRANSIT_SDK_OK); }
static transit_sdk_bytes text(const char *value) { return (transit_sdk_bytes){(const uint8_t *)value, strlen(value)}; }
static void values(void) {
    transit_logical_type_view scalar = {.kind = TRANSIT_LOGICAL_INT128};
    char name[] = "amount";
    transit_logical_field field = {text(name), &scalar, true, false};
    transit_logical_type_view structure = {.kind = TRANSIT_LOGICAL_STRUCTURE, .as.fields = {&field, 1}};
    transit_logical_type *type = NULL;
    ok(transit_logical_type_create(&structure, &type));
    memset(name, 'x', sizeof(name) - 1); scalar.kind = TRANSIT_LOGICAL_BOOLEAN;
    const transit_logical_type_view *view = NULL;
    ok(transit_logical_type_get(type, &view));
    assert(view->as.fields.size == 1 && view->as.fields.data[0].type->kind == TRANSIT_LOGICAL_INT128);
    assert(!memcmp(view->as.fields.data[0].name.data, "amount", 6));
    transit_sdk_buffer encoded = {0}; ok(transit_logical_type_encode(type, &encoded));
    transit_logical_type_destroy(type); type = NULL;
    ok(transit_logical_type_decode((transit_sdk_bytes){encoded.data, encoded.size}, &type));
    memset(encoded.data, 0xcc, encoded.size); transit_sdk_buffer_release(&encoded);
    ok(transit_logical_type_get(type, &view)); assert(view->as.fields.data[0].type->kind == TRANSIT_LOGICAL_INT128);
    transit_logical_type_destroy(type);

    uint8_t *bytes = malloc(300000); assert(bytes); memset(bytes, 0x9a, 300000);
    transit_logical_cell_view cell = {.state = TRANSIT_LOGICAL_VALUE, .as.value = {.kind = TRANSIT_VALUE_ATOM,
        .as.atom = {.kind = TRANSIT_ATOM_BINARY, .as.bytes = {bytes, 300000}}}};
    transit_logical_cell *owner = NULL; ok(transit_logical_cell_create(&cell, &owner));
    memset(bytes, 0, 300000); free(bytes);
    const transit_logical_cell_view *owned = NULL; ok(transit_logical_cell_get(owner, &owned));
    assert(owned->as.value.as.atom.as.bytes.size == 300000 && owned->as.value.as.atom.as.bytes.data[299999] == 0x9a);
    ok(transit_logical_cell_encode(owner, &encoded)); assert(encoded.size > 600000);
    transit_logical_cell_destroy(owner); owner = NULL;
    ok(transit_logical_cell_decode((transit_sdk_bytes){encoded.data, encoded.size}, &owner));
    memset(encoded.data, 0, encoded.size); transit_sdk_buffer_release(&encoded);
    ok(transit_logical_cell_get(owner, &owned)); assert(owned->as.value.as.atom.as.bytes.data[0] == 0x9a);
    transit_logical_cell_destroy(owner);

    transit_logical_type_view cycle = {.kind = TRANSIT_LOGICAL_LIST}; cycle.as.list.type = &cycle;
    type = (transit_logical_type *)(uintptr_t)1;
    assert(transit_logical_type_create(&cycle, &type).kind == TRANSIT_SDK_INVALID_ARGUMENT && type == NULL);
    cell.state = (transit_logical_state)99; owner = (transit_logical_cell *)(uintptr_t)1;
    assert(transit_logical_cell_create(&cell, &owner).kind == TRANSIT_SDK_INVALID_ARGUMENT && owner == NULL);
    scalar.kind = UINT32_MAX;
    assert(transit_logical_type_create(&scalar, &type).kind == TRANSIT_SDK_INVALID_ARGUMENT && type == NULL);
    scalar.kind = TRANSIT_LOGICAL_TIMESTAMP; scalar.as.timestamp = UINT32_MAX;
    assert(transit_logical_type_create(&scalar, &type).kind == TRANSIT_SDK_INVALID_ARGUMENT && type == NULL);
    cell.state = TRANSIT_LOGICAL_VALUE; cell.as.value.kind = UINT32_MAX;
    assert(transit_logical_cell_create(&cell, &owner).kind == TRANSIT_SDK_INVALID_ARGUMENT && owner == NULL);
    cell.as.value.kind = TRANSIT_VALUE_ATOM; cell.as.value.as.atom.kind = UINT32_MAX;
    assert(transit_logical_cell_create(&cell, &owner).kind == TRANSIT_SDK_INVALID_ARGUMENT && owner == NULL);
    assert(transit_logical_cell_decode(text("{\"null\":{},\"n\\u0075ll\":{}}"), &owner).kind == TRANSIT_SDK_INVALID_ARGUMENT && owner == NULL);
    transit_logical_type_destroy(NULL); transit_logical_cell_destroy(NULL);
}
int main(int argc, char **argv) {
    (void)argv;
    if (argc == 1) { values(); puts("C owned logical values passed."); return 0; }
    char *line = NULL; size_t capacity = 0; ssize_t size;
    while ((size = getline(&line, &capacity, stdin)) >= 0) {
        assert(size > 1 && size <= 16777218);
        transit_sdk_bytes input = {(const uint8_t *)line + 1, (size_t)size - 1};
        transit_sdk_buffer output = {0}; transit_sdk_error error;
        if (line[0] == 't') {
            transit_logical_type *value = NULL; error = transit_logical_type_decode(input, &value);
            memset(line, 0xcc, (size_t)size);
            if (error.kind == TRANSIT_SDK_OK) error = transit_logical_type_encode(value, &output);
            transit_logical_type_destroy(value);
        } else {
            transit_logical_cell *value = NULL; error = transit_logical_cell_decode(input, &value);
            memset(line, 0xcc, (size_t)size);
            if (error.kind == TRANSIT_SDK_OK) error = transit_logical_cell_encode(value, &output);
            transit_logical_cell_destroy(value);
        }
        if (error.kind != TRANSIT_SDK_OK) { assert(error.kind == TRANSIT_SDK_INVALID_ARGUMENT); puts("invalid"); }
        else { assert(fwrite(output.data, 1, output.size, stdout) == output.size); putchar('\n'); }
        transit_sdk_buffer_release(&output); fflush(stdout);
    }
    free(line); return 0;
}
