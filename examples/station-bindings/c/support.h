#ifndef TRANSIT_EXAMPLE_SUPPORT_H
#define TRANSIT_EXAMPLE_SUPPORT_H
#include <transit_station.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static inline void require(int condition) {
    if (!condition) { fputs("Station example failed\n", stderr); exit(1); }
}
static inline uint64_t deadline(void) {
    struct timespec time;
    require(clock_gettime(CLOCK_REALTIME, &time) == 0);
    return (uint64_t)time.tv_sec * 1000 + (uint64_t)time.tv_nsec / 1000000 + 30000;
}
static inline char* copy_buffer(station_buffer* value) {
    size_t size = station_buffer_size(value);
    char* text = (char*)malloc(size + 1);
    require(text != NULL);
    memcpy(text, station_buffer_data(value), size);
    text[size] = 0;
    station_buffer_destroy(value);
    return text;
}
static inline char* extract(const char* json, const char* path, int string) {
    station_buffer* result = NULL;
    require(station_json_extract((const uint8_t*)json, strlen(json), (const uint8_t*)path, strlen(path), (uint32_t)string, &result) == 0);
    return copy_buffer(result);
}
static inline char* read_text(const char* file) {
    FILE* stream = fopen(file, "rb");
    require(stream != NULL);
    char* text = (char*)calloc(8193, 1);
    require(text != NULL);
    size_t length = fread(text, 1, 8192, stream);
    require(length < 8192 && !ferror(stream));
    require(fclose(stream) == 0);
    return text;
}
static inline unsigned nibble(char value) {
    if (value >= '0' && value <= '9') return (unsigned)(value - '0');
    if (value >= 'a' && value <= 'f') return (unsigned)(value - 'a' + 10);
    require(0);
    return 0;
}
static inline void decode(const char* hex, uint8_t* output, size_t capacity) {
    size_t size = strlen(hex);
    require(size % 2 == 0 && size / 2 <= capacity);
    for (size_t i = 0; i < size / 2; ++i) output[i] = (uint8_t)(nibble(hex[i*2]) * 16 + nibble(hex[i*2+1]));
}
static inline void erase(void* bytes, size_t length) {
    volatile unsigned char* value = (volatile unsigned char*)bytes;
    while (length--) *value++ = 0;
}
static inline void seed_from(const char* file, uint8_t seed[32]) {
    char* text = read_text(file);
    size_t length = strlen(text);
    while (length && (text[length-1] == '\n' || text[length-1] == '\r' || text[length-1] == ' ')) text[--length] = 0;
    require(length == 64);
    decode(text, seed, 32);
    erase(text, length);
    free(text);
}
#endif
