/* Neutral test serialization of public owned C inspection values. */
#ifndef TRANSIT_TEST_UNIFIED_INSPECTION_H
#define TRANSIT_TEST_UNIFIED_INSPECTION_H
#include <transit/unified_query.h>
#include <stdio.h>
static void inspection_text(const char *value) {
    putchar('"');
    for(const unsigned char *p=(const unsigned char *)value;*p;++p) {
        if(*p=='"'||*p=='\\') { putchar('\\'); putchar(*p); }
        else if(*p<32)printf("\\u%04x",*p);
        else putchar(*p);
    }
    putchar('"');
}
static const char *inspection_types[]={"int64","uint64","float64","boolean","utf8","binary"};
static void inspection_columns(const transit_station_unified_source_description *value) {
    putchar('[');
    for(size_t i=0;i<value->column_count;++i) {
        if(i)putchar(',');printf("{\"name\":");inspection_text(value->columns[i].name);
        printf(",\"type\":\"%s\"}",inspection_types[value->columns[i].type]);
    }
    putchar(']');
}
static void print_inspection(const transit_station_unified_inspection *value) {
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
        const char *operators[]={"scan","filter","limit","project","count","sum"},*aggregates[]={"rows","count","sum"};
        printf("\"explanation\":{\"operators\":[");for(size_t i=0;i<p->operator_count;++i){if(i)putchar(',');inspection_text(operators[p->operators[i]]);}
        printf("],\"predicate\":{");
        if(p->predicate==TRANSIT_UNIFIED_ALL)printf("\"all\":{}");
        else if(p->predicate==TRANSIT_UNIFIED_IS_STATE) {
            const char *states[]={"missing","null","type_error","value","conflict"};
            printf("\"state\":{\"column\":");inspection_text(p->column);printf(",\"value\":\"%s\"}",states[p->state]);
        } else {
            const char *comparisons[]={"eq","ne","lt","le","gt","ge"};
            printf("\"compare\":{\"column\":");inspection_text(p->column);printf(",\"op\":\"%s\",\"type\":\"%s\"}",comparisons[p->comparison],inspection_types[p->type]);
        }
        printf("},\"projection\":[");for(size_t i=0;i<p->projection_count;++i){if(i)putchar(',');inspection_text(p->projection[i]);}
        printf("],\"limit\":");if(p->has_limit)printf("\"%llu\"",(unsigned long long)p->limit);else printf("null");
        printf(",\"aggregate\":\"%s\",\"columns\":",aggregates[p->aggregate]);inspection_columns(&p->output);
        printf(",\"budgets\":{\"pages\":\"%llu\",\"segments\":\"%llu\",\"result_bytes\":\"%llu\"}}",
            (unsigned long long)p->budgets.pages,(unsigned long long)p->budgets.segments,(unsigned long long)p->budgets.result_bytes);
    }
    printf("}}}");
}
#endif
