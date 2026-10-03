%% Immutable public records; shared Zig owns compilation, signing and recovery.
-module(transit_catalog).
-include("transit_catalog.hrl").
-export([open/3,close/1,capabilities/1,describe/1,lookup/2,definition/3,list/1,list/2,compile_sql/5,prepare_initialize/2,
         prepare_create/2,prepare_policy/2,submit/2,observe/3,input_disposition/3,status/2]).
%% Internal callbacks for the existing bounded owned worker.
-export([open/2,execute/2,evidence/1]).
-export_type([client/0,observation/0,outcome/0]).
-opaque client() :: {transit_catalog_client,transit_sdk_worker:handle()}.
-type observation() :: pending | processed.
-type outcome() :: applied | name_conflict | object_conflict | table_conflict.
-record(state,{bridge,connection}).

positive(V) -> transit_sdk_value:integer(V,1,18446744073709551615).
counter(V) -> transit_sdk_value:counter(V).
table(V) -> transit_sdk_value:integer(V,1,4294967295).
wide(V) -> positive(transit_sdk_value:wide(V)).
identifier(V) -> B=transit_sdk_value:text(V,16),true=byte_size(B)>0,B.
letter(C) -> (C >= $A andalso C =< $Z) orelse (C >= $a andalso C =< $z) orelse C =:= $_.
metadata_name(V) ->
    B=identifier(V),<<First,_/binary>>=B,true=letter(First),
    true=lists:all(fun(C)->letter(C) orelse (C >= $0 andalso C =< $9) end,binary_to_list(B)),B.
metadata(F) -> try F() catch _:_ -> transit_sdk_value:fail(incompatible_native,catalog_metadata) end.
cursor(undefined) -> null;
cursor(#transit_catalog_cursor{definition=Definition,scope=Scope,resource_revision=Revision,after_name=After}) ->
    Definition=maps:get(<<"definition">>,transit_sdk_value:contract(transit_station_sdk)),
    #{<<"definition">>=>Definition,<<"scope">>=>scope(Scope),<<"resource_revision">>=>counter(Revision),<<"after">>=>metadata_name(After)}.
fixed(V,N) -> B=transit_sdk_value:unhex(V,N),true=byte_size(B)=:=N,B.
saved(#transit_catalog_prepared{bytes=B}) -> true=byte_size(B)>0,transit_sdk_value:text(B,8192).
prepared(V) -> P=#transit_catalog_prepared{bytes=transit_sdk_value:text(V,8192)},saved(P),P.
known(V,Allowed) -> case [A || A<-Allowed,atom_to_binary(A,utf8)=:=V] of
    [A]->A; _->transit_sdk_value:fail(incompatible_native,catalog_variant) end.
fields(V,Names) when is_map(V),map_size(V)=:=length(Names) ->
    case lists:all(fun(K)->maps:is_key(K,V) end,Names) of true->V; false->transit_sdk_value:fail(incompatible_native,catalog_fields) end;
fields(_,_) -> transit_sdk_value:fail(incompatible_native,catalog_fields).
result(V,Key) -> maps:get(Key,fields(V,[Key])).
optional(null,_) -> undefined;
optional(V,F) -> F(V).

scope(#transit_catalog_scope{resource=#transit_resource{realm=Realm,resource=Resource},catalog=Catalog}) ->
    #{<<"realm">>=>counter(Realm),<<"resource">>=>counter(Resource),<<"catalog">>=>integer_to_binary(positive(Catalog))}.
connection(#transit_catalog_connection{owner=#transit_process{realm=Realm,pid=Owner},
    scope=#transit_catalog_scope{resource=#transit_resource{realm=Realm}}=Scope},
    #transit_credential{realm=Realm,principal=Principal}) ->
    #{<<"scope">>=>scope(Scope),<<"owner">>=>counter(Owner),<<"principal">>=>transit_sdk_value:counter(Principal,0)}.
configuration(#transit_catalog_configuration{scope=#transit_catalog_scope{resource=#transit_resource{realm=Realm}}=Scope,
    owner=#transit_process{realm=Realm,pid=Owner},administrator=Administrator}) ->
    #{<<"scope">>=>scope(Scope),<<"owner">>=>counter(Owner),<<"administrator">>=>counter(Administrator)}.
schema(#transit_catalog_schema{names=[Key,Value],value_type=Type}) ->
    #{<<"names">>=>[identifier(Key),identifier(Value)],<<"value_type">>=>transit_station_value:enum(Type,[int64,boolean,utf8,binary])}.
create(#transit_catalog_create_table{scope=Scope,operation=Operation,object=Object,table=Table,name=Name,schema=Schema}) ->
    #{<<"scope">>=>scope(Scope),<<"operation">>=>integer_to_binary(positive(Operation)),<<"object">>=>integer_to_binary(positive(Object)),
      <<"table">>=>table(Table),<<"name">>=>identifier(Name),<<"schema">>=>schema(Schema)}.
policy(#transit_catalog_policy{scope=Scope,principal=Principal,revision=Revision,inspect=Inspect,create=Create}) ->
    #{<<"scope">>=>scope(Scope),<<"principal">>=>transit_sdk_value:counter(Principal,0),<<"revision">>=>integer_to_binary(positive(Revision)),
      <<"inspect">>=>transit_sdk_value:boolean(Inspect),<<"create">>=>transit_sdk_value:boolean(Create)}.
change(#transit_catalog_policy_change{expected_revision=Expected,policy=Policy}) ->
    #{<<"expected_revision">>=>integer_to_binary(transit_sdk_value:integer(Expected,0,18446744073709551615)),<<"policy">>=>policy(Policy)}.
parse_scope(Value) ->
    V=fields(Value,[<<"realm">>,<<"resource">>,<<"catalog">>]),
    #transit_catalog_scope{resource=#transit_resource{realm=counter(maps:get(<<"realm">>,V)),resource=counter(maps:get(<<"resource">>,V))},catalog=wide(maps:get(<<"catalog">>,V))}.
parse_configuration(Value) ->
    V=fields(Value,[<<"scope">>,<<"owner">>,<<"administrator">>]),Scope=parse_scope(maps:get(<<"scope">>,V)),
    #transit_catalog_configuration{scope=Scope,owner=#transit_process{realm=(Scope#transit_catalog_scope.resource)#transit_resource.realm,pid=counter(maps:get(<<"owner">>,V))},administrator=counter(maps:get(<<"administrator">>,V))}.
parse_policy(Value) ->
    V=fields(Value,[<<"scope">>,<<"principal">>,<<"revision">>,<<"inspect">>,<<"create">>]),
    #transit_catalog_policy{scope=parse_scope(maps:get(<<"scope">>,V)),principal=transit_sdk_value:counter(maps:get(<<"principal">>,V),0),revision=wide(maps:get(<<"revision">>,V)),
        inspect=transit_sdk_value:boolean(maps:get(<<"inspect">>,V)),create=transit_sdk_value:boolean(maps:get(<<"create">>,V))}.
parse_create(Value) ->
    V=fields(Value,[<<"scope">>,<<"operation">>,<<"object">>,<<"table">>,<<"name">>,<<"schema">>]),
    S=fields(maps:get(<<"schema">>,V),[<<"names">>,<<"value_type">>]),[Key,ValueName]=maps:get(<<"names">>,S),
    #transit_catalog_create_table{scope=parse_scope(maps:get(<<"scope">>,V)),operation=wide(maps:get(<<"operation">>,V)),object=wide(maps:get(<<"object">>,V)),
        table=table(maps:get(<<"table">>,V)),name=identifier(maps:get(<<"name">>,V)),schema=#transit_catalog_schema{names=[identifier(Key),identifier(ValueName)],value_type=known(maps:get(<<"value_type">>,S),[int64,boolean,utf8,binary])}}.
parse_definition(null) -> undefined;
parse_definition(Value) ->
    V=fields(Value,[<<"scope">>,<<"object">>,<<"revision">>,<<"name">>,<<"source">>,<<"principal">>,<<"operation">>,<<"input">>]),
    Source=fields(maps:get(<<"source">>,V),[<<"table">>]),T=fields(maps:get(<<"table">>,Source),[<<"id">>,<<"schema">>]),
    S=fields(maps:get(<<"schema">>,T),[<<"names">>,<<"value_type">>]),[K,N]=maps:get(<<"names">>,S),true=K=/=N,
    Schema=#transit_catalog_schema{names=[metadata_name(K),metadata_name(N)],value_type=known(maps:get(<<"value_type">>,S),[int64,boolean,utf8,binary])},
    #transit_catalog_definition{scope=parse_scope(maps:get(<<"scope">>,V)),object=wide(maps:get(<<"object">>,V)),revision=wide(maps:get(<<"revision">>,V)),name=metadata_name(maps:get(<<"name">>,V)),
        source=#transit_catalog_table_source{table=table(maps:get(<<"id">>,T)),schema=Schema},principal=transit_sdk_value:counter(maps:get(<<"principal">>,V),0),operation=wide(maps:get(<<"operation">>,V)),input=counter(maps:get(<<"input">>,V))}.
resolved(Value,Scope,Name,Object,Revision) -> metadata(fun()->
    case parse_definition(Value) of
        undefined->undefined;
        #transit_catalog_definition{scope=Scope,name=N,object=O,revision=R}=D ->
            true=(Name=:=undefined orelse Name=:=N),true=(Object=:=undefined orelse Object=:=O),true=(Revision=:=undefined orelse Revision=:=R),D
    end end).
parse_cursor(null) -> undefined;
parse_cursor(Value) ->
    V=fields(Value,[<<"definition">>,<<"scope">>,<<"resource_revision">>,<<"after">>]),
    C=#transit_catalog_cursor{definition=maps:get(<<"definition">>,V),scope=parse_scope(maps:get(<<"scope">>,V)),resource_revision=counter(maps:get(<<"resource_revision">>,V)),after_name=metadata_name(maps:get(<<"after">>,V))},cursor(C),C.
page_entries([],_,_,Acc)->lists:reverse(Acc);
page_entries([null|Rest],Scope,_,Acc)->page_entries(Rest,Scope,true,Acc);
page_entries([Value|Rest],Scope,false,Acc)->
    #transit_catalog_definition{scope=Scope,name=Name}=D=parse_definition(Value),
    case Acc of []->ok; [#transit_catalog_definition{name=Previous}|_]->true=Previous<Name end,
    page_entries(Rest,Scope,false,[D|Acc]).
parse_page(Value,Scope,Previous)->metadata(fun()->
    V=fields(Value,[<<"resource_revision">>,<<"entries">>,<<"next">>]),Revision=counter(maps:get(<<"resource_revision">>,V)),
    Slots=maps:get(<<"entries">>,V),true=is_list(Slots),8=length(Slots),Entries=page_entries(Slots,Scope,false,[]),Next=parse_cursor(maps:get(<<"next">>,V)),
    case Next of undefined->ok; #transit_catalog_cursor{scope=Scope,resource_revision=Revision,after_name=After}->#transit_catalog_definition{name=After}=lists:last(Entries) end,
    case Previous of undefined->ok; #transit_catalog_cursor{resource_revision=Revision,after_name=Before}->case Entries of []->ok; [#transit_catalog_definition{name=First}|_]->true=First>Before end end,
    #transit_catalog_page{resource_revision=Revision,entries=Entries,next=Next} end).
parse_caps(Value) ->
    V=fields(Value,[<<"version">>,<<"definition">>,<<"initialize">>,<<"create_table">>,<<"conditional_policy">>,<<"current_metadata">>,<<"max_saved_bytes">>,<<"table_columns">>]),
    Definition=maps:get(<<"definition">>,transit_sdk_value:contract(transit_station_sdk)),
    #{<<"version">>:=1,<<"definition">>:=Definition,<<"max_saved_bytes">>:=8192,<<"table_columns">>:=2}=V,
    #transit_catalog_capabilities{version=1,definition=Definition,max_saved_bytes=8192,table_columns=2,
        initialize=transit_sdk_value:boolean(maps:get(<<"initialize">>,V)),create_table=transit_sdk_value:boolean(maps:get(<<"create_table">>,V)),
        conditional_policy=transit_sdk_value:boolean(maps:get(<<"conditional_policy">>,V)),current_metadata=transit_sdk_value:boolean(maps:get(<<"current_metadata">>,V))}.

-spec open(#transit_config{},#transit_credential{},#transit_catalog_connection{}) -> {ok,client()} | {error,#transit_error{}}.
open(Config,Credential,Connection) ->
    case transit_sdk_worker:open(?MODULE,{Config,Credential,Connection},false) of
        {ok,Worker}->{ok,{transit_catalog_client,Worker}}; Error->Error end.
open({Config,Credential,Connection},_) ->
    Bridge=transit_station_bridge:catalog(Config,Credential,connection(Connection,Credential)),
    try
        case operation(Bridge,capabilities) of
            #transit_catalog_capabilities{initialize=true,create_table=true,conditional_policy=true,current_metadata=true}->ok;
            _->transit_sdk_value:fail(unsupported_capability,catalog_capabilities)
        end,
        #state{bridge=Bridge,connection=Connection}
    catch C:R:S -> catch transit_station_bridge:close(Bridge),erlang:raise(C,R,S) end.
close({transit_catalog_client,Worker}) -> transit_sdk_worker:close(Worker);
close(#state{bridge=Bridge}) -> transit_station_bridge:close(Bridge).
evidence(_) -> undefined.
call({transit_catalog_client,Worker},Request) -> transit_sdk_worker:invoke(Worker,Request).
capabilities(Client) -> call(Client,capabilities).
describe(Client) -> call(Client,describe).
lookup(Client,Name) -> call(Client,{lookup,Name}).
definition(Client,Object,Revision) -> call(Client,{definition,Object,Revision}).
list(Client) -> list(Client,undefined).
list(Client,Cursor) -> call(Client,{list,Cursor}).
compile_sql(Client,Sql,Operation,Object,Table) -> call(Client,{compile,Sql,Operation,Object,Table}).
prepare_initialize(Client,Configuration) -> call(Client,{prepare_initialize,Configuration}).
prepare_create(Client,Request) -> call(Client,{prepare_create,Request}).
prepare_policy(Client,Change) -> call(Client,{prepare_policy,Change}).
submit(Client,Prepared) -> case call(Client,{submit,Prepared}) of
    {error,#transit_error{kind=unknown_outcome}=E}->{uncertain,Prepared,E}; Other->Other end.
observe(Client,Prepared,Input) -> call(Client,{observe,Prepared,Input}).
input_disposition(Client,Prepared,Input) -> call(Client,{input_disposition,Prepared,Input}).
status(Client,Original) -> call(Client,{status,Original}).
execute({lookup,Name},#state{bridge=B,connection=#transit_catalog_connection{scope=Scope}}=State) ->
    N=metadata_name(Name),Value=request(B,#{<<"lookup">>=>N},<<"definition">>),{{ok,resolved(Value,Scope,N,undefined,undefined)},State};
execute({definition,Object,Revision},#state{bridge=B,connection=#transit_catalog_connection{scope=Scope}}=State) ->
    Action=#{<<"definition">>=>#{<<"object">>=>integer_to_binary(positive(Object)),<<"revision">>=>integer_to_binary(positive(Revision))}},
    Value=request(B,Action,<<"definition">>),{{ok,resolved(Value,Scope,undefined,Object,Revision)},State};
execute({list,Cursor},#state{bridge=B,connection=#transit_catalog_connection{scope=Scope}}=State) ->
    Value=request(B,#{<<"list">>=>cursor(Cursor)},<<"page">>),{{ok,parse_page(Value,Scope,Cursor)},State};
execute(Request,#state{bridge=B}=State) -> {{ok,operation(B,Request)},State}.
request(B,A,Key) -> result(transit_station_bridge:catalog_call(B,A,false),Key).

operation(B,capabilities) -> parse_caps(request(B,#{<<"capabilities">>=>#{}},<<"capabilities">>));
operation(B,describe) ->
    V=fields(request(B,#{<<"describe">>=>#{}},<<"description">>),[<<"configuration">>,<<"policy">>,<<"resource_revision">>]),
    #transit_catalog_description{configuration=parse_configuration(maps:get(<<"configuration">>,V)),policy=parse_policy(maps:get(<<"policy">>,V)),resource_revision=transit_sdk_value:counter(maps:get(<<"resource_revision">>,V),0)};
operation(B,{compile,Sql,Operation,Object,Table}) ->
    S=transit_sdk_value:text(Sql,4096),true=byte_size(S)>0,
    V=fields(request(B,#{<<"compile">>=>#{<<"sql">>=>S,<<"operation">>=>integer_to_binary(positive(Operation)),<<"object">>=>integer_to_binary(positive(Object)),<<"table">>=>table(Table)}},<<"compiled">>),[<<"request">>,<<"canonical">>]),
    Bytes=transit_sdk_value:unhex(maps:get(<<"canonical">>,V),256),true=byte_size(Bytes)>0,
    #transit_catalog_compiled{request=parse_create(maps:get(<<"request">>,V)),canonical=Bytes};
operation(B,{prepare_initialize,Configuration}) -> prepared(request(B,#{<<"prepare_initialize">>=>configuration(Configuration)},<<"prepared">>));
operation(B,{prepare_create,Request}) -> prepared(request(B,#{<<"prepare_create">>=>create(Request)},<<"prepared">>));
operation(B,{prepare_policy,Change}) -> prepared(request(B,#{<<"prepare_policy">>=>change(Change)},<<"prepared">>));
operation(B,{submit,Prepared}) ->
    Value=transit_station_bridge:catalog_call(B,#{<<"submit">>=>saved(Prepared)},true),
    try V=fields(result(Value,<<"receipt">>),[<<"position">>]),#transit_admission{position=counter(maps:get(<<"position">>,V))}
    catch _:_ -> throw({transit_sdk,#transit_error{kind=unknown_outcome,phase=catalog_receipt,status=6}}) end;
operation(B,{observe,Prepared,Input}) ->
    known(request(B,#{<<"observe">>=>#{<<"prepared">>=>saved(Prepared),<<"input">>=>counter(Input)}},<<"observation">>),[pending,processed]);
operation(B,{input_disposition,Prepared,Input}) ->
    optional(request(B,#{<<"input_disposition">>=>#{<<"prepared">>=>saved(Prepared),<<"input">>=>counter(Input)}},<<"disposition">>),fun(Value)->
        V=fields(Value,[<<"scope">>,<<"origin">>,<<"principal">>,<<"input">>,<<"payload">>,<<"outcome">>,<<"diagnostic">>]),
        #transit_catalog_disposition{scope=parse_scope(maps:get(<<"scope">>,V)),origin=known(maps:get(<<"origin">>,V),[external,process,effect]),principal=transit_sdk_value:counter(maps:get(<<"principal">>,V),0),
            input=counter(maps:get(<<"input">>,V)),payload=fixed(maps:get(<<"payload">>,V),32),outcome=known(maps:get(<<"outcome">>,V),[initialized,policy_applied,invalid_command,denied,identity_conflict,stale_policy]),diagnostic=maps:get(<<"diagnostic">>,V)} end);
operation(B,{status,Original}) ->
    optional(request(B,#{<<"status">>=>create(Original)},<<"status">>),fun(Value)->
        V=fields(Value,[<<"request">>,<<"principal">>,<<"input">>,<<"outcome">>,<<"diagnostic">>]),
        case parse_create(maps:get(<<"request">>,V)) =:= Original of true->ok; false->transit_sdk_value:fail(incompatible_native,catalog_original_request) end,
        #transit_catalog_receipt{request=Original,principal=transit_sdk_value:counter(maps:get(<<"principal">>,V),0),input=counter(maps:get(<<"input">>,V)),outcome=known(maps:get(<<"outcome">>,V),[applied,name_conflict,object_conflict,table_conflict]),diagnostic=maps:get(<<"diagnostic">>,V)} end).
