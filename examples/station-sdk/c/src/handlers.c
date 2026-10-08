#include <transit/sdk_examples.h>
#include <transit/unified_query.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>
#define TRY(expression) do { const transit_sdk_error problem = (expression); if (problem.kind != TRANSIT_SDK_OK) return problem; } while (0)
static transit_sdk_error unexpected(void) { transit_sdk_error error = {0}; error.kind = TRANSIT_SDK_HANDLER_ERROR; return error; }
transit_station_key transit_example_total_key(void) { return (transit_station_key){{(const uint8_t *)"total", 5}, transit_example_u64_codec()}; }
transit_station_key transit_example_request_key(void) { return (transit_station_key){{(const uint8_t *)"request", 7}, transit_example_u64_codec()}; }
transit_station_key transit_example_observed_key(void) { return (transit_station_key){{(const uint8_t *)"observed", 8}, transit_example_u64_codec()}; }
transit_station_key transit_example_not_ready_key(void) { return (transit_station_key){{(const uint8_t *)"not-ready", 9}, transit_example_u64_codec()}; }
transit_logical_cell_view transit_example_signed(int64_t value) {
    transit_logical_cell_view cell = {0}; cell.state = TRANSIT_LOGICAL_VALUE; cell.as.value.kind = TRANSIT_VALUE_ATOM;
    cell.as.value.as.atom.kind = TRANSIT_ATOM_SIGNED; cell.as.value.as.atom.as.signed_value = (transit_logical_i128){(uint64_t)value, value < 0 ? -1 : 0}; return cell;
}
transit_station_catalog_limits transit_example_table_limits(void) { return (transit_station_catalog_limits){65536,8388608,1024}; }
transit_station_catalog_schema transit_example_table(void) {
    static const transit_logical_type_view int64_type = {.kind=TRANSIT_LOGICAL_INT64}, utf8_type = {.kind=TRANSIT_LOGICAL_UTF8};
    static const transit_logical_type_view list_type = {.kind=TRANSIT_LOGICAL_LIST,.as.list={&int64_type,false}};
    static const transit_logical_cell_view label = {.state=TRANSIT_LOGICAL_VALUE,.as.value={.kind=TRANSIT_VALUE_ATOM,.as.atom={.kind=TRANSIT_ATOM_UTF8,.as.bytes={(const uint8_t *)"example",7}}}};
    static const transit_logical_cell_view children[] = {
        {.state=TRANSIT_LOGICAL_VALUE,.as.value={.kind=TRANSIT_VALUE_ATOM,.as.atom={.kind=TRANSIT_ATOM_SIGNED,.as.signed_value={1,0}}}},
        {.state=TRANSIT_LOGICAL_VALUE,.as.value={.kind=TRANSIT_VALUE_ATOM,.as.atom={.kind=TRANSIT_ATOM_SIGNED,.as.signed_value={2,0}}}}
    };
    static const transit_logical_cell_view tags = {.state=TRANSIT_LOGICAL_VALUE,.as.value={.kind=TRANSIT_VALUE_LIST,.as.cells={children,2}}};
    static const transit_station_catalog_column columns[] = {{1,"id",&int64_type,false,NULL,0},{2,"value",&int64_type,true,NULL,0},{3,"label",&utf8_type,false,&label,0},{4,"tags",&list_type,false,&tags,0}};
    static const uint64_t primary[] = {1}; return (transit_station_catalog_schema){1,1,5,columns,4,primary,1};
}
static transit_sdk_error required(transit_station_turn *turn, const transit_station_key *key, uint64_t *out) {
    transit_station_value *value = NULL; TRY(transit_station_state_find(turn, NULL, key, &value));
    if (!value) { transit_sdk_error error = {0}; error.kind = TRANSIT_SDK_MISSING_VALUE; return error; }
    *out = *(const uint64_t *)transit_station_value_data(value); transit_station_value_destroy(value); return (transit_sdk_error){0};
}
static transit_sdk_error initialize_counter(void *context, transit_station_turn *turn) {
    (void)context; const transit_station_key key = transit_example_total_key(); const uint64_t zero = 0; return transit_station_state_put(turn, &key, &zero);
}
static transit_sdk_error counter(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    (void)context; const transit_counter_message *message = input->value; const transit_station_key key = transit_example_total_key(); uint64_t total;
    if (input->kind == TRANSIT_INPUT_CAST && message->tag == TRANSIT_COUNTER_ADD) {
        TRY(required(turn, &key, &total)); if (UINT64_MAX - total < message->value) return unexpected(); total += message->value; return transit_station_state_put(turn, &key, &total);
    }
    if (input->kind == TRANSIT_INPUT_CALL && message->tag == TRANSIT_COUNTER_READ) {
        TRY(required(turn, &key, &total)); const transit_counter_message reply = {TRANSIT_COUNTER_TOTAL, total}; const transit_station_codec codec = transit_example_total_codec(); return transit_station_turn_reply(turn, &reply, &codec);
    }
    return unexpected();
}
static transit_sdk_error requester(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    const transit_example_peer *peer = context; const transit_counter_message *message = input->value; const transit_station_key request = transit_example_request_key();
    if (input->kind == TRANSIT_INPUT_CAST && message->tag == TRANSIT_COUNTER_START) {
        transit_station_value *saved = NULL; TRY(transit_station_state_find(turn, NULL, &request, &saved));
        if (saved) { transit_station_value_destroy(saved); return unexpected(); }
        const transit_counter_message call = {TRANSIT_COUNTER_READ, 0}; const transit_station_codec codec = transit_example_counter_codec(); uint64_t correlation;
        TRY(transit_station_turn_call(turn, peer->peer, &call, &codec, (transit_station_wait){0}, &correlation)); return transit_station_state_put(turn, &request, &correlation);
    }
    if (input->kind == TRANSIT_INPUT_REPLY && message->tag == TRANSIT_COUNTER_TOTAL) {
        uint64_t correlation; TRY(required(turn, &request, &correlation)); TRY(transit_station_turn_require_reply(turn, peer->peer, correlation));
        const transit_station_key observed = transit_example_observed_key(); return transit_station_state_put(turn, &observed, &message->value);
    }
    return unexpected();
}
static transit_station_key metadata_key(void) { return (transit_station_key){{(const uint8_t *)"table.queue",11},transit_example_table_queue_codec()}; }
static transit_station_key work_key(uint64_t id, char *buffer) {
    snprintf(buffer,28,"table.work.%016" PRIx64,id); return (transit_station_key){{(const uint8_t *)buffer,27},transit_example_table_work_codec()};
}
static transit_station_key outcome_key(uint64_t id, char *buffer) {
    snprintf(buffer,28,"table.done.%016" PRIx64,id); return (transit_station_key){{(const uint8_t *)buffer,27},transit_example_table_outcome_codec()};
}
static transit_sdk_error find_copy(transit_station_turn *turn, const transit_station_key *key, void *out, bool *found) {
    transit_station_value *value=NULL; TRY(transit_station_state_find(turn,NULL,key,&value)); *found=value!=NULL;
    if(value) { memcpy(out,transit_station_value_data(value),key->codec.object_bytes); transit_station_value_destroy(value); } return (transit_sdk_error){0};
}
static transit_sdk_error queue_read(transit_station_turn *turn, transit_example_table_queue *queue) {
    const transit_station_key key=metadata_key(); bool found; *queue=(transit_example_table_queue){0}; return find_copy(turn,&key,queue,&found);
}
static transit_sdk_error wake(transit_station_turn *turn) {
    transit_station_turn_info info; TRY(transit_station_turn_inspect(turn,&info));
    const transit_query_message message={TRANSIT_QUERY_ADVANCE,0,false,0}; const transit_station_codec codec=transit_example_query_codec();
    return transit_station_turn_cast(turn,info.process,&message,&codec);
}
static transit_sdk_error enqueue(transit_station_turn *turn,uint64_t id,transit_query_message command) {
    if(!id || id>UINT64_C(9007199254740991)) return unexpected(); transit_example_table_queue queue; TRY(queue_read(turn,&queue));
    char current_name[28],done_name[28],previous_name[28]; const transit_station_key current=work_key(id,current_name),done=outcome_key(id,done_name),metadata=metadata_key();
    transit_example_table_work work; transit_example_table_outcome outcome; bool found;
    TRY(find_copy(turn,&current,&work,&found)); if(found) return unexpected(); TRY(find_copy(turn,&done,&outcome,&found)); if(found) return unexpected();
    const bool empty=queue.head==0;
    if(queue.tail) {
        if(id<=queue.tail) return unexpected(); const transit_station_key previous=work_key(queue.tail,previous_name);
        TRY(find_copy(turn,&previous,&work,&found)); if(!found || work.next) return unexpected(); work.next=id; TRY(transit_station_state_put(turn,&previous,&work));
    } else if(!queue.ready && command.tag!=TRANSIT_QUERY_INITIALIZE) {
        const transit_station_key initial=work_key(UINT64_MAX,previous_name); work=(transit_example_table_work){id,{TRANSIT_QUERY_INITIALIZE,0,false,0}};
        TRY(transit_station_state_put(turn,&initial,&work)); queue.head=UINT64_MAX;
    } else queue.head=id;
    work=(transit_example_table_work){0,command}; TRY(transit_station_state_put(turn,&current,&work)); queue.tail=id; TRY(transit_station_state_put(turn,&metadata,&queue));
    return empty?wake(turn):(transit_sdk_error){0};
}
static transit_sdk_error table_step(transit_station_turn *turn,transit_example_table_queue queue,transit_query_message command,bool *building,transit_example_table_outcome *out) {
    const transit_station_catalog_schema schema=transit_example_table(); *out=(transit_example_table_outcome){0};
    if(command.tag==TRANSIT_QUERY_INITIALIZE) {
        const transit_station_catalog_limits limits=transit_example_table_limits(); transit_station_table_creation status;
        TRY(transit_station_table_create(turn,&schema,&limits,&status)); *building=status.state==TRANSIT_TABLE_CREATION_BUILDING;
        out->admitted=status.admitted_input; out->completed=status.completed_input; return (transit_sdk_error){0};
    }
    if(!queue.ready || queue.head==UINT64_MAX) return unexpected();
    transit_logical_cell_view key=transit_example_signed(command.key),value=command.has_value?transit_example_signed(command.value):(transit_logical_cell_view){.state=TRANSIT_LOGICAL_NULL};
    const transit_station_catalog_assignment assignments[]={{1,&key},{2,&value}};
    const transit_station_catalog_assignments row={assignments,2};
    const transit_station_catalog_predicate_term term={.kind=TRANSIT_CATALOG_COMPARE,.column=1,.as.compare={TRANSIT_CATALOG_EQ,key.as.value.as.atom}};
    const transit_station_catalog_predicate predicate={&term,1}; transit_station_table_mutation_spec spec={0};
    if(command.tag==TRANSIT_QUERY_INSERT) { spec.kind=TRANSIT_TABLE_INSERT; spec.as.insert.rows=&row; spec.as.insert.row_count=1; }
    else if(command.tag==TRANSIT_QUERY_UPDATE) { spec.kind=TRANSIT_TABLE_UPDATE; spec.as.update.assignments=(transit_station_catalog_assignments){assignments+1,1}; spec.as.update.predicate=predicate; }
    else if(command.tag==TRANSIT_QUERY_DELETE) { spec.kind=TRANSIT_TABLE_DELETE; spec.as.remove=predicate; } else return unexpected();
    transit_station_turn_info info; TRY(transit_station_turn_inspect(turn,&info)); transit_station_table_mutation *mutation=NULL;
    TRY(transit_station_table_mutation_prepare(info.resource,0,queue.head,&schema,&spec,&mutation)); transit_station_table_status status;
    const transit_sdk_error result=transit_station_table_mutation_step(turn,mutation,&status); transit_station_table_mutation_destroy(mutation); TRY(result);
    *building=status.state==TRANSIT_TABLE_BUILDING; if(*building) return (transit_sdk_error){0};
    out->state=(uint8_t)status.state; out->admitted=status.admitted_input; out->completed=status.completed_input;
    if(status.has_counts) { out->matched=status.counts.matched; out->changed=status.counts.changed; } out->rejection=(uint8_t)status.rejection; return (transit_sdk_error){0};
}
static transit_sdk_error drive(transit_station_turn *turn,transit_sdk_process peer) {
    transit_example_table_queue queue; TRY(queue_read(turn,&queue)); if(!queue.head) return (transit_sdk_error){0};
    char work_name[28],done_name[28]; const transit_station_key key=work_key(queue.head,work_name),done=outcome_key(queue.head,done_name),metadata=metadata_key();
    transit_example_table_work work; bool found; TRY(find_copy(turn,&key,&work,&found));
    if(!found || ((work.next==0)!=(queue.head==queue.tail)) || (work.next && queue.head!=UINT64_MAX && work.next<=queue.head)) return unexpected();
    transit_example_table_outcome outcome; bool building; TRY(table_step(turn,queue,work.command,&building,&outcome));
    const bool initialize=work.command.tag==TRANSIT_QUERY_INITIALIZE; transit_station_budgets budget; TRY(transit_station_turn_budgets(turn,&budget));
    if(building || budget.mutations<3u+(initialize&&!queue.ready?1u:0u)) return wake(turn);
    if(initialize&&!queue.ready) TRY(transit_station_turn_allow_query(turn,peer,1,0,true));
    TRY(transit_station_state_put(turn,&done,&outcome)); TRY(transit_station_state_delete(turn,&key));
    queue.head=work.next; if(!work.next) queue.tail=0; queue.ready=queue.ready||initialize; TRY(transit_station_state_put(turn,&metadata,&queue));
    return work.next?wake(turn):(transit_sdk_error){0};
}
static transit_sdk_error table_service(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    const transit_example_peer *peer=context; const transit_query_message *message=input->value;
    if(input->kind==TRANSIT_INPUT_CAST) {
        if(message->tag==TRANSIT_QUERY_ADVANCE) {
            transit_station_turn_info info; TRY(transit_station_turn_inspect(turn,&info));
            if(input->origin.kind!=TRANSIT_ORIGIN_PROCESS || input->origin.process.realm!=info.process.realm || input->origin.process.pid!=info.process.pid) return unexpected();
            return drive(turn,peer->peer);
        }
        if(message->tag==TRANSIT_QUERY_INITIALIZE || message->tag==TRANSIT_QUERY_INSERT || message->tag==TRANSIT_QUERY_UPDATE || message->tag==TRANSIT_QUERY_DELETE) return enqueue(turn,input->position,*message);
    }
    if(input->kind==TRANSIT_INPUT_CALL && message->tag==TRANSIT_QUERY_ROWS) {
        transit_example_table_queue queue; TRY(queue_read(turn,&queue));
        if(!queue.ready || queue.head) { const transit_query_message reply={TRANSIT_QUERY_NOT_READY,0,false,0}; const transit_station_codec codec=transit_example_query_start_codec(); return transit_station_turn_reply(turn,&reply,&codec); }
        const uint8_t projection[]={0,1,2,3}; const transit_station_unified_plan plan={.projection=projection,.projection_count=4,.has_limit=true,.limit=UINT64_MAX}; transit_station_query_job job;
        return transit_station_turn_start_query(turn,1,&plan,&job);
    }
    return unexpected();
}
static transit_sdk_error query_start(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    const transit_example_query_requester *requester = context; const transit_query_message *message = input->value;
    const transit_station_key request=transit_example_request_key(),not_ready=transit_example_not_ready_key();
    if(input->kind==TRANSIT_INPUT_REPLY && message->tag==TRANSIT_QUERY_NOT_READY) {
        uint64_t saved; TRY(required(turn,&request,&saved)); TRY(transit_station_turn_require_reply(turn,requester->source,saved)); return transit_station_state_put(turn,&not_ready,&input->correlation);
    }
    if(input->kind!=TRANSIT_INPUT_CAST || message->tag!=TRANSIT_QUERY_START) return unexpected();
    bool previous_found,not_ready_found; uint64_t previous=0,busy=0;
    TRY(find_copy(turn,&request,&previous,&previous_found)); TRY(find_copy(turn,&not_ready,&busy,&not_ready_found));
    if(previous_found && (!not_ready_found || previous!=busy)) return unexpected();
    const transit_query_message call = {TRANSIT_QUERY_ROWS, 0, false, 0}; const transit_station_codec codec = transit_example_query_codec(); uint64_t correlation;
    TRY(transit_station_turn_call(turn, requester->source, &call, &codec, (transit_station_wait){0}, &correlation)); TRY(transit_station_state_put(turn, &request, &correlation));
    return not_ready_found ? transit_station_state_delete(turn,&not_ready) : (transit_sdk_error){0};
}
static transit_sdk_error query_result(void *context, transit_station_turn *turn, const transit_station_incoming *input) {
    const transit_example_query_requester *requester = context; const transit_station_key request = transit_example_request_key(); uint64_t saved;
    TRY(required(turn, &request, &saved)); transit_station_manifest manifest; TRY(transit_station_result_manifest(turn, input->correlation, &manifest));
    if (saved != manifest.correlation || manifest.source.pid != requester->source.pid || manifest.source.realm != requester->source.realm || !requester->consume) return unexpected();
    for (uint64_t ordinal = 0; ordinal < manifest.segments; ++ordinal) {
        transit_station_segment *segment = NULL; TRY(transit_station_result_segment(turn, input->correlation, ordinal, &segment));
        const transit_sdk_error error = requester->consume(requester->context, segment); transit_station_segment_destroy(segment); if (error.kind != TRANSIT_SDK_OK) return error;
    }
    const transit_station_key observed = transit_example_observed_key(); return transit_station_state_put(turn, &observed, &manifest.rows);
}
transit_station_handler transit_example_counter_handler(void) { return (transit_station_handler){NULL, initialize_counter, counter, NULL, NULL, NULL}; }
transit_station_handler transit_example_requester_handler(transit_example_peer *context) { return (transit_station_handler){context, NULL, requester, NULL, NULL, NULL}; }
transit_station_handler transit_example_table_handler(transit_example_peer *context) { return (transit_station_handler){context, NULL, table_service, NULL, NULL, NULL}; }
transit_station_handler transit_example_query_requester_handler(transit_example_query_requester *context) { return (transit_station_handler){context, NULL, query_start, NULL, query_result, NULL}; }
