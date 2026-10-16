%% Scoped host helpers. Every read/codec is guarded for its entire operation.
-module(transit_turn).
-include("transit_station_sdk.hrl").
-export([open_scope/4, end_scope/1, access/3, check/1, raw/2, data/1, limit/2,
         process/1, resource/1, resource_revision/1, budgets/1, key/2, state/1,
         find/2, require/2, put/3, delete/2, page/1, page/2, retain/1,
         open_version/2, source_state/1, release/2, cast/4, call/5, reply/3,
         require_reply/4, cancel_call/2, peer/2, version/1]).
-export_type([turn/0, state/0, source/0]).
-opaque turn() :: {transit_turn, pid(), reference(), atomics:atomics_ref()}.
-opaque state() :: {transit_state, turn(), undefined | #transit_read_version{}}.
-opaque source() :: {transit_source, turn(), #transit_read_version{}}.
open_scope(Bridge, Event, Process, Stop) ->
    Ref = make_ref(), Life = atomics:new(1, [{signed, false}]), atomics:put(Life, 1, 1),
    erlang:put(Ref, #{bridge => Bridge, event => Event, process => Process, stop => Stop, busy => false, poison => undefined}),
    {transit_turn, self(), Ref, Life}.
end_scope({transit_turn, _, Ref, Life}) ->
    atomics:put(Life, 1, 0), Context = erase(Ref), maps:get(poison, Context).
check({transit_turn, Owner, Ref, Life}) ->
    case atomics:get(Life, 1) of 0 -> transit_sdk_value:fail(turn_expired, turn_scope); _ -> ok end,
    case Owner =:= self() of true -> ok; false -> transit_sdk_value:fail(busy, turn_owner) end,
    Context = erlang:get(Ref),
    case maps:get(busy, Context) of true -> transit_sdk_value:fail(busy, turn_reentry); false -> ok end,
    case transit_sdk_worker:stopped(maps:get(stop, Context)) of true -> transit_sdk_value:fail(closed, turn_stop); false -> ok end,
    case maps:get(poison, Context) of undefined -> ok; Error -> throw({transit_sdk, Error}) end.
data({transit_turn, _, Ref, _}) -> erlang:get(Ref).
access(Turn, Read, Fun) ->
    transit_sdk_value:protect(fun() ->
        check(Turn), {transit_turn, _, Ref, _} = Turn,
        erlang:put(Ref, (data(Turn))#{busy := true}),
        try Fun() catch Class:Reason ->
            Error = case {Class, Reason} of {throw, {transit_sdk, Known}} -> Known; _ -> transit_sdk_value:error(handler, turn_operation) end,
            case Read of true -> erlang:put(Ref, (data(Turn))#{poison := Error}); false -> ok end,
            throw({transit_sdk, Error})
        after erlang:put(Ref, (data(Turn))#{busy := false}) end
    end).
raw(Turn, Action) -> Context = data(Turn), Event = maps:get(event, Context),
    transit_station_bridge:apply(maps:get(bridge, Context), maps:get(<<"scope">>, Event), Action).
limit(Turn, Key) -> maps:get(Key, transit_station_bridge:caps(maps:get(bridge, data(Turn)))).
process(Turn) -> access(Turn, false, fun() -> maps:get(process, data(Turn)) end).
resource(Turn) -> access(Turn, false, fun() ->
    #transit_process{realm = Realm} = maps:get(process, data(Turn)),
    #transit_resource{realm = Realm, resource = maps:get(<<"resource">>, maps:get(event, data(Turn)))} end).
resource_revision(Turn) -> access(Turn, false, fun() -> maps:get(<<"resource_revision">>, maps:get(event, data(Turn))) end).
budgets(Turn) -> access(Turn, false, fun() ->
    Value = maps:get(<<"budgets">>, raw(Turn, #{<<"budgets">> => #{}})),
    #{mutations => maps:get(<<"mutations">>, Value), outputs => maps:get(<<"outputs">>, Value), views => maps:get(<<"views">>, Value),
      retained_reads => maps:get(<<"retained_reads">>, Value), retains => maps:get(<<"retains">>, Value), releases => maps:get(<<"releases">>, Value)} end).
key(Name, Codec) -> transit_sdk_value:protect(fun() ->
    Bytes = transit_sdk_value:bytes(Name, 262144),
    case Bytes of <<First, _/binary>> when First =/= 0, is_atom(Codec) -> #transit_key{name = Bytes, codec = Codec}; _ -> transit_sdk_value:fail(invalid_argument, key) end end).
state(Turn) -> access(Turn, false, fun() -> {transit_state, Turn, undefined} end).
name(Turn, #transit_key{name = Name}) ->
    case Name of <<First, _/binary>> when First =/= 0 -> transit_sdk_value:hex(transit_sdk_value:bytes(Name, limit(Turn, <<"key_bytes">>))); _ -> transit_sdk_value:fail(invalid_argument, key) end.
find({transit_state, Turn, Version}, #transit_key{codec = Codec} = Key) -> access(Turn, true, fun() ->
    Name = name(Turn, Key), Request = case Version of undefined -> #{<<"get">> => Name}; _ -> #{<<"version_get">> => #{<<"id">> => version(Version), <<"key">> => Name}} end,
    case maps:get(<<"value">>, raw(Turn, Request)) of null -> missing;
        Value -> {found, transit_station_value:decode(Codec, transit_sdk_value:unhex(Value, limit(Turn, <<"value_bytes">>)), limit(Turn, <<"value_bytes">>))} end end).
require(State, Key) -> case find(State, Key) of {ok, {found, Value}} -> {ok, Value}; {ok, missing} -> {error, transit_sdk_value:error(missing_value, state_require)}; Error -> Error end.
put({transit_state, Turn, Version}, #transit_key{codec = Codec} = Key, Value) -> access(Turn, false, fun() ->
    writable(Version), Name = name(Turn, Key), Bytes = transit_station_value:encode(Codec, Value, limit(Turn, <<"value_bytes">>)),
    raw(Turn, #{<<"put">> => #{<<"key">> => Name, <<"value">> => transit_sdk_value:hex(Bytes)}}), ok end).
delete({transit_state, Turn, Version}, Key) -> access(Turn, false, fun() -> writable(Version), raw(Turn, #{<<"delete">> => name(Turn, Key)}), ok end).
writable(undefined) -> ok;
writable(_) -> transit_sdk_value:fail(handler, retained_source_read_only).
page(State) -> page(State, undefined).
page({transit_state, Turn, Version}, Cursor) -> access(Turn, true, fun() ->
    Next = transit_station_value:cursor(Cursor),
    Request = case Version of undefined -> #{<<"page">> => Next}; _ -> #{<<"version_page">> => #{<<"id">> => version(Version), <<"cursor">> => Next}} end,
    Value = maps:get(<<"page">>, raw(Turn, Request)),
    Entries = [#transit_kv_entry{key = transit_sdk_value:unhex(maps:get(<<"key">>, Entry), limit(Turn, <<"key_bytes">>)),
        value = transit_sdk_value:unhex(maps:get(<<"value">>, Entry), limit(Turn, <<"value_bytes">>)), revision = maps:get(<<"revision">>, Entry)}
        || Entry <- maps:get(<<"entries">>, Value), Entry =/= null],
    #transit_page{entries = Entries, cursor = transit_station_value:cursor(maps:get(<<"next">>, Value))} end).
version(Identity) -> transit_station_value:version_wire(Identity).
retain(Turn) -> access(Turn, false, fun() -> transit_station_value:version(maps:get(<<"version">>, raw(Turn, #{<<"retain">> => #{}}))) end).
open_version(Turn, Identity) -> access(Turn, false, fun() -> version(Identity), {transit_source, Turn, Identity} end).
source_state({transit_source, Turn, Identity}) -> access(Turn, false, fun() -> {transit_state, Turn, Identity} end).
release(Turn, Identity) -> access(Turn, false, fun() -> raw(Turn, #{<<"release">> => version(Identity)}), ok end).
peer(Turn, #transit_process{realm = Realm, pid = Pid}) ->
    case maps:get(process, data(Turn)) of #transit_process{realm = Realm} -> transit_sdk_value:counter(Pid); _ -> transit_sdk_value:fail(invalid_argument, peer_realm) end.
cast(Turn, Peer, Value, Codec) -> access(Turn, false, fun() ->
    Pid = peer(Turn, Peer), Bytes = transit_station_value:encode(Codec, Value, limit(Turn, <<"message_bytes">>)),
    raw(Turn, #{<<"cast">> => #{<<"pid">> => Pid, <<"value">> => transit_sdk_value:hex(Bytes)}}), ok end).
call(Turn, Peer, Value, Codec, Wait) -> access(Turn, false, fun() ->
    Pid = peer(Turn, Peer), {Deadline, Observer} = case Wait of untimed -> {null, null}; {until, At, Who} -> {transit_sdk_value:counter(At), peer(Turn, Who)} end,
    Bytes = transit_station_value:encode(Codec, Value, limit(Turn, <<"message_bytes">>)),
    Result = raw(Turn, #{<<"call">> => #{<<"pid">> => Pid, <<"value">> => transit_sdk_value:hex(Bytes), <<"deadline_ms">> => Deadline, <<"observer">> => Observer}}),
    positive(transit_sdk_value:wide(maps:get(<<"correlation">>, Result))) end).
reply(Turn, Value, Codec) -> access(Turn, false, fun() ->
    Bytes = transit_station_value:encode(Codec, Value, limit(Turn, <<"message_bytes">>)), raw(Turn, #{<<"reply">> => transit_sdk_value:hex(Bytes)}), ok end).
require_reply(Turn, #transit_incoming{kind = reply, correlation = Correlation, position = Position}, Peer, Correlation) -> access(Turn, false, fun() ->
    Pid = peer(Turn, Peer), positive(Correlation), Input = maps:get(<<"input">>, maps:get(event, data(Turn))),
    case Input of #{<<"kind">> := <<"reply">>, <<"position">> := Position, <<"origin">> := #{<<"process">> := #{<<"pid">> := Pid}}, <<"correlation">> := Corr} ->
        case transit_sdk_value:wide(Corr) =:= Correlation of true -> ok; false -> transit_sdk_value:fail(handler, reply_identity) end;
        _ -> transit_sdk_value:fail(handler, reply_identity) end end);
require_reply(Turn, _, _, _) -> access(Turn, false, fun() -> transit_sdk_value:fail(handler, reply_identity) end).
cancel_call(Turn, Correlation) -> access(Turn, false, fun() -> maps:get(<<"cancelled">>, raw(Turn, #{<<"cancel">> => transit_station_value:decimal(positive(Correlation))})) end).
positive(Value) -> transit_sdk_value:integer(Value, 1, 18446744073709551615).
