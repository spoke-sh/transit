%% Public owned HTTP values; shared Zig owns encoding, publication and replay.
-module(transit_http).
-include("transit_station_sdk.hrl").
-export([prepare/5, prepare/6, decode_reply/2, decode_reply/3, stage/2, call/3,
         release/4, open/2, open/3, read/1, complete/1, close/1, part/2]).
-export_type([reader/0, piece/0]).
-opaque reader() :: {transit_http_reader, transit_station_sdk:runner(), pos_integer(), non_neg_integer(), boolean()}.
-type piece() :: {literal, binary()} | {variable, binary(), binary()} | {secret, binary(), pos_integer()}.
prepare(Resource, Namespace, Request, Body, Options) -> prepare(Resource, Namespace, Request, Body, Options, undefined).
prepare(#transit_resource{realm = Realm, resource = Resource} = Ref, Namespace, #transit_http_request{method = Method, target = Target, headers = Headers}, Body, Options, Override) ->
    transit_sdk_value:protect(fun() ->
        transit_sdk_value:counter(Realm), transit_sdk_value:counter(Resource), positive(Namespace),
        Bytes = transit_sdk_value:bytes(Body, 65536),
        true = lists:member(Method, [get, head, post, put, patch, delete, options]),
        true = is_list(Headers) andalso length(Headers) =< 64,
        Request = #{<<"method">> => string:uppercase(atom_to_binary(Method, utf8)), <<"target">> => pieces(Target),
            <<"headers">> => [#{<<"name">> => transit_sdk_value:text(Name, 8192), <<"value">> => pieces(Value)} || {Name, Value} <- Headers]},
        true = length(maps:get(<<"headers">>, Request)) =:= length(Headers),
        Revision = positive(maps:get(endpoint_revision, Options)), Deadline = transit_sdk_value:counter(maps:get(reconcile_before_ms, Options)),
        Attempts = transit_sdk_value:integer(maps:get(max_attempts, Options, 1), 1, 4294967295),
        #{<<"prepared">> := Prepared} = local(#{<<"prepare">> => #{<<"resource">> => Resource, <<"namespace">> => integer_to_binary(Namespace),
            <<"request">> => Request, <<"body">> => transit_sdk_value:hex(Bytes), <<"endpoint_revision">> => integer_to_binary(Revision),
            <<"reconcile_before_ms">> => Deadline, <<"max_attempts">> => Attempts}}, Override),
        #transit_http_prepared{resource = Ref, namespace = Namespace, reference = transit_sdk_value:unhex(maps:get(<<"reference">>, Prepared), 112),
            metadata = transit_sdk_value:unhex(maps:get(<<"metadata">>, Prepared), 8192), body = Bytes}
    end);
prepare(_, _, _, _, _, _) -> {error, transit_sdk_value:error(invalid_argument, http_request)}.
pieces(Values) when is_list(Values), length(Values) =< 128 -> [piece(Value) || Value <- Values];
pieces(_) -> transit_sdk_value:fail(invalid_argument, http_pieces).
piece({literal, Value}) -> #{<<"literal">> => transit_sdk_value:text(Value, 8192)};
piece({variable, Name, Value}) -> #{<<"variable">> => #{<<"name">> => transit_sdk_value:text(Name, 128), <<"value">> => transit_sdk_value:text(Value, 8192)}};
piece({secret, Binding, Version}) -> #{<<"secret">> => #{<<"binding">> => transit_sdk_value:text(Binding, 128), <<"version">> => integer_to_binary(positive(Version))}};
piece(_) -> transit_sdk_value:fail(invalid_argument, http_piece).
positive(Value) -> transit_sdk_value:integer(Value, 1, 18446744073709551615).
local(Action, Override) -> local(Action, Override, <<"http_requests">>).
local(Action, Override, Capability) ->
    case transit_sdk_worker:open(transit_station_runner, {local, Override}, false) of
        {ok, Worker} ->
            try
                case transit_sdk_worker:invoke(Worker, {http_codec, Action, Capability}) of
                    {ok, Result} -> Result;
                    {error, Error} -> throw({transit_sdk, Error})
                end
            after transit_sdk_worker:close(Worker) end;
        {error, Error} -> throw({transit_sdk, Error})
    end.
decode_reply(Realm, Bytes) -> decode_reply(Realm, Bytes, undefined).
decode_reply(Realm, Bytes, Override) -> transit_sdk_value:protect(fun() ->
    transit_sdk_value:counter(Realm),
    Owned = transit_sdk_value:bytes(Bytes, 71),
    Capability = case Owned of <<"HTK1", _/binary>> -> <<"http_release">>; _ -> <<"http_requests">> end,
    Value = local(#{<<"outcome">> => transit_sdk_value:hex(Owned)}, Override, Capability),
    case Value of
        #{<<"rejected">> := Rejection} -> #transit_http_rejected{reason = known(Rejection, [denied, invalid_request, busy])};
        #{<<"released">> := Released} -> #transit_http_released{
            resource = #transit_resource{realm = Realm, resource = transit_sdk_value:counter(maps:get(<<"resource">>, Released))},
            exchange = positive(transit_sdk_value:wide(maps:get(<<"exchange">>, Released)))};
        #{<<"outcome">> := Result} ->
            #transit_http_outcome{phase = known(maps:get(<<"phase">>, Result), [observed, closed_unknown, not_dispatched]),
                resource = #transit_resource{realm = Realm, resource = transit_sdk_value:counter(maps:get(<<"resource">>, Result))},
                exchange = positive(transit_sdk_value:wide(maps:get(<<"exchange">>, Result))), effect = transit_sdk_value:counter(maps:get(<<"effect">>, Result), 0),
                attempt = transit_sdk_value:counter(maps:get(<<"attempt">>, Result), 0),
                status = case maps:get(<<"status">>, Result) of null -> undefined; Code -> transit_sdk_value:integer(Code, 200, 599) end,
                reference = case maps:get(<<"reference">>, Result) of null -> undefined; Ref -> transit_sdk_value:unhex(Ref, 256) end}
    end end).
known(Value, Allowed) ->
    case [Atom || Atom <- Allowed, atom_to_binary(Atom, utf8) =:= Value] of [Result] -> Result; _ -> transit_sdk_value:fail(incompatible_native, http_enum) end.
scope(Turn, #transit_http_prepared{resource = #transit_resource{realm = Realm, resource = Resource}}) ->
    #{process := #transit_process{realm = Realm}, event := #{<<"resource">> := Resource}, bridge := Bridge} = transit_turn:data(Turn),
    case maps:get(<<"http_requests">>, transit_station_bridge:caps(Bridge)) of true -> ok; false -> transit_sdk_value:fail(unsupported_capability, http_requests) end.
stage(Turn, #transit_http_prepared{reference = Reference, metadata = Metadata, body = Body} = Request) -> transit_turn:access(Turn, false, fun() ->
    scope(Turn, Request),
    Result = transit_turn:raw(Turn, #{<<"http_stage">> => #{<<"reference">> => transit_sdk_value:hex(transit_sdk_value:bytes(Reference, 112)),
        <<"metadata">> => transit_sdk_value:hex(transit_sdk_value:bytes(Metadata, 8192)), <<"body">> => transit_sdk_value:hex(transit_sdk_value:bytes(Body, 65536))}}),
    transit_sdk_value:boolean(maps:get(<<"staged">>, Result)) end).
call(Turn, Peer, #transit_http_prepared{reference = Reference} = Request) -> transit_turn:access(Turn, false, fun() ->
    scope(Turn, Request),
    Result = transit_turn:raw(Turn, #{<<"http_call">> => #{<<"pid">> => transit_turn:peer(Turn, Peer), <<"reference">> => transit_sdk_value:hex(transit_sdk_value:bytes(Reference, 112))}}),
    positive(transit_sdk_value:wide(maps:get(<<"correlation">>, Result))) end).
release(Turn, Peer, Capture, Exchange) -> transit_turn:access(Turn, false, fun() ->
    #{process := #transit_process{realm = Realm}, bridge := Bridge} = transit_turn:data(Turn),
    Resource = case Capture of #transit_resource{realm = Realm, resource = Id} -> transit_sdk_value:counter(Id);
        _ -> transit_sdk_value:fail(invalid_argument, http_release_resource) end,
    positive(Exchange),
    case maps:get(<<"http_release">>, transit_station_bridge:caps(Bridge), false) of
        true -> ok; false -> transit_sdk_value:fail(unsupported_capability, http_release) end,
    Result = transit_turn:raw(Turn, #{<<"http_release">> => #{<<"pid">> => transit_turn:peer(Turn, Peer),
        <<"resource">> => Resource, <<"exchange">> => integer_to_binary(Exchange)}}),
    positive(transit_sdk_value:wide(maps:get(<<"correlation">>, Result))) end).
open(Runner, Outcome) -> open(Runner, Outcome, captured).
open(Runner, #transit_http_outcome{phase = observed, resource = #transit_resource{realm = Realm}, reference = Reference}, Policy) ->
    case transit_sdk_value:protect(fun() -> {transit_sdk_value:bytes(Reference, 256), transit_station_value:enum(Policy, [captured, require_unredacted])} end) of
        {ok, {Ref, Mode}} -> case transit_sdk_worker:invoke(Runner, {http, {open, Realm, Ref, Mode}}) of
            {ok, {Id, Step}} -> {ok, {transit_http_reader, Runner, Id, Step, false}};
            Error -> Error end;
        Error -> Error
    end;
open(_, _, _) -> {error, transit_sdk_value:error(invalid_argument, http_outcome)}.
read({transit_http_reader, Runner, Id, Step, _}) ->
    case transit_sdk_worker:invoke(Runner, {http, {next, Id, Step}}) of
        {ok, {Part, Next, Complete}} -> {ok, {Part, {transit_http_reader, Runner, Id, Next, Complete}}};
        Error -> Error
    end.
complete({transit_http_reader, _, _, _, Complete}) -> Complete.
close({transit_http_reader, Runner, Id, _, _}) -> transit_sdk_worker:invoke(Runner, {http, {close, Id}}).
part(#{<<"part">> := null}, true) -> {done, true};
part(#{<<"part">> := #{<<"kind">> := Kind, <<"bytes">> := Bytes, <<"complete">> := Complete}}, _) ->
    Part = #transit_http_part{kind = known(Kind, [request_template, request_head, request_body, response_head, response_body, response_trailers, timing, omission, completion]),
        bytes = transit_sdk_value:unhex(Bytes, 256), complete = transit_sdk_value:boolean(Complete)},
    {Part, Complete};
part(_, _) -> transit_sdk_value:fail(incompatible_native, http_incomplete).
