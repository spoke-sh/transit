%% Direct Table lifecycle and explicit retention over one joined native worker.
-module(transit_catalog).
-include("transit_catalog.hrl").
-export([open/3,open/4,close/1,capabilities/1,describe/1,namespace/2,namespaces/1,namespaces/2,tables/1,tables/2,tables/3,lookup/2,lookup/3,
         compile_sql/3,compile_sql/4,compile_sql/6,prepare/4,load/2,forget/2,preview/2,stage/2,admit/2,inspect/2,execute/2,execute/3,cancel/2,
         prepare_snapshot/3,acquire_snapshot/2,snapshot_status/2,snapshot_metadata/2,release_snapshot/2,basis/1,save/1,restore/2]).
-export([open/2,evidence/1]).
-export_type([client/0,operation/0,mutation/0,change/0,predicate/0,encoding/0,collation/0]).
-opaque client() :: {transit_catalog_client,transit_sdk_worker:handle(),map(),#transit_catalog_connection{},non_neg_integer()}.
-type operation() :: {create,#transit_catalog_schema{},boolean()} |
    {alter,#transit_catalog_basis{},change()} | {rename,#transit_catalog_basis{},binary()} |
    {drop,undefined | #transit_catalog_basis{},boolean()} | {mutate,#transit_catalog_basis{},mutation(),point | bulk}.
-type mutation() :: {insert,[[#transit_catalog_assignment{}]]} |
    {update,[#transit_catalog_assignment{}],undefined | [predicate()]} | {delete,undefined | [predicate()]}.
-type change() :: {add,binary(),transit_logical:descriptor(),boolean(),undefined | transit_logical:cell(),undefined | pos_integer(),encoding(),collation()} |
    {drop,pos_integer()} | {rename,pos_integer(),binary()} | {default,pos_integer(),undefined | transit_logical:cell()} |
    {physical,pos_integer(),encoding(),collation()} | {nullable,pos_integer(),boolean()} | {type,pos_integer(),transit_logical:descriptor(),undefined | pos_integer()}.
-type encoding() :: plain | bitpacked | rle | dictionary | fsst | comp | comp_3 | zoned | ibm_hfp | ebcdic.
-type collation() :: none | utf8_binary | ascii_ci | ebcdic_cp037 | icu_root | ebcdic_037_pad | ebcdic_1047_nopad.
-type predicate() :: all | negate | conjunction | disjunction |
    {state,pos_integer(),missing | null | type_error | value | conflict} |
    {compare,pos_integer(),eq | ne | lt | le | gt | ge,transit_logical:atom_value()}.
-record(state,{bridge,connection,principal,context}).
open(Config,Credential,Connection) -> open(Config,Credential,Connection,undefined).
open(Config,Credential,Connection,ServiceUrl) ->
    case transit_sdk_value:protect(fun transit_catalog_value:context/0) of
        {ok,Context}->case transit_sdk_worker:open(?MODULE,{Config,Credential,Connection,ServiceUrl,Context},false) of
            {ok,Worker}->{ok,{transit_catalog_client,Worker,Context,Connection,Credential#transit_credential.principal}};Error->Error end;
        Error->Error
    end.
open({Config,Credential,Connection,ServiceUrl,Context},_) ->
    Bridge=transit_station_bridge:catalog(Config,Credential,transit_catalog_value:connection(Connection,Credential),ServiceUrl),
    try transit_catalog_value:with_context(Context,fun()->
        State=#state{bridge=Bridge,connection=Connection,principal=Credential#transit_credential.principal,context=Context},
        Caps=execute_value(transit_catalog_value:action(capabilities),State),
        case transit_catalog_value:supported(Caps) of true->State;false->transit_sdk_value:fail(unsupported_capability,catalog_capabilities) end
    end) catch C:R:S->catch transit_station_bridge:close(Bridge),erlang:raise(C,R,S) end.
close({transit_catalog_client,Worker,_,_,_})->transit_sdk_worker:close(Worker);
close(#state{bridge=B})->transit_station_bridge:close(B).
evidence(_)->undefined.
call({transit_catalog_client,Worker,Context,_,_},Request)->
    Prepared=transit_sdk_value:protect(fun()->transit_catalog_value:with_context(Context,fun()->
        try transit_catalog_value:action(Request) catch _:_ -> transit_sdk_value:fail(invalid_argument,catalog_request) end
    end) end),
    case Prepared of {ok,{_,_,_,Original}=Work}->
        case transit_sdk_worker:invoke(Worker,Work) of
            {error,#transit_error{kind=unknown_outcome}=E} when Original=/=undefined->{uncertain,Original,E};Other->Other
        end;
        Error->Error
    end.
capabilities(C)->call(C,capabilities).
describe(C)->call(C,describe).
namespace(C,N)->call(C,{namespace,N}).
namespaces(C)->namespaces(C,undefined).
namespaces(C,Cursor)->call(C,{namespaces,Cursor}).
tables(C)->tables(C,1,undefined).
tables(C,N)->tables(C,N,undefined).
tables(C,N,Cursor)->call(C,{tables,N,Cursor}).
lookup(C,N)->lookup(C,N,1).
lookup(C,Name,N)->call(C,{lookup,Name,N}).
compile_sql(C,S,I)->compile_sql(C,S,I,undefined,transit,point).
compile_sql(C,S,I,O)->compile_sql(C,S,I,O,transit,point).
compile_sql(C,S,I,O,D,Ingestion)->call(C,{compile,S,I,O,D,Ingestion}).
prepare(C,N,I,O)->call(C,{prepare,N,I,O}).
load(C,S)->call(C,{load,S}).
forget(C,I)->call(C,{forget,I}).
preview(C,I)->call(C,{preview,I}).
stage(C,I)->call(C,{stage,I}).
admit(C,R)->call(C,{admit,R}).
inspect(C,R)->call(C,{operation,R,inspect,1}).
execute(C,R) when is_tuple(C),element(1,C)=:=transit_catalog_client->execute(C,R,256);
execute(Work,#state{context=Context}=State)->
    Value=transit_catalog_value:with_context(Context,fun()->execute_value(Work,State) end),{{ok,Value},State}.
execute(C,R,Steps)->call(C,{operation,R,execute,Steps}).
cancel(C,R)->call(C,{operation,R,cancel,1}).
prepare_snapshot({transit_catalog_client,_,Context,C,P},#transit_catalog_metadata{basis=#transit_catalog_basis{connection=C,principal=P}}=M,O)->
    transit_sdk_value:protect(fun()->transit_catalog_value:with_context(Context,fun()->transit_catalog_value:prepare_snapshot(M,O,transit_catalog_value:definition()) end) end);
prepare_snapshot(_,_,_)->{error,#transit_error{kind=invalid_argument,phase=catalog_snapshot_owner}}.
acquire_snapshot(C,A)->call(C,{retention,acquire,A}).
snapshot_status(C,O)->call(C,{retention,status,O}).
snapshot_metadata(C,S)->call(C,{retention,metadata,S}).
release_snapshot(C,S)->call(C,{retention,release,S}).
basis(M)->transit_catalog_value:basis(M).
save(V)->transit_sdk_value:protect(fun()->transit_catalog_value:save(V) end).
restore(K,D)->transit_sdk_value:protect(fun()->transit_catalog_value:restore(K,D) end).
execute_value({Action,Path,Check,Original},#state{bridge=B,connection=C,principal=P})->
    transit_catalog_value:check_request(Check,C,P),Response=transit_station_bridge:catalog_call(B,Action,Original=/=undefined),
    try Value=lists:foldl(fun(Key,V)->true=is_map(V) andalso map_size(V)=:=1,maps:get(Key,V) end,Response,Path),
        transit_catalog_value:decode(Check,Value,C,P)
    catch _:_ when Original=/=undefined->transit_sdk_value:fail(unknown_outcome,catalog_response);
          _:_ -> transit_sdk_value:fail(incompatible_native,catalog_response)
    end.
