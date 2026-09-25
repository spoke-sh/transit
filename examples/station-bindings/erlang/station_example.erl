-module(station_example).
-export([main/1]).
main([Config, Role, PeerText]) ->
    {ok, Host} = transit_station:open(os:getenv("TRANSIT_HOST"), Config),
    try loop(Host, Role, list_to_integer(PeerText))
    after transit_station:close(Host) end.
ok_apply(Host, Action) -> {ok, _} = transit_station:apply(Host, Action), ok.
loop(Host, Role, Peer) ->
    {ok, Event} = transit_station:next(Host),
    case maps:get(<<"event">>, Event) of
        <<"committed">> -> ok;
        <<"progress">> -> loop(Host, Role, Peer);
        <<"ready">> ->
            case maps:get(<<"initializing">>, Event) of
                true ->
                    ok_apply(Host, #{<<"table_create">> => #{<<"id">> => 1,
                        <<"key_name">> => <<"id">>, <<"value_name">> => <<"value">>, <<"value_type">> => <<"int64">>}}),
                    case Role of
                        "service" ->
                            ok_apply(Host, #{<<"query_policy">> => #{<<"peer">> => Peer, <<"table">> => 1,
                                <<"expected_revision">> => 0, <<"allow">> => true}}),
                            ok_apply(Host, #{<<"table_write">> => #{<<"id">> => 1, <<"mode">> => <<"insert">>,
                                <<"row">> => #{<<"key">> => <<"1">>, <<"value">> => #{<<"int64">> => <<"9007199254740993">>}}}});
                        "requester" -> ok
                    end;
                false -> ok
            end,
            handle(Host, maps:get(<<"input">>, Event), Peer),
            {ok, _} = transit_station:finish(Host, false), loop(Host, Role, Peer);
        Other -> error({unexpected_event, Other})
    end.
handle(_, #{<<"payload">> := <<"696e6974">>}, _) -> ok;
handle(Host, #{<<"kind">> := <<"cast">>}, Peer) ->
    ok_apply(Host, #{<<"call">> => #{<<"pid">> => Peer, <<"value">> => <<"7175657279">>}});
handle(Host, #{<<"kind">> := <<"call">>}, _) -> ok_apply(Host, #{<<"query_reply">> => #{<<"id">> => 1}});
handle(Host, #{<<"kind">> := <<"result_complete">>, <<"correlation">> := Correlation}, _) ->
    {ok, #{<<"arrow">> := Hex}} = transit_station:apply(Host, #{<<"query_result">> => Correlation}),
    Ipc = binary:decode_hex(Hex),
    {ok, #{<<"value">> := #{<<"int64">> := Text}}} = transit_station:arrow_cell(Host, Ipc, 0, 1),
    9007199254740993 = binary_to_integer(Text),
    ok_apply(Host, #{<<"put">> => #{<<"key">> => <<"6f62736572766564">>,
        <<"value">> => binary:encode_hex(Text, lowercase)}}).
