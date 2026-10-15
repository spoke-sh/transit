#define _GNU_SOURCE
#include <transit/client.h>
#include <assert.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

static void path(char *out, size_t size, const char *base, const char *suffix) {
    int count = snprintf(out, size, "%s/%s", base, suffix);
    assert(count > 0 && (size_t)count < size);
}
int main(int argc, char **argv) {
    assert(argc == 3);
    transit_sdk_config config = transit_sdk_growing_config("http://127.0.0.1:1");
    config.native_directory = argv[1];
    char library[8192]; path(library, sizeof library, argv[1], "libtransit_client.so");
    void *image = NULL;
    for (unsigned i = 0; i < 64; ++i) {
        transit_sdk_client *client = NULL;
        assert(transit_sdk_client_open(&config, &client).kind == TRANSIT_SDK_OK && client);
        transit_sdk_client_destroy(client);
        // No client remains. NOLOAD observes retention without loading a copy.
        void *retained = dlopen(library, RTLD_NOW | RTLD_NOLOAD);
        assert(retained && (!image || image == retained));
        image = retained;
        assert(!dlclose(retained));
    }
    char directory[8192];
    for (unsigned i = 0; i < 16; ++i) {
        char number[16]; assert(snprintf(number, sizeof number, "%u", i) > 0);
        path(directory, sizeof directory, argv[2], number);
        config.native_directory = directory;
        for (unsigned repeat = 0; repeat < 2; ++repeat) {
            transit_sdk_client *client = NULL;
            transit_sdk_error error = transit_sdk_client_open(&config, &client);
            assert(!client && error.kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE);
            assert(!strcmp(error.phase, i < 15 ? "native-version" : "native-library-capacity"));
        }
    }
    // A changed loaded file cannot silently reuse the previous mapping.
    path(directory, sizeof directory, argv[2], "0");
    path(library, sizeof library, directory, "libtransit_client.so");
    FILE *file = fopen(library, "ab"); assert(file);
    assert(fputc(0, file) == 0 && !fclose(file));
    config.native_directory = directory;
    transit_sdk_client *client = NULL;
    transit_sdk_error changed = transit_sdk_client_open(&config, &client);
    assert(!client && changed.kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE && !strcmp(changed.phase, "native-file-changed"));
    puts("C/C++ native loader: retained image after 64 closes, exact reuse, 16-image bound and changed-file rejection passed.");
}
