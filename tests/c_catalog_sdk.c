/* Installed C11 catalog caller: no generated ABI or private helper imports. */
#include "catalog_sdk_io.h"
static void values(void){
    transit_station_catalog_prepared *prepared=(transit_station_catalog_prepared *)(uintptr_t)1;
    assert(transit_station_catalog_prepared_import((transit_sdk_bytes){NULL,0},&prepared).kind==TRANSIT_SDK_INVALID_ARGUMENT && !prepared);
    uint8_t bytes[8193]={1};
    assert(transit_station_catalog_prepared_import((transit_sdk_bytes){bytes,sizeof(bytes)},&prepared).kind==TRANSIT_SDK_INVALID_ARGUMENT && !prepared);
    checked(transit_station_catalog_prepared_import((transit_sdk_bytes){bytes,1},&prepared));bytes[0]=2;
    transit_sdk_bytes saved;checked(transit_station_catalog_prepared_bytes(prepared,&saved));assert(saved.size==1 && saved.data[0]==1);transit_station_catalog_prepared_destroy(prepared);
    transit_station_catalog_create_table request={.scope={{1,7},UINT64_MAX},.operation=UINT64_MAX,.object=UINT64_MAX,.table=UINT32_MAX,.name="items",.schema={{"id","value"},TRANSIT_CELL_UTF8}};
    transit_station_catalog_compiled *compiled=NULL;checked(transit_station_catalog_compiled_import(&request,(transit_sdk_bytes){bytes,1},&compiled));
    bytes[0]=3;request.object=1;transit_station_catalog_create_table copy;checked(transit_station_catalog_compiled_get(compiled,&copy,&saved));assert(copy.object==UINT64_MAX && saved.data[0]==2);transit_station_catalog_compiled_destroy(compiled);
    memset(request.name,'x',sizeof(request.name));assert(transit_station_catalog_compiled_import(&request,(transit_sdk_bytes){bytes,1},&compiled).kind==TRANSIT_SDK_INVALID_ARGUMENT && !compiled);
    strcpy(request.name,"items");request.schema.value_type=TRANSIT_CELL_NULL;assert(transit_station_catalog_compiled_import(&request,(transit_sdk_bytes){bytes,1},&compiled).kind==TRANSIT_SDK_INVALID_ARGUMENT && !compiled);
}
int main(int argc,char **argv){
    assert(argc==8);setvbuf(stdout,NULL,_IOLBF,0);values();
    uint64_t realm=number(argv[3]);transit_station_catalog_connection connection={{realm,number(argv[5])},{{realm,number(argv[6])},number(argv[7])}};
    transit_sdk_config config=transit_sdk_growing_config(argv[1]);config.timeout_ms=10000;
    transit_sdk_credential credential={realm,number(argv[4]),argv[2]};transit_station_catalog_client *client=NULL;
    checked(transit_station_catalog_open(&config,&credential,connection,&client));
    transit_station_catalog_prepared *retained=NULL;transit_sdk_bytes retained_bytes={0};
    transit_station_catalog_compiled *compiled=NULL;
    puts("{\"ready\":true}");
    while(read_command() && strcmp(args[0],"close")){
        const char *command=args[0];transit_sdk_error error={0};
        if(!strcmp(command,"capabilities")){transit_station_catalog_capabilities out;error=transit_station_catalog_capabilities_read(client,&out);if(!error.kind)emit_capabilities(&out);}
        else if(!strcmp(command,"describe")){transit_station_catalog_description out;memset(&out,0xa5,sizeof(out));error=transit_station_catalog_describe(client,&out);if(!error.kind)emit_description(&out);else assert(!out.configuration.owner.pid && !out.resource_revision);}
        else if(!strcmp(command,"compile")){
            transit_sdk_bytes sql=unhex(args[1]);transit_station_catalog_compiled *out=NULL;
            error=transit_station_catalog_compile_sql(client,(const char *)sql.data,number(args[2]),number(args[3]),(uint32_t)number(args[4]),&out);free((void *)sql.data);
            if(!error.kind){transit_station_catalog_create_table r;transit_sdk_bytes canonical;checked(transit_station_catalog_compiled_get(out,&r,&canonical));
                printf("{\"status\":0,\"value\":{\"compiled\":{\"request\":");emit_request(&r);printf(",\"canonical\":\"");print_hex(canonical);puts("\"}}}");
                transit_station_catalog_compiled_destroy(compiled);checked(transit_station_catalog_compiled_import(&r,canonical,&compiled));memset(&r,0,sizeof(r));
            }else assert(!out);transit_station_catalog_compiled_destroy(out);
        }else if(!strcmp(command,"initialize") || !strcmp(command,"create") || !strcmp(command,"policy")){
            transit_station_catalog_prepared *out=NULL;
            if(!strcmp(command,"initialize")){transit_station_catalog_configuration v={scope(1),{number(args[1]),number(args[4])},number(args[5])};error=transit_station_catalog_prepare_initialize(client,&v,&out);}
            else if(!strcmp(command,"create")){transit_station_catalog_create_table v=request();error=transit_station_catalog_prepare_create(client,&v,&out);}
            else {transit_station_catalog_policy_change v={number(args[8]),{scope(1),number(args[4]),number(args[5]),number(args[6])!=0,number(args[7])!=0}};error=transit_station_catalog_prepare_policy(client,&v,&out);}
            if(!error.kind){transit_sdk_bytes data;checked(transit_station_catalog_prepared_bytes(out,&data));emit_prepared(data);}else assert(!out);transit_station_catalog_prepared_destroy(out);
        }else if(!strcmp(command,"status")){
            transit_station_catalog_create_table v=request();transit_station_catalog_receipt out;memset(&out,0xa5,sizeof(out));error=transit_station_catalog_status_read(client,&v,&out);
            if(!error.kind)emit_status(&out);else assert(!out.found && !out.input && !out.request.object);
        }else{
            transit_sdk_bytes saved=unhex(args[1]);transit_station_catalog_prepared *prepared=NULL;checked(transit_station_catalog_prepared_import(saved,&prepared));
            memset((void *)saved.data,0,saved.size);free((void *)saved.data);saved=unhex(args[1]);
            if(!strcmp(command,"submit")){uint64_t position=999;error=transit_station_catalog_submit(client,prepared,&position);if(!error.kind)printf("{\"status\":0,\"value\":{\"receipt\":{\"position\":%llu}}}\n",(unsigned long long)position);else assert(!position);}
            else if(!strcmp(command,"observe")){transit_station_catalog_observation out;error=transit_station_catalog_observe(client,prepared,number(args[2]),&out);if(!error.kind)printf("{\"status\":0,\"value\":{\"observation\":\"%s\"}}\n",out==TRANSIT_CATALOG_PENDING?"pending":"processed");}
            else {assert(!strcmp(command,"input_disposition"));transit_station_catalog_disposition out;memset(&out,0xa5,sizeof(out));error=transit_station_catalog_input_disposition(client,prepared,number(args[2]),&out);if(!error.kind)emit_disposition(&out);else assert(!out.found && !out.input);}
            transit_sdk_bytes current;checked(transit_station_catalog_prepared_bytes(prepared,&current));equal(saved,current);
            transit_station_catalog_prepared_destroy(retained);free((void *)retained_bytes.data);retained=prepared;retained_bytes=saved;
        }
        if(error.kind)emit_error(error);
    }
    checked(transit_station_catalog_close(client));transit_station_catalog_description closed;
    assert(transit_station_catalog_describe(client,&closed).kind==TRANSIT_SDK_CLOSED);transit_station_catalog_client_destroy(client);
    if(retained){transit_sdk_bytes bytes;checked(transit_station_catalog_prepared_bytes(retained,&bytes));equal(bytes,retained_bytes);transit_station_catalog_prepared_destroy(retained);free((void *)retained_bytes.data);}
    if(compiled){transit_station_catalog_create_table r;transit_sdk_bytes bytes;checked(transit_station_catalog_compiled_get(compiled,&r,&bytes));assert(r.object && bytes.size);transit_station_catalog_compiled_destroy(compiled);}
    puts("{\"closed\":true}");return 0;
}
