-module(transit_query).
-include("transit_station_sdk.hrl").
-export([allow/5, start/3, close/3, result/2, manifest/1, segment/2]).
-export_type([reader/0]).
-opaque reader() :: {transit_result, transit_turn:turn(), pos_integer()}.
allow(Turn, Peer, #transit_table_schema{id = Id}, Revision, Allow) -> transit_turn:access(Turn, false, fun() ->
    transit_turn:raw(Turn, #{<<"query_policy">> => #{<<"peer">> => transit_turn:peer(Turn, Peer), <<"table">> => transit_sdk_value:integer(Id, 1, 4294967295),
        <<"expected_revision">> => transit_sdk_value:counter(Revision, 0), <<"allow">> => transit_sdk_value:boolean(Allow)}}), ok end).
start(Turn, #transit_table_schema{id = Id} = Schema, Plan) ->
    case transit_table:open(Turn, Schema) of
        {error, _} = Error -> Error;
        {ok, _} -> transit_turn:access(Turn, false, fun() ->
            Value = maps:get(<<"query">>, transit_turn:raw(Turn, #{<<"query_start">> => #{<<"id">> => Id, <<"plan">> => plan(Plan, transit_turn:limit(Turn, <<"table_cell_bytes">>))}})),
            #transit_query_job{result = maps:get(<<"result">>, Value), correlation = transit_sdk_value:wide(maps:get(<<"correlation">>, Value)), source = transit_station_value:version(maps:get(<<"source">>, Value))} end)
    end.
close(Turn, Result, Reason) -> transit_turn:access(Turn, false, fun() ->
    transit_turn:raw(Turn, #{<<"query_close">> => #{<<"result">> => transit_sdk_value:counter(Result), <<"reason">> => transit_station_value:enum(Reason, [cancelled, denied])}}), ok end).
result(Turn, Correlation) -> transit_turn:access(Turn, false, fun() -> {transit_result, Turn, transit_sdk_value:integer(Correlation, 1, 18446744073709551615)} end).
manifest({transit_result, Turn, Correlation}) -> transit_turn:access(Turn, true, fun() -> read_manifest(Turn, Correlation) end).
read_manifest(Turn, Correlation) ->
    Value = maps:get(<<"manifest">>, transit_turn:raw(Turn, #{<<"query_completed">> => transit_station_value:decimal(Correlation)})),
    #transit_process{realm = Realm} = maps:get(process, transit_turn:data(Turn)),
    #transit_manifest{result = maps:get(<<"result">>, Value), source = #transit_process{realm = Realm, pid = maps:get(<<"source">>, Value)},
        destination = #transit_process{realm = Realm, pid = maps:get(<<"destination">>, Value)},
        correlation = transit_sdk_value:wide(maps:get(<<"correlation">>, Value)), table = maps:get(<<"table">>, Value),
        policy_revision = transit_sdk_value:wide(maps:get(<<"policy_revision">>, Value)), basis = transit_station_value:basis(maps:get(<<"basis">>, Value), Realm),
        plan = transit_station_value:digest(maps:get(<<"plan">>, Value)), segments = transit_sdk_value:wide(maps:get(<<"segments">>, Value)),
        byte_count = transit_sdk_value:wide(maps:get(<<"bytes">>, Value)), rows = transit_sdk_value:wide(maps:get(<<"rows">>, Value)),
        chain = transit_station_value:digest(maps:get(<<"chain">>, Value)), schema = transit_station_value:digest(maps:get(<<"schema">>, Value))}.
segment({transit_result, Turn, Correlation}, Ordinal) -> transit_turn:access(Turn, true, fun() ->
    Number = transit_station_value:decimal(Ordinal), Manifest = read_manifest(Turn, Correlation),
    Value = maps:get(<<"segment">>, transit_turn:raw(Turn, #{<<"query_segment">> => #{<<"correlation">> => transit_station_value:decimal(Correlation), <<"ordinal">> => Number}})),
    Ipc = transit_sdk_value:unhex(maps:get(<<"ipc">>, Value), transit_turn:limit(Turn, <<"query_segment_bytes">>)),
    case {byte_size(Ipc) =:= maps:get(<<"bytes">>, Value), Manifest#transit_manifest.result =:= maps:get(<<"result">>, Value), Ordinal =:= transit_sdk_value:wide(maps:get(<<"ordinal">>, Value))} of
        {true, true, true} -> #transit_ipc_segment{manifest = Manifest, ordinal = Ordinal, rows = maps:get(<<"rows">>, Value), digest = transit_station_value:digest(maps:get(<<"digest">>, Value)), ipc = Ipc};
        _ -> transit_sdk_value:fail(incompatible_native, segment_identity)
    end end).
plan(#transit_query_plan{projection = Projection, aggregate = Aggregate, limit = Limit, predicate = Predicate}, Bound) ->
    #{<<"projection">> => transit_station_value:enum(Projection, [both, key, value]), <<"aggregate">> => transit_station_value:enum(Aggregate, [rows, count, sum]),
      <<"limit">> => case Limit of undefined -> null; _ -> transit_station_value:decimal(Limit) end, <<"predicate">> => predicate(Predicate, Bound)}.
predicate(all, _) -> #{<<"all">> => #{}};
predicate({is_null, Column}, _) -> #{<<"is_null">> => column(Column)};
predicate({compare, Column, Operator, Cell, Value}, Bound) ->
    case Column =:= key andalso Cell =/= int64 of true -> transit_sdk_value:fail(invalid_argument, key_predicate); false -> ok end,
    #{<<"compare">> => #{<<"column">> => column(Column), <<"op">> => transit_station_value:enum(Operator, [eq, ne, lt, le, gt, ge]), <<"value">> => transit_station_value:cell(Value, Cell, Bound)}}.
column(key) -> 0;
column(value) -> 1;
column(_) -> transit_sdk_value:fail(invalid_argument, query_column).
