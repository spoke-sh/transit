%% Installed strict values, large frames and actual owned-port failure schedules.
-module(beam_catalog_values).
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-export([main/2]).
max() -> 18446744073709551615.
config(Root,Override) ->
    {#transit_config{url= <<"http://127.0.0.1:9">>,profile=native_v1,timeout_ms=1000,native_host=Override},
     #transit_credential{realm=46,principal=17,seed_file=unicode:characters_to_binary(filename:join(Root,"seed"))},
     #transit_catalog_connection{owner=#transit_process{realm=46,pid=3},scope=#transit_catalog_scope{resource=#transit_resource{realm=46,resource=7},catalog=max()}}}.
open(A,Root,Mode) ->
    file:delete(filename:join(Root,"entered")),file:delete(filename:join(Root,"release")),ok=file:write_file(filename:join(Root,"mode.json"),json:encode(Mode)),
    {Config,Identity,Connection}=config(Root,filename:join(Root,"host")),{ok,Client}=A:open(Config,Identity,Connection),Client.
wait(F) -> wait(F,erlang:monotonic_time(millisecond)+5000).
wait(F,Deadline) -> case F() of true->ok; false->true=erlang:monotonic_time(millisecond)<Deadline,timer:sleep(10),wait(F,Deadline) end.
joined(Root) -> {ok,Bytes}=file:read_file(filename:join(Root,"host-pid")),Pid=binary_to_integer(Bytes),wait(fun()->not filelib:is_dir(filename:join("/proc",integer_to_list(Pid))) end).
close(A,C) -> case A:close(C) of {ok,_}->ok; {error,#transit_error{kind=cleanup},_}->ok end.
response(A,Root,Value,Action) -> C=open(A,Root,#{status=>0,value=>Value}),try Action(C) after close(A,C) end,joined(Root).
invalid({error,#transit_error{kind=Kind}}) -> true=lists:member(Kind,[incompatible_native,read_failed]),ok.
definition_id() -> maps:get(<<"definition">>,transit_sdk_value:contract(transit_station_sdk)).
scope_json() -> #{realm=>46,resource=>7,catalog=>integer_to_binary(max())}.
metadata() -> #{scope=>scope_json(),object=>integer_to_binary(max()),revision=>integer_to_binary(max()),name=><<"items">>,schema_fingerprint=>binary:copy(<<"ab">>,32),principal=>17,operation=>integer_to_binary(max()),admitted_input=>9,commitment=>#{format=>16#54434d01,length=>200,digest=>lists:duplicate(32,171)}}.
schema() -> #{definition=>definition_id(),object=>integer_to_binary(max()),revision=><<"1">>,next_column=><<"2">>,columns=>[#{id=><<"1">>,name=><<"id">>,type=>#{int128=>#{}},nullable=>true,default=>null,max_characters=>null}],primary_key=>[]}.
entry() -> #{metadata=>metadata(),head=>#{revision=><<"1">>,rows=><<"0">>,pending=><<"0">>}}.
metadata_definition() -> (entry())#{schema=>schema()}.
metadata_page() -> #{resource_revision=>9,entries=>[entry()|lists:duplicate(7,null)],next=>#{definition=>definition_id(),scope=>scope_json(),resource_revision=>9,after_object=>integer_to_binary(max())}}.
metadata_values(A,Root) ->
    Max=max(),
    response(A,Root,#{definition=>metadata_definition()},fun(C)->
        {ok,#transit_catalog_definition{metadata=#transit_catalog_metadata{object=Max,revision=Max,operation=Max,name= <<"items">>,commitment=#transit_catalog_metadata_commitment{bytes=200,digest=Digest}},schema=#transit_catalog_schema{columns=[#transit_catalog_column{id=1,type=int128,name= <<"id">>}]}}}=A:lookup(C,<<"items">>),true=Digest=:=binary:copy(<<171>>,32),
        invalid(A:lookup(C,<<"wrong">>))
    end),
    response(A,Root,#{historical=>#{metadata=>metadata(),schema=>schema()}},fun(C)->
        {ok,#transit_catalog_historical_definition{metadata=#transit_catalog_metadata{object=Max,revision=Max}}}=A:definition(C,Max,Max),
        invalid(A:definition(C,1,Max)),invalid(A:definition(C,Max,1))
    end),
    response(A,Root,#{definition=>null},fun(C)->{ok,undefined}=A:lookup(C,<<"items">>) end),
    response(A,Root,#{historical=>null},fun(C)->{ok,undefined}=A:definition(C,Max,Max) end),
    Page=metadata_page(),
    response(A,Root,#{page=>Page},fun(C)->
        {ok,#transit_catalog_page{resource_revision=9,entries=[#transit_catalog_entry{metadata=#transit_catalog_metadata{object=Max}}],next=Next}}=A:list(C),
        invalid(A:list(C,Next)),invalid(A:list(C,Next#transit_catalog_cursor{resource_revision=8,after_object=1})),
        {error,#transit_error{kind=invalid_argument}}=A:list(C,Next#transit_catalog_cursor{definition=undefined}),
        {error,#transit_error{kind=invalid_argument}}=A:list(C,Next#transit_catalog_cursor{definition=binary:copy(<<"0">>,64)})
    end),
    response(A,Root,#{page=>Page#{entries=>lists:duplicate(8,null),next=>null}},fun(C)->{ok,#transit_catalog_page{entries=[],next=undefined}}=A:list(C) end),
    Next=maps:get(next,Page),
    response(A,Root,#{page=>Page#{entries=>lists:duplicate(8,null),next=>Next#{after_object=><<"9">>}}},fun(C)->
        {_,_,#transit_catalog_connection{scope=Scope}}=config(Root,undefined),
        {ok,#transit_catalog_page{entries=[],next=#transit_catalog_cursor{after_object=9}}}=A:list(C,#transit_catalog_cursor{definition=definition_id(),scope=Scope,resource_revision=9,after_object=8})
    end),
    D=metadata(),Commitment=maps:get(commitment,D),
    lists:foreach(fun(Bad)->
        response(A,Root,#{definition=>(metadata_definition())#{metadata=>Bad}},fun(C)->invalid(A:lookup(C,<<"items">>)) end)
    end,[maps:remove(commitment,D),D#{commitment=>Commitment#{format=>0}},D#{commitment=>Commitment#{length=>0}},D#{commitment=>Commitment#{length=>437}},D#{commitment=>Commitment#{digest=>lists:duplicate(31,171)}}]),
    E=entry(),
    Invalid=[Page#{entries=>lists:duplicate(7,null)},Page#{entries=>[null,E|lists:duplicate(6,null)]},Page#{entries=>[E,E|lists:duplicate(6,null)]},
        Page#{entries=>[E#{metadata=>D#{scope=>(scope_json())#{catalog=><<"1">>}}}|lists:duplicate(7,null)]},
        Page#{next=>maps:remove(definition,Next)},Page#{next=>Next#{definition=>binary:copy(<<"0">>,64)}},Page#{next=>Next#{after_object=><<"1">>}},Page#{next=>Next#{resource_revision=>10}},
        Page#{entries=>[E#{metadata=>D#{object=>Max}}|lists:duplicate(7,null)]},Page#{entries=>[E#{metadata=>D#{revision=><<"01">>}}|lists:duplicate(7,null)]},Page#{extra=>true}],
    lists:foreach(fun(Bad)->response(A,Root,#{page=>Bad},fun(C)->invalid(A:list(C)) end) end,Invalid).
large_values(A,Root) ->
    Definition=definition_id(),Identity=#transit_catalog_identity{operation=10,namespace=100},
    Summary=#{reference=>#{definition=>Definition,digest=>binary:copy(<<"00">>,32)},scope=>scope_json(),owner=>3,principal=>17,operation=><<"10">>,namespace=><<"100">>,object=><<"1">>,kind=><<"insert">>},
    Compiled=#{intent=>Summary,saved=>#{definition=>Definition,bytes=>binary:copy(<<"ab">>,300000)}},
    Big={value,{atom,{binary,binary:copy(<<0>>,1048576)}}},Bad={value,{list,[Big,Big]}},
    BigColumn=#transit_catalog_column{id=1,name= <<"data">>,type=binary,default=Big},
    BadColumn=BigColumn#transit_catalog_column{id=2,name= <<"later">>,default=Bad},
    BigSchema=#transit_catalog_schema{object=1,revision=1,next_column=3,columns=[BigColumn,BadColumn],primary_key=[]},
    BigRows=lists:duplicate(9,[#transit_catalog_assignment{column=1,value=Big}])++[[#transit_catalog_assignment{column=1,value=Bad}]],
    Oversized=[{create,BigSchema,false},{mutate,#transit_catalog_basis{object=1,revision=1,schema_fingerprint= <<0:256>>},{insert,BigRows}}],
    lists:foreach(fun(Op)->
        {error,#transit_error{kind=invalid_argument,phase=catalog_wire_budget}}=transit_sdk_value:protect(fun()->transit_catalog_value:action({prepare,<<"items">>,Identity,Op}) end)
    end,Oversized),
    response(A,Root,#{},fun(C)->
        lists:foreach(fun(Op)->
            {error,#transit_error{kind=invalid_argument,phase=catalog_request}}=A:prepare(C,<<"items">>,Identity,Op)
        end,Oversized)
    end),
    Operation={mutate,#transit_catalog_basis{object=1,revision=1,schema_fingerprint= <<0:256>>},{insert,[[#transit_catalog_assignment{column=1,value={value,{atom,{binary,binary:copy(<<0>>,300000)}}}}]]}},
    response(A,Root,#{compiled=>Compiled},fun(C)->
        {ok,#transit_catalog_compiled{saved=#transit_catalog_saved_intent{bytes=Bytes},intent=#transit_catalog_intent{identity=Identity,object=1,kind=insert}}}=A:prepare(C,<<"items">>,Identity,Operation),300000=byte_size(Bytes)
    end),
    lists:foreach(fun(Field)->
        Value=case Field of owner->18; principal->18; kind-> <<"update">>; _-> <<"11">> end,
        response(A,Root,#{compiled=>Compiled#{intent=>Summary#{Field=>Value}}},fun(C)->invalid(A:prepare(C,<<"items">>,Identity,Operation)) end)
    end,[owner,principal,operation,namespace,object,kind]),
    Deep=lists:foldl(fun(_,V)->{value,{map,[{{utf8,<<"k">>},V}]}} end,null,lists:seq(1,15)),
    {ok,Wire}=transit_logical:encode(cell,Deep),Wrapped=lists:foldl(fun(_,V)->#{<<"wrapper">>=>V} end,Wire,lists:seq(1,5)),Bytes=transit_sdk_value:encode(Wrapped),
    Wrapped=transit_sdk_value:json(Bytes,96),{error,#transit_error{kind=incompatible_native}}=transit_sdk_value:protect(fun()->transit_sdk_value:json(Bytes) end).
main(A,[Root]) ->
    ok=beam_schema_values:run(),ok=beam_logical_values:run(),
    ok=file:write_file(filename:join(Root,"seed"),lists:duplicate(64,$1)),
    {Config,Identity,Connection}=config(Root,undefined),{ok,Native}=A:open(Config,Identity,Connection),
    try
        lists:foreach(fun(Bytes)->{error,#transit_error{kind=invalid_argument}}=A:submit(Native,#transit_catalog_prepared{bytes=Bytes}) end,[<<>>,binary:copy(<<0>>,8193),<<255>>]),
        {error,#transit_error{kind=invalid_argument}}=A:load(Native,#transit_catalog_saved_intent{definition=binary:copy(<<"0">>,64),bytes= <<1>>})
    after {ok,_}=A:close(Native) end,
    metadata_values(A,Root),large_values(A,Root),
    Prepared=#transit_catalog_prepared{bytes= <<"opaque fixture command">>},
    Modes=[<<"loss">>,#{status=>0,value=>#{receipt=>#{position=><<"1">>}}},#{status=>0,value=>#{receipt=>#{position=>7},extra=>true}}],
    lists:foreach(fun(Mode)->C=open(A,Root,Mode),try {uncertain,Prepared,#transit_error{kind=unknown_outcome,status=6}}=A:submit(C,Prepared) after close(A,C) end,joined(Root) end,Modes),
    Denied=open(A,Root,#{status=>4,value=>#{err=><<"CatalogDenied">>}}),
    try {error,#transit_error{kind=access_denied,status=4,code= <<"CatalogDenied">>}}=A:submit(Denied,Prepared) after {ok,_}=A:close(Denied) end,joined(Root),
    Success=open(A,Root,#{status=>0,value=>#{receipt=>#{position=>7}}}),
    try {ok,#transit_admission{position=7}}=A:submit(Success,Prepared) after {ok,_}=A:close(Success) end,joined(Root),
    C=open(A,Root,<<"block">>),Parent=self(),{Waiting,Monitor}=spawn_monitor(fun()->Parent!{unexpected,A:submit(C,Prepared)} end),
    try
        wait(fun()->filelib:is_file(filename:join(Root,"entered")) end),exit(Waiting,kill),
        receive {'DOWN',Monitor,process,Waiting,killed}->ok after 5000->error(waiter_alive) end,
        {error,#transit_error{kind=busy}}=A:capabilities(C),{Closer,CloseMonitor}=spawn_monitor(fun()->Parent!{closed,A:close(C)} end),
        receive {closed,_}->error(abandoned_native_work) after 100->ok end,
        ok=file:write_file(filename:join(Root,"release"),<<"1">>),receive {closed,{ok,_}}->ok after 5000->error(close_not_joined) end,
        receive {'DOWN',CloseMonitor,process,Closer,normal}->ok after 5000->error(closer_alive) end,
        {error,#transit_error{kind=closed}}=A:capabilities(C),joined(Root),<<"opaque fixture command">>=Prepared#transit_catalog_prepared.bytes
    after file:write_file(filename:join(Root,"release"),<<"1">>),A:close(C) end,
    file:delete(filename:join(Root,"seed")),io:format("~p general Table values, schema history, large frames, uncertain receipts and joined waiter loss passed.~n",[A]).
