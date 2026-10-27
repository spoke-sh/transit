/* Neutral test serialization of public owned C inspection values. */
#ifndef TRANSIT_TEST_UNIFIED_INSPECTION_H
#define TRANSIT_TEST_UNIFIED_INSPECTION_H
#include <transit/unified_query.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
static void inspection_text(const char *value) {
    putchar('"');
    for(const unsigned char *p=(const unsigned char *)value;*p;++p) {
        if(*p=='"'||*p=='\\') { putchar('\\'); putchar(*p); }
        else if(*p<32)printf("\\u%04x",*p);
        else putchar(*p);
    }
    putchar('"');
}
static void inspection_type(const transit_logical_type_view *view) {
    transit_logical_type *owner=NULL;assert(transit_logical_type_create(view,&owner).kind==TRANSIT_SDK_OK);
    transit_sdk_buffer encoded;memset(&encoded,0,sizeof(encoded));assert(transit_logical_type_encode(owner,&encoded).kind==TRANSIT_SDK_OK);
    fwrite(encoded.data,1,encoded.size,stdout);transit_sdk_buffer_release(&encoded);transit_logical_type_destroy(owner);
}
static void inspection_columns(const transit_station_unified_source_description *value) {
    putchar('[');
    for(size_t i=0;i<value->column_count;++i) {
        if(i)putchar(',');printf("{\"name\":");inspection_text(value->columns[i].name);
        printf(",\"type\":");inspection_type(value->columns[i].type);printf(",\"nullable\":%s,\"optional\":%s}",value->columns[i].nullable?"true":"false",value->columns[i].optional?"true":"false");
    }
    putchar(']');
}
static void inspection_atom(transit_station_unified_predicate_kind kind,const char *column,transit_station_unified_state state,transit_station_comparison comparison,const transit_logical_type_view *type) {
    if(kind==TRANSIT_UNIFIED_ALL)printf("{\"all\":{}}");
    else if(kind==TRANSIT_UNIFIED_IS_STATE){
        const char *states[]={"missing","null","type_error","value","conflict"};
        printf("{\"state\":{\"column\":");inspection_text(column);printf(",\"value\":\"%s\"}}",states[state]);
    }else {
        const char *comparisons[]={"eq","ne","lt","le","gt","ge"};
        printf("{\"compare\":{\"column\":");inspection_text(column);printf(",\"op\":\"%s\",\"type\":",comparisons[comparison]);inspection_type(type);printf("}}");
    }
}
static void print_inspection(const transit_station_unified_inspection_info *value) {
    const char *kinds[]={"kv","table","document"};
    printf("{\"inspection\":{\"version\":1,\"scope\":\"configured_source\",\"name\":");inspection_text(value->name);
    printf(",\"resource\":%llu,\"source_kind\":\"%s\",\"resource_revision\":%llu,\"policy_revision\":\"%llu\",\"contract\":[",
        (unsigned long long)value->resource.resource,kinds[value->source_kind],(unsigned long long)value->resource_revision,(unsigned long long)value->policy_revision);
    for(size_t i=0;i<32;++i)printf("%s%u",i?",":"",value->source_digest[i]);
    printf("],\"schema\":[");for(size_t i=0;i<32;++i)printf("%s%u",i?",":"",value->schema_digest[i]);
    printf("],\"details\":{");
    if(value->kind==TRANSIT_UNIFIED_DESCRIPTION) { printf("\"description\":{\"columns\":");inspection_columns(&value->details.description);putchar('}'); }
    else if(value->kind==TRANSIT_UNIFIED_TABLES) {
        printf("\"tables\":[");for(size_t i=0;i<value->details.tables.count;++i){if(i)putchar(',');inspection_text(value->details.tables.names[i]);}putchar(']');
    } else {
        const transit_station_unified_explanation *p=&value->details.explanation;
        const char *operators[]={"scan","filter","limit","project","count","sum","count_values"},*aggregates[]={"rows","count","sum","count_values"};
        printf("\"explanation\":{\"operators\":[");for(size_t i=0;i<p->operator_count;++i){if(i)putchar(',');inspection_text(operators[p->operators[i]]);}
        printf("],\"predicate\":");
        if(p->predicate==TRANSIT_UNIFIED_PROGRAM){
            const char *ops[]={"negate","conjunction","disjunction"};printf("{\"program\":[");
            for(size_t i=0;i<p->instruction_count;++i){
                const transit_station_unified_inspected_instruction *instruction=&p->instructions[i];if(i)putchar(',');
                if(instruction->kind==TRANSIT_UNIFIED_ATOM){const transit_station_unified_inspected_atom *a=&instruction->atom;printf("{\"atom\":");inspection_atom(a->kind,a->column,a->state,a->comparison,a->type);putchar('}');}
                else printf("{\"%s\":{}}",ops[instruction->kind-TRANSIT_UNIFIED_NEGATE]);
            }
            printf("]}");
        }else inspection_atom(p->predicate,p->column,p->state,p->comparison,p->type);
        printf(",\"projection\":[");for(size_t i=0;i<p->projection_count;++i){if(i)putchar(',');inspection_text(p->projection[i]);}
        printf("],\"limit\":");if(p->has_limit)printf("\"%llu\"",(unsigned long long)p->limit);else printf("null");
        printf(",\"aggregate\":\"%s\",\"columns\":",aggregates[p->aggregate]);inspection_columns(&p->output);
        printf(",\"budgets\":{\"pages\":\"%llu\",\"segments\":\"%llu\",\"result_bytes\":\"%llu\"}}",
            (unsigned long long)p->budgets.pages,(unsigned long long)p->budgets.segments,(unsigned long long)p->budgets.result_bytes);
    }
    printf("}}}");
}
#endif
