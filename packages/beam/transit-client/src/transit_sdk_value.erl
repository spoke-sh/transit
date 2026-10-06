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
        {6, _} -> unknown_outcome;
        {_, <<"StaleActivation">>} -> stale_ownership;
        {_, <<"ProcessExpired">>} -> process_retired;
        {_, <<"ProcessTerminated">>} -> process_retired;
        {_, <<"HistoryReclaimed">>} -> history_unavailable;
        {_, <<"QueryExpired">>} -> history_unavailable;
        {3, _} -> authority_rejected; {4, _} -> access_denied;
        {5, _} -> authority_rejected;
        {7, _} -> read_failed; {8, _} -> read_failed; {9, _} -> busy;
        {10, _} -> incompatible_native; {11, _} -> stale_ownership;
        {12, _} -> blocked; {13, _} -> turn_expired; {14, _} -> budget_exceeded;
        _ -> handler
    end,
    {Diagnostic, Invalid} = diagnostic(Detail),
    #transit_error{kind = Kind, status = Status, code = Code, phase = Phase,
                   diagnostic = Diagnostic, diagnostic_invalid = Invalid}.
diagnostic(#{<<"diagnostic">> := null}) -> {undefined, false};
diagnostic(#{<<"diagnostic">> := Candidate}) ->
    try
        Schema = maps:get(<<"Diagnostic">>, maps:get(<<"schemas">>, contract(transit_client))),
        case byte_size(encode(Candidate)) =< 32768 andalso valid(Schema, Candidate) of
            true -> {Candidate, false};
            false -> {undefined, true}
        end
    catch _:_ -> {undefined, true} end;
diagnostic(_) -> {undefined, false}.
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
    try valid(Schema, Value, maps:get(<<"$defs">>, Schema, #{}), #{}, 0, 0, true)
    catch _:_ -> false end.
%% Data depth and non-consuming reference/union hops are separate bounds.
%% BEAM values are immutable acyclic terms; references visited at this data node
%% must not be revisited before consuming an object/array child.
valid(S, V, Defs, Seen, Depth, Hops, Root) when is_map(S), is_map(Defs), Depth =< 128, Hops =< 128 ->
    Keywords = [<<"type">>, <<"properties">>, <<"additionalProperties">>, <<"required">>, <<"maxProperties">>,
        <<"anyOf">>, <<"oneOf">>, <<"enum">>, <<"const">>, <<"minimum">>, <<"maximum">>, <<"maxLength">>, <<"pattern">>, <<"items">>, <<"minItems">>, <<"maxItems">>, <<"$ref">>, <<"$defs">>],
    lists:all(fun(Key) -> case Key of <<"x-transit-", _/binary>> -> true; _ -> lists:member(Key, Keywords) end end, maps:keys(S))
        andalso (not maps:is_key(<<"$defs">>, S) orelse Root)
        andalso rule(S, V, Defs, Seen, Depth, Hops);
valid(_, _, _, _, _, _, _) -> false.
rule(#{<<"$ref">> := <<"#/$defs/", Name/binary>>} = S, V, Defs, Seen, Depth, Hops) ->
    lists:all(fun(K) -> K =:= <<"$ref">> orelse K =:= <<"$defs">> end, maps:keys(S))
        andalso reference_name(Name) andalso not maps:is_key(Name, Seen)
        andalso maps:is_key(Name, Defs)
        andalso valid(maps:get(Name, Defs), V, Defs, Seen#{Name => true}, Depth, Hops + 1, false);
rule(#{<<"$ref">> := _}, _, _, _, _, _) -> false;
rule(S, V, Defs, Seen, Depth, Hops) ->
    union(S, V, <<"anyOf">>, Defs, Seen, Depth, Hops)
        andalso union(S, V, <<"oneOf">>, Defs, Seen, Depth, Hops)
        andalso (not maps:is_key(<<"const">>, S) orelse V =:= maps:get(<<"const">>, S))
        andalso (not maps:is_key(<<"enum">>, S) orelse lists:member(V, maps:get(<<"enum">>, S)))
        andalso typed(maps:get(<<"type">>, S, undefined), S, V, Defs, Depth).
reference_name(<<>>) -> false;
reference_name(B) -> reference_tail(B).
reference_tail(<<>>) -> true;
reference_tail(<<C, Rest/binary>>) when C >= $A, C =< $Z; C >= $a, C =< $z; C >= $0, C =< $9; C =:= $_ -> reference_tail(Rest);
reference_tail(_) -> false.
union(S, V, Kind, Defs, Seen, Depth, Hops) ->
    case maps:find(Kind, S) of
        error -> true;
        {ok, Branches} when is_list(Branches), Branches =/= [] ->
            Count = length([ok || Branch <- Branches, valid(Branch, V, Defs, Seen, Depth, Hops + 1, false)]),
            Count > 0 andalso (Kind =/= <<"oneOf">> orelse Count =:= 1);
        _ -> false
    end.
typed(undefined, _, _, _, _) -> true;
typed(<<"null">>, _, V, _, _) -> V =:= null;
typed(<<"boolean">>, _, V, _, _) -> is_boolean(V);
typed(Type, S, V, _, _) when Type =:= <<"integer">>; Type =:= <<"number">> ->
    is_integer(V) andalso V >= maps:get(<<"minimum">>, S, V) andalso V =< maps:get(<<"maximum">>, S, V);
typed(<<"string">>, S, V, _, _) when is_binary(V) ->
    utf8_bound(V, maps:get(<<"maxLength">>, S, byte_size(V))) andalso pattern(S, V);
typed(<<"array">>, S, V, Defs, Depth) when is_list(V) ->
    length(V) >= maps:get(<<"minItems">>, S, 0) andalso length(V) =< maps:get(<<"maxItems">>, S, length(V))
        andalso lists:all(fun(E) -> valid(maps:get(<<"items">>, S), E, Defs, #{}, Depth + 1, 0, false) end, V);
typed(<<"object">>, S, V, Defs, Depth) when is_map(V) ->
    P = maps:get(<<"properties">>, S, #{}),
    map_size(V) =< maps:get(<<"maxProperties">>, S, map_size(V))
        andalso lists:all(fun(K) -> maps:is_key(K, V) end, maps:get(<<"required">>, S, []))
        andalso (maps:get(<<"additionalProperties">>, S, true) orelse lists:all(fun(K) -> maps:is_key(K, P) end, maps:keys(V)))
        andalso lists:all(fun({K, Child}) -> not maps:is_key(K, V) orelse valid(Child, maps:get(K, V), Defs, #{}, Depth + 1, 0, false) end, maps:to_list(P));
typed(_, _, _, _, _) -> false.
%% Count Unicode scalars without materializing a list proportional to a large
%% hexadecimal/binary payload. The generated hex pattern is checked linearly.
utf8_bound(<<>>, N) -> is_integer(N) andalso N >= 0;
utf8_bound(<<_/utf8, Rest/binary>>, N) when is_integer(N), N > 0 -> utf8_bound(Rest, N - 1);
utf8_bound(_, _) -> false.
hex_pattern(<<>>) -> true;
hex_pattern(<<A, B, Rest/binary>>) when ((A >= $0 andalso A =< $9) orelse (A >= $a andalso A =< $f)),
                                      ((B >= $0 andalso B =< $9) orelse (B >= $a andalso B =< $f)) -> hex_pattern(Rest);
hex_pattern(_) -> false.
pattern(S, V) ->
    case maps:find(<<"pattern">>, S) of
        error -> true;
        {ok, <<"^(?:[0-9a-f]{2})*$">>} -> hex_pattern(V);
        {ok, Pattern} -> re:run(V, <<"\\A(?:", Pattern/binary, ")\\z">>, [{capture, none}, {match_limit, 1000000}]) =:= match
    end.
