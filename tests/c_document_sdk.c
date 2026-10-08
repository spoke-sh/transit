#include "c_document_sdk.h"
#include <assert.h>
#include <string.h>
#define TRY(expression) do { transit_sdk_error error=(expression); if(error.kind!=TRANSIT_SDK_OK) return error; } while(0)
transit_sdk_error document_test_bootstrap(transit_station_document_prepared **out) {
    transit_station_document_change change={0};
    change.document=UINT64_MAX; change.epoch=1; change.type_revision=1; change.replica=UINT64_MAX; change.first=1; change.operation_count=3;
    change.operations[0].kind=TRANSIT_DOCUMENT_ASSIGN; memcpy(change.operations[0].field,"value",5); change.operations[0].field_size=5;
    change.operations[0].value.kind=TRANSIT_DOCUMENT_SIGNED; change.operations[0].value.signed_value=INT64_MIN;
    change.operations[1].kind=TRANSIT_DOCUMENT_ASSIGN; memcpy(change.operations[1].field,"body",4); change.operations[1].field_size=4; change.operations[1].value.kind=TRANSIT_DOCUMENT_TEXT;
    change.operations[2].kind=TRANSIT_DOCUMENT_INSERT; change.operations[2].object=(transit_station_document_dot){2,UINT64_MAX};
    change.operations[2].value.kind=TRANSIT_DOCUMENT_CHARACTER; memcpy(change.operations[2].value.bytes,"🙂",4); change.operations[2].value.size=4;
    return transit_station_document_prepare(&change,NULL,out);
}
typedef struct message { uint8_t bytes[243]; size_t size; } message;
static transit_sdk_error encode(void *ctx,const void *value,uint8_t *out,size_t capacity,size_t *written) {
    (void)ctx; const message *v=value; assert(v->size<=capacity); memcpy(out,v->bytes,v->size); *written=v->size; return (transit_sdk_error){0};
}
static transit_sdk_error decode(void *ctx,transit_sdk_bytes value,void *out) {
    (void)ctx; message *v=out; assert(value.size<=243); memset(v,0,sizeof(*v)); memcpy(v->bytes,value.data,value.size); v->size=value.size; return (transit_sdk_error){0};
}
transit_station_codec document_test_codec(void) { return (transit_station_codec){"test.document-control",1,243,sizeof(message),NULL,encode,decode,NULL}; }
static transit_sdk_error initialize(void *ctx,transit_station_turn *turn) {
    (void)ctx; return transit_station_turn_document_create(turn,UINT64_MAX,1,(transit_station_document_limits){4096,8192,2});
}
static bool is(const message *v,const char *text) { return v->size==strlen(text) && !memcmp(v->bytes,text,v->size); }
static transit_sdk_error handle(void *ctx,transit_station_turn *turn,const transit_station_incoming *input) {
    document_test_context *owner=ctx; const message *v=input->value; assert(input->kind==TRANSIT_INPUT_CAST);
    transit_station_turn_release(owner->escaped); owner->escaped=turn; transit_station_turn_retain(turn); owner->phase=-1;
    transit_station_document_progress progress={0};
    if(is(v,"initialize")) return (transit_sdk_error){0};
    if(is(v,"window")) return transit_station_turn_document_merge_window(turn,UINT64_MAX,2);
    if(is(v,"retire")) return transit_station_turn_document_retire(turn,UINT64_MAX);
    if(is(v,"checkpoint")) { TRY(transit_station_turn_document_checkpoint(turn,UINT64_MAX,90,&progress)); }
    else { assert(is(v,"0") || is(v,"1")); const size_t index=v->bytes[0]-'0'; TRY(transit_station_turn_document_stage(turn,UINT64_MAX,index+1,owner->changes[index],256,&progress)); }
    owner->phase=(int)progress.phase; return (transit_sdk_error){0};
}
transit_station_handler document_test_handler(document_test_context *ctx) { return (transit_station_handler){ctx,initialize,handle,NULL,NULL,NULL}; }
