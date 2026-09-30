%% Immutable public values; shared Zig owns compilation, signing and recovery.
-module(transit_mutations).
-include("transit_mutations.hrl").
-export([open/3,close/1,describe/1,compile_sql/4,prepare_next/2,prepare_control/3,
         submit/2,observe/3,rejection/3,status/2]).
%% Internal callbacks for the existing bounded owned worker.
-export([open/2,execute/2,evidence/1]).
-export_type([client/0,phase/0,reason/0,rejection/0]).
-opaque client() :: {transit_mutation_client,transit_sdk_worker:handle()}.
-type phase() :: uploading | sealed | applied | rejected | cancelled.
-type reason() :: none | row_exists | source_changed | invalid_request | denied | budget.
-type rejection() :: invalid_command | denied | identity_conflict | busy | not_found | not_active |
                     upload_closed | not_sealed | invalid_part | incomplete_upload | source_changed | stale_policy.
-record(state,{bridge,connection}).

positive(V) -> transit_sdk_value:integer(V,1,18446744073709551615).
counter(V) -> transit_sdk_value:counter(V).
table(V) -> transit_sdk_value:integer(V,1,4294967295).
wide(V) -> positive(transit_sdk_value:wide(V)).
fixed(B,N) -> transit_sdk_value:bytes(B,N),true=byte_size(B)=:=N,B.
decoded(V,N) -> fixed(transit_sdk_value:unhex(V,N),N).
reference(#transit_mutation_reference{bytes=B}) -> transit_sdk_value:hex(fixed(B,72)).
saved(#transit_mutation_prepared{bytes=B}) -> true=byte_size(B)>0,transit_sdk_value:text(B,8192).
prepared(null) -> undefined;
prepared(V) -> P=#transit_mutation_prepared{bytes=transit_sdk_value:text(V,8192)},saved(P),P.
known(V,Allowed) -> case [A || A<-Allowed,atom_to_binary(A,utf8)=:=V] of
    [A]->A; _->transit_sdk_value:fail(incompatible_native,mutation_variant) end.
optional(null,_) -> undefined;
optional(V,F) -> F(V).
connection(#transit_mutation_connection{writer=#transit_process{realm=Realm,pid=Writer},
    resource=#transit_resource{realm=Realm,resource=Resource},table=Table},
    #transit_credential{realm=Realm,principal=Principal}) ->
    #{<<"realm">>=>counter(Realm),<<"principal">>=>counter(Principal),<<"writer">>=>counter(Writer),
      <<"resource">>=>counter(Resource),<<"table">>=>table(Table)}.

-spec open(#transit_config{},#transit_credential{},#transit_mutation_connection{}) -> {ok,client()} | {error,#transit_error{}}.
open(Config,Credential,Connection) ->
    case transit_sdk_worker:open(?MODULE,{Config,Credential,Connection},false) of
        {ok,Worker}->{ok,{transit_mutation_client,Worker}}; Error->Error end.
open({Config,Credential,Connection},_) ->
    Bridge=transit_station_bridge:mutation(Config,Credential,connection(Connection,Credential)),
    try
        #{<<"capabilities">>:=#{<<"version">>:=1,<<"max_rows">>:=3,<<"max_request_bytes">>:=799,
          <<"max_saved_bytes">>:=8192,<<"insert">>:=true,<<"update_primary_key">>:=true,<<"delete_primary_key">>:=true}}=
            transit_station_bridge:table_mutation(Bridge,#{<<"capabilities">>=>#{}},false),
        #state{bridge=Bridge,connection=Connection}
    catch C:R:S -> catch transit_station_bridge:close(Bridge),erlang:raise(C,R,S) end.
close({transit_mutation_client,Worker}) -> transit_sdk_worker:close(Worker);
close(#state{bridge=Bridge}) -> transit_station_bridge:close(Bridge).
evidence(_) -> undefined.
call({transit_mutation_client,Worker},Request) -> transit_sdk_worker:invoke(Worker,Request).
describe(Client) -> call(Client,describe).
compile_sql(Client,Name,Sql,Namespace) -> call(Client,{compile,Name,Sql,Namespace}).
prepare_next(Client,Compiled) -> call(Client,{next,Compiled}).
prepare_control(Client,Control,Reference) -> call(Client,{control,Control,Reference}).
submit(Client,Prepared) -> case call(Client,{submit,Prepared}) of
    {error,#transit_error{kind=unknown_outcome}=E}->{uncertain,Prepared,E}; Other->Other end.
observe(Client,Prepared,Input) -> call(Client,{observe,Prepared,Input}).
rejection(Client,Prepared,Input) -> call(Client,{rejection,Prepared,Input}).
status(Client,Reference) -> call(Client,{status,Reference}).
execute(Request,#state{bridge=B,connection=C}=State) -> {{ok,operation(B,C,Request)},State}.
request(B,A) -> transit_station_bridge:table_mutation(B,A,false).

operation(B,#transit_mutation_connection{resource=R,table=Table},describe) ->
    #{<<"description">>:=V}=request(B,#{<<"describe">>=>#{}}),
    #{<<"resource">>:=Resource,<<"table">>:=Table,<<"names">>:=[Key,Value]}=V,
    true=Resource=:=R#transit_resource.resource,
    Bits=transit_sdk_value:integer(maps:get(<<"permissions">>,V),0,7),
    #transit_mutation_description{resource=R,table=Table,names=[transit_sdk_value:text(Key,16),transit_sdk_value:text(Value,16)],
        value_type=known(maps:get(<<"value_type">>,V),[int64,boolean,utf8,binary]),
        resource_revision=transit_sdk_value:counter(maps:get(<<"resource_revision">>,V),0),
        policy_revision=counter(wide(maps:get(<<"policy_revision">>,V))),declaration=decoded(maps:get(<<"declaration">>,V),32),
        permissions=[Name || {Bit,Name}<-[{1,insert},{2,update},{4,delete}], Bits band Bit=/=0],
        active=optional(maps:get(<<"active">>,V),fun wide/1)};
operation(B,_,{compile,Name,Sql,Namespace}) ->
    #{<<"compiled">>:=#{<<"request">>:=Request,<<"reference">>:=Reference}}=request(B,#{<<"compile">>=>#{
        <<"name">>=>transit_sdk_value:text(Name,16),<<"sql">>=>transit_sdk_value:text(Sql,4096),
        <<"namespace">>=>integer_to_binary(positive(Namespace))}}),
    Bytes=transit_sdk_value:unhex(Request,799),true=byte_size(Bytes)>0,
    #transit_mutation_compiled{request=Bytes,reference=#transit_mutation_reference{bytes=decoded(Reference,72)}};
operation(B,_,{next,#transit_mutation_compiled{request=Bytes,reference=Reference}}) ->
    true=byte_size(Bytes)>0,
    #{<<"prepared">>:=V}=request(B,#{<<"next">>=>#{<<"request">>=>transit_sdk_value:hex(transit_sdk_value:bytes(Bytes,799)),
        <<"reference">>=>reference(Reference)}}),prepared(V);
operation(B,_,{control,Control,Reference}) ->
    #{<<"prepared">>:=V}=request(B,#{<<"prepare">>=>#{transit_station_value:enum(Control,[apply,cancel])=>reference(Reference)}}),
    #transit_mutation_prepared{}=prepared(V);
operation(B,_,{submit,Prepared}) ->
    Result=transit_station_bridge:table_mutation(B,#{<<"submit">>=>saved(Prepared)},true),
    try #{<<"receipt">>:=#{<<"position">>:=Position}}=Result,#transit_admission{position=counter(Position)}
    catch _:_ -> throw({transit_sdk,#transit_error{kind=unknown_outcome,phase=mutation_receipt,status=6}}) end;
operation(B,_,{observe,Prepared,Input}) ->
    #{<<"observation">>:=V}=request(B,#{<<"observe">>=>#{<<"prepared">>=>saved(Prepared),<<"input">>=>counter(Input)}}),
    known(V,[pending,processed]);
operation(B,_,{rejection,Prepared,Input}) ->
    #{<<"rejection">>:=V}=request(B,#{<<"rejection">>=>#{<<"prepared">>=>saved(Prepared),<<"input">>=>counter(Input)}}),
    optional(V,fun(X)->known(X,[invalid_command,denied,identity_conflict,busy,not_found,not_active,
        upload_closed,not_sealed,invalid_part,incomplete_upload,source_changed,stale_policy]) end);
operation(B,#transit_mutation_connection{table=Table},{status,Reference}) ->
    #{<<"status">>:=V}=request(B,#{<<"status">>=>reference(Reference)}),
    optional(V,fun(X)->
        Reference=#transit_mutation_reference{bytes=decoded(maps:get(<<"reference">>,X),72)},
        Table=table(maps:get(<<"table">>,X)),
        #transit_mutation_status{reference=Reference,principal=counter(maps:get(<<"principal">>,X)),table=Table,
            declaration=decoded(maps:get(<<"declaration">>,X),32),policy_revision=counter(wide(maps:get(<<"policy_revision">>,X))),
            phase=known(maps:get(<<"phase">>,X),[uploading,sealed,applied,rejected,cancelled]),
            affected_rows=transit_sdk_value:integer(maps:get(<<"affected_rows">>,X),0,3),
            reason=known(maps:get(<<"reason">>,X),[none,row_exists,source_changed,invalid_request,denied,budget]),
            input=transit_sdk_value:counter(maps:get(<<"input">>,X),0)} end).
