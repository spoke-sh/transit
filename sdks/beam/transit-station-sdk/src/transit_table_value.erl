%% Bounded general handler Table codecs. Authority and domain execution stay native.
-module(transit_table_value).
-include("transit_station_sdk.hrl").
-include("transit_catalog.hrl").
-export([fields/2,check/1,positive/1,fixed/2,saved/2,mutation/1,reference/1,
         prepare/5,status/1,basis/2,row/1,creation/1,limits/1]).
check(true)->ok;
check(_)->transit_sdk_value:fail(incompatible_native,table_value).
fields(V,Names) when is_map(V),map_size(V)=:=length(Names)->check(lists:all(fun(K)->maps:is_key(K,V) end,Names)),V;
fields(_,_) -> check(false).
positive(V)->transit_sdk_value:integer(V,1,18446744073709551615).
wide(V)->positive(transit_sdk_value:wide(V)).
known(V,Allowed)->case [A||A<-Allowed,atom_to_binary(A,utf8)=:=V] of [A]->A; _->check(false) end.
fixed(V,N)->B=transit_sdk_value:bytes(V,N),check(byte_size(B)=:=N),B.
unhex(V,N)->B=fixed(transit_sdk_value:unhex(V,N),N),check(transit_sdk_value:hex(B)=:=V),B.
optional(null,_)->undefined;
optional(V,F)->F(V).
resource(V)->#transit_resource{realm=transit_sdk_value:counter(maps:get(<<"realm">>,V)),resource=transit_sdk_value:counter(maps:get(<<"resource">>,V))}.
saved(Data,Tag)->
    Bound=transit_catalog_value:limit(<<"handler_action_bytes">>),B=transit_sdk_value:text(Data,Bound),
    V=transit_sdk_value:json(B,96),check(transit_sdk_value:encode(V)=:=B),
    Envelope=#{<<"table">>=>#{Tag=>V}},transit_sdk_value:bytes(transit_sdk_value:encode(Envelope),Bound),
    Contract=transit_sdk_value:contract(transit_station_sdk),
    transit_sdk_value:require(maps:get(<<"GrowingAction">>,maps:get(<<"schemas">>,Contract)),Envelope),V.
mutation(Data)->V=saved(Data,<<"mutate">>),resource(V),wide(maps:get(<<"operation">>,V)),
    transit_catalog_value:parse_schema(maps:get(<<"schema">>,V)),transit_catalog_value:parse_mutation(maps:get(<<"mutation">>,V)),V.
reference(Data)->V=saved(Data,<<"status">>),resource(V),
    check(maps:get(<<"definition">>,V)=:=transit_catalog_value:definition()),wide(maps:get(<<"object">>,V)),wide(maps:get(<<"operation">>,V)),unhex(maps:get(<<"digest">>,V),32),V.
prepare(#transit_resource{realm=Realm,resource=Resource},Principal,Operation,Schema,Mutation)->
    {M,_}=transit_catalog_value:mutation(Mutation),
    Data=transit_sdk_value:encode(#{<<"realm">>=>transit_sdk_value:counter(Realm),<<"resource">>=>transit_sdk_value:counter(Resource),
        <<"principal">>=>transit_sdk_value:counter(Principal,0),<<"operation">>=>integer_to_binary(positive(Operation)),
        <<"schema">>=>transit_catalog_value:schema(Schema),<<"mutation">>=>M}),
    mutation(Data),{transit_table_mutation,Data}.
status(V)->
    fields(V,[<<"reference">>,<<"state">>,<<"route">>,<<"admitted_input">>,<<"completed_input">>,<<"counts">>,<<"rejection">>,<<"witness">>]),
    State=known(maps:get(<<"state">>,V),[building,applied,rejected,cancelled]),
    Route=known(maps:get(<<"route">>,V),[point,statement,alter]),
    Rejection=known(maps:get(<<"rejection">>,V),[none,row_exists,row_identity_exists,null_not_allowed,missing_required_field,character_limit_exceeded,overflow,inexact]),
    Admitted=transit_sdk_value:counter(maps:get(<<"admitted_input">>,V)),Completed=optional(maps:get(<<"completed_input">>,V),fun transit_sdk_value:counter/1),
    check((Completed=:=undefined)=:=(State=:=building)),check(Completed=:=undefined orelse Completed>=Admitted),check((Rejection=/=none)=:=(State=:=rejected)),
    Counts=optional(maps:get(<<"counts">>,V),fun(C)->fields(C,[<<"matched">>,<<"changed">>]),
        Matched=transit_sdk_value:wide(maps:get(<<"matched">>,C)),Changed=transit_sdk_value:wide(maps:get(<<"changed">>,C)),check(Changed=<Matched),
        #transit_catalog_counts{matched=Matched,changed=Changed} end),
    check((Counts=/=undefined)=:=(State=:=applied)),
    Witness=optional(maps:get(<<"witness">>,V),fun(W)->fields(W,[<<"source">>,<<"row">>,<<"column">>,<<"text">>,<<"truncated">>]),
        #transit_table_witness{source=known(maps:get(<<"source">>,W),[input,stored,withheld]),row=optional(maps:get(<<"row">>,W),fun(R)->unhex(R,20) end),
            column=transit_sdk_value:wide(maps:get(<<"column">>,W)),text=transit_sdk_value:text(maps:get(<<"text">>,W),256),truncated=transit_sdk_value:boolean(maps:get(<<"truncated">>,W))} end),
    Data=transit_sdk_value:encode(maps:get(<<"reference">>,V)),reference(Data),
    #transit_table_status{reference={transit_table_reference,Data},state=State,route=Route,admitted_input=Admitted,completed_input=Completed,counts=Counts,rejection=Rejection,witness=Witness}.
basis(V,Realm)->fields(V,[<<"resource">>,<<"revision">>,<<"object">>,<<"head">>]),
    #transit_table_basis{resource=#transit_resource{realm=Realm,resource=transit_sdk_value:counter(maps:get(<<"resource">>,V))},
        revision=transit_sdk_value:counter(maps:get(<<"revision">>,V)),object=wide(maps:get(<<"object">>,V)),head=unhex(maps:get(<<"head">>,V),32)}.
row(V)->fields(V,[<<"identity">>,<<"cells">>]),Cells=maps:get(<<"cells">>,V),check(is_list(Cells) andalso length(Cells)>0 andalso length(Cells)=<128),
    #transit_row{identity=unhex(maps:get(<<"identity">>,V),20),cells=[transit_logical:cell_from_wire(C)||C<-Cells]}.
creation(V)->fields(V,[<<"state">>,<<"admitted_input">>,<<"completed_input">>]),
    State=known(maps:get(<<"state">>,V),[building,applied]),Admitted=transit_sdk_value:counter(maps:get(<<"admitted_input">>,V)),Completed=transit_sdk_value:counter(maps:get(<<"completed_input">>,V),0),
    check((Completed=:=0)=:=(State=:=building)),check(Completed=:=0 orelse Completed>=Admitted),
    #transit_table_creation{state=State,admitted_input=Admitted,completed_input=case Completed of 0->undefined; _->Completed end}.
limits(#transit_catalog_limits{record_bytes=Bytes,staging_bytes=Staging,staging_records=Records})->
    check(Staging>=Bytes),#{<<"record_bytes">>=>transit_sdk_value:integer(Bytes,1,4294967295),<<"staging_bytes">>=>integer_to_binary(positive(Staging)),<<"staging_records">>=>transit_sdk_value:integer(Records,1,4294967295)}.
