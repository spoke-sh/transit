defmodule Transit.Client.Error do
  @enforce_keys [:kind, :phase]
  @derive {Inspect, only: [:kind, :phase, :status, :code, :diagnostic_invalid]}
  defstruct [:kind, :phase, :status, :code, :diagnostic, diagnostic_invalid: false]

  @type t :: %__MODULE__{
          kind: atom(),
          phase: atom(),
          status: non_neg_integer() | nil,
          code: binary() | nil,
          diagnostic: map() | nil,
          diagnostic_invalid: boolean()
        }
end

defmodule Transit.Client.ProcessRef do
  @enforce_keys [:realm, :pid]
  defstruct [:realm, :pid]
  @type t :: %__MODULE__{realm: pos_integer(), pid: pos_integer()}
end

defmodule Transit.Client.ResourceRef do
  @enforce_keys [:realm, :resource]
  defstruct [:realm, :resource]
end

defmodule Transit.Client.Credential do
  @enforce_keys [:realm, :principal, :seed_file]
  @derive {Inspect, only: [:realm, :principal]}
  defstruct [:realm, :principal, :seed_file]
end

defmodule Transit.Client.Config do
  @enforce_keys [:url, :profile]
  defstruct [:url, :profile, :native_host, timeout_ms: 5000]
end

defmodule Transit.Client.Identity do
  @enforce_keys [:sha256]
  defstruct [:sha256]
  @type t :: %__MODULE__{}
end

defmodule Transit.Client.AdmissionReceipt do
  @enforce_keys [:position]
  defstruct [:position]
end

defmodule Transit.Client.MutationReceipt do
  @enforce_keys [:position]
  defstruct [:position]
  @type t :: %__MODULE__{}
end

defmodule Transit.Client.Pending do
  @moduledoc "Opaque, immutable native retry material. Persist export/1 before dispatch."
  @enforce_keys [:kind, :info, :native]
  @derive {Inspect, only: [:kind, :info]}
  defstruct [:kind, :info, :native]
end

defmodule Transit.Client.Uncertain do
  @enforce_keys [:recovery, :error]
  @derive {Inspect, only: [:error]}
  defstruct [:recovery, :error]
end

defmodule Transit.Client.Shutdown do
  defstruct [:last_admission, :last_mutation]
end

defmodule Transit.Client do
  @moduledoc """
  Independent public client over an owned OTP/native bridge. Task cancellation
  abandons a local wait; admitted native work continues. Observe acquisition and
  close results explicitly. A local BEAM PID is never a durable ProcessRef.
  """
  alias Transit.Client.{Config, Credential, ProcessRef, ResourceRef, Pending}

  def config(url, profile, options \\ %{}),
    do: convert(:transit_client.config(url, profile, options))

  def process(realm, pid), do: convert(:transit_client.process(realm, pid))
  def resource(realm, resource), do: convert(:transit_client.resource(realm, resource))

  def credential(realm, principal, seed_file),
    do: convert(:transit_client.credential(realm, principal, seed_file))

  def open(%Config{} = config) do
    with :ok <- compatible(), do: convert(:transit_client.open(native(config)))
  end

  def start_link(%Config{} = config) do
    with :ok <- compatible(), do: :transit_client.start_link(native(config))
  end

  def child_spec(%Config{} = config),
    do: %{:transit_client.child_spec(native(config)) | start: {__MODULE__, :start_link, [config]}}

  defp compatible do
    :application.load(:transit_client)

    case :application.get_key(:transit_client, :vsn) do
      {:ok, ~c"0.0.1"} -> :ok
      _ -> {:error, %Transit.Client.Error{kind: :incompatible_native, phase: :client_sdk_version}}
    end
  end

  def handle(pid), do: convert(:transit_client.handle(pid))
  def close(client), do: convert(:transit_client.close(client))

  def capabilities(client, %Credential{} = credential),
    do: convert(:transit_client.capabilities(client, native(credential)))

  def prepare_send(client, %ProcessRef{} = peer, bytes, %Credential{} = credential, sequence),
    do:
      convert(
        :transit_client.prepare_send(client, native(peer), bytes, native(credential), sequence)
      )

  def recover_send(client, bytes), do: convert(:transit_client.recover_send(client, bytes))

  def recover_mutation(client, bytes),
    do: convert(:transit_client.recover_mutation(client, bytes))

  def dispatch(client, %Pending{kind: :send, native: pending}),
    do: convert(:transit_client.dispatch(client, pending))

  def dispatch_mutation(client, %Pending{kind: :mutation, native: pending}),
    do: convert(:transit_client.dispatch_mutation(client, pending))

  def export(%Pending{native: pending}), do: :transit_client.export(pending)
  def info(%Pending{info: info}), do: info
  def evidence(client), do: convert(:transit_client.evidence(client))

  @doc false
  def native(%Config{} = value),
    do:
      {:transit_config, value.url, value.profile, value.timeout_ms,
       value.native_host || :undefined}

  def native(%Credential{} = value),
    do: {:transit_credential, value.realm, value.principal, value.seed_file}

  def native(%ProcessRef{} = value), do: {:transit_process, value.realm, value.pid}
  def native(%ResourceRef{} = value), do: {:transit_resource, value.realm, value.resource}

  @doc false
  def convert({:ok, value}), do: {:ok, convert(value)}
  def convert({:error, value}), do: {:error, convert(value)}
  def convert({:error, error, evidence}), do: {:error, convert(error), convert(evidence)}

  def convert({kind, value}) when kind in [:admitted, :confirmed, :rejected],
    do: {kind, convert(value)}

  def convert({:uncertain, bytes, error}),
    do: {:uncertain, %Transit.Client.Uncertain{recovery: bytes, error: convert(error)}}

  def convert({:transit_error, kind, phase, status, code, diagnostic, invalid}),
    do: %Transit.Client.Error{
      kind: kind,
      phase: phase,
      status: convert(status),
      code: convert(code),
      diagnostic: convert(diagnostic),
      diagnostic_invalid: invalid
    }

  def convert({:transit_config, url, profile, timeout, host}),
    do: %Config{url: url, profile: profile, timeout_ms: timeout, native_host: convert(host)}

  def convert({:transit_process, realm, pid}), do: %ProcessRef{realm: realm, pid: pid}

  def convert({:transit_resource, realm, resource}),
    do: %ResourceRef{realm: realm, resource: resource}

  def convert({:transit_credential, realm, principal, seed}),
    do: %Credential{realm: realm, principal: principal, seed_file: seed}

  def convert({:transit_identity, sha}), do: %Transit.Client.Identity{sha256: sha}

  def convert({:transit_admission, position}),
    do: %Transit.Client.AdmissionReceipt{position: position}

  def convert({:transit_receipt, position}),
    do: %Transit.Client.MutationReceipt{position: position}

  def convert({:transit_pending, kind, info, _bytes} = native),
    do: %Pending{kind: kind, info: convert(info), native: native}

  def convert({:transit_shutdown, admission, mutation}),
    do: %Transit.Client.Shutdown{
      last_admission: convert(admission),
      last_mutation: convert(mutation)
    }

  def convert(:undefined), do: nil

  def convert(value) when is_map(value),
    do: Map.new(value, fn {key, child} -> {key, convert(child)} end)

  def convert(value), do: value
end
