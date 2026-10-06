/* Installed C11 consumer. Only public SDK operations cross the native boundary. */
#include <transit/unified_query.h>
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "unified_inspection_fixture.h"

static void checked(transit_sdk_error error) {
    if(error.kind) { fprintf(stderr,"C query error kind=%d status=%u phase=%s code=%s\n",error.kind,error.native_status,error.phase,error.code); abort(); }
}
static transit_sdk_bytes bytes(const char *s) { return (transit_sdk_bytes){(const uint8_t *)s,strlen(s)}; }
static transit_sdk_bytes file_bytes(const char *path) {
    FILE *file=fopen(path,"rb"); assert(file); assert(!fseek(file,0,SEEK_END)); long n=ftell(file); assert(n>=0 && n<=65536); rewind(file);
    uint8_t *data=malloc((size_t)n+1); assert(data); assert(fread(data,1,(size_t)n,file)==(size_t)n); fclose(file);
    return (transit_sdk_bytes){data,(size_t)n};
}
static transit_sdk_bytes fixture(const char *root,const char *name) { char path[4096]; assert(snprintf(path,sizeof(path),"%s/%s",root,name)>0); return file_bytes(path); }
static int digit(char c) { if(c>='0'&&c<='9')return c-'0'; if(c>='a'&&c<='f')return c-'a'+10; abort(); }
static transit_sdk_bytes unhex(const char *text) {
    if(!strcmp(text,"-")) return (transit_sdk_bytes){0};
    size_t n=strlen(text); assert(!(n%2)); uint8_t *data=malloc(n/2+1); assert(data);
    for(size_t i=0;i<n/2;++i)data[i]=(uint8_t)(digit(text[2*i])*16+digit(text[2*i+1]));
    return (transit_sdk_bytes){data,n/2};
}
static void print_hex(transit_sdk_bytes v) { for(size_t i=0;i<v.size;++i)printf("%02x",v.data[i]); }
static void equal(transit_sdk_bytes a,transit_sdk_bytes b) { assert(a.size==b.size && (!a.size || !memcmp(a.data,b.data,a.size))); }
typedef struct definition { transit_station_unified_source source; transit_station_unified_projection projections[4]; transit_station_catalog_metadata metadata;transit_station_catalog_schema schema; } definition;
static void bind_source(definition *d){
    if(d->source.kind==TRANSIT_UNIFIED_DOCUMENT)d->source.source.document.projections=d->projections;
    if(d->source.kind==TRANSIT_UNIFIED_TABLE&&!d->source.source.table.metadata){d->source.source.table.metadata=&d->metadata;d->source.source.table.schema=&d->schema;}
}
static definition source(transit_sdk_resource resource,int kind,bool golden) {
    definition d={0}; d.source.resource=resource; d.source.kind=(transit_station_unified_source_kind)kind;
    if(kind==0) { d.source.source.kv.prefix=bytes(golden?"data/":"k"); d.source.source.kv.key=(transit_station_unified_decoder){1,TRANSIT_UNIFIED_BINARY}; d.source.source.kv.value=(transit_station_unified_decoder){1,golden?TRANSIT_UNIFIED_UINT64:TRANSIT_UNIFIED_UTF8}; }
    else if(kind==1 && golden) {
        static const transit_logical_type_view id={.kind=TRANSIT_LOGICAL_INT64},label={.kind=TRANSIT_LOGICAL_UTF8};
        static const transit_station_catalog_column columns[]={{1,"id",&id,false,NULL,0},{2,"label",&label,true,NULL,0}};
        d.source.resource=(transit_sdk_resource){1,7};d.source.source.table.owner=(transit_sdk_process){1,3};
        d.metadata.scope=(transit_station_catalog_scope){{1,7},9};d.metadata.object=9;d.metadata.revision=1;strcpy(d.metadata.name,"items");memset(d.metadata.schema_fingerprint,1,32);d.metadata.principal=17;d.metadata.operation=1;d.metadata.admitted_input=1;d.metadata.commitment.bytes=200;memset(d.metadata.commitment.digest,1,32);
        d.schema=(transit_station_catalog_schema){9,1,3,columns,2,NULL,0};
    } else if(kind==1) { d.source.source.table.owner=(transit_sdk_process){resource.realm,3}; }
    else {
        d.source.source.document.reference=(transit_station_document_reference){resource,golden?UINT64_MAX:17,golden?3:1,1,golden?42:13};
        static const char *title[]={"title"},*body[]={"body"},*items[]={"items"},*optional[]={"optional"};
        d.source.source.document.projection_count=golden?2:4;
        d.source.source.document.has_expansion=!golden; d.source.source.document.expand=items; d.source.source.document.expand_count=golden?0:1;
        for(size_t i=0;i<4;++i) { d.projections[i].text_bytes=4096; d.projections[i].text_steps=4096; }
        if(golden) {
            d.projections[0].column=(transit_station_unified_decoder_column){"title",TRANSIT_UNIFIED_UTF8}; d.projections[0].path=title; d.projections[0].path_count=1;
            d.projections[1].column=(transit_station_unified_decoder_column){"body",TRANSIT_UNIFIED_UTF8}; d.projections[1].path=body; d.projections[1].path_count=1; d.projections[1].mode=TRANSIT_UNIFIED_TEXT;
        } else {
            d.projections[0].column=(transit_station_unified_decoder_column){"value",TRANSIT_UNIFIED_UTF8}; d.projections[0].relative=true;
            d.projections[1].column=(transit_station_unified_decoder_column){"counter",TRANSIT_UNIFIED_UINT64}; d.projections[1].relative=true; d.projections[1].mode=TRANSIT_UNIFIED_ELEMENT_COUNTER;
            d.projections[2].column=(transit_station_unified_decoder_column){"replica",TRANSIT_UNIFIED_UINT64}; d.projections[2].relative=true; d.projections[2].mode=TRANSIT_UNIFIED_ELEMENT_REPLICA;
            d.projections[3].column=(transit_station_unified_decoder_column){"optional",TRANSIT_UNIFIED_UTF8}; d.projections[3].path=optional; d.projections[3].path_count=1;
        }
    }
    return d;
}
static transit_station_unified_bundle *bundle(definition *d,bool golden,bool named,bool compound) {
    bind_source(d);
    char padding[513]; memset(padding,'x',512); padding[512]=0;
    static const uint8_t both[]={1,0},value[]={1},document[]={0,1,2,3};
    bool doc=d->source.kind==TRANSIT_UNIFIED_DOCUMENT;
    transit_station_unified_plan plan={0}; plan.projection=golden?both:(doc?document:value); plan.projection_count=golden?2:(doc?4:1);
    plan.output_names[0]=named?"Result":NULL; plan.has_limit=golden; plan.limit=UINT64_MAX; plan.predicate=TRANSIT_UNIFIED_COMPARE; plan.column=golden?1:(doc?0:1); plan.comparison=TRANSIT_COMPARE_NE;
    if(golden&&d->source.kind==TRANSIT_UNIFIED_KV){plan.value.kind=TRANSIT_ATOM_UNSIGNED;plan.value.as.unsigned_value=(transit_logical_u128){UINT64_MAX,0};}else{plan.value.kind=TRANSIT_ATOM_UTF8;plan.value.as.bytes=bytes(padding);}
    transit_station_unified_instruction instructions[6]={0};char ceiling[160];
    if(compound){
        assert(!golden);int n=snprintf(ceiling,sizeof(ceiling),"東京🙂/%.*s/%s",doc?64:128,padding,doc?"10":"39");assert(n>0&&(size_t)n<sizeof(ceiling));
        instructions[0].atom=(transit_station_unified_predicate_atom){TRANSIT_UNIFIED_COMPARE,plan.column,0,plan.comparison,plan.value};
        instructions[1].atom=instructions[0].atom;instructions[1].atom.comparison=TRANSIT_COMPARE_GE;instructions[1].atom.value.as.bytes=bytes(ceiling);
        instructions[2].atom.kind=TRANSIT_UNIFIED_IS_STATE;instructions[2].atom.column=plan.column;instructions[2].atom.state=TRANSIT_UNIFIED_NULL;
        instructions[3].kind=TRANSIT_UNIFIED_DISJUNCTION;instructions[4].kind=TRANSIT_UNIFIED_NEGATE;instructions[5].kind=TRANSIT_UNIFIED_CONJUNCTION;
        plan.predicate=TRANSIT_UNIFIED_PROGRAM;plan.instructions=instructions;plan.instruction_count=6;
    }
    transit_station_unified_bundle *out=NULL;
    checked(transit_station_unified_prepare_bundle(&d->source,&plan,(transit_station_unified_budgets){1000,golden?500:100,1048576},NULL,&out)); return out;
}
static void scalar(transit_logical_atom v,size_t column) {
    const transit_logical_atom_kind kinds[]={TRANSIT_ATOM_SIGNED,TRANSIT_ATOM_UNSIGNED,TRANSIT_ATOM_FLOAT64,TRANSIT_ATOM_BOOLEAN,TRANSIT_ATOM_UTF8,TRANSIT_ATOM_BINARY};assert(v.kind==kinds[column]);
    if(column==0)assert(v.as.signed_value.low==(uint64_t)INT64_MIN && v.as.signed_value.high==-1);
    if(column==1)assert(v.as.unsigned_value.low==UINT64_MAX && v.as.unsigned_value.high==0);
    if(column==2)assert(v.as.float64==0.0 && signbit(v.as.float64));
    if(column==3)assert(!v.as.boolean);
    if(column==4)equal(v.as.bytes,bytes("café é 東京🙂"));
    if(column==5)equal(v.as.bytes,(transit_sdk_bytes){(const uint8_t *)"\x00\xff\x80",3});
}
static void boolean_codecs(const char *root) {
    const uint8_t projection[]={0};
    transit_station_unified_source source={0};source.kind=TRANSIT_UNIFIED_KV;source.resource=(transit_sdk_resource){46,7};source.source.kv.key.version=1;source.source.kv.value=(transit_station_unified_decoder){1,TRANSIT_UNIFIED_UINT64};
    transit_station_unified_budgets budgets={1000,500,1048576};
    for(size_t i=0;i<9;++i){
        const transit_station_unified_decoder_type type=i<6?(transit_station_unified_decoder_type)i:i==6?TRANSIT_UNIFIED_UTF8:TRANSIT_UNIFIED_INT64;source.source.kv.key.type=type;
        char padding[513];memset(padding,'x',512);padding[512]=0;
        transit_station_unified_instruction instructions[64]={0};size_t count=4;
        if(i<7){
            instructions[0].atom.kind=TRANSIT_UNIFIED_COMPARE;instructions[0].atom.comparison=TRANSIT_COMPARE_EQ;
            transit_logical_atom *value=&instructions[0].atom.value;
            switch(i){
                case 0:value->kind=TRANSIT_ATOM_SIGNED;value->as.signed_value=(transit_logical_i128){(uint64_t)INT64_MIN,-1};break;
                case 1:value->kind=TRANSIT_ATOM_UNSIGNED;value->as.unsigned_value=(transit_logical_u128){UINT64_MAX,0};break;
                case 2:value->kind=TRANSIT_ATOM_FLOAT64;value->as.float64=-0.0;break;
                case 3:value->kind=TRANSIT_ATOM_BOOLEAN;value->as.boolean=true;break;
                case 5:value->kind=TRANSIT_ATOM_BINARY;value->as.bytes=(transit_sdk_bytes){(const uint8_t *)"\x00\xff\x80",3};break;
                default:value->kind=TRANSIT_ATOM_UTF8;value->as.bytes=bytes(i==6?padding:"café é 🙂");break;
            }
            instructions[1].kind=TRANSIT_UNIFIED_NEGATE;instructions[2].atom.kind=TRANSIT_UNIFIED_IS_STATE;instructions[2].atom.state=TRANSIT_UNIFIED_NULL;instructions[3].kind=TRANSIT_UNIFIED_DISJUNCTION;
        }else if(i==7){instructions[1].atom.kind=TRANSIT_UNIFIED_IS_STATE;instructions[1].atom.state=TRANSIT_UNIFIED_NULL;instructions[2].kind=TRANSIT_UNIFIED_NEGATE;instructions[3].kind=TRANSIT_UNIFIED_CONJUNCTION;}
        else {count=64;for(size_t j=1;j<count;++j)instructions[j].kind=TRANSIT_UNIFIED_NEGATE;}
        transit_station_unified_plan plan={0};plan.projection=projection;plan.projection_count=1;plan.predicate=TRANSIT_UNIFIED_PROGRAM;plan.instructions=instructions;plan.instruction_count=count;
        transit_station_unified_bundle *bundle=NULL;checked(transit_station_unified_prepare_bundle(&source,&plan,budgets,NULL,&bundle));
        memset(instructions,0,sizeof(instructions));memset(padding,0,sizeof(padding));
        transit_sdk_bytes encoded={0};checked(transit_station_unified_bundle_bytes(bundle,&encoded));char name[32];snprintf(name,sizeof(name),"boolean%zu.bin",i);transit_sdk_bytes expected=fixture(root,name);equal(encoded,expected);free((void *)expected.data);transit_station_unified_bundle_destroy(bundle);
    }
    source.source.kv.key.type=TRANSIT_UNIFIED_INT64;
    for(size_t i=0;i<9;++i){
        transit_station_unified_instruction instructions[65]={0};size_t count=1;
        if(i==0)count=0;
        else if(i==1)instructions[0].kind=TRANSIT_UNIFIED_NEGATE;
        else if(i==2)count=2;
        else if(i==3){count=65;for(size_t j=1;j<count;++j)instructions[j].kind=TRANSIT_UNIFIED_NEGATE;}
        else if(i==4)instructions[0].kind=(transit_station_unified_instruction_kind)99;
        else if(i==5)instructions[0].atom.kind=TRANSIT_UNIFIED_PROGRAM;
        else if(i==6){instructions[0].atom.kind=TRANSIT_UNIFIED_IS_STATE;instructions[0].atom.column=7;}
        else if(i==7){instructions[0].atom.kind=TRANSIT_UNIFIED_COMPARE;instructions[0].atom.value.kind=TRANSIT_ATOM_UTF8;instructions[0].atom.value.as.bytes=bytes("wrong type");}
        transit_station_unified_plan plan={0};plan.projection=projection;plan.projection_count=1;plan.predicate=TRANSIT_UNIFIED_PROGRAM;plan.instructions=i==8?NULL:instructions;plan.instruction_count=count;
        transit_station_unified_bundle *bundle=(transit_station_unified_bundle *)(uintptr_t)1;
        assert(transit_station_unified_prepare_bundle(&source,&plan,budgets,NULL,&bundle).kind!=TRANSIT_SDK_OK && !bundle);
    }
}
static void codecs(const char *root) {
    for(int i=0;i<3;++i) {
        definition d=source((transit_sdk_resource){46,7},i,true); transit_station_unified_bundle *b=bundle(&d,true,false,false); transit_sdk_bytes encoded={0}; checked(transit_station_unified_bundle_bytes(b,&encoded));
        char name[32]; snprintf(name,sizeof(name),"bundle%d.bin",i); transit_sdk_bytes expected=fixture(root,name); equal(encoded,expected); free((void *)expected.data); transit_station_unified_bundle_destroy(b);
        b=bundle(&d,true,true,false); checked(transit_station_unified_bundle_bytes(b,&encoded)); snprintf(name,sizeof(name),"named-bundle%d.bin",i); expected=fixture(root,name); equal(encoded,expected); free((void *)expected.data); transit_station_unified_bundle_destroy(b);
        const uint8_t projection[]={1};transit_station_unified_plan counted={0};counted.projection=projection;counted.projection_count=1;counted.aggregate=TRANSIT_AGGREGATE_COUNT_VALUES;counted.output_names[0]="present";
        b=NULL;checked(transit_station_unified_prepare_bundle(&d.source,&counted,(transit_station_unified_budgets){1000,500,1048576},NULL,&b));checked(transit_station_unified_bundle_bytes(b,&encoded));snprintf(name,sizeof(name),"counted-bundle%d.bin",i);expected=fixture(root,name);equal(encoded,expected);free((void*)expected.data);transit_station_unified_bundle_destroy(b);
    }
    boolean_codecs(root);
    const char *names[]={"int64","uint64","float64","boolean","utf8","binary"}; transit_station_unified_column columns[6];
    const transit_logical_kind kinds[]={TRANSIT_LOGICAL_INT64,TRANSIT_LOGICAL_UINT64,TRANSIT_LOGICAL_FLOAT64,TRANSIT_LOGICAL_BOOLEAN,TRANSIT_LOGICAL_UTF8,TRANSIT_LOGICAL_BINARY};transit_logical_type_view types[6]={{0}};
    for(size_t i=0;i<6;++i){types[i].kind=kinds[i];columns[i]=(transit_station_unified_column){names[i],&types[i],true,true};}
    transit_sdk_bytes ipc=fixture(root,"arrow.ipc"); transit_station_unified_rows *rows=NULL;
    checked(transit_station_unified_decode_arrow(columns,6,ipc,5,NULL,&rows)); memset((void *)ipc.data,0,ipc.size); free((void *)ipc.data);
    for(size_t row=0;row<5;++row) for(size_t col=0;col<6;++col) {
        transit_logical_cell_view cell={0}; checked(transit_station_unified_rows_cell(rows,row,col,&cell)); assert(cell.state==row);
        if(row==2)assert(cell.as.type_error==TRANSIT_LOGICAL_MAP);
        if(row==3)scalar(cell.as.value.as.atom,col);
        if(row==4){assert(cell.as.conflict.size==2);for(size_t i=0;i<2;++i){const transit_logical_alternative *alt=&cell.as.conflict.data[i];assert(alt->counter==UINT64_MAX&&alt->replica==i+1);assert(alt->value.state==(i?TRANSIT_LOGICAL_NULL:TRANSIT_LOGICAL_VALUE));if(!i)scalar(alt->value.as.value.as.atom,col);}}
    }
    transit_station_unified_rows_destroy(rows); rows=NULL;
    ipc=fixture(root,"empty.ipc"); checked(transit_station_unified_decode_arrow(columns,6,ipc,0,NULL,&rows)); free((void *)ipc.data); transit_logical_cell_view missing={0}; assert(transit_station_unified_rows_cell(rows,0,0,&missing).kind!=TRANSIT_SDK_OK); transit_station_unified_rows_destroy(rows); rows=NULL;
    ipc=fixture(root,"malformed.ipc"); assert(transit_station_unified_decode_arrow(columns,6,ipc,5,NULL,&rows).kind!=TRANSIT_SDK_OK && !rows); free((void *)ipc.data);
    definition wide=source((transit_sdk_resource){1,7},1,true);bind_source(&wide);
    transit_logical_type_view u128={.kind=TRANSIT_LOGICAL_UINT128};transit_station_catalog_column wide_columns[128]={{0}};char wide_names[128][24],aliases[128][24];uint8_t projection[128];
    transit_station_unified_plan plan={0};plan.projection=projection;plan.projection_count=128;plan.predicate=TRANSIT_UNIFIED_COMPARE;plan.column=127;plan.value.kind=TRANSIT_ATOM_UNSIGNED;plan.value.as.unsigned_value=(transit_logical_u128){UINT64_MAX,UINT64_MAX};
    for(size_t i=0;i<128;++i){snprintf(wide_names[i],24,"列 %zu",i);snprintf(aliases[i],24,"結果 %zu",i);wide_columns[i]=(transit_station_catalog_column){i+1,wide_names[i],&u128,true,NULL,0};projection[i]=(uint8_t)i;plan.output_names[i]=aliases[i];}
    wide.schema.columns=wide_columns;wide.schema.column_count=128;wide.schema.next_column=129;transit_station_unified_bundle *wide_bundle=NULL;checked(transit_station_unified_prepare_bundle(&wide.source,&plan,(transit_station_unified_budgets){1,1,65536},NULL,&wide_bundle));transit_sdk_bytes wide_bytes={0};checked(transit_station_unified_bundle_bytes(wide_bundle,&wide_bytes));assert(wide_bytes.size&&wide_bytes.size<=25069);transit_station_unified_bundle_destroy(wide_bundle);
    transit_logical_type_view nested_type={.kind=TRANSIT_LOGICAL_LIST};nested_type.as.list=(transit_logical_element){&u128,true};transit_station_unified_column nested={"value",&nested_type,false,false};
    ipc=fixture(root,"nested.ipc");rows=NULL;checked(transit_station_unified_decode_arrow(&nested,1,ipc,1,NULL,&rows));memset((void*)ipc.data,0,ipc.size);free((void*)ipc.data);transit_logical_cell_view nested_cell={0};checked(transit_station_unified_rows_cell(rows,0,0,&nested_cell));assert(nested_cell.state==TRANSIT_LOGICAL_VALUE&&nested_cell.as.value.kind==TRANSIT_VALUE_LIST&&nested_cell.as.value.as.cells.size==2);const transit_logical_cell_view *children=nested_cell.as.value.as.cells.data;assert(children[1].state==TRANSIT_LOGICAL_NULL);const transit_logical_atom atom=children[0].as.value.as.atom;assert(atom.kind==TRANSIT_ATOM_UNSIGNED&&atom.as.unsigned_value.low==UINT64_MAX&&atom.as.unsigned_value.high==UINT64_MAX);transit_station_unified_rows_destroy(rows);
    puts("C installed unified codecs: three sources, nine Boolean bundles, six types, five states, owned rows, 128 columns, uint128, nested values and malformed rejection passed");
}
static void serve(char **args) {
    const uint64_t realm=strtoull(args[6],NULL,10),principal=strtoull(args[7],NULL,10);
    transit_station_unified_connection connection={{realm,strtoull(args[8],NULL,10)},{realm,strtoull(args[10],NULL,10)},{realm,strtoull(args[9],NULL,10)},{realm,strtoull(args[11],NULL,10)}};
    const int kind=!strcmp(args[4],"kv")?0:!strcmp(args[4],"table")?1:2;
    transit_sdk_config config=transit_sdk_growing_config(args[2]);config.timeout_ms=10000;transit_sdk_credential credential={realm,principal,args[3]};
    definition d=source(connection.resource,kind,false);transit_station_catalog_definition *catalog_definition=NULL;
    if(kind==1){transit_station_catalog_client *catalog=NULL;checked(transit_station_catalog_open(&config,&credential,(transit_station_catalog_connection){connection.source,{connection.resource,1}},&catalog));checked(transit_station_catalog_lookup(catalog,"items",&catalog_definition));assert(catalog_definition);const transit_station_catalog_definition_view *view=NULL;checked(transit_station_catalog_definition_get(catalog_definition,&view));d.source.source.table.owner=connection.source;d.source.source.table.metadata=&view->metadata;d.source.source.table.schema=&view->schema;checked(transit_station_catalog_close(catalog));transit_station_catalog_client_destroy(catalog);}
    transit_station_unified_bundle *b=bundle(&d,false,true,!strcmp(args[12],"compound"));transit_sdk_bytes data={0};checked(transit_station_unified_bundle_bytes(b,&data));transit_sdk_bytes expected=file_bytes(args[5]);equal(data,expected);free((void*)expected.data);transit_station_unified_bundle_destroy(b);
    transit_station_unified_client *client=NULL;checked(transit_station_unified_open(&config,&credential,connection,&client));
    transit_station_unified_description description={0}; checked(transit_station_unified_describe(client,&d.source,&description)); assert(description.bundle_bytes==25069&&description.batch_rows==8);
    puts("{\"ready\":true}"); char line[140000]; transit_station_unified_page *saved=NULL;
    while(fgets(line,sizeof(line),stdin)) {
        char *command=strtok(line," \n"),*arg=strtok(NULL," \n"),*token=strtok(NULL," \n"); assert(command);
        if(!strcmp(command,"close"))break;
        transit_sdk_error error={0};
        if(!strcmp(command,"compile")) {
            transit_sdk_bytes sql=unhex(token); ((char *)sql.data)[sql.size]='\0';
            transit_station_unified_budgets budgets={0}; budgets.pages=strtoull(strtok(NULL," \n"),NULL,10);budgets.segments=strtoull(strtok(NULL," \n"),NULL,10);budgets.result_bytes=strtoull(strtok(NULL," \n"),NULL,10);
            long count=strtol(strtok(NULL," \n"),NULL,10);assert(count>=-1&&count<=65);
            transit_station_unified_scalar values[65]={{0}};
            for(long i=0;i<count;++i){
                char *type=strtok(NULL," \n"),*payload=strchr(type,':');assert(payload);*payload++='\0';
                if(!strcmp(type,"signed")){int64_t n=strtoll(payload,NULL,10);values[i].kind=TRANSIT_ATOM_SIGNED;values[i].as.signed_value=(transit_logical_i128){(uint64_t)n,n<0?-1:0};}
                else if(!strcmp(type,"unsigned")){values[i].kind=TRANSIT_ATOM_UNSIGNED;values[i].as.unsigned_value=(transit_logical_u128){strtoull(payload,NULL,10),0};}
                else if(!strcmp(type,"boolean")){values[i].kind=TRANSIT_ATOM_BOOLEAN;values[i].as.boolean=!strcmp(payload,"true");}
                else if(!strcmp(type,"float64_bits")){transit_sdk_bytes bits=unhex(payload);assert(bits.size==8);uint64_t raw=0;for(size_t j=0;j<8;++j)raw|=(uint64_t)bits.data[j]<<(8*j);values[i].kind=TRANSIT_ATOM_FLOAT64;memcpy(&values[i].as.float64,&raw,8);free((void*)bits.data);}
                else{assert(!strcmp(type,"utf8")||!strcmp(type,"binary"));values[i].kind=!strcmp(type,"utf8")?TRANSIT_ATOM_UTF8:TRANSIT_ATOM_BINARY;values[i].as.bytes=unhex(payload);}
            }
            transit_station_unified_bindings parameters={values,count<0?0:(size_t)count};transit_station_unified_bundle *compiled=NULL;
            error=transit_station_unified_compile_sql(client,&d.source,arg,(const char *)sql.data,budgets,count<0?NULL:&parameters,&compiled);
            free((void *)sql.data);for(long i=0;i<count;++i)if(values[i].kind==TRANSIT_ATOM_UTF8||values[i].kind==TRANSIT_ATOM_BINARY)free((void *)values[i].as.bytes.data);
            if(!error.kind){checked(transit_station_unified_bundle_bytes(compiled,&data));printf("{\"status\":0,\"value\":{\"compiled\":{\"bundle\":\"");print_hex(data);puts("\"}}}");}else assert(!compiled);
            transit_station_unified_bundle_destroy(compiled);
        } else if(!strcmp(command,"inspect")) {
            transit_sdk_bytes sql=unhex(token); ((char *)sql.data)[sql.size]='\0';
            transit_station_unified_budgets budgets={0}; budgets.pages=strtoull(strtok(NULL," \n"),NULL,10);budgets.segments=strtoull(strtok(NULL," \n"),NULL,10);budgets.result_bytes=strtoull(strtok(NULL," \n"),NULL,10);
            transit_station_unified_inspection *out=NULL;error=transit_station_unified_inspect_sql(client,&d.source,arg,(const char*)sql.data,budgets,&out);free((void*)sql.data);
            if(!error.kind){const transit_station_unified_inspection_info *view=NULL;checked(transit_station_unified_inspection_get(out,&view));assert(view->resource.resource==connection.resource.resource&&view->source_kind==(transit_station_unified_source_kind)kind);printf("{\"status\":0,\"value\":");print_inspection(view);puts("}");}else assert(!out);
            transit_station_unified_inspection_destroy(out);
        } else if(!strcmp(command,"next")) {
            transit_sdk_bytes input=unhex(token); transit_station_unified_bundle *v=NULL; checked(transit_station_unified_bundle_import(input,&v)); free((void *)input.data); transit_station_unified_prepared *out=NULL;
            error=transit_station_unified_prepare_next(client,strtoull(arg,NULL,10),v,&out); transit_station_unified_bundle_destroy(v);
            if(!error.kind) { printf("{\"status\":0,\"value\":{\"prepared_hex\":"); if(out) { checked(transit_station_unified_prepared_bytes(out,&data)); putchar('"'); print_hex(data); putchar('"'); }else printf("null"); puts("}}"); }
            transit_station_unified_prepared_destroy(out);
        } else if(!strcmp(command,"submit")) {
            transit_sdk_bytes input=unhex(arg); transit_station_unified_prepared *v=NULL; checked(transit_station_unified_prepared_import(input,&v)); uint64_t position=0; error=transit_station_unified_submit(client,v,&position); checked(transit_station_unified_prepared_bytes(v,&data)); equal(input,data); free((void *)input.data); transit_station_unified_prepared_destroy(v);
            if(!error.kind)printf("{\"status\":0,\"value\":{\"receipt\":{\"position\":%llu}}}\n",(unsigned long long)position);
        } else if(!strcmp(command,"observe")) {
            transit_station_unified_observation v={0}; error=transit_station_unified_observe(client,strtoull(arg,NULL,10),&v);
            if(!error.kind) { const char *names[]={"pending","committed","rejected"}; printf("{\"status\":0,\"value\":{\"observation\":{\"%s\":",names[v.state]); if(v.state==TRANSIT_UNIFIED_REJECTED) { putchar('"'); print_hex(bytes(v.reason)); putchar('"'); }else printf("{}"); puts("}}}"); }
        } else if(!strcmp(command,"status")) {
            transit_station_unified_status v={0}; error=transit_station_unified_status_read(client,strtoull(arg,NULL,10),&v);
            if(!error.kind) { const char *phases[]={"uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"}; printf("{\"status\":0,\"value\":{\"status\":"); if(v.found){printf("{\"phase\":\"%s\",\"correlation\":\"%llu\",\"failure\":",phases[v.phase],(unsigned long long)v.correlation);if(v.has_failure)printf("{\"code\":\"%s\",\"stage\":\"%s\",\"dimension\":\"%s\",\"limit\":\"%llu\",\"observed\":\"%llu\"}",v.failure.code,v.failure.stage,v.failure.dimension,(unsigned long long)v.failure.limit,(unsigned long long)v.failure.observed);else printf("null");printf(",\"diagnostic\":%s}",v.diagnostic.size?v.diagnostic.json:"null");}else printf("null"); puts("}}"); }
        } else {
            assert(!strcmp(command,"page")); transit_station_unified_cursor *cursor=NULL; transit_sdk_bytes input=unhex(token); if(input.size)checked(transit_station_unified_cursor_import(input,&cursor)); free((void *)input.data);
            transit_station_unified_page *out=NULL; error=transit_station_unified_page_read(client,strtoull(arg,NULL,10),cursor,&out); transit_station_unified_cursor_destroy(cursor);
            if(!error.kind) {
                transit_station_unified_page_info info={0}; checked(transit_station_unified_page_get(out,&info)); assert(info.manifest.source_kind==(transit_station_unified_source_kind)kind && info.manifest.resource.resource==connection.resource.resource);
                transit_station_unified_rows *rows=NULL; checked(transit_station_unified_decode_arrow(info.columns,info.column_count,info.ipc,info.rows,NULL,&rows)); transit_station_unified_rows_destroy(rows);
                printf("{\"status\":0,\"value\":{\"page\":{\"ordinal\":\"%llu\",\"ipc\":\"",(unsigned long long)info.ordinal); print_hex(info.ipc); printf("\",\"manifest\":{\"segments\":\"%llu\",\"selected\":\"%llu\",\"value_count\":\"%llu\"},\"next_hex\":",(unsigned long long)info.manifest.segments,(unsigned long long)info.manifest.selected,(unsigned long long)info.manifest.value_count);
                checked(transit_station_unified_page_next(out,&cursor)); if(cursor) { checked(transit_station_unified_cursor_bytes(cursor,&data)); putchar('"'); print_hex(data); putchar('"'); }else printf("null"); puts("}}}"); transit_station_unified_cursor_destroy(cursor); transit_station_unified_page_destroy(saved); saved=out;
            }
        }
        if(error.kind) { assert(error.has_native_status); printf("{\"status\":%u,\"value\":{\"err\":\"%s\",\"diagnostic\":%s,\"diagnostic_invalid\":%s}}\n",error.native_status,error.code,error.diagnostic.size?error.diagnostic.json:"null",error.diagnostic_invalid?"true":"false"); }
        fflush(stdout);
    }
    checked(transit_station_unified_close(client)); assert(transit_station_unified_describe(client,&d.source,&description).kind==TRANSIT_SDK_CLOSED); transit_station_unified_client_destroy(client);
    if(saved) { transit_station_unified_page_info info={0}; checked(transit_station_unified_page_get(saved,&info)); transit_station_unified_rows *rows=NULL; checked(transit_station_unified_decode_arrow(info.columns,info.column_count,info.ipc,info.rows,NULL,&rows)); transit_station_unified_page_destroy(saved); if(info.rows) { transit_logical_cell_view cell={0}; checked(transit_station_unified_rows_cell(rows,0,0,&cell)); assert(cell.state==TRANSIT_UNIFIED_VALUE); } transit_station_unified_rows_destroy(rows); }
    transit_station_catalog_definition_destroy(catalog_definition);
    puts("{\"closed\":true}");
}
int main(int argc,char **argv) { setvbuf(stdout,NULL,_IOLBF,0); assert(argc>=3); if(!strcmp(argv[1],"codecs"))codecs(argv[2]);else { assert(argc==13); serve(argv); } return 0; }
