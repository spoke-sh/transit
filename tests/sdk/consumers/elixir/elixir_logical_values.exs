alias Transit.Station.Sdk.Logical, as: L
alias Transit.Station.Sdk.Logical.{Field, Element, Alternative}

round = fn kind, value ->
  {:ok, wire} = L.encode(kind, value)
  {:ok, ^value} = L.decode(kind, wire)
end

bounded = %Field{
  name: "label",
  type: :utf8,
  nullable: true,
  optional: true,
  max_characters: 4_294_967_295
}

round.(:type, {:structure, [%Field{name: "inner", type: {:tagged_union, [bounded]}}]})

for maximum <- [0, -1, 1.5, true, false, 4_294_967_296] do
  {:error, _} = L.encode(:type, {:structure, [%{bounded | max_characters: maximum}]})
end

{:error, _} = L.encode(:type, {:structure, [%{bounded | type: :binary}]})
{:ok, %{"structure" => [field]}} = L.encode(:type, {:structure, [bounded]})
{:error, _} = L.decode(:type, %{"structure" => [Map.delete(field, "max_characters")]})

for type <- [
      :capability,
      {:structure, [%Field{name: "東京", type: {:decimal, 38, 2}, nullable: true}]},
      {:tagged_union, [%Field{name: "value", type: :uuid, optional: true}]},
      {:list, %Element{type: :int128}},
      {:array, %Element{type: :uint128, nullable: true}, 2},
      {:map, :utf8, %Element{type: {:timestamp, :utc}}}
    ],
    do: round.(:type, type)

for kind <- [:unknown, :null_value, :text, :character] do
  round.(:cell, {:type_error, kind})
  {:error, _} = L.encode(:type, kind)
end

conflict =
  {:conflict,
   [
     %Alternative{counter: 1, replica: 1, value: :null},
     %Alternative{counter: 1, replica: 2, value: {:value, {:atom, {:boolean, true}}}}
   ]}

deep = Enum.reduce(1..15, conflict, fn _, value -> {:value, {:list, [value]}} end)
round.(:cell, deep)

{:error, %Transit.Client.Error{kind: :invalid_argument}} =
  L.encode(:cell, {:value, {:list, [deep]}})

round.(:atom, {:signed, -170_141_183_460_469_231_731_687_303_715_884_105_728})
round.(:atom, {:unsigned, 340_282_366_920_938_463_463_374_607_431_768_211_455})

round.(
  :cell,
  {:value, {:map, [{{:utf8, "k"}, {:value, {:atom, {:binary, :binary.copy(<<0>>, 300_000)}}}}]}}
)

{:ok, %{"float_bits" => "00000080"}} = L.encode(:atom, {:float32, -0.0})
{:error, %Transit.Client.Error{kind: :incompatible_native}} = L.decode(:atom, %{"signed" => "01"})
# Host-to-record projection is bounded before the shared logical validation.
too_deep = Enum.reduce(1..100, :null, fn _, value -> [value] end)
{:error, %Transit.Client.Error{kind: :invalid_argument}} = L.encode(:cell, too_deep)
IO.puts("Elixir logical structs, recursive values and shared codec checks passed.")
