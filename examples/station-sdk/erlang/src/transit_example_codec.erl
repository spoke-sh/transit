%% Versioned application formats shared by the public SDK examples.
-module(transit_example_codec).
-export([encode/2, decode/2, allowed/2]).
encode(u64, Value) when is_integer(Value), Value >= 0, Value =< 18446744073709551615 -> {ok, <<"TSU", 1, Value:64/little-unsigned>>};
encode(counter, {add, Value}) when is_integer(Value), Value >= 0, Value =< 18446744073709551615 -> {ok, <<"TSC", 1, 1, Value:64/little-unsigned>>};
encode(counter, read) -> {ok, <<"TSC", 1, 2>>};
encode(counter, start) -> {ok, <<"TSC", 1, 3>>};
encode(counter, {total, Value}) when is_integer(Value), Value >= 0, Value =< 18446744073709551615 -> {ok, <<"TSC", 1, 4, Value:64/little-unsigned>>};
encode(query, initialize) -> {ok, <<"TSQ", 1, 1>>};
encode(query, {insert, Key, null}) when is_integer(Key), Key >= -9223372036854775808, Key =< 9223372036854775807 -> {ok, <<"TSQ", 1, 2, Key:64/little-signed, 0>>};
encode(query, {insert, Key, Value}) when is_integer(Key), Key >= -9223372036854775808, Key =< 9223372036854775807,
    is_integer(Value), Value >= -9223372036854775808, Value =< 9223372036854775807 -> {ok, <<"TSQ", 1, 2, Key:64/little-signed, 1, Value:64/little-signed>>};
encode(query, rows) -> {ok, <<"TSQ", 1, 3>>};
encode(query, start) -> {ok, <<"TSQ", 1, 4>>};
encode(_, _) -> {error, invalid_application_value}.
decode(u64, <<"TSU", 1, Value:64/little-unsigned>>) -> {ok, Value};
decode(counter, <<"TSC", 1, 1, Value:64/little-unsigned>>) -> {ok, {add, Value}};
decode(counter, <<"TSC", 1, 2>>) -> {ok, read};
decode(counter, <<"TSC", 1, 3>>) -> {ok, start};
decode(counter, <<"TSC", 1, 4, Value:64/little-unsigned>>) -> {ok, {total, Value}};
decode(query, <<"TSQ", 1, 1>>) -> {ok, initialize};
decode(query, <<"TSQ", 1, 2, Key:64/little-signed, 0>>) -> {ok, {insert, Key, null}};
decode(query, <<"TSQ", 1, 2, Key:64/little-signed, 1, Value:64/little-signed>>) -> {ok, {insert, Key, Value}};
decode(query, <<"TSQ", 1, 3>>) -> {ok, rows};
decode(query, <<"TSQ", 1, 4>>) -> {ok, start};
decode(_, _) -> {error, malformed_application_payload}.
allowed(counter, {add, _}) -> true;
allowed(counter, read) -> true;
allowed(requester, start) -> true;
allowed(requester, {total, _}) -> true;
allowed(reply, {total, _}) -> true;
allowed(query_service, initialize) -> true;
allowed(query_service, {insert, _, _}) -> true;
allowed(query_service, rows) -> true;
allowed(query_requester, start) -> true;
allowed(u64, Value) -> is_integer(Value) andalso Value >= 0 andalso Value =< 18446744073709551615;
allowed(_, _) -> false.
