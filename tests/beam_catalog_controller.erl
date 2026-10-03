-module(beam_catalog_controller).
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-export([main/2]).
hex(B)->binary:encode_hex(B,lowercase).
prepared(B)->#transit_catalog_prepared{bytes=B}.
report(V)->io:put_chars([json:encode(V),"\n"]).
result({ok,V})->V;
result({error,E})->throw({failure,E}).
optional(undefined,_)->null;
optional(V,F)->F(V).
scope(#{<<"realm">>:=R,<<"resource">>:=K,<<"catalog">>:=C})->#transit_catalog_scope{resource=#transit_resource{realm=R,resource=K},catalog=binary_to_integer(C)}.
scope_json(#transit_catalog_scope{resource=#transit_resource{realm=R,resource=K},catalog=C})->#{realm=>R,resource=>K,catalog=>integer_to_binary(C)}.
configuration(#{<<"scope">>:=S,<<"owner">>:=O,<<"administrator">>:=A})->Scope=scope(S),#transit_catalog_configuration{scope=Scope,owner=#transit_process{realm=(Scope#transit_catalog_scope.resource)#transit_resource.realm,pid=O},administrator=A}.
configuration_json(#transit_catalog_configuration{scope=S,owner=#transit_process{pid=O},administrator=A})->#{scope=>scope_json(S),owner=>O,administrator=>A}.
policy(#{<<"scope">>:=S,<<"principal">>:=P,<<"revision">>:=R,<<"inspect">>:=I,<<"create">>:=C})->#transit_catalog_policy{scope=scope(S),principal=P,revision=binary_to_integer(R),inspect=I,create=C}.
policy_json(#transit_catalog_policy{scope=S,principal=P,revision=R,inspect=I,create=C})->#{scope=>scope_json(S),principal=>P,revision=>integer_to_binary(R),inspect=>I,create=>C}.
request(#{<<"scope">>:=S,<<"operation">>:=O,<<"object">>:=Obj,<<"table">>:=T,<<"name">>:=N,<<"schema">>:=#{<<"names">>:=Names,<<"value_type">>:=Type}})->
    Atom=case Type of <<"int64">>->int64; <<"boolean">>->boolean; <<"utf8">>->utf8; <<"binary">>->binary end,
    #transit_catalog_create_table{scope=scope(S),operation=binary_to_integer(O),object=binary_to_integer(Obj),table=T,name=N,schema=#transit_catalog_schema{names=Names,value_type=Atom}}.
request_json(#transit_catalog_create_table{scope=S,operation=O,object=Obj,table=T,name=N,schema=#transit_catalog_schema{names=Names,value_type=Type}})->
    #{scope=>scope_json(S),operation=>integer_to_binary(O),object=>integer_to_binary(Obj),table=>T,name=>N,schema=>#{names=>Names,value_type=>atom_to_binary(Type)}}.
cursor(null)->undefined;
cursor(#{<<"definition">>:=D,<<"scope">>:=S,<<"resource_revision">>:=R,<<"after">>:=N})->#transit_catalog_cursor{definition=D,scope=scope(S),resource_revision=R,after_name=N}.
cursor_json(#transit_catalog_cursor{definition=D,scope=S,resource_revision=R,after_name=N})->#{definition=>D,scope=>scope_json(S),resource_revision=>R,'after'=>N}.
definition_json(#transit_catalog_definition{scope=S,object=O,revision=R,name=N,source=#transit_catalog_table_source{table=T,schema=#transit_catalog_schema{names=Names,value_type=Type}},principal=P,operation=Op,input=I})->
    #{scope=>scope_json(S),object=>integer_to_binary(O),revision=>integer_to_binary(R),name=>N,source=>#{table=>#{id=>T,schema=>#{names=>Names,value_type=>atom_to_binary(Type)}}},principal=>P,operation=>integer_to_binary(Op),input=>I}.
page_json(#transit_catalog_page{resource_revision=R,entries=Entries,next=Next})->#{resource_revision=>R,entries=>[definition_json(D)||D<-Entries]++lists:duplicate(8-length(Entries),null),next=>optional(Next,fun cursor_json/1)}.
action(A,C,#{<<"capabilities">>:=_})->
    #transit_catalog_capabilities{version=V,definition=D,initialize=I,create_table=T,conditional_policy=P,current_metadata=M,max_saved_bytes=S,table_columns=Cols}=result(A:capabilities(C)),
    #{capabilities=>#{version=>V,definition=>D,initialize=>I,create_table=>T,conditional_policy=>P,current_metadata=>M,max_saved_bytes=>S,table_columns=>Cols}};
action(A,C,#{<<"describe">>:=_})->
    #transit_catalog_description{configuration=Configuration,policy=Policy,resource_revision=Revision}=result(A:describe(C)),
    #{description=>#{configuration=>configuration_json(Configuration),policy=>policy_json(Policy),resource_revision=>Revision}};
action(A,C,#{<<"lookup">>:=Name})->#{definition=>optional(result(A:lookup(C,Name)),fun definition_json/1)};
action(A,C,#{<<"definition">>:=#{<<"object">>:=O,<<"revision">>:=R}})->#{definition=>optional(result(A:definition(C,binary_to_integer(O),binary_to_integer(R))),fun definition_json/1)};
action(A,C,#{<<"list">>:=Cursor})->#{page=>page_json(result(A:list(C,cursor(Cursor))))};
action(A,C,#{<<"compile">>:=#{<<"sql">>:=Sql,<<"operation">>:=O,<<"object">>:=Obj,<<"table">>:=T}})->
    #transit_catalog_compiled{request=R,canonical=Canonical}=result(A:compile_sql(C,Sql,binary_to_integer(O),binary_to_integer(Obj),T)),#{compiled=>#{request=>request_json(R),canonical=>hex(Canonical)}};
action(A,C,#{<<"prepare_initialize">>:=V})->#transit_catalog_prepared{bytes=B}=result(A:prepare_initialize(C,configuration(V))),#{prepared=>B};
action(A,C,#{<<"prepare_create">>:=V})->#transit_catalog_prepared{bytes=B}=result(A:prepare_create(C,request(V))),#{prepared=>B};
action(A,C,#{<<"prepare_policy">>:=#{<<"expected_revision">>:=E,<<"policy">>:=P}})->
    #transit_catalog_prepared{bytes=B}=result(A:prepare_policy(C,#transit_catalog_policy_change{expected_revision=binary_to_integer(E),policy=policy(P)})),#{prepared=>B};
action(A,C,#{<<"submit">>:=Bytes})->
    Prepared=prepared(Bytes),case A:submit(C,Prepared) of
        {uncertain,Prepared,#transit_error{kind=unknown_outcome}=Error}->throw({failure,Error});
        R->#transit_admission{position=Position}=result(R),Bytes=Prepared#transit_catalog_prepared.bytes,#{receipt=>#{position=>Position}}
    end;
action(A,C,#{<<"observe">>:=#{<<"prepared">>:=Bytes,<<"input">>:=Input}})->#{observation=>atom_to_binary(result(A:observe(C,prepared(Bytes),Input)))};
action(A,C,#{<<"input_disposition">>:=#{<<"prepared">>:=Bytes,<<"input">>:=Input}})->
    #{disposition=>optional(result(A:input_disposition(C,prepared(Bytes),Input)),fun(#transit_catalog_disposition{scope=S,origin=O,principal=P,input=I,payload=Payload,outcome=Outcome,diagnostic=Diagnostic})->
        #{scope=>scope_json(S),origin=>atom_to_binary(O),principal=>P,input=>I,payload=>hex(Payload),outcome=>atom_to_binary(Outcome),diagnostic=>Diagnostic} end)};
action(A,C,#{<<"status">>:=V})->Original=request(V),
    #{status=>optional(result(A:status(C,Original)),fun(#transit_catalog_receipt{request=R,principal=P,input=I,outcome=O,diagnostic=Diagnostic})->
        Original=R,#{request=>request_json(R),principal=>P,input=>I,outcome=>atom_to_binary(O),diagnostic=>Diagnostic} end)}.
loop(A,C)->case io:get_line("") of
    eof->ok;
    Line->Action=json:decode(unicode:characters_to_binary(Line)),case maps:is_key(<<"close">>,Action) of
        true->ok;
        false->
            try action(A,C,Action) of Value->report(#{status=>0,value=>Value})
            catch throw:{failure,#transit_error{kind=Kind,status=Status,code=Code,diagnostic=Diagnostic,diagnostic_invalid=Invalid}}->
                Native=case Status of undefined->case Kind of unknown_outcome->6; _->1 end; _->Status end,
                report(#{status=>Native,value=>#{err=>optional(Code,fun(X)->X end),diagnostic=>optional(Diagnostic,fun(X)->X end),diagnostic_invalid=>Invalid}})
            end,loop(A,C)
    end end.
main(A,[Path])->
    try
        {ok,Bytes}=file:read_file(Path),Cfg=json:decode(Bytes),Conn=maps:get(<<"connection">>,Cfg),Scope=scope(maps:get(<<"scope">>,Conn)),Realm=(Scope#transit_catalog_scope.resource)#transit_resource.realm,
        Config=#transit_config{url=maps:get(<<"url">>,Cfg),profile=native_v1,timeout_ms=10000},
        Identity=#transit_credential{realm=Realm,principal=maps:get(<<"principal">>,Conn),seed_file=maps:get(<<"seed_file">>,Cfg)},
        Connection=#transit_catalog_connection{owner=#transit_process{realm=Realm,pid=maps:get(<<"owner">>,Conn)},scope=Scope},
        Client=result(A:open(Config,Identity,Connection)),
        try report(#{ready=>true}),loop(A,Client),result(A:close(Client)),{error,#transit_error{kind=closed}}=A:describe(Client),report(#{closed=>true})
        after A:close(Client) end
    catch Class:Reason:_ ->
        Safe=case Reason of {failure,#transit_error{kind=K,phase=P}}->{K,P}; Atom when is_atom(Atom)->Atom; _->assertion_failed end,
        io:format(standard_error,"Catalog SDK proof failed: ~p ~p~n",[Class,Safe]),halt(1)
    end.
