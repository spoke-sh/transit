-module(transit_table).
-include("transit_station_sdk.hrl").
-include("transit_catalog.hrl").
-export([create/3,open/2,open_source/2,schema/1,basis/1,get/2,get_key/2,page/1,page/2,page/3,
         prepare/4,prepare/5,load/1,save/1,step/2,load_reference/1,save_reference/1,status/2,cancel/2]).
-export_type([table/0,mutation/0,mutation_reference/0]).
-opaque table() :: {transit_table,transit_turn:turn(),#transit_catalog_schema{},undefined | #transit_read_version{},#transit_table_basis{}}.
-opaque mutation() :: {transit_table_mutation,binary()}.
-opaque mutation_reference() :: {transit_table_reference,binary()}.
create(Turn,Schema,Limits)->transit_turn:access(Turn,false,fun()->
    #transit_resource{realm=Realm,resource=Resource}=resource(Turn),
    transit_table_value:creation(raw(Turn,<<"create">>,#{<<"realm">>=>Realm,<<"resource">>=>Resource,
        <<"schema">>=>transit_catalog_value:schema(Schema),<<"limits">>=>transit_table_value:limits(Limits)},<<"created">>)) end).
open(Turn,Object)->transit_turn:access(Turn,true,fun()->open_raw(Turn,Object,undefined) end).
open_source({transit_source,Turn,Version},Object)->transit_turn:access(Turn,true,fun()->open_raw(Turn,Object,Version) end).
open_raw(Turn,Object,Version)->
    V=raw(Turn,<<"schema">>,source(Object,Version),<<"schema">>),transit_table_value:fields(V,[<<"schema">>,<<"basis">>]),
    Schema=transit_catalog_value:parse_schema(maps:get(<<"schema">>,V)),Basis=transit_table_value:basis(maps:get(<<"basis">>,V),realm(Turn)),
    transit_table_value:check(Schema#transit_catalog_schema.object=:=Object andalso Basis#transit_table_basis.object=:=Object),
    {transit_table,Turn,Schema,Version,Basis}.
schema({transit_table,Turn,Schema,_,_})->transit_turn:access(Turn,false,fun()->Schema end).
basis({transit_table,Turn,_,_,Basis})->transit_turn:access(Turn,false,fun()->Basis end).
raw(Turn,Tag,Request,Expected)->
    V=transit_turn:raw(Turn,#{<<"table">>=>#{Tag=>Request}}),transit_table_value:fields(V,[<<"table">>]),
    Inner=maps:get(<<"table">>,V),transit_table_value:fields(Inner,[Expected]),maps:get(Expected,Inner).
source(Object,Version)->#{<<"object">>=>integer_to_binary(transit_table_value:positive(Object)),
    <<"version">>=>case Version of undefined->null; _->transit_turn:version(Version) end}.
source({transit_table,_,#transit_catalog_schema{object=Object},Version,_})->source(Object,Version).
realm(Turn)->#transit_process{realm=Realm}=maps:get(process,transit_turn:data(Turn)),Realm.
resource(Turn)->#transit_resource{realm=realm(Turn),resource=maps:get(<<"resource">>,maps:get(event,transit_turn:data(Turn)))}.
check_basis({transit_table,Turn,_,_,Basis},V)->
    transit_table_value:fields(V,[<<"schema">>,<<"basis">>]),
    transit_table_value:check(transit_table_value:basis(maps:get(<<"basis">>,V),realm(Turn))=:=Basis).
read_row(Table={transit_table,Turn,_,_,_},Tag,MakeRequest)->transit_turn:access(Turn,true,fun()->
    V=raw(Turn,Tag,MakeRequest(),<<"row">>),transit_table_value:fields(V,[<<"definition">>,<<"row">>]),check_basis(Table,maps:get(<<"definition">>,V)),
    case maps:get(<<"row">>,V) of null->missing; Row->{found,transit_table_value:row(Row)} end end).
get(Table,Identity)->read_row(Table,<<"get">>,fun()->#{<<"source">>=>source(Table),<<"identity">>=>transit_sdk_value:hex(transit_table_value:fixed(Identity,20))} end).
get_key(Table,Key)->read_row(Table,<<"get_key">>,fun()->
    transit_table_value:check(is_list(Key) andalso length(Key)>0 andalso length(Key)=<128),
    #{<<"source">>=>source(Table),<<"key">>=>[transit_logical:cell_wire(C)||C<-Key]} end).
page(Table)->page(Table,undefined,8).
page(Table,Cursor)->page(Table,Cursor,8).
page(Table={transit_table,Turn,_,_,_},Cursor,Limit)->transit_turn:access(Turn,true,fun()->
    transit_sdk_value:integer(Limit,1,8),Next=case Cursor of undefined->null; _->transit_sdk_value:text(Cursor,2048) end,
    V=raw(Turn,<<"page">>,#{<<"source">>=>source(Table),<<"cursor">>=>Next,<<"limit">>=>Limit},<<"page">>),
    transit_table_value:fields(V,[<<"definition">>,<<"rows">>,<<"next">>]),check_basis(Table,maps:get(<<"definition">>,V)),
    Rows=maps:get(<<"rows">>,V),transit_table_value:check(is_list(Rows) andalso length(Rows)=<Limit),
    #transit_table_page{rows=[transit_table_value:row(R)||R<-Rows],next=transit_station_value:cursor(maps:get(<<"next">>,V))} end).
prepare({transit_table,Turn,Schema,Version,Basis},Principal,Operation,Mutation)->transit_turn:access(Turn,false,fun()->
    case Version of undefined->ok; _->transit_sdk_value:fail(handler,retained_source_read_only) end,
    transit_table_value:prepare(Basis#transit_table_basis.resource,Principal,Operation,Schema,Mutation) end).
prepare(Resource,Principal,Operation,Schema,Mutation)->transit_sdk_value:protect(fun()->transit_table_value:prepare(Resource,Principal,Operation,Schema,Mutation) end).
load(Data)->transit_sdk_value:protect(fun()->transit_table_value:mutation(Data),{transit_table_mutation,binary:copy(Data)} end).
save({transit_table_mutation,Data})->transit_sdk_value:protect(fun()->transit_table_value:mutation(Data),binary:copy(Data) end).
load_reference(Data)->transit_sdk_value:protect(fun()->transit_table_value:reference(Data),{transit_table_reference,binary:copy(Data)} end).
save_reference({transit_table_reference,Data})->transit_sdk_value:protect(fun()->transit_table_value:reference(Data),binary:copy(Data) end).
same_resource(Turn,V)->#transit_resource{realm=Realm,resource=Resource}=resource(Turn),
    case maps:get(<<"realm">>,V)=:=Realm andalso maps:get(<<"resource">>,V)=:=Resource of true->ok; false->transit_sdk_value:fail(handler,foreign_table_resource) end.
step(Turn,{transit_table_mutation,Data})->transit_turn:access(Turn,false,fun()->
    Request=transit_table_value:mutation(Data),same_resource(Turn,Request),
    Result=transit_table_value:status(raw(Turn,<<"mutate">>,Request,<<"mutation">>)),
    {transit_table_reference,Reference}=Result#transit_table_status.reference,Identity=transit_table_value:reference(Reference),
    transit_table_value:check(lists:all(fun(K)->maps:get(K,Identity)=:=maps:get(K,Request) end,[<<"realm">>,<<"resource">>,<<"principal">>,<<"operation">>])),
    transit_table_value:check(maps:get(<<"object">>,Identity)=:=maps:get(<<"object">>,maps:get(<<"schema">>,Request))),Result end).
status(Turn,Reference)->read_status(Turn,Reference,<<"status">>).
cancel(Turn,Reference)->read_status(Turn,Reference,<<"cancel">>).
read_status(Turn,{transit_table_reference,Data},Tag)->transit_turn:access(Turn,Tag=:=<<"status">>,fun()->
    Request=transit_table_value:reference(Data),same_resource(Turn,Request),
    case raw(Turn,Tag,Request,<<"mutation">>) of
        null->transit_table_value:check(Tag=:=<<"status">>),undefined;
        V->Result=transit_table_value:status(V),{transit_table_reference,Actual}=Result#transit_table_status.reference,
            transit_table_value:check(transit_table_value:reference(Actual)=:=Request),Result
    end end).
