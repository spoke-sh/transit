#ifndef TRANSIT_TEST_CATALOG_IO_H
#define TRANSIT_TEST_CATALOG_IO_H
#include <transit/catalog.h>
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* Fixture-only, bounded whitespace protocol; public callers remain typed. */
static char line[32768];
static char *args[16];
static inline int read_command(void) {
    if(!fgets(line,sizeof(line),stdin))return 0;
    assert(strchr(line,'\n'));size_t n=0;
    for(char *p=strtok(line," \n");p;p=strtok(NULL," \n")){assert(n<16);args[n++]=p;}
    assert(n);for(;n<16;++n)args[n]=NULL;return 1;
}
static inline uint64_t number(const char *v) {
    assert(v && *v && *v!='-');errno=0;char *end=NULL;unsigned long long n=strtoull(v,&end,10);assert(!errno && !*end);return (uint64_t)n;
}
static inline void checked(transit_sdk_error e) {
    if(e.kind){fprintf(stderr,"catalog kind=%d status=%u phase=%s code=%s\n",e.kind,e.native_status,e.phase,e.code);abort();}
}
static inline int digit(char c) { if(c>='0'&&c<='9')return c-'0';if(c>='a'&&c<='f')return c-'a'+10;abort(); }
static inline transit_sdk_bytes unhex(const char *v) {
    size_t n=strlen(v);assert(!(n%2));uint8_t *out=(uint8_t *)malloc(n/2+1);assert(out);
    for(size_t i=0;i<n/2;++i)out[i]=(uint8_t)(16*digit(v[2*i])+digit(v[2*i+1]));out[n/2]=0;
    transit_sdk_bytes result={out,n/2};return result;
}
static inline void print_hex(transit_sdk_bytes v){for(size_t i=0;i<v.size;++i)printf("%02x",v.data[i]);}
static inline void equal(transit_sdk_bytes a,transit_sdk_bytes b){assert(a.size==b.size && (!a.size || !memcmp(a.data,b.data,a.size)));}
static inline void emit_error(transit_sdk_error e) {
    unsigned status=e.has_native_status?e.native_status:(e.kind==TRANSIT_SDK_UNKNOWN_OUTCOME?6:1);
    printf("{\"status\":%u,\"value\":{\"err\":\"%s\",\"diagnostic\":%s,\"diagnostic_invalid\":%s}}\n",status,e.code,e.diagnostic.size?e.diagnostic.json:"null",e.diagnostic_invalid?"true":"false");
}
static inline void emit_prepared(transit_sdk_bytes v){printf("{\"status\":0,\"value\":{\"prepared_hex\":\"");print_hex(v);puts("\"}}");}
static inline transit_station_catalog_scope scope(size_t at){transit_station_catalog_scope s={{number(args[at]),number(args[at+1])},number(args[at+2])};return s;}
static inline void emit_scope(transit_station_catalog_scope s){printf("{\"realm\":%llu,\"resource\":%llu,\"catalog\":\"%llu\"}",(unsigned long long)s.resource.realm,(unsigned long long)s.resource.resource,(unsigned long long)s.catalog);}
static inline void copy_name(char out[17],const char *v){assert(v && strlen(v)<=16);memset(out,0,17);strcpy(out,v);}
static inline const char *type_name(transit_station_cell_kind type){const char *names[]={"invalid","int64","boolean","utf8","binary"};assert(type>=1 && type<=4);return names[type];}
static inline transit_station_catalog_create_table request(void){
    transit_station_catalog_create_table r;memset(&r,0,sizeof(r));r.scope=scope(1);r.operation=number(args[4]);r.object=number(args[5]);assert(number(args[6])<=UINT32_MAX);r.table=(uint32_t)number(args[6]);
    copy_name(r.name,args[7]);copy_name(r.schema.names[0],args[8]);copy_name(r.schema.names[1],args[9]);
    for(int i=1;i<=4;++i)if(!strcmp(args[10],type_name((transit_station_cell_kind)i)))r.schema.value_type=(transit_station_cell_kind)i;
    assert(r.schema.value_type);return r;
}
static inline void emit_request(const transit_station_catalog_create_table *r){
    printf("{\"scope\":");emit_scope(r->scope);printf(",\"operation\":\"%llu\",\"object\":\"%llu\",\"table\":%u,\"name\":\"%s\",\"schema\":{\"names\":[\"%s\",\"%s\"],\"value_type\":\"%s\"}}",(unsigned long long)r->operation,(unsigned long long)r->object,r->table,r->name,r->schema.names[0],r->schema.names[1],type_name(r->schema.value_type));
}
static inline void emit_description(const transit_station_catalog_description *v){
    printf("{\"status\":0,\"value\":{\"description\":{\"configuration\":{\"scope\":");emit_scope(v->configuration.scope);
    printf(",\"owner\":%llu,\"administrator\":%llu},\"policy\":{\"scope\":",(unsigned long long)v->configuration.owner.pid,(unsigned long long)v->configuration.administrator);emit_scope(v->policy.scope);
    printf(",\"principal\":%llu,\"revision\":\"%llu\",\"inspect\":%s,\"create\":%s},\"resource_revision\":%llu}}}\n",(unsigned long long)v->policy.principal,(unsigned long long)v->policy.revision,v->policy.inspect?"true":"false",v->policy.create?"true":"false",(unsigned long long)v->resource_revision);
}
static inline void emit_capabilities(const transit_station_catalog_capabilities *v){printf("{\"status\":0,\"value\":{\"capabilities\":{\"version\":%u,\"definition\":\"%s\",\"initialize\":%s,\"create_table\":%s,\"conditional_policy\":%s,\"current_metadata\":%s,\"max_saved_bytes\":%u,\"table_columns\":%u}}}\n",v->version,v->definition,v->initialize?"true":"false",v->create_table?"true":"false",v->conditional_policy?"true":"false",v->current_metadata?"true":"false",v->max_saved_bytes,v->table_columns);}
static inline transit_station_catalog_cursor cursor(void){
    transit_station_catalog_cursor v;memset(&v,0,sizeof(v));assert(args[1] && strlen(args[1])==64);strcpy(v.definition,args[1]);v.scope=scope(2);v.resource_revision=number(args[5]);copy_name(v.after,args[6]);return v;
}
static inline void emit_definition_value(const transit_station_catalog_definition *v){
    if(!v->found){printf("null");return;}
    printf("{\"scope\":");emit_scope(v->scope);
    printf(",\"object\":\"%llu\",\"revision\":\"%llu\",\"name\":\"%s\",\"source\":{\"table\":{\"id\":%u,\"schema\":{\"names\":[\"%s\",\"%s\"],\"value_type\":\"%s\"}}},\"principal\":%llu,\"operation\":\"%llu\",\"input\":%llu}",
        (unsigned long long)v->object,(unsigned long long)v->revision,v->name,v->source.table,v->source.schema.names[0],v->source.schema.names[1],type_name(v->source.schema.value_type),(unsigned long long)v->principal,(unsigned long long)v->operation,(unsigned long long)v->input);
}
static inline void emit_definition(const transit_station_catalog_definition *v){printf("{\"status\":0,\"value\":{\"definition\":");emit_definition_value(v);puts("}}");}
static inline void emit_page(const transit_station_catalog_page *v){
    assert(v->count<=8);printf("{\"status\":0,\"value\":{\"page\":{\"resource_revision\":%llu,\"entries\":[",(unsigned long long)v->resource_revision);
    for(size_t i=0;i<8;++i){if(i)printf(",");if(i<v->count){assert(v->entries[i].found);emit_definition_value(&v->entries[i]);}else printf("null");}
    printf("],\"next\":");if(v->has_next){printf("{\"definition\":\"%s\",\"scope\":",v->next.definition);emit_scope(v->next.scope);printf(",\"resource_revision\":%llu,\"after\":\"%s\"}",(unsigned long long)v->next.resource_revision,v->next.after);}else printf("null");puts("}}}");
}
static inline void emit_status(const transit_station_catalog_receipt *v){
    const char *names[]={"applied","name_conflict","object_conflict","table_conflict"};printf("{\"status\":0,\"value\":{\"status\":");
    if(v->found){assert(v->outcome<=TRANSIT_CATALOG_TABLE_CONFLICT);printf("{\"request\":");emit_request(&v->request);printf(",\"principal\":%llu,\"input\":%llu,\"outcome\":\"%s\",\"diagnostic\":%.*s}",(unsigned long long)v->principal,(unsigned long long)v->input,names[v->outcome],(int)v->diagnostic.size,v->diagnostic.json);}else printf("null");puts("}}");
}
static inline void emit_disposition(const transit_station_catalog_disposition *v){
    const char *origins[]={"external","process","effect"};const char *outcomes[]={"initialized","policy_applied","invalid_command","denied","identity_conflict","stale_policy"};
    printf("{\"status\":0,\"value\":{\"disposition\":");if(v->found){assert(v->origin<=TRANSIT_CATALOG_EFFECT && v->outcome<=TRANSIT_CATALOG_STALE_POLICY);printf("{\"scope\":");emit_scope(v->scope);printf(",\"origin\":\"%s\",\"principal\":%llu,\"input\":%llu,\"payload\":\"",origins[v->origin],(unsigned long long)v->principal,(unsigned long long)v->input);transit_sdk_bytes payload={v->payload,32};print_hex(payload);printf("\",\"outcome\":\"%s\",\"diagnostic\":%.*s}",outcomes[v->outcome],(int)v->diagnostic.size,v->diagnostic.json);}else printf("null");puts("}}");
}
#endif
