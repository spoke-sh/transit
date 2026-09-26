%% Internal shared SDK checks. Never turn external text into atoms.
-module(transit_sdk_value).
-compile({no_auto_import, [error/2]}).
-include("transit_client.hrl").
-export([fail/2, error/2, native/3, protect/1, counter/1, counter/2, boolean/1,
         bytes/2, text/2, hex/1, unhex/2, integer/3, contract/1, require/2,
         json/1, encode/1, valid/2, wide/1, signed/1]).
fail(Kind, Phase) -> throw({transit_sdk, error(Kind, Phase)}).
error(Kind, Phase) ->
    Status = case Kind of unknown_outcome -> 6; read_failed -> 7; busy -> 9; incompatible_native -> 10; _ -> undefined end,
    #transit_error{kind = Kind, phase = Phase, status = Status}.
protect(Fun) ->
    try {ok, Fun()} catch
        throw:{transit_sdk, Error} -> {error, Error};
        _:_ -> {error, error(handler, callback)}
    end.
integer(Value, Min, Max) when is_integer(Value), Value >= Min, Value =< Max -> Value;
integer(_, _, _) -> fail(invalid_argument, integer).
counter(Value) -> counter(Value, 1).
counter(Value, Min) -> integer(Value, Min, 9007199254740991).
boolean(Value) when is_boolean(Value) -> Value;
boolean(_) -> fail(incompatible_native, boolean).
bytes(Value, Bound) when is_binary(Value), byte_size(Value) =< Bound -> binary:copy(Value);
bytes(_, _) -> fail(invalid_argument, bytes).
text(Value, Bound) ->
    Bytes = bytes(Value, Bound),
    case unicode:characters_to_binary(Bytes, utf8, utf8) of Bytes -> Bytes; _ -> fail(invalid_argument, utf8) end.
hex(Bytes) -> binary:encode_hex(Bytes, lowercase).
unhex(Value, Bound) when is_binary(Value), byte_size(Value) =< Bound * 2 ->
    try binary:decode_hex(Value) of
        Bytes -> case hex(Bytes) =:= Value of true -> Bytes; false -> fail(incompatible_native, hex) end
    catch _:_ -> fail(incompatible_native, hex) end;
unhex(_, _) -> fail(incompatible_native, hex).
wide(Value) -> decimal(Value, 0, 18446744073709551615).
signed(Value) -> decimal(Value, -9223372036854775808, 9223372036854775807).
decimal(Value, Min, Max) when is_binary(Value), byte_size(Value) =< 21 ->
    try binary_to_integer(Value) of
        N when N >= Min, N =< Max -> case integer_to_binary(N) =:= Value of true -> N; false -> fail(incompatible_native, decimal) end;
        _ -> fail(incompatible_native, decimal)
    catch _:_ -> fail(incompatible_native, decimal) end;
decimal(_, _, _) -> fail(incompatible_native, decimal).
native(Status, Detail, Phase) ->
    Code = case Detail of
        #{<<"protocol_error">> := V} when is_binary(V), byte_size(V) =< 256 -> V;
        #{<<"err">> := V} when is_binary(V), byte_size(V) =< 256 -> V;
        _ -> undefined
    end,
    Kind = case {Status, Code} of
        {_, <<"StaleActivation">>} -> stale_ownership;
        {_, <<"ProcessExpired">>} -> process_retired;
        {_, <<"ProcessTerminated">>} -> process_retired;
        {_, <<"HistoryReclaimed">>} -> history_unavailable;
        {_, <<"QueryExpired">>} -> history_unavailable;
        {3, _} -> authority_rejected; {4, _} -> access_denied;
        {5, _} -> authority_rejected; {6, _} -> unknown_outcome;
        {7, _} -> read_failed; {8, _} -> read_failed; {9, _} -> busy;
        {10, _} -> incompatible_native; {11, _} -> stale_ownership;
        {12, _} -> blocked; {13, _} -> turn_expired; {14, _} -> budget_exceeded;
        _ -> handler
    end,
    #transit_error{kind = Kind, status = Status, code = Code, phase = Phase}.
contract(App) ->
    case code:priv_dir(App) of
        Dir when is_list(Dir) ->
            case file:read_file(filename:join(Dir, "contract.json")) of
                {ok, Bytes} -> json(Bytes);
                _ -> fail(incompatible_native, contract)
            end;
        _ -> fail(incompatible_native, contract)
    end.
encode(Value) -> iolist_to_binary(json:encode(Value)).
json(Bytes) ->
    %% OTP callbacks bound depth and preserve duplicate-member errors before a
    %% map can overwrite data. Numeric ABI fields are integral, never floats.
    StartObject = fun({Depth, _}) when Depth < 64 -> {Depth + 1, #{}}; (_) -> erlang:error(depth) end,
    StartArray = fun({Depth, _}) when Depth < 64 -> {Depth + 1, []}; (_) -> erlang:error(depth) end,
    PushObject = fun(Key, Value, {Depth, Map}) ->
        case maps:is_key(Key, Map) of true -> erlang:error(duplicate); false -> {Depth, Map#{Key => Value}} end
    end,
    PushArray = fun(Value, {Depth, List}) -> {Depth, [Value | List]} end,
    FinishObject = fun({_, Map}, Parent) -> {Map, Parent} end,
    FinishArray = fun({_, List}, Parent) -> {lists:reverse(List), Parent} end,
    Integer = fun(Value) when byte_size(Value) =< 21 -> binary_to_integer(Value); (_) -> erlang:error(number) end,
    try json:decode(Bytes, {0, undefined}, #{object_start => StartObject, object_push => PushObject,
        object_finish => FinishObject, array_start => StartArray, array_push => PushArray,
        array_finish => FinishArray, integer => Integer, float => fun(_) -> erlang:error(fraction) end}) of
        {Value, _, Rest} -> case string:trim(Rest) of <<>> -> Value; _ -> fail(incompatible_native, json) end
    catch _:_ -> fail(incompatible_native, json) end.
require(Schema, Value) -> case valid(Schema, Value) of true -> Value; false -> fail(incompatible_native, schema) end.
valid(Schema, Value) ->
    Keywords = [<<"type">>, <<"properties">>, <<"additionalProperties">>, <<"required">>, <<"maxProperties">>,
        <<"anyOf">>, <<"oneOf">>, <<"enum">>, <<"minimum">>, <<"maximum">>, <<"maxLength">>, <<"pattern">>, <<"items">>, <<"minItems">>, <<"maxItems">>],
    lists:all(fun(Key) -> case Key of <<"x-transit-", _/binary>> -> true; _ -> lists:member(Key, Keywords) end end, maps:keys(Schema))
        andalso union(Schema, Value, <<"anyOf">>) andalso union(Schema, Value, <<"oneOf">>)
        andalso (not maps:is_key(<<"enum">>, Schema) orelse lists:member(Value, maps:get(<<"enum">>, Schema)))
        andalso typed(maps:get(<<"type">>, Schema, undefined), Schema, Value).
union(Schema, Value, Kind) ->
    case maps:find(Kind, Schema) of
        error -> true;
        {ok, Branches} -> Count = length([ok || Branch <- Branches, valid(Branch, Value)]),
            Count > 0 andalso (Kind =/= <<"oneOf">> orelse Count =:= 1)
    end.
typed(undefined, _, _) -> true;
typed(<<"null">>, _, V) -> V =:= null;
typed(<<"boolean">>, _, V) -> is_boolean(V);
typed(Type, S, V) when Type =:= <<"integer">>; Type =:= <<"number">> ->
    is_integer(V) andalso V >= maps:get(<<"minimum">>, S, V) andalso V =< maps:get(<<"maximum">>, S, V);
typed(<<"string">>, S, V) when is_binary(V) ->
    case unicode:characters_to_list(V) of
        List when is_list(List) -> length(List) =< maps:get(<<"maxLength">>, S, length(List)) andalso pattern(S, V);
        _ -> false
    end;
typed(<<"array">>, S, V) when is_list(V) ->
    length(V) >= maps:get(<<"minItems">>, S, 0) andalso length(V) =< maps:get(<<"maxItems">>, S, length(V))
        andalso lists:all(fun(E) -> valid(maps:get(<<"items">>, S), E) end, V);
typed(<<"object">>, S, V) when is_map(V) ->
    P = maps:get(<<"properties">>, S, #{}),
    map_size(V) =< maps:get(<<"maxProperties">>, S, map_size(V))
        andalso lists:all(fun(K) -> maps:is_key(K, V) end, maps:get(<<"required">>, S, []))
        andalso (maps:get(<<"additionalProperties">>, S, true) orelse lists:all(fun(K) -> maps:is_key(K, P) end, maps:keys(V)))
        andalso lists:all(fun({K, Child}) -> not maps:is_key(K, V) orelse valid(Child, maps:get(K, V)) end, maps:to_list(P));
typed(_, _, _) -> false.
pattern(S, V) ->
    case maps:find(<<"pattern">>, S) of
        error -> true;
        {ok, Pattern} -> re:run(V, <<"\\A(?:", Pattern/binary, ")\\z">>, [{capture, none}, {match_limit, 1000000}]) =:= match
    end.
