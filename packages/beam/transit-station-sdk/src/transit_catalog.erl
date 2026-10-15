%% General Table values and exact recovery over the owned native worker.
-module(transit_catalog).
-include("transit_catalog.hrl").
-export([open/3,open/4,close/1,capabilities/1,describe/1,lookup/2,definition/3,list/1,list/2,
         compile_sql/3,compile_sql/4,prepare/4,load/2,forget/2,next/2,status/2,
         prepare_resume/2,prepare_control/3,prepare_initialize/2,prepare_dependency/3,
         submit/2,observe/3,observe/4,input_disposition/3,progress/4,progress/5,basis/1]).
%% Internal bounded-worker callbacks.
-export([open/2,execute/2,evidence/1]).
-export_type([client/0,observation/0,operation/0,mutation/0,change/0,predicate/0]).
-opaque client() :: {transit_catalog_client,transit_sdk_worker:handle(),map()}.
-type observation() :: pending | processed.
-type operation() :: {create,#transit_catalog_schema{},boolean()} |
    {alter,#transit_catalog_basis{},change()} | {rename,#transit_catalog_basis{},binary()} |
    {drop,undefined | #transit_catalog_basis{},boolean()} | {mutate,#transit_catalog_basis{},mutation()}.
-type mutation() :: {insert,[[#transit_catalog_assignment{}]]} |
    {update,[#transit_catalog_assignment{}],undefined | [predicate()]} | {delete,undefined | [predicate()]}.
-type change() :: {add,binary(),transit_logical:descriptor(),boolean(),undefined | transit_logical:cell(),undefined | pos_integer()} |
    {drop,pos_integer()} | {rename,pos_integer(),binary()} | {default,pos_integer(),undefined | transit_logical:cell()} |
    {nullable,pos_integer(),boolean()} | {type,pos_integer(),transit_logical:descriptor(),undefined | pos_integer()}.
-type predicate() :: all | negate | conjunction | disjunction |
    {state,pos_integer(),missing | null | type_error | value | conflict} |
    {compare,pos_integer(),eq | ne | lt | le | gt | ge,transit_logical:atom_value()}.
-record(state,{bridge,connection,principal,context}).

open(Config,Credential,Connection) -> open(Config,Credential,Connection,undefined).
open(Config,Credential,Connection,TableServiceUrl) ->
    case transit_sdk_value:protect(fun transit_catalog_value:context/0) of
        {ok,Context}->case transit_sdk_worker:open(?MODULE,{Config,Credential,Connection,TableServiceUrl,Context},false) of
            {ok,Worker}->{ok,{transit_catalog_client,Worker,Context}}; Error->Error end;
        Error->Error
    end.
open({Config,Credential,Connection,TableServiceUrl,Context},_) ->
    Bridge=transit_station_bridge:catalog(Config,Credential,transit_catalog_value:connection(Connection,Credential),TableServiceUrl),
    try transit_catalog_value:with_context(Context,fun()->
        State=#state{bridge=Bridge,connection=Connection,principal=Credential#transit_credential.principal,context=Context},
        Caps=execute_value(transit_catalog_value:action(capabilities),State),
        case transit_catalog_value:supported(Caps) of true->State; false->transit_sdk_value:fail(unsupported_capability,catalog_capabilities) end
    end) catch C:R:S -> catch transit_station_bridge:close(Bridge),erlang:raise(C,R,S) end.
close({transit_catalog_client,Worker,_}) -> transit_sdk_worker:close(Worker);
close(#state{bridge=Bridge}) -> transit_station_bridge:close(Bridge).
evidence(_) -> undefined.
call({transit_catalog_client,Worker,Context},Request) ->
    %% Validate and own the complete request before admission to a local worker.
    Prepared=transit_sdk_value:protect(fun()->transit_catalog_value:with_context(Context,fun()->
        try
            {Action,_,_}=Out=transit_catalog_value:action(Request),
            true=byte_size(transit_sdk_value:encode(Action))=<transit_catalog_value:limit(<<"catalog_action_bytes">>),Out
        catch _:_ -> transit_sdk_value:fail(invalid_argument,catalog_request) end
    end) end),
    case Prepared of {ok,Work}->transit_sdk_worker:invoke(Worker,Work); Error->Error end.
capabilities(C) -> call(C,capabilities).
describe(C) -> call(C,describe).
lookup(C,N) -> call(C,{lookup,N}).
definition(C,O,R) -> call(C,{definition,O,R}).
list(C) -> list(C,undefined).
list(C,Cursor) -> call(C,{list,Cursor}).
compile_sql(C,Sql,Identity) -> compile_sql(C,Sql,Identity,undefined).
compile_sql(C,Sql,Identity,CreateObject) -> call(C,{compile,Sql,Identity,CreateObject}).
prepare(C,Name,Identity,Operation) -> call(C,{prepare,Name,Identity,Operation}).
load(C,Saved) -> call(C,{load,Saved}).
forget(C,Reference) -> call(C,{forget,Reference}).
next(C,Reference) -> call(C,{next,Reference}).
status(C,Reference) -> call(C,{status,Reference}).
prepare_resume(C,Reference) -> call(C,{prepare_resume,Reference}).
prepare_control(C,Reference,Control) -> call(C,{prepare_control,Reference,Control}).
prepare_initialize(C,Configuration) -> call(C,{prepare_initialize,Configuration}).
prepare_dependency(C,Dependency,Present) -> call(C,{prepare_dependency,Dependency,Present}).
submit(C,Prepared) -> case call(C,{submit,Prepared}) of
    {error,#transit_error{kind=unknown_outcome}=E}->{uncertain,Prepared,E}; Other->Other end.
observe(C,Prepared,Input) -> observe(C,Prepared,Input,false).
observe(C,Prepared,Input,Wait) -> call(C,{observe,Prepared,Input,Wait}).
input_disposition(C,Prepared,Input) -> call(C,{input_disposition,Prepared,Input}).
progress(C,Reference,Prepared,Input) -> progress(C,Reference,Prepared,Input,false).
progress(C,Reference,Prepared,Input,Wait) -> call(C,{progress,Reference,Prepared,Input,Wait}).
basis(Metadata) -> transit_catalog_value:basis(Metadata).
execute(Work,#state{context=Context}=State) ->
    Value=transit_catalog_value:with_context(Context,fun()->execute_value(Work,State) end),{{ok,Value},State}.
execute_value({Action,Field,Check},#state{bridge=B,connection=C,principal=P}) ->
    transit_catalog_value:check_request(Check,C),
    Response=transit_station_bridge:catalog_call(B,Action,Check=:=admission),
    try
        true=is_map(Response) andalso map_size(Response)=:=1,
        Value=maps:get(Field,Response),transit_catalog_value:decode(Check,Value,C,P)
    catch
        _:_ when Check=:=admission -> transit_sdk_value:fail(unknown_outcome,catalog_receipt);
        _:_ -> transit_sdk_value:fail(incompatible_native,catalog_response)
    end.
