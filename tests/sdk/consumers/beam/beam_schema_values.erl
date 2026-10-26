%% Independent recursive contract fixtures for the installed public package.
-module(beam_schema_values).
-export([run/0]).
json(B) -> transit_sdk_value:json(B).
valid(S, V) -> transit_sdk_value:valid(S, V).
ref(Name) -> #{<<"$ref">> => <<"#/$defs/", Name/binary>>}.
run() ->
    S = json(<<"{\"$ref\":\"#/$defs/Cell\",\"$defs\":{\"Cell\":{\"oneOf\":[{\"type\":\"null\"},{\"type\":\"integer\",\"minimum\":-128,\"maximum\":127},{\"type\":\"array\",\"items\":{\"$ref\":\"#/$defs/Cell\"},\"maxItems\":4}]}}}">>),
    true = valid(S, [1,[null,[-128,127]],[]]),
    lists:foreach(fun(V) -> false = valid(S,V) end, [128,-129,<<"1">>,[1,2,3,4,5],[1,[true]]]),
    Other = (ref(<<"Cell">>))#{<<"$defs">> => #{<<"Cell">> => #{<<"type">> => <<"object">>, <<"additionalProperties">> => false}}},
    true = valid(Other,#{}), false = valid(Other,1), false = valid(S,#{}),
    lists:foreach(fun(B) -> false = valid(json(B),null) end, [
        <<"{\"$ref\":\"https://example.invalid/schema\"}">>,
        <<"{\"$ref\":\"#/$defs/Missing\",\"$defs\":{}}">>,
        <<"{\"$ref\":\"#/$defs/X\",\"const\":null,\"$defs\":{\"X\":{\"type\":\"null\"}}}">>,
        <<"{\"$ref\":\"#/$defs/X\",\"$defs\":{\"X\":{\"$ref\":\"#/$defs/X\"}}}">>,
        <<"{\"$ref\":\"#/$defs/X\",\"$defs\":{\"X\":{\"anyOf\":[{\"$ref\":\"#/$defs/X\"},{\"$ref\":\"#/$defs/X\"}]}}}">>,
        <<"{\"$ref\":\"#/$defs/X\",\"$defs\":{\"X\":{\"unknown\":true}}}">>,
        <<"{\"anyOf\":[]}">>, <<"{\"oneOf\":[]}">>, <<"{\"$defs\":null}">>,
        <<"{\"anyOf\":[{\"$defs\":{},\"type\":\"null\"}]}">>
    ]),
    Deep = lists:foldl(fun(_,V) -> [V] end,null,lists:seq(1,129)), false = valid(S,Deep),
    Defs = maps:from_list([{integer_to_binary(I),ref(integer_to_binary(I+1))} || I <- lists:seq(0,199)]),
    false = valid((ref(<<"0">>))#{<<"$defs">> => Defs#{<<"200">> => #{<<"type">> => <<"null">>}}},null),
    %% References recurse only after consuming a child; nullable termination works.
    true = valid(S,lists:foldl(fun(_,V) -> [V] end,null,lists:seq(1,64))),
    Hex = #{<<"type">> => <<"string">>, <<"pattern">> => <<"^(?:[0-9a-f]{2})*$">>, <<"maxLength">> => 800000},
    true = valid(Hex,binary:copy(<<"ab">>,300000)),
    false = valid(Hex,<<"abc">>), false = valid(Hex,<<"AB">>), false = valid(Hex,<<255>>),
    true = valid(#{<<"type">> => <<"string">>, <<"maxLength">> => 2},<<"東京"/utf8>>),
    false = valid(#{<<"type">> => <<"string">>, <<"maxLength">> => 1},<<"東京"/utf8>>),
    ok.
