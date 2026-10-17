-module(transit_query).
-include("transit_station_sdk.hrl").
-export([allow/5, start/3, close/3, result/2, manifest/1, segment/2]).
-export_type([reader/0]).
-opaque reader() :: {transit_result, transit_turn:turn(), pos_integer()}.
allow(Turn, Peer, Object, Revision, Allow) -> transit_turn:access(Turn, false, fun() ->
    transit_turn:raw(Turn, #{<<"query_policy">> => #{<<"peer">> => transit_turn:peer(Turn, Peer), <<"table">> => integer_to_binary(transit_table_value:positive(Object)),
        <<"expected_revision">> => transit_station_value:decimal(Revision), <<"allow">> => transit_sdk_value:boolean(Allow)}}), ok end).
start(Turn, Object, Plan) -> transit_turn:access(Turn, false, fun() ->
    Value = maps:get(<<"query">>, transit_turn:raw(Turn, #{<<"query_start">> => #{<<"id">> => integer_to_binary(transit_table_value:positive(Object)), <<"plan">> => transit_unified_query:plan(Plan)}})),
    #transit_query_job{result = transit_sdk_value:counter(maps:get(<<"result">>, Value)), correlation = transit_table_value:positive(transit_sdk_value:wide(maps:get(<<"correlation">>, Value))), source = transit_station_value:version(maps:get(<<"source">>, Value))} end).
close(Turn, Result, Reason) -> transit_turn:access(Turn, false, fun() ->
    transit_turn:raw(Turn, #{<<"query_close">> => #{<<"result">> => transit_sdk_value:counter(Result), <<"reason">> => transit_station_value:enum(Reason, [cancelled, denied])}}), ok end).
result(Turn, Correlation) -> transit_turn:access(Turn, false, fun() -> {transit_result, Turn, transit_sdk_value:integer(Correlation, 1, 18446744073709551615)} end).
manifest({transit_result, Turn, Correlation}) -> transit_turn:access(Turn, true, fun() -> read_manifest(Turn, Correlation) end).
read_manifest(Turn, Correlation) ->
    Value = maps:get(<<"manifest">>, transit_turn:raw(Turn, #{<<"query_completed">> => transit_station_value:decimal(Correlation)})),
    #transit_process{realm = Realm} = maps:get(process, transit_turn:data(Turn)),
    #transit_manifest{result = maps:get(<<"result">>, Value), source = #transit_process{realm = Realm, pid = maps:get(<<"source">>, Value)},
        destination = #transit_process{realm = Realm, pid = maps:get(<<"destination">>, Value)},
        correlation = transit_sdk_value:wide(maps:get(<<"correlation">>, Value)), table = transit_table_value:positive(transit_sdk_value:wide(maps:get(<<"table">>, Value))),
        policy_revision = transit_sdk_value:wide(maps:get(<<"policy_revision">>, Value)), basis = #transit_table_basis{resource = #transit_resource{realm=Realm,resource=transit_sdk_value:counter(maps:get(<<"resource">>,maps:get(<<"basis">>,Value)))},
            revision=transit_sdk_value:counter(maps:get(<<"revision">>,maps:get(<<"basis">>,Value))),object=transit_table_value:positive(transit_sdk_value:wide(maps:get(<<"table">>,Value))),head=transit_station_value:digest(maps:get(<<"head">>,maps:get(<<"basis">>,Value)))},
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
