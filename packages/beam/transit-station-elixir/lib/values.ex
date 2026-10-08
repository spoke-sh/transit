defmodule Transit.Station.Sdk.Activation do
  @enforce_keys [:process, :generation, :credential]
  defstruct [:process, :generation, :credential]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.ServiceConfig do
  @enforce_keys [:client, :activation]
  defstruct [:client, :activation, association: "data", query_results: false]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Key do
  @enforce_keys [:name, :codec]
  defstruct [:name, :codec]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Incoming do
  @enforce_keys [:kind, :value, :position, :origin]
  defstruct [:kind, :value, :position, :origin, correlation: nil]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Control do
  @enforce_keys [:kind, :position, :origin, :correlation]
  defstruct [:kind, :position, :origin, :correlation]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.QueryFailure do
  @enforce_keys [:position, :origin, :correlation, :result, :reason]
  defstruct [:position, :origin, :correlation, :result, :reason]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.ResultComplete do
  @enforce_keys [:position, :origin, :correlation]
  defstruct [:position, :origin, :correlation]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.ReadVersion do
  @enforce_keys [:pid, :input, :index]
  defstruct [:pid, :input, :index]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Page do
  @enforce_keys [:entries]
  defstruct [:entries, cursor: nil]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.KVEntry do
  @enforce_keys [:key, :value, :revision]
  @derive {Inspect, only: [:revision]}
  defstruct [:key, :value, :revision]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Row do
  @enforce_keys [:identity, :cells]
  @derive {Inspect, only: [:identity]}
  defstruct [:identity, :cells]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.TableBasis do
  @enforce_keys [:resource, :revision, :object, :head]
  defstruct [:resource, :revision, :object, :head]
end

defmodule Transit.Station.Sdk.TablePage do
  @enforce_keys [:rows]
  defstruct [:rows, next: nil]
end

defmodule Transit.Station.Sdk.TableCreation do
  @enforce_keys [:state, :admitted_input]
  defstruct [:state, :admitted_input, completed_input: nil]
end

defmodule Transit.Station.Sdk.TableWitness do
  @enforce_keys [:source, :column, :text, :truncated]
  @derive {Inspect, only: [:source, :column, :truncated]}
  defstruct [:source, :column, :text, :truncated, row: nil]
end

defmodule Transit.Station.Sdk.TableStatus do
  @enforce_keys [:reference, :state, :route, :admitted_input, :rejection]
  defstruct [
    :reference,
    :state,
    :route,
    :admitted_input,
    :rejection,
    completed_input: nil,
    counts: nil,
    witness: nil
  ]
end

defmodule Transit.Station.Sdk.QueryJob do
  @enforce_keys [:result, :correlation, :source]
  defstruct [:result, :correlation, :source]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Manifest do
  @enforce_keys [
    :result,
    :source,
    :destination,
    :correlation,
    :table,
    :policy_revision,
    :basis,
    :plan,
    :segments,
    :byte_count,
    :rows,
    :chain,
    :schema
  ]
  defstruct [
    :result,
    :source,
    :destination,
    :correlation,
    :table,
    :policy_revision,
    :basis,
    :plan,
    :segments,
    :byte_count,
    :rows,
    :chain,
    :schema
  ]

  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.IpcSegment do
  @enforce_keys [:manifest, :ordinal, :rows, :digest, :ipc]
  @derive {Inspect, only: [:ordinal, :rows, :digest]}
  defstruct [:manifest, :ordinal, :rows, :digest, :ipc]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.FrozenMutation do
  @enforce_keys [:identity, :purpose, :input, :bytes]
  @derive {Inspect, only: [:identity, :purpose, :input]}
  defstruct [:identity, :purpose, :input, :bytes]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Committed do
  @enforce_keys [:input, :receipt]
  defstruct [:input, :receipt]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Blocked do
  defstruct input: nil, receipt: nil
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.NeedsRecovery do
  @enforce_keys [:mutation, :phase, :error]
  defstruct [:mutation, :phase, :error, receipt: nil]
  @type t :: %__MODULE__{}
end

defmodule Transit.Station.Sdk.Shutdown do
  defstruct pending: nil, last_event: nil
  @type t :: %__MODULE__{}
end
