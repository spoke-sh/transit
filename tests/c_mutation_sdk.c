/* Installed C11 consumer, exclusively through typed public SDK operations. */
#include <transit/table_mutation.h>
#include "mutation_sdk_io.h"
static transit_station_table_mutation_reference reference(const char *text) {
    transit_sdk_bytes bytes=unhex(text);assert(bytes.size==68);transit_station_table_mutation_reference out;
    memcpy(out.bytes,bytes.data,68);free((void *)bytes.data);return out;
}
int main(int argc,char **argv) {
    assert(argc==8);setvbuf(stdout,NULL,_IOLBF,0);
    uint64_t realm=strtoull(argv[3],NULL,10);
    transit_station_table_mutation_connection connection={{realm,strtoull(argv[5],NULL,10)},{realm,strtoull(argv[6],NULL,10)},(uint32_t)strtoul(argv[7],NULL,10)};
    transit_sdk_config config=transit_sdk_growing_config(argv[1]);config.timeout_ms=10000;
    transit_sdk_credential credential={realm,strtoull(argv[4],NULL,10),argv[2]};
    transit_station_table_mutation_client *client=NULL;checked(transit_station_table_mutation_open(&config,&credential,connection,&client));
    transit_station_table_mutation_prepared *retained=NULL;transit_sdk_bytes retained_bytes={0};
    puts("{\"ready\":true}");
    while(read_command() && strcmp(command,"close")) {
        transit_sdk_error error={0};
        if(!strcmp(command,"capabilities"))puts("{\"status\":0,\"value\":{\"capabilities\":{\"max_rows\":3}}}");
        else if(!strcmp(command,"describe")) {
            transit_station_table_mutation_description out;memset(&out,0xa5,sizeof(out));error=transit_station_table_mutation_describe(client,&out);
            if(!error.kind)printf("{\"status\":0,\"value\":{\"description\":{\"resource\":%llu}}}\n",(unsigned long long)out.resource.resource);
            else assert(out.table==0 && out.resource.resource==0);
        } else if(!strcmp(command,"compile")) {
            transit_sdk_bytes name=unhex(first),sql=unhex(second);transit_station_table_mutation_compiled *out=NULL;
            error=transit_station_table_mutation_compile_sql(client,(const char *)name.data,(const char *)sql.data,strtoull(third,NULL,10),&out);free((void *)name.data);free((void *)sql.data);
            if(!error.kind){transit_sdk_bytes request;transit_station_table_mutation_reference ref;checked(transit_station_table_mutation_compiled_get(out,&request,&ref));printf("{\"status\":0,\"value\":{\"compiled\":{\"request\":\"");print_hex(request);printf("\",\"reference\":\"");print_hex((transit_sdk_bytes){ref.bytes,68});puts("\"}}}");}
            transit_station_table_mutation_compiled_destroy(out);
        } else if(!strcmp(command,"next")) {
            transit_sdk_bytes request=unhex(first);transit_station_table_mutation_compiled *compiled=NULL;
            checked(transit_station_table_mutation_compiled_import(request,reference(second),&compiled));
            memset((void *)request.data,0,request.size);free((void *)request.data);
            transit_sdk_bytes copy;transit_station_table_mutation_reference ref;checked(transit_station_table_mutation_compiled_get(compiled,&copy,&ref));request=unhex(first);equal(request,copy);free((void *)request.data);
            transit_station_table_mutation_prepared *out=NULL;error=transit_station_table_mutation_prepare_next(client,compiled,&out);transit_station_table_mutation_compiled_destroy(compiled);
            if(!error.kind){transit_sdk_bytes data={0};if(out)checked(transit_station_table_mutation_prepared_bytes(out,&data));emit_prepared(data,out!=NULL);}else assert(!out);
            transit_station_table_mutation_prepared_destroy(out);
        } else if(!strcmp(command,"prepare")) {
            transit_station_table_mutation_prepared *out=NULL;assert(!strcmp(first,"apply")||!strcmp(first,"cancel"));
            error=transit_station_table_mutation_prepare_control(client,!strcmp(first,"apply")?TRANSIT_TABLE_MUTATION_APPLY:TRANSIT_TABLE_MUTATION_CANCEL,reference(second),&out);
            if(!error.kind){transit_sdk_bytes data={0};checked(transit_station_table_mutation_prepared_bytes(out,&data));emit_prepared(data,1);}transit_station_table_mutation_prepared_destroy(out);
        } else if(!strcmp(command,"submit")||!strcmp(command,"observe")||!strcmp(command,"rejection")) {
            transit_sdk_bytes saved=unhex(first);transit_station_table_mutation_prepared *prepared=NULL;checked(transit_station_table_mutation_prepared_import(saved,&prepared));
            memset((void *)saved.data,0,saved.size);free((void *)saved.data);saved=unhex(first);
            if(!strcmp(command,"submit")) {
                uint64_t position=999;error=transit_station_table_mutation_submit(client,prepared,&position);
                if(!error.kind)printf("{\"status\":0,\"value\":{\"receipt\":{\"position\":%llu}}}\n",(unsigned long long)position);else assert(position==0);
            } else if(!strcmp(command,"observe")) {
                transit_station_table_mutation_observation out;error=transit_station_table_mutation_observe(client,prepared,strtoull(second,NULL,10),&out);
                if(!error.kind)printf("{\"status\":0,\"value\":{\"observation\":\"%s\"}}\n",out==TRANSIT_TABLE_INPUT_PENDING?"pending":"processed");
            } else {
                bool found;transit_station_table_mutation_rejection out;error=transit_station_table_mutation_input_rejection(client,prepared,strtoull(second,NULL,10),&found,&out);
                const char *names[]={"invalid_command","denied","identity_conflict","busy","not_found","not_active","upload_closed","not_sealed","invalid_part","incomplete_upload","source_changed","stale_policy"};
                if(!error.kind){printf("{\"status\":0,\"value\":{\"rejection\":");if(found)printf("\"%s\"",names[out]);else printf("null");puts("}}");}
            }
            transit_sdk_bytes current;checked(transit_station_table_mutation_prepared_bytes(prepared,&current));equal(saved,current);
            transit_station_table_mutation_prepared_destroy(retained);free((void *)retained_bytes.data);retained=prepared;retained_bytes=saved;
        } else {
            assert(!strcmp(command,"status"));transit_station_table_mutation_status out;memset(&out,0xa5,sizeof(out));
            error=transit_station_table_mutation_status_read(client,reference(first),&out);
            if(!error.kind){const char *phases[]={"uploading","sealed","applied","rejected","cancelled"};const char *reasons[]={"none","row_exists","source_changed","invalid_request","denied","budget"};printf("{\"status\":0,\"value\":{\"status\":");if(out.found){printf("{\"reference\":\"");print_hex((transit_sdk_bytes){out.reference.bytes,68});printf("\",\"phase\":\"%s\",\"affected_rows\":%u,\"reason\":\"%s\",\"input\":%llu}",phases[out.phase],out.affected_rows,reasons[out.reason],(unsigned long long)out.input);}else printf("null");puts("}}");}
            else assert(!out.found && out.table==0 && out.reference.bytes[0]==0);
        }
        if(error.kind)emit_error(error);
    }
    checked(transit_station_table_mutation_close(client));transit_station_table_mutation_description closed;
    assert(transit_station_table_mutation_describe(client,&closed).kind==TRANSIT_SDK_CLOSED);transit_station_table_mutation_client_destroy(client);
    if(retained){transit_sdk_bytes data;checked(transit_station_table_mutation_prepared_bytes(retained,&data));equal(data,retained_bytes);transit_station_table_mutation_prepared_destroy(retained);free((void *)retained_bytes.data);}
    puts("{\"closed\":true}");return 0;
}
