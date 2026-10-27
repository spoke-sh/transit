/* Installed C11 caller; direct Table ownership is separate from query progress. */
#include <transit/unified_query.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void checked(transit_sdk_error e) { if(e.kind){fprintf(stderr,"C capture error: %d %s %s\n",e.kind,e.phase,e.code);abort();} }
static uint64_t number(const char *s) { return strtoull(s,NULL,10); }
int main(int argc,char **args) {
    assert(argc==19);bool prepare=!strcmp(args[1],"prepare");uint64_t realm=number(args[5]);
    transit_sdk_config config=transit_sdk_growing_config(args[2]);config.timeout_ms=10000;
    transit_sdk_credential credential={realm,number(args[6]),args[3]};
    transit_station_unified_connection connection={{realm,number(args[7])},{realm,number(args[9])},{realm,number(args[8])},{realm,number(args[10])},false,0};
    transit_station_unified_tables tables={args[2],{{realm,number(args[11])},number(args[12])},number(args[14]),number(args[13])};
    assert(tables.scope.resource.resource!=connection.resource.resource);
    FILE *file=fopen(args[4],"rb");assert(file);uint8_t bytes[25613];size_t size=fread(bytes,1,sizeof(bytes),file);assert(feof(file));fclose(file);
    transit_station_unified_bundle *bundle=NULL;checked(transit_station_unified_bundle_import((transit_sdk_bytes){bytes,size},&bundle));
    transit_station_unified_client *client=NULL;checked(transit_station_unified_open(&config,&credential,connection,&tables,&client));
    transit_station_unified_table_definition *definition=NULL;
    checked(transit_station_unified_lookup_table(client,1,prepare?"missing_capture_input":"captured_input",&definition));assert(!definition);
    checked(transit_station_unified_lookup_table(client,1,prepare?"captured_input":"captured_renamed",&definition));assert(definition);
    const transit_station_unified_table_definition_view *v=NULL;checked(transit_station_unified_table_definition_get(definition,&v));
    if(prepare) {
        assert(v->partition==number(args[17])&&v->next_lsn==number(args[18]));
        transit_station_unified_bundle *compiled=NULL,*sealed=NULL;
        checked(transit_station_unified_compile_sql(client,&v->source,"captured_input","SELECT COUNT(*) AS n FROM captured_input",(transit_station_unified_budgets){64,64,1048576},NULL,&compiled));
        transit_station_unified_capture capture={number(args[15]),number(args[16]),v->partition,v->next_lsn};
        checked(transit_station_unified_authorize_bundle(client,compiled,&capture,&sealed));
        transit_sdk_bytes actual={0};checked(transit_station_unified_bundle_bytes(sealed,&actual));assert(actual.size==size&&!memcmp(actual.data,bytes,size));
        transit_station_unified_bundle_destroy(sealed);transit_station_unified_bundle_destroy(compiled);
    } else {
        assert(v->source.source.table.interpretation.revision==2&&v->source.source.table.schema->revision==1);
        transit_station_unified_page *page=NULL;checked(transit_station_unified_page_read(client,1,NULL,&page));
        transit_station_unified_page_info info={0};checked(transit_station_unified_page_get(page,&info));
        transit_station_unified_cursor *cursor=NULL;checked(transit_station_unified_page_next(page,&cursor));assert(!cursor&&info.rows==1);
        assert(info.manifest.source_kind==TRANSIT_UNIFIED_TABLE&&info.manifest.source.table_worker.pid==connection.source.pid);
        assert(info.manifest.resource.resource==tables.scope.resource.resource&&info.manifest.pages==3&&info.manifest.scanned==19);
        transit_station_unified_rows *rows=NULL;checked(transit_station_unified_decode_arrow(info.columns,info.column_count,info.ipc,info.rows,NULL,&rows));
        transit_logical_cell_view cell={0};checked(transit_station_unified_rows_cell(rows,0,0,&cell));
        assert(cell.state==TRANSIT_LOGICAL_VALUE&&cell.as.value.as.atom.kind==TRANSIT_ATOM_UNSIGNED&&cell.as.value.as.atom.as.unsigned_value.low==19&&cell.as.value.as.atom.as.unsigned_value.high==0);
        transit_station_unified_rows_destroy(rows);transit_station_unified_page_destroy(page);
        transit_station_unified_prepared *cleanup=NULL;checked(transit_station_unified_prepare_cleanup(client,1,bundle,&cleanup));assert(cleanup);transit_station_unified_prepared_destroy(cleanup);
    }
    checked(transit_station_unified_close(client));transit_station_unified_client_destroy(client);
    /* Definition owns the schema even after closing and destroying the client. */
    assert(v->source.source.table.schema->column_count>0);
    transit_station_unified_table_definition_destroy(definition);transit_station_unified_bundle_destroy(bundle);
    printf("C installed direct capture %s: public API passed\n",args[1]);
    return 0;
}
