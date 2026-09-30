#ifndef TRANSIT_TEST_MUTATION_IO_H
#define TRANSIT_TEST_MUTATION_IO_H
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static char command[32], first[16385], second[8193], third[256];
static inline int read_command(void) {
    char line[32768]; if(!fgets(line,sizeof(line),stdin)) return 0;
    first[0]=second[0]=third[0]=0;
    assert(sscanf(line,"%31s %16384s %8192s %255s",command,first,second,third)>=1); return 1;
}
static inline void checked(transit_sdk_error error) {
    if(error.kind) { fprintf(stderr,"mutation kind=%d status=%u phase=%s code=%s\n",error.kind,error.native_status,error.phase,error.code); abort(); }
}
static inline int digit(char c) { if(c>='0'&&c<='9')return c-'0'; if(c>='a'&&c<='f')return c-'a'+10; abort(); }
static inline transit_sdk_bytes unhex(const char *text) {
    size_t n=strlen(text);assert(!(n%2));uint8_t *data=(uint8_t *)malloc(n/2+1);assert(data);
    for(size_t i=0;i<n/2;++i)data[i]=(uint8_t)(digit(text[i*2])*16+digit(text[i*2+1]));data[n/2]=0;
    transit_sdk_bytes out={data,n/2};return out;
}
static inline void print_hex(transit_sdk_bytes v) { for(size_t i=0;i<v.size;++i)printf("%02x",v.data[i]); }
static inline void equal(transit_sdk_bytes a,transit_sdk_bytes b) { assert(a.size==b.size && (!a.size || !memcmp(a.data,b.data,a.size))); }
static inline void emit_prepared(transit_sdk_bytes data,int found) {
    printf("{\"status\":0,\"value\":{\"prepared_hex\":");if(found){putchar('"');print_hex(data);putchar('"');}else printf("null");puts("}}");
}
static inline void emit_error(transit_sdk_error error) {
    unsigned status=error.has_native_status?error.native_status:(error.kind==TRANSIT_SDK_UNKNOWN_OUTCOME?6:1);
    printf("{\"status\":%u,\"value\":{\"err\":\"%s\"}}\n",status,error.code);
}
#endif
