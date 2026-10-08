defmodule Transit.Station.Sdk.Turn do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]
  @type t :: %__MODULE__{}
  alias Transit.Station.Sdk.Value, as: V
  alias Transit.Client

  def process(%__MODULE__{native: t}), do: V.result(:transit_turn.process(t))
  def resource(%__MODULE__{native: t}), do: V.result(:transit_turn.resource(t))
  def resource_revision(%__MODULE__{native: t}), do: V.result(:transit_turn.resource_revision(t))
  def budgets(%__MODULE__{native: t}), do: V.result(:transit_turn.budgets(t))
  def key(name, codec), do: V.result(:transit_turn.key(name, codec))
  def state(%__MODULE__{native: t}), do: V.result(:transit_turn.state(t))

  def cast(%__MODULE__{native: t}, peer, value, codec),
    do: V.result(:transit_turn.cast(t, Client.native(peer), value, codec))

  def call(%__MODULE__{native: t}, peer, value, codec, wait),
    do: V.result(:transit_turn.call(t, Client.native(peer), value, codec, V.wait(wait)))

  def reply(%__MODULE__{native: t}, value, codec),
    do: V.result(:transit_turn.reply(t, value, codec))

  def require_reply(%__MODULE__{native: t}, reply, peer, correlation),
    do:
      V.result(:transit_turn.require_reply(t, V.native(reply), Client.native(peer), correlation))

  def cancel_call(%__MODULE__{native: t}, correlation),
    do: V.result(:transit_turn.cancel_call(t, correlation))

  def retain(%__MODULE__{native: t}), do: V.result(:transit_turn.retain(t))

  def open_version(%__MODULE__{native: t}, identity),
    do: V.result(:transit_turn.open_version(t, V.native(identity)))

  def release(%__MODULE__{native: t}, identity),
    do: V.result(:transit_turn.release(t, V.native(identity)))
end

defmodule Transit.Station.Sdk.State do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]
  @type t :: %__MODULE__{}
  alias Transit.Station.Sdk.Value, as: V
  def find(%__MODULE__{native: s}, key), do: V.application(:transit_turn.find(s, V.native(key)))

  def require(%__MODULE__{native: s}, key),
    do: V.application(:transit_turn.require(s, V.native(key)))

  def put(%__MODULE__{native: s}, key, value),
    do: V.result(:transit_turn.put(s, V.native(key), value))

  def delete(%__MODULE__{native: s}, key), do: V.result(:transit_turn.delete(s, V.native(key)))

  def page(%__MODULE__{native: s}, cursor \\ nil),
    do: V.result(:transit_turn.page(s, V.optional(cursor)))
end

defmodule Transit.Station.Sdk.Source do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]
  @type t :: %__MODULE__{}
  alias Transit.Station.Sdk.Value, as: V
  def state(%__MODULE__{native: s}), do: V.result(:transit_turn.source_state(s))

  def table(%__MODULE__{native: s}, object),
    do: V.result(:transit_table.open_source(s, object))
end

defmodule Transit.Station.Sdk.Table do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]
  @type t :: %__MODULE__{}
  alias Transit.Station.Sdk.{Value, Turn, Catalog, Logical}

  def create(%Turn{native: t}, schema, limits),
    do: Value.result(:transit_table.create(t, Catalog.native(schema), Catalog.native(limits)))

  def open(%Turn{native: t}, object), do: Value.result(:transit_table.open(t, object))
  def schema(%__MODULE__{native: t}), do: Value.result(:transit_table.schema(t))
  def basis(%__MODULE__{native: t}), do: Value.result(:transit_table.basis(t))
  def get(%__MODULE__{native: t}, identity), do: Value.result(:transit_table.get(t, identity))

  def get_key(%__MODULE__{native: t}, cells),
    do: Value.result(:transit_table.get_key(t, Logical.native(cells)))

  def page(%__MODULE__{native: t}, cursor \\ nil, limit \\ 8),
    do: Value.result(:transit_table.page(t, Value.optional(cursor), limit))

  def prepare(%__MODULE__{native: t}, principal, operation, mutation),
    do: Value.result(:transit_table.prepare(t, principal, operation, Catalog.native(mutation)))
end

defmodule Transit.Station.Sdk.TableMutation do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]
  @type t :: %__MODULE__{}
  alias Transit.Station.Sdk.{Value, Turn, Catalog}

  def prepare(resource, principal, operation, schema, mutation),
    do:
      Value.result(
        :transit_table.prepare(
          Transit.Client.native(resource),
          principal,
          operation,
          Catalog.native(schema),
          Catalog.native(mutation)
        )
      )

  def load(data), do: Value.result(:transit_table.load(data))
  def save(%__MODULE__{native: m}), do: Value.result(:transit_table.save(m))
  def step(%__MODULE__{native: m}, %Turn{native: t}), do: Value.result(:transit_table.step(t, m))
end

defmodule Transit.Station.Sdk.TableMutationReference do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]
  @type t :: %__MODULE__{}
  alias Transit.Station.Sdk.{Value, Turn}
  def load(data), do: Value.result(:transit_table.load_reference(data))
  def save(%__MODULE__{native: r}), do: Value.result(:transit_table.save_reference(r))

  def status(%__MODULE__{native: r}, %Turn{native: t}),
    do: Value.result(:transit_table.status(t, r))

  def cancel(%__MODULE__{native: r}, %Turn{native: t}),
    do: Value.result(:transit_table.cancel(t, r))
end

defmodule Transit.Station.Sdk.Query do
  alias Transit.Station.Sdk.{Value, Turn, UnifiedQuery}

  def allow(%Turn{native: t}, peer, object, revision, allow),
    do:
      Value.result(:transit_query.allow(t, Transit.Client.native(peer), object, revision, allow))

  def start(%Turn{native: t}, object, plan),
    do: Value.result(:transit_query.start(t, object, UnifiedQuery.native(plan)))

  def close(%Turn{native: t}, result, reason),
    do: Value.result(:transit_query.close(t, result, reason))

  def result(%Turn{native: t}, correlation),
    do: Value.result(:transit_query.result(t, correlation))
end

defmodule Transit.Station.Sdk.ResultReader do
  @enforce_keys [:native]
  @derive {Inspect, only: []}
  defstruct [:native]
  @type t :: %__MODULE__{}
  alias Transit.Station.Sdk.Value
  def manifest(%__MODULE__{native: r}), do: Value.result(:transit_query.manifest(r))

  def segment(%__MODULE__{native: r}, ordinal),
    do: Value.result(:transit_query.segment(r, ordinal))
end
