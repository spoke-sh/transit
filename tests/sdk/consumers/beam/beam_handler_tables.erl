%% Installed immutable handler values and exact recovery boundaries.
-module(beam_handler_tables).
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-include_lib("transit_station_sdk/include/transit_unified_query.hrl").
-export([run/0,main/0]).
-define(MAX,18446744073709551615).
main()->ok=run(),halt(0).
check(true)->ok;
check(_)->erlang:error(handler_table_assertion).
reject(Fun)->{error,_}=Fun(),put(rejected,get(rejected)+1),ok.
protected(Fun)->transit_sdk_value:protect(Fun).
encode(V)->transit_sdk_value:encode(V).
signed(N)->{value,{atom,{signed,N}}}.
schema()->#transit_catalog_schema{object=?MAX,revision=1,next_column=5,columns=[
    #transit_catalog_column{id=1,name= <<"id">>,type=int64,nullable=false},
    #transit_catalog_column{id=2,name= <<"amount">>,type={decimal,20,2}},
    #transit_catalog_column{id=3,name= <<"data">>,type=binary},
    #transit_catalog_column{id=4,name= <<"tags">>,type={list,#transit_logical_element{type=utf8,nullable=true}}}],primary_key=[1]}.
reference()->#{<<"definition">>=>transit_catalog_value:definition(),<<"realm">>=>46,<<"resource">>=>7,<<"object">>=>integer_to_binary(?MAX),
    <<"principal">>=>17,<<"operation">>=>integer_to_binary(?MAX),<<"digest">>=>binary:copy(<<"ab">>,32)}.
status()->#{<<"reference">>=>reference(),<<"state">>=> <<"applied">>,<<"route">>=> <<"statement">>,<<"admitted_input">>=>9,<<"completed_input">>=>11,
    <<"counts">>=>#{<<"matched">>=> <<"1">>,<<"changed">>=> <<"1">>},<<"rejection">>=> <<"none">>,<<"witness">>=>null}.
run()->put(rejected,0),Resource=#transit_resource{realm=46,resource=7},Schema=schema(),
    Mutation={insert,[[#transit_catalog_assignment{column=1,value=signed(7)},#transit_catalog_assignment{column=2,value={value,{atom,{decimal,12345}}}},
        #transit_catalog_assignment{column=3,value={value,{atom,{binary,<<1,2,3>>}}}},#transit_catalog_assignment{column=4,value={value,{list,[{value,{atom,{utf8,<<"red">>}}},null]}}}]]},
    {ok,Intent}=transit_table:prepare(Resource,17,?MAX,Schema,Mutation),{ok,Saved}=transit_table:save(Intent),{ok,Intent}=transit_table:load(Saved),
    Wire=transit_sdk_value:json(Saved,96),Schema=transit_catalog_value:parse_schema(maps:get(<<"schema">>,Wire)),Mutation=transit_catalog_value:parse_mutation(maps:get(<<"mutation">>,Wire)),
    Parent= <<0:8000000,Saved/binary,0:8000000>>,Part=binary:part(Parent,1000000,byte_size(Saved)),
    {ok,{transit_table_mutation,Owned}}=transit_table:load(Part),check(binary:referenced_byte_size(Owned)=:=byte_size(Saved)),
    EncodedSchema=maps:get(<<"schema">>,Wire),
    Bad=[Wire#{<<"schema">>=>maps:remove(<<"definition">>,EncodedSchema)},Wire#{<<"schema">>=>EncodedSchema#{<<"definition">>=>binary:copy(<<"0">>,64)}},
        Wire#{<<"operation">>=> <<"0">>},Wire#{<<"operation">>=> <<"01">>},Wire#{<<"operation">>=> <<"18446744073709551616">>},
        Wire#{<<"realm">>=>0},Wire#{<<"extra">>=>true},Wire#{<<"schema">>=>EncodedSchema#{<<"object">>=> <<"0">>}}],
    lists:foreach(fun(V)->reject(fun()->transit_table:load(encode(V)) end) end,Bad),
    reject(fun()->transit_table:load(<<" ",Saved/binary>>) end),
    DeepJson= <<(binary:copy(<<"[">>,97))/binary,"0",(binary:copy(<<"]">>,97))/binary>>,
    reject(fun()->transit_table:load(DeepJson) end),
    lists:foreach(fun(V)->BadMutation=#{<<"action">>=>#{<<"insert">>=>[[#{<<"column">>=> <<"1">>,<<"value">>=>#{<<"cell">>=>#{<<"value">>=>#{<<"atom">>=>#{<<"signed">>=>V}}}}}]]},<<"predicate">>=>null},
        reject(fun()->transit_table:load(encode(Wire#{<<"mutation">>=>BadMutation})) end) end,[<<"01">>,<<"170141183460469231731687303715884105728">>]),
    WideSchema=#transit_catalog_schema{object=1,revision=1,next_column=129,columns=[#transit_catalog_column{id=I,name= <<"c",(integer_to_binary(I))/binary>>,type=int64}||I<-lists:seq(1,128)]},
    WideAssignments=[#transit_catalog_assignment{column=I,value=signed(I)}||I<-lists:seq(1,128)],
    {ok,_}=transit_table:prepare(Resource,0,1,WideSchema,{insert,[WideAssignments]}),
    {ok,_}=transit_table:prepare(Resource,0,1,Schema,{insert,lists:duplicate(1024,[#transit_catalog_assignment{column=1,value=signed(1)}])}),
    reject(fun()->transit_table:prepare(Resource,0,1,Schema,{insert,lists:duplicate(1025,[])}) end),
    reject(fun()->transit_table:prepare(Resource,0,1,Schema,{insert,[lists:duplicate(129,#transit_catalog_assignment{column=1,value=null})]}) end),
    reject(fun()->transit_table:prepare(Resource,0,1,Schema,{insert,[[#transit_catalog_assignment{column=3,value={value,{atom,{binary,binary:copy(<<0>>,140000)}}}}]]}) end),
    Update={update,[#transit_catalog_assignment{column=2,value=default}],[{compare,1,gt,{signed,0}},{state,2,null},disjunction]},
    {U,_}=transit_catalog_value:mutation(Update),Update=transit_catalog_value:parse_mutation(U),
    {D,_}=transit_catalog_value:mutation({delete,undefined}),{delete,undefined}=transit_catalog_value:parse_mutation(D),
    {NestedType,Nested}=lists:foldl(fun(_,{T,V})->{{map,int64,#transit_logical_element{type=T}},{value,{map,[{{signed,0},V}]}}} end,{int64,signed(1)},lists:seq(1,15)),
    {ok,NestedIntent}=transit_table:prepare(Resource,0,1,#transit_catalog_schema{object=1,revision=1,next_column=2,columns=[#transit_catalog_column{id=1,name= <<"deep">>,type=NestedType}]},{insert,[[#transit_catalog_assignment{column=1,value=Nested}]]}),
    {ok,NestedSaved}=transit_table:save(NestedIntent),Envelope=encode(#{<<"table">>=>#{<<"mutate">>=>transit_sdk_value:json(NestedSaved,96)}}),
    #{<<"table">>:=_}=transit_sdk_value:json(Envelope,96),reject(fun()->protected(fun()->transit_sdk_value:json(Envelope,64) end) end),
    {ok,Reference}=transit_table:load_reference(encode(reference())),{ok,_}=transit_table:save_reference(Reference),
    lists:foreach(fun(V)->reject(fun()->transit_table:load_reference(encode(V)) end) end,
        [maps:remove(<<"definition">>,reference()),(reference())#{<<"digest">>=> <<"ab">>},(reference())#{<<"digest">>=>binary:copy(<<"AB">>,32)},(reference())#{<<"object">>=> <<"0">>}]),
    #transit_table_status{counts=#transit_catalog_counts{matched=1,changed=1},completed_input=11}=transit_table_value:status(status()),
    lists:foreach(fun(V)->reject(fun()->protected(fun()->transit_table_value:status(V) end) end) end,
        [(status())#{<<"counts">>=>null},(status())#{<<"state">>=> <<"building">>},(status())#{<<"completed_input">>=>8},
         (status())#{<<"rejection">>=> <<"row_exists">>},(status())#{<<"counts">>=>#{<<"matched">>=> <<"1">>,<<"changed">>=> <<"2">>}}]),
    #transit_table_status{counts=undefined}=transit_table_value:status((status())#{<<"state">>=> <<"building">>,<<"counts">>=>null,<<"completed_input">>=>null}),
    Turn=transit_turn:open_scope(undefined,#{<<"scope">>=>1,<<"resource">>=>8},#transit_process{realm=46,pid=3},atomics:new(3,[{signed,false}])),
    reject(fun()->transit_table:step(Turn,Intent) end),transit_turn:end_scope(Turn),reject(fun()->transit_table:step(Turn,Intent) end),
    GoodTurn=transit_turn:open_scope(undefined,#{<<"scope">>=>1,<<"resource">>=>7},#transit_process{realm=46,pid=3},atomics:new(3,[{signed,false}])),
    Table={transit_table,GoodTurn,Schema,undefined,#transit_table_basis{resource=Resource,revision=4,object=?MAX,head= <<0:256>>}},
    {ok,Schema}=transit_table:schema(Table),{error,Error}=transit_table:get(Table,<<0>>),{error,Error}=transit_table:basis(Table),Error=transit_turn:end_scope(GoodTurn),
    Plan=#transit_unified_plan{projection=[3,1,127],predicate={compare,1,gt,{decimal,123}},limit=?MAX,output_names=[<<"tags">>,undefined,<<"last">>]},
    #{<<"projection">>:=[3,1,127],<<"limit">>:= <<"18446744073709551615">>}=transit_unified_query:plan(Plan),
    io:format("Erlang handler Tables: typed saved schemas, full-width identities, deep nesting, ownership, bounds, applied counts and scoped failed-read gates passed (~p rejections).~n",[get(rejected)]),erase(rejected),ok.
