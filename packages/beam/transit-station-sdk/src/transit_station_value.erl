-module(transit_station_value).
-include("transit_station_sdk.hrl").
-export([bound/2, encode/3, decode/3, origin/2, version/1, version_wire/1, basis/2,
         digest/1, cursor/1, cell/3, cell_value/2, decimal/1, signed/1, enum/2]).
bound(Codec, Limit) ->
    try
        Id = transit_sdk_value:text(Codec:type_id(), 256), true = byte_size(Id) > 0,
        transit_sdk_value:integer(Codec:version(), 1, 4294967295),
        transit_sdk_value:integer(Codec:max_encoded_bytes(), 1, Limit)
    catch _:_ -> transit_sdk_value:fail(codec, application_codec) end.
encode(Codec, Value, Limit) ->
    try Maximum = bound(Codec, Limit), {ok, Bytes} = Codec:encode(Value), transit_sdk_value:bytes(Bytes, Maximum)
    catch _:_ -> transit_sdk_value:fail(codec, application_codec) end.
decode(Codec, Bytes, Limit) ->
    try Input = transit_sdk_value:bytes(Bytes, bound(Codec, Limit)), {ok, Value} = Codec:decode(Input), Value
    catch _:_ -> transit_sdk_value:fail(codec, application_codec) end.
origin(#{<<"external">> := #{<<"principal">> := P, <<"policy_revision">> := R}}, _) -> {external, #{principal => P, policy_revision => R}};
origin(#{<<"process">> := #{<<"pid">> := P, <<"turn">> := T, <<"output">> := O}}, Realm) -> {process, #{process => #transit_process{realm = Realm, pid = P}, turn => T, output => O}};
origin(#{<<"effect">> := #{<<"id">> := I, <<"attempt">> := A, <<"executor">> := E}}, _) -> {effect, #{effect => I, attempt => A, executor => E}};
origin(_, _) -> transit_sdk_value:fail(incompatible_native, origin).
version(#{<<"pid">> := P, <<"input">> := I, <<"index">> := X}) -> #transit_read_version{pid = P, input = I, index = X}.
version_wire(#transit_read_version{pid = P, input = I, index = X}) -> #{<<"pid">> => transit_sdk_value:counter(P), <<"input">> => transit_sdk_value:counter(I), <<"index">> => transit_sdk_value:integer(X, 0, 255)}.
basis(#{<<"resource">> := R, <<"revision">> := V, <<"schema">> := S}, Realm) -> #transit_basis{resource = #transit_resource{realm = Realm, resource = R}, revision = V, schema = digest(S)}.
digest(Value) when is_list(Value), length(Value) =:= 32 -> list_to_binary([transit_sdk_value:integer(X, 0, 255) || X <- Value]);
digest(_) -> transit_sdk_value:fail(incompatible_native, digest).
cursor(null) -> undefined;
cursor(undefined) -> null;
cursor(Value) -> transit_sdk_value:text(Value, 262144).
decimal(Value) -> integer_to_binary(transit_sdk_value:integer(Value, 0, 18446744073709551615)).
signed(Value) -> integer_to_binary(transit_sdk_value:integer(Value, -9223372036854775808, 9223372036854775807)).
enum(Value, Choices) -> case lists:member(Value, Choices) of true -> atom_to_binary(Value, utf8); false -> transit_sdk_value:fail(invalid_argument, enum) end.
cell(null, _, _) -> #{<<"null">> => #{}};
cell(Value, int64, _) -> #{<<"int64">> => signed(Value)};
cell(Value, boolean, _) when is_boolean(Value) -> #{<<"boolean">> => Value};
cell(Value, utf8, Limit) -> #{<<"utf8">> => transit_sdk_value:text(Value, Limit)};
cell(Value, binary, Limit) -> #{<<"binary">> => transit_sdk_value:hex(transit_sdk_value:bytes(Value, Limit))};
cell(_, _, _) -> transit_sdk_value:fail(invalid_argument, table_cell).
cell_value(#{<<"null">> := _}, _) -> null;
cell_value(#{<<"int64">> := Value}, _) -> transit_sdk_value:signed(Value);
cell_value(#{<<"boolean">> := Value}, _) -> transit_sdk_value:boolean(Value);
cell_value(#{<<"utf8">> := Value}, Limit) -> transit_sdk_value:text(Value, Limit);
cell_value(#{<<"binary">> := Value}, Limit) -> transit_sdk_value:unhex(Value, Limit).
