defmodule Transit.Station.Sdk.Logical.Field do
  @enforce_keys [:name, :type]
  @derive {Inspect, only: [:name, :nullable, :optional]}
  defstruct [:name, :type, nullable: false, optional: false]
end

defmodule Transit.Station.Sdk.Logical.Element do
  @enforce_keys [:type]
  @derive {Inspect, only: [:nullable]}
  defstruct [:type, nullable: false]
end

defmodule Transit.Station.Sdk.Logical.Alternative do
  @enforce_keys [:counter, :replica, :value]
  @derive {Inspect, only: [:counter, :replica]}
  defstruct [:counter, :replica, :value]
end

defmodule Transit.Station.Sdk.Logical do
  @moduledoc """
  Owned recursive logical descriptors and five-state cells. Tagged values retain
  exact wide integers, explicit float widths and structured nested data. Encode
  and decode return `{:ok, value}` or `{:error, %Transit.Client.Error{}}`.
  """
  alias Transit.Client
  alias __MODULE__.{Field, Element, Alternative}

  def encode(kind, value) when kind in [:type, :atom, :cell] do
    :transit_logical.encode(kind, native(value)) |> Client.convert()
  rescue
    ArgumentError -> {:error, %Client.Error{kind: :invalid_argument, phase: :logical_value}}
  end

  def decode(kind, wire) when kind in [:type, :atom, :cell] do
    case :transit_logical.decode(kind, wire) do
      {:ok, value} -> {:ok, convert(value)}
      error -> Client.convert(error)
    end
  end

  # Projection has its own finite structural budget before Erlang checks the
  # logical depth/node/data limits. No caller binary is converted to an atom.
  @doc false
  def native(value), do: project(value, :native)
  @doc false
  def convert(value), do: project(value, :public)

  defp project(value, direction) do
    {result, _} = walk(value, direction, 0, 1_000_000)
    result
  end

  defp walk(_, _, depth, left) when depth > 96 or left <= 0,
    do: raise(ArgumentError, "Logical projection bound")

  defp walk(%Field{} = v, :native, depth, left),
    do:
      tagged(
        :transit_logical_field,
        [v.name, v.type, v.nullable, v.optional],
        :native,
        depth,
        left
      )

  defp walk(%Element{} = v, :native, depth, left),
    do: tagged(:transit_logical_element, [v.type, v.nullable], :native, depth, left)

  defp walk(%Alternative{} = v, :native, depth, left),
    do:
      tagged(:transit_logical_alternative, [v.counter, v.replica, v.value], :native, depth, left)

  defp walk({:transit_logical_field, name, type, nullable, optional}, :public, depth, left) do
    {[n, t, z, o], next} = children([name, type, nullable, optional], :public, depth, left)
    {%Field{name: n, type: t, nullable: z, optional: o}, next}
  end

  defp walk({:transit_logical_element, type, nullable}, :public, depth, left) do
    {[t, z], next} = children([type, nullable], :public, depth, left)
    {%Element{type: t, nullable: z}, next}
  end

  defp walk({:transit_logical_alternative, counter, replica, value}, :public, depth, left) do
    {[c, r, v], next} = children([counter, replica, value], :public, depth, left)
    {%Alternative{counter: c, replica: r, value: v}, next}
  end

  defp walk(values, direction, depth, left) when is_list(values),
    do: children(values, direction, depth, left)

  defp walk(value, direction, depth, left) when is_tuple(value) do
    {values, next} = children(Tuple.to_list(value), direction, depth, left)
    {List.to_tuple(values), next}
  end

  defp walk(value, _, _, left), do: {value, left - 1}

  defp children(values, direction, depth, left),
    do: Enum.map_reduce(values, left - 1, &walk(&1, direction, depth + 1, &2))

  defp tagged(tag, values, direction, depth, left) do
    {result, next} = children(values, direction, depth, left)
    {List.to_tuple([tag | result]), next}
  end
end
